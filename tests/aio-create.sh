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

set -evu

echo "Building an AIO"
echo "+-------------------- AIO ENV VARS --------------------+"
env
echo "+-------------------- AIO ENV VARS --------------------+"

## Vars ----------------------------------------------------------------------
export IRR_SERIES="${IRR_SERIES:-master}"
export IRR_CONTEXT="${IRR_CONTEXT:-undefined}"

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

function _ensure_osa_dir {
  # NOTE(cloudnull): Create the OSA dir if it's not present.
  if [[ ! -d "/etc/openstack_deploy" ]]; then
    mkdir -p /etc/openstack_deploy
  fi
}

function pin_galera {
  # NOTE(cloudnull): The MariaDB repos in these releases used https, this broke
  #                  the deployment. These patches simply point at the same
  #                  repos just without https.
  _ensure_osa_dir

  cat > /etc/openstack_deploy/user_rpco_galera.yml <<EOF
---
galera_client_apt_repo_url: "http://mirror.rackspace.com/mariadb/repo/${1}/ubuntu"
galera_apt_repo_url: "http://mirror.rackspace.com/mariadb/repo/${1}/ubuntu"
galera_apt_percona_xtrabackup_url: "http://repo.percona.com/apt"
EOF
}

function disable_security_role {
  # NOTE(cloudnull): The security role is tested elsewhere, there's no need to run it here.
  _ensure_osa_dir

  echo "apply_security_hardening: false" | tee -a /etc/openstack_deploy/user_nosec.yml
}

function git_checkout {
  # NOTE(cloudnull): Checkout the provided when the series undefined
  if [ "${IRR_CONTEXT}" == "undefined" ]; then
    git checkout "${1}"
  else
    git checkout "${IRR_CONTEXT}"
  fi
}

function set_gating_vars {
  # NOTE(cloudnull): Set variables to ensure AIO gate success.
  _ensure_osa_dir

  cat > /etc/openstack_deploy/user_rpco_leap.yml <<EOF
---
neutron_legacy_ha_tool_enabled: true
lxc_container_backing_store: dir
EOF
}

function run_bootstrap {
  # run the bootstrap to pull down all roles in case we need to modify by context
  export DEPLOY_AIO="yes"
  export DEPLOY_OA="no"
  scripts/deploy.sh
}

function kilo_caches {
  # NOTE(cloudnull): Set variables to ensure Kilo caches are functional.
  _ensure_osa_dir

  # NOTE(cloudnull): Early kilo versions fail system bootstrap due to the get
  #                  pip script and general SSL issues.
  export GET_PIP_URL="https://raw.githubusercontent.com/pypa/get-pip/master/get-pip.py"

  cat > /etc/openstack_deploy/user_kilo_caches.yml <<EOF
---
pip_get_pip_url: 'https://raw.githubusercontent.com/pypa/get-pip/master/get-pip.py'

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

function allow_frontloading_vars {
  # NOTE(cloudnull): The kilo/liberty RPC-O deployment tools are inflexable and
  #                  require further tuning to mimic a customer deploy. To
  #                  get the basic setup we change this one condition so that
  #                  we can pre-load some extra configs.
  sed -i 's|! -d /etc/openstack_deploy/|-d "/etc/openstack_deploy/"|g' /opt/rpc-openstack/scripts/deploy.sh
}

function rpco_exports {
  # NOTE(cloudnull): Used to set basic AIO Deployment variables.
  export DEPLOY_HAPROXY="yes"
  export DEPLOY_MAAS="no"
  export DEPLOY_AIO="yes"
}

function get_ssh_role {
  # NOTE(cloudnull): We have a broken version of the ssh role listed in the role
  #                  requirements file. This patch gets the role from master and
  #                  puts into a place which satisfies the role requirement.
  if [[ ! -d "/etc/ansible/roles" ]]; then
    mkdir -p /etc/ansible/roles
  fi

  if [[ ! -d "/etc/ansible/roles/sshd" ]]; then
    git clone https://github.com/willshersystems/ansible-sshd /etc/ansible/roles/sshd
    pushd /etc/ansible/roles/sshd
      # checks out commit before it breaks by using "package" on Ansible 1.9x
      git checkout f85838007002e47712dde60d7bbf747400264dc9
    popd
  fi
}

function fix_galera_apt_cache {
  # galera server role doesn't refresh apt cache for repos
  if grep '\scache_valid_time\:' /etc/ansible/roles/galera_server/tasks/galera_install.yml; then
    sed -i '/\scache_valid_time:.*/d' /etc/ansible/roles/galera_server/tasks/galera_install.yml
  fi
}

function run_deploy {
  export DEPLOY_AIO=yes
  export DEPLOY_OA=yes
  export DEPLOY_RPC=yes
  scripts/deploy.sh
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
  if [ "${IRR_SERIES}" == "kilo" ]; then
    git_checkout "kilo"  # Last commit of Kilo
    (git submodule init && git submodule update) || true

    # NOTE(cloudnull): Run Kilo pre-setup functions
    pin_jinja
    kilo_caches
    allow_frontloading_vars
    rpco_exports
    get_ssh_role

    # NOTE(cloudnull): Pycrypto has to be limited.
    sed -i 's|pycrypto.*|pycrypto<=2.6.1|g' ${OSA_PATH}/requirements.txt

    # NOTE(cloudnull): Early kilo versions forced repo-clone from our mirrors.
    #                  Sadly this takes forever and is largely broken. This
    #                  changes the default behaviour to build.
    echo -e "---\n- include: repo-server.yml\n- include: repo-build.yml" | tee ${OSA_PATH}/playbooks/repo-install.yml
  elif [ "${IRR_SERIES}" == "liberty" ]; then
    git_checkout "liberty"  # Last commit of Liberty
    (git submodule init && git submodule update) || true

    # NOTE(cloudnull): Run Liberty pre-setup functions
    pin_jinja
    pin_galera "10.0"
    unset_affinity
    allow_frontloading_vars
    rpco_exports
    get_ssh_role
    fix_galera_apt_cache

    # NOTE(cloudnull): The global requirement pins for early Liberty are broken.
    #                  This pull the pins forward so that we can continue with
    #                  the AIO deployment for liberty
    echo -e "pip==9.0.1\nsetuptools==28.8.0\nwheel==0.26.0" | tee ${OSA_PATH}/global-requirement-pins.txt
  elif [ "${IRR_SERIES}" == "mitaka" ]; then
    git_checkout "mitaka"  # Last commit of Mitaka
    (git submodule init && git submodule update) || true

    # NOTE(cloudnull): Run Mitaka pre-setup functions
    pin_jinja
    pin_galera "10.0"
    unset_affinity
    allow_frontloading_vars
    rpco_exports
  else
    if ! git_checkout ${IRR_SERIES}; then
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
  if [[ -f "${OSA_PATH}/scripts/gate-check-commit.sh" ]]; then
    sed -i '/.*run-tempest.sh.*/d' ${OSA_PATH}/scripts/gate-check-commit.sh  # Disable the tempest run
  fi

  # Disable the sec role
  disable_security_role

  # Run the leapfrog job with gate specific vars
  set_gating_vars
 
  # Run initial bootstrap but don't deploy OSA yet
  run_bootstrap

  fix_galera_apt_cache
 
  # Setup an AIO
  run_deploy

popd
