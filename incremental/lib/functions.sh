#!/usr/bin/env bash

# Copyright 2018, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# functions for incremental upgrades

function discover_code_version {
  if [[ ! -f "/etc/openstack-release" ]]; then
      failure "No release file could be found, failing..."
      exit 99
  else
      source /etc/openstack-release
      case "${DISTRIB_RELEASE%%.*}" in
        *14|newton-eol)
          export CODE_UPGRADE_FROM="newton"
          echo "You seem to be running Newton"
        ;;
        *15|ocata)
           export CODE_UPGRADE_FROM="ocata"
           echo "You seem to be running Ocata"
          ;;
        *16|pike)
           export CODE_UPGRADE_FROM="pike"
           echo "You seem to be running Pike"
        ;;
        *17|queens)
           export CODE_UPGRADE_FROM="queens"
           echo "You seem to be running Queens"
        ;;
        *)
           echo "Unable to detect current OpenStack version, failing...."
           exit 99
        esac
    fi
}

# Fail if Ubuntu Major release is not the minimum required for a given OpenStack upgrade
function require_ubuntu_version {
  REQUIRED_VERSION="$1"
  if [ "$(lsb_release -r | cut -f2 -d$'\t' | cut -f1 -d$'.')" -lt "$REQUIRED_VERSION" ]; then
    echo "Please upgrade to Ubuntu "$REQUIRED_VERSION" before attempting to upgrade OpenStack"
    exit 99
  fi
}

function pre_flight {
    ## Pre-flight Check ----------------------------------------------------------
    # Clear the screen and make sure the user understands whats happening.
    clear

    # Notify the user.
    echo -e "
    Once you start the upgrade there is no going back.
    This script will guide you through the process of
    upgrading RPC-O from:

    ${CODE_UPGRADE_FROM^} to ${TARGET^}

    Note that the upgrade targets impacting the data
    plane as little as possible, but assumes that the
    control plane can experience some down time.

    This script executes a one-size-fits-all upgrade,
    and given that the tests implemented for it are
    not monitored as well as those for a greenfield
    environment, the results may vary with each release.

    Please use it against a test environment with your
    configurations to validate whether it suits your
    needs and does a suitable upgrade.

    Are you ready to perform this upgrade now?
    "

    # Confirm the user is ready to upgrade.
    read -p 'Enter "YES" to continue or anything else to quit: ' UPGRADE
    if [ "${UPGRADE}" == "YES" ]; then
      echo "Running Upgrade from ${CODE_UPGRADE_FROM^} to ${TARGET^}"
    else
      exit 99
    fi
}

function check_user_variables {
  if [[ ! -f /etc/openstack_deploy/user_variables.yml ]]; then
     echo "---" > /etc/openstack_deploy/user_variables.yml
     echo "default_bind_mount_logs: False" >> /etc/openstack_deploy/user_variables.yml
  elif [[ -f /etc/openstack_deploy/user_variables.yml ]]; then
     if ! grep -i -q "default_bind_mount_logs" /etc/openstack_deploy/user_variables.yml; then
       echo "default_bind_mount_logs: False" >> /etc/openstack_deploy/user_variables.yml
     fi
  fi
}

function checkout_rpc_openstack {
  pushd /opt/rpc-openstack
    git clean -df
    git reset --hard HEAD
    rm -rf openstack-ansible
    rm -rf scripts/artifacts-building/
    git checkout ${RPC_BRANCH}
  popd
}

function checkout_openstack_ansible {
  if [ ! -d "/opt/openstack-ansible" ]; then
    git clone --recursive https://github.com/openstack/openstack-ansible /opt/openstack-ansible
    pushd /opt/openstack-ansible
      git checkout ${OSA_SHA}
    popd
  else
    pushd /opt/openstack-ansible
      git reset --hard HEAD
      git fetch --all
      git checkout ${OSA_SHA}
    popd
  fi
}

