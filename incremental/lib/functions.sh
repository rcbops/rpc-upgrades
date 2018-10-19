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

function prepare_ocata {
  pushd /opt/rpc-upgrades/incremental/playbooks
    openstack-ansible prepare-ocata-upgrade.yml
  popd
}

function prepare_pike {
  pushd /opt/openstack-ansible
    # remove once https://review.openstack.org/#/c/604804/ merges
    sed -i '/- name: os_keystone/,+3d' /opt/openstack-ansible/ansible-role-requirements.yml
    cat <<EOF >> /opt/openstack-ansible/ansible-role-requirements.yml
- name: os_keystone
  scm: git
  src: https://github.com/antonym/openstack-ansible-os_keystone.git
  version: 7af19232541b74726133a01c140b42828c2c59d7
EOF
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
