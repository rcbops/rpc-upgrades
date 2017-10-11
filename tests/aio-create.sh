#!/usr/bin/env bash

# Copyright 2017, Rackspace US, Inc.
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


## Shell Opts ----------------------------------------------------------------

set -eovu

echo "Building an AIO"
echo "+-------------------- AIO ENV VARS --------------------+"
env
echo "+-------------------- AIO ENV VARS --------------------+"

## Vars ----------------------------------------------------------------------
export IRR_CONTEXT="${IRR_CONTEXT:-master}"
# NOTE(cloudnull): The series parameter is unused for now, We need to change
#                  the gate job to contain checkout for our test matrix.
# export IRR_SERIES="${IRR_SERIES:-undefined}"
export IRR_SERIES="undefined"  # This should be reverted when the gate jobs are pointed at specific checkouts.

export TESTING_HOME="${TESTING_HOME:-$HOME}"
export ANSIBLE_LOG_DIR="${TESTING_HOME}/.ansible/logs"
export ANSIBLE_LOG_PATH="${ANSIBLE_LOG_DIR}/ansible-aio.log"
export OSA_PATH="/opt/rpc-openstack/openstack-ansible"

## Functions -----------------------------------------------------------------
function pin_jinja {
  # Pin Jinja2 because versions >2.9 is broken w/ earlier versions of Ansible.
  if [[ -f "${OSA_PATH}/global-requirement-pins.txt" ]]; then
    if ! grep -i 'jinja2' ${OSA_PATH}/global-requirement-pins.txt; then
      echo 'Jinja2==2.8' | tee -a ${OSA_PATH}/global-requirement-pins.txt
    else
      sed -i 's|^Jinja2.*|Jinja2==2.8|g' ${OSA_PATH}/global-requirement-pins.txt
    fi
  fi

  if [[ -f "${OSA_PATH}/requirements.txt" ]]; then
    sed -i 's|^Jinja2.*|Jinja2==2.8|g' ${OSA_PATH}/requirements.txt
  fi
}

function pin_galera {
  # NOTE(cloudnull): The MariaDB repos in these releases used https, this broke the deployment.
  #                  These patches simply point at the same repos just without https.
  # Create the configuration dir if it's not present
  if [[ ! -d "/etc/openstack_deploy" ]]; then
    mkdir -p /etc/openstack_deploy
  fi

  cat > /etc/openstack_deploy/user_rpco_galera.yml <<EOF
---
galera_client_apt_repo_url: "http://mirror.rackspace.com/mariadb/repo/${1}/ubuntu"
galera_apt_repo_url: "http://mirror.rackspace.com/mariadb/repo/${1}/ubuntu"
galera_apt_percona_xtrabackup_url: "http://repo.percona.com/apt"
EOF
}

function disable_security_role {
  # NOTE(cloudnull): The security role is tested elsewhere, there's no need to run it here.
  if [[ ! -d "/etc/openstack_deploy" ]]; then
    mkdir -p /etc/openstack_deploy
  fi
  echo "apply_security_hardening: false" | tee -a /etc/openstack_deploy/user_nosec.yml
}

function git_checkout {
  # Checkout the provided when the series undefined
  if [ "${IRR_SERIES}" == "undefined" ]; then
    git checkout "${1}"
  else
    git checkout "${IRR_SERIES}"
  fi
}

function set_gating_vars {
  # NOTE(cloudnull): Set gate specific vars needed for AIOs.
  if [[ ! -d "/etc/openstack_deploy" ]]; then
    mkdir -p /etc/openstack_deploy
  fi

  cat > /etc/openstack_deploy/user_rpco_leap.yml <<EOF
---
neutron_legacy_ha_tool_enabled: true
lxc_container_backing_store: dir
EOF
}

function kilo_caches {
  # NOTE(cloudnull): Set variables to ensure Kilo caches are functional.
  cat > /etc/openstack_deploy/user_kilo_caches.yml <<EOF
---
repo_mirror_excludes:
  - '/repos'
  - '/mirror'
  - '/rpcgit'
  - '/openstackgit'
  - '/python_packages'
  - '/lxc-images'

lxc_cache_commands:
  - 'apt-get update'
  - 'apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y upgrade'
  - 'apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y install python2.7'
  - 'rm -f /usr/bin/python'
  - 'ln -s /usr/bin/python2.7 /usr/bin/python'
EOF
}

function unset_affinity {
  # NOTE(cloudnull) This RPC release used affinity groups which are not needed
  #                 for this test.
  # Change Affinity - only create 1 galera/rabbit/keystone/horizon and repo server
  sed -i 's/\(_container\: \).*/\11/' ${OSA_PATH}/etc/openstack_deploy/openstack_user_config.yml.aio
}