function set_keystone_flush_memcache {
  if [[ ! -f /etc/openstack_deploy/user_rpco_upgrade.yml ]]; then
     echo "---" > /etc/openstack_deploy/user_rpco_upgrade.yml
     echo "keystone_flush_memcache: yes" >> /etc/openstack_deploy/user_rpco_upgrade.yml
  elif [[ -f /etc/openstack_deploy/user_rpco_upgrade.yml ]]; then
    if ! grep -i "keystone_flush_memcache" /etc/openstack_deploy/user_rpco_upgrade.yml; then
      echo "keystone_flush_memcache: yes" >> /etc/openstack_deploy/user_rpco_upgrade.yml
    fi
  fi
}

function disable_hardening {
  if [[ ! -f /etc/openstack_deploy/user_rpco_upgrade.yml ]]; then
     echo "---" > /etc/openstack_deploy/user_rpco_upgrade.yml
     echo "apply_security_hardening: false" >> /etc/openstack_deploy/user_rpco_upgrade.yml
  elif [[ -f /etc/openstack_deploy/user_rpco_upgrade.yml ]]; then
    if ! grep -i "apply_security_hardening" /etc/openstack_deploy/user_rpco_upgrade.yml; then
      echo "apply_security_hardening: false" >> /etc/openstack_deploy/user_rpco_upgrade.yml
    fi
  fi
}

function set_secrets_file {
  if [ -f "/etc/openstack_deploy/user_secrets.yml" ]; then
    if ! grep "^osa_secrets_file_name" /etc/openstack_deploy/user_rpco_upgrade.yml; then
      echo 'osa_secrets_file_name: "user_secrets.yml"' >> /etc/openstack_deploy/user_rpco_upgrade.yml
    fi
  elif [ -f "/etc/openstack_deploy/user_osa_secrets.yml" ]; then
    if ! grep "^osa_secrets_file_name" /etc/openstack_deploy/user_rpco_upgrade.yml; then
      echo 'osa_secrets_file_name: "user_osa_secrets.yml"' >> /etc/openstack_deploy/user_rpco_upgrade.yml
    fi
  fi
}

function run_upgrade {
  pushd /opt/openstack-ansible
    export TERM=linux
    export I_REALLY_KNOW_WHAT_I_AM_DOING=true
    export SETUP_ARA=true
    export ANSIBLE_CALLBACK_PLUGINS=/etc/ansible/roles/plugins/callback:/opt/ansible-runtime/local/lib/python2.7/site-packages/ara/plugins/callbacks
    echo "YES" | bash scripts/run-upgrade.sh
  popd
}

function strip_install_steps {
  pushd /opt/openstack-ansible/scripts
    sed -i '/RUN_TASKS+=("[a-z]/d' run-upgrade.sh
    sed -i "/memcached-flush.yml/d" run-upgrade.sh
    sed -i "/galera-cluster-rolling-restart/d" run-upgrade.sh
  popd
}

# Because we are upgrading in place using OSA tooling, rpc_release (defined in /etc/openstack_deploy)
function set_rpc_release {
  RPC_RELEASE=$(awk "/$RPC_BRANCH/,/rpc_release/ {print \$2}" /opt/rpc-openstack/playbooks/vars/rpc-release.yml | tail -1)
  sed -i "s/^\(rpc_release:\).*/\1 \"$RPC_RELEASE\"/" /etc/openstack_deploy/group_vars/all/release.yml
}

function prepare_ocata {
  pushd /opt/rpc-upgrades/incremental/playbooks
    openstack-ansible prepare-ocata-upgrade.yml
  popd
}

function prepare_pike {
  pushd /opt/openstack-ansible
    # patch in restarting of containers into run-upgrade
    cp /opt/rpc-upgrades/playbooks/patches/pike/lxc-containers-restart.yml /opt/openstack-ansible/scripts/upgrade-utilities/playbooks
    cp /opt/rpc-upgrades/playbooks/patches/pike/run-upgrade.patch /opt/openstack-ansible
    patch -p1 < run-upgrade.patch
  popd
}

function prepare_queens {
  echo "Queens prepare steps go here..."
}

function prepare_rocky {
  echo "Rocky prepare steps go here..."
}
