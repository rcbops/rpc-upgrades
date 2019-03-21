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
  elif [[ -f "${UPGRADES_WORKING_DIR}/openstack-release.upgrade" ]]; then
    source ${UPGRADES_WORKING_DIR}/openstack-release.upgrade
    determine_release
  else
    source /etc/openstack-release
    determine_release
  fi
}

function determine_release {
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
}

# Fail if Ubuntu Major release is not the minimum required for a given OpenStack upgrade
function require_ubuntu_version {
  REQUIRED_VERSION="$1"
  if [ "$(lsb_release -r | cut -f2 -d$'\t' | cut -f1 -d$'.')" -lt "$REQUIRED_VERSION" ]; then
    echo "Please upgrade to Ubuntu "$REQUIRED_VERSION" before attempting to upgrade OpenStack"
    exit 99
  fi
}

function ensure_working_dir {
  if [ ! -d "${UPGRADES_WORKING_DIR}" ]; then
    mkdir -p ${UPGRADES_WORKING_DIR}
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
    git fetch --all
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

function ensure_osa_bootstrap {
  if [ ! -f "/etc/openstack_deploy/osa_bootstrapped.complete" ]; then
    # purge osa and wrapper so that we start fresh without RPC-O settings
    if [ -d "/opt/openstack-ansible" ]; then
      rm -rf /opt/openstack-ansible
      rm -f /usr/local/bin/openstack-ansible
      rm -f /usr/local/bin/openstack-ansible.rc
    fi
  fi
  checkout_openstack_ansible
  pushd /opt/openstack-ansible
    scripts/bootstrap-ansible.sh
  popd
  touch /etc/openstack_deploy/osa_bootstrapped.complete
}


function configure_rpc_openstack {
  rsync -av --delete /opt/rpc-openstack/etc/openstack_deploy/group_vars /etc/openstack_deploy/
  rm -rf /opt/rpc-ansible
  virtualenv /opt/rpc-ansible
  install_ansible_source
  pushd /opt/rpc-openstack/playbooks
    /opt/rpc-ansible/bin/ansible-playbook -i 'localhost,' site-release.yml
  popd
  # clean out any existing env.d inventory
  if [ -d "/etc/openstack_deploy/env.d" ]; then
    rm -rf /etc/openstack_deploy/env.d
  fi
}

function install_ansible_source {
  DEBIAN_FRONTEND=noninteractive apt-get -y install \
                                            gcc libssl-dev libffi-dev \
                                            python-apt python3-apt \
                                            python-dev python3-dev \
                                            python-minimal python-virtualenv

  /opt/rpc-ansible/bin/pip install --isolated "ansible==${RPC_ANSIBLE_VERSION}"
}

function run_upgrade {
  pushd /opt/openstack-ansible
    export TERM=linux
    export I_REALLY_KNOW_WHAT_I_AM_DOING=true
    export SETUP_ARA=true
    export ANSIBLE_CALLBACK_PLUGINS=/etc/ansible/roles/plugins/callback:/opt/ansible-runtime/local/lib/python2.7/site-packages/ara/plugins/callbacks

    # Destroy repo container prior to the upgrade to reduce "No space left on device" issues
    pushd /opt/openstack-ansible/playbooks
      openstack-ansible lxc-containers-destroy.yml -e force_containers_destroy=true -e force_containers_data_destroy=true --limit repo_container
      openstack-ansible lxc-containers-create.yml --limit repo-infra_all -e lxc_container_fs_size=10G
    popd

    # ensure no traces of rpco repos that may have come from lxc-cache
    pushd /opt/rpc-upgrades/incremental/playbooks
      openstack-ansible remove-rpco-repos.yml
    popd

    # Remove pip from deploy host to prevent issues before repo has been rebuilt
    if [ -f /root/.pip/pip.conf ]; then
      rm /root/.pip/pip.conf
    fi

    # Run upgrade
    echo "YES" | bash scripts/run-upgrade.sh
  popd
}

function generate_upgrade_config {
  # generate user_rpco_upgrade.yml
  pushd /opt/rpc-upgrades/incremental/playbooks
    openstack-ansible rpco-upgrade-configs.yml
  popd
}

function prepare_ocata {
  pushd /opt/rpc-upgrades/incremental/playbooks
    openstack-ansible configure-lxc-backend.yml

    if [[ ! -f "/etc/openstack_deploy/ocata_upgrade_prep.complete" ]]; then
      openstack-ansible prepare-ocata-upgrade.yml
    fi

    if [[ ! -f "/etc/openstack_deploy/ocata_migrate.complete" ]]; then
      openstack-ansible create-cell0.yml
      openstack-ansible db-migration-ocata.yml
    fi
  popd
}

function prepare_pike {
  pushd /opt/rpc-upgrades/incremental/playbooks
    openstack-ansible configure-lxc-backend.yml
  popd

  pushd /opt/openstack-ansible
    # patch in restarting of containers into run-upgrade
    cp /opt/rpc-upgrades/playbooks/patches/pike/lxc-containers-restart.yml /opt/openstack-ansible/scripts/upgrade-utilities/playbooks
    cp /opt/rpc-upgrades/playbooks/patches/pike/run-upgrade.patch /opt/openstack-ansible
    patch -p1 < run-upgrade.patch
  popd
}

function prepare_queens {
  pushd /opt/rpc-upgrades/incremental/playbooks
    openstack-ansible configure-lxc-backend.yml

    if [[ ! -f "/etc/openstack_deploy/queens_upgrade_prep.complete" ]]; then
      openstack-ansible prepare-queens-upgrade.yml
    fi
  popd
}

function prepare_rocky {
  echo "Rocky prepare steps go here..."
}

function cleanup {
  if [ -f "/etc/openstack_deploy/user_rpco_upgrade.yml" ]; then
    rm /etc/openstack_deploy/user_rpco_upgrade.yml
  fi
}

function mark_started {
  echo "Starting ${RPC_PRODUCT_RELEASE^} upgrade..."
  ensure_working_dir
  if [ ! -f ${UPGRADES_WORKING_DIR}/upgrade-to-${RPC_PRODUCT_RELEASE}.started ]; then
    cp /etc/openstack-release ${UPGRADES_WORKING_DIR}/openstack-release.upgrade
  fi
  touch ${UPGRADES_WORKING_DIR}/upgrade-to-${RPC_PRODUCT_RELEASE}.started
}

function mark_completed {
  echo "Completing ${RPC_PRODUCT_RELEASE^} upgrade..."
  touch ${UPGRADES_WORKING_DIR}/upgrade-to-${RPC_PRODUCT_RELEASE}.complete
}