## Main ----------------------------------------------------------------------

echo "Gate test starting
with:
  IRR_CONTEXT: ${IRR_CONTEXT}
  IRR_SERIES: ${IRR_SERIES}
  TESTING_HOME: ${TESTING_HOME}
  ANSIBLE_LOG_PATH: ${ANSIBLE_LOG_PATH}
"

if [[ -d "${TESTING_HOME}/.ansible" ]]; then
  mv "${TESTING_HOME}/.ansible" "${TESTING_HOME}/.ansible.$(date +%M%d%H%s)"
fi

if [[ -f "${TESTING_HOME}/.ansible.cfg" ]]; then
  mv "${TESTING_HOME}/.ansible.cfg" "${TESTING_HOME}/.ansible.cfg.$(date +%M%d%H%s)"
fi

mkdir -p "${ANSIBLE_LOG_DIR}"

if [ ! -d "/opt/rpc-openstack" ]; then
  git clone --recursive https://github.com/rcbops/rpc-openstack /opt/rpc-openstack
else
  pushd /opt/rpc-openstack
    git fetch --all
  popd
fi

# Enter the RPC-O workspace
pushd /opt/rpc-openstack
  if [ "${IRR_CONTEXT}" == "kilo" ]; then
    git_checkout "kilo"  # Last commit of Kilo
    (git submodule init && git submodule update) || true

    # NOTE(cloudnull): The kilo RPC-O deployment tools are inflexable and
    #                  require further tuning to mimic a customer deploy. To
    #                  get the basic setup we change this one condition so that
    #                  we can pre-load some extra configs.
    sed -i 's|! -d /etc/openstack_deploy/|-d "/etc/openstack_deploy/"|g' /opt/rpc-openstack/scripts/deploy.sh

    # NOTE(cloudnull): Within an AIO the data disk is not needed. This disables
    #                  it so that we're not waisting cycles.
    sed -i 's|bootstrap_host_data_disk_device is defined|disable_data_disk_device is defined|g' ${OSA_PATH}/tests/roles/bootstrap-host/tasks/main.yml
    sed -i 's|bootstrap_host_data_disk_device is defined|disable_data_disk_device is defined|g' ${OSA_PATH}/tests/roles/bootstrap-host/tasks/check-requirements.yml

    # NOTE(cloudnull): Pycrypto has to be limited.
    sed -i 's|pycrypto.*|pycrypto<=2.6.1|g' ${OSA_PATH}/requirements.txt

    # NOTE(cloudnull): In kilo we had a broken version of the ssh plugin listed in the role
    #                  requirements file. This patch gets the role from master and puts
    #                  into place which satisfies the role requirement.
    mkdir -p /etc/ansible/roles
    if [[ ! -d "/etc/ansible/roles/sshd" ]]; then
      git clone https://github.com/willshersystems/ansible-sshd /etc/ansible/roles/sshd
    fi

    # NOTE(cloudnull): Used to set basic Kilo variables.
    export DEPLOY_HAPROXY="yes"
    export DEPLOY_MAAS="no"
    export DEPLOY_AIO="yes"
    pin_jinja
    pin_galera "5.5"
    unset_affinity
    kilo_caches
  elif [ "${IRR_CONTEXT}" == "liberty" ]; then
    git_checkout "liberty"  # Last commit of Liberty
    pin_jinja
    pin_galera "10.0"
    unset_affinity
  elif [ "${IRR_CONTEXT}" == "mitaka" ]; then
    git_checkout "mitaka"  # Last commit of Mitaka
    pin_jinja
    pin_galera "10.0"
    unset_affinity
  else
    if ! git_checkout ${IRR_CONTEXT}; then
      echo "FAIL!"
      echo "This job requires the IRR_CONTEXT or IRR_SERIES to be a valid checkout within OSA"
      exit 99
    fi
  fi

  # Disbale tempest on newer releases
  if [[ -f "tests/roles/bootstrap-host/templates/user_variables.aio.yml.j2" ]]; then
    sed -i 's|^tempest_install.*|tempest_install: no|g' tests/roles/bootstrap-host/templates/user_variables.aio.yml.j2
    sed -i 's|^tempest_run.*|tempest_run: no|g' tests/roles/bootstrap-host/templates/user_variables.aio.yml.j2
  fi

  # Disable tempest on older releases
  sed -i '/.*run-tempest.sh.*/d' ${OSA_PATH}/scripts/gate-check-commit.sh  # Disable the tempest run

  # Disable the sec role
  disable_security_role

  # Run the leapfrog job with gate specific vars
  set_gating_vars

  # Setup an AIO
  scripts/deploy.sh
popd
