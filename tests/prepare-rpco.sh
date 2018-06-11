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
export RE_JOB_SERIES="${RE_JOB_SERIES:-master}"
export RE_JOB_CONTEXT="${RE_JOB_CONTEXT:-undefined}"
export RE_JOB_IMAGE_TYPE="${RE_JOB_IMAGE_TYPE:-aio}"
export TESTING_HOME="${TESTING_HOME:-$HOME}"
export ANSIBLE_LOG_DIR="${TESTING_HOME}/.ansible/logs"
export ANSIBLE_LOG_PATH="${ANSIBLE_LOG_DIR}/ansible-aio.log"
export OSA_PATH="/opt/rpc-openstack/openstack-ansible"
export WORKSPACE_PATH=`pwd`

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

function git_checkout {
  # NOTE(cloudnull): Checkout the provided when the series undefined
  if [ "${RE_JOB_CONTEXT}" == "undefined" ]; then
    git checkout "${1}"
  else
    git checkout "${RE_JOB_CONTEXT}"
  fi
}

function set_gating_vars {
  # NOTE(cloudnull): Set variables to ensure AIO gate success.
  _ensure_osa_dir

  cat > /etc/openstack_deploy/user_rpco_upgrade.yml <<EOF
---
neutron_legacy_ha_tool_enabled: true
lxc_container_backing_store: dir
maas_use_api: false
EOF
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
  # if old percona key, then add new key and regen apt cache
  pushd /opt/rpc-openstack/openstack-ansible
    if grep '0x1c4cbdcdcd2efd2a' /opt/rpc-openstack/openstack-ansible/playbooks/roles/galera_server/defaults/main.yml; then
      patch -p1 < ${WORKSPACE_PATH}/playbooks/patches/liberty/galera_server/galera_server_apt_repo_defaults.patch
      patch -p1 < ${WORKSPACE_PATH}/playbooks/patches/liberty/galera_server/galera_server_apt_repo_pre_install.patch
    fi
  popd
}

function remove_xtrabackup_from_galera_client {
  pushd /opt/rpc-openstack/openstack-ansible
    if grep 'percona-xtrabackup' /opt/rpc-openstack/openstack-ansible/playbooks/roles/galera_client/defaults/main.yml; then
      patch -p1 < ${WORKSPACE_PATH}/playbooks/patches/liberty/galera_client/galera_client_remove_percona_xtrabackup.patch
    fi
  popd
}

function maas_tweaks {
  # RLM-518 older versions of liberty and kilo did not set maas_swift_accesscheck_password
  if ! grep '^maas_swift_accesscheck_password\:' /opt/rpc-openstack/rpcd/etc/openstack_deploy/user_extras_secrets.yml; then
    echo 'maas_swift_accesscheck_password:' >> /opt/rpc-openstack/rpcd/etc/openstack_deploy/user_extras_secrets.yml
  fi
}

function spice_repo_fix {
  cat > /etc/openstack_deploy/user_osa_variables_spice.yml <<EOF
---
nova_spicehtml5_git_repo: https://gitlab.freedesktop.org/spice/spice-html5
EOF
}

function spice_repo_fix_patch {
  pushd /opt/rpc-openstack/openstack-ansible
    if grep 'github.com/SPICE' /opt/rpc-openstack/openstack-ansible/playbooks/defaults/repo_packages/openstack_other.yml; then
      patch -p1 < ${WORKSPACE_PATH}/playbooks/patches/${RE_JOB_SERIES}/spice-html5-repo-fix.patch
    fi
  popd
}

## Main ----------------------------------------------------------------------
echo "Gate test starting
with:
  RE_JOB_CONTEXT: ${RE_JOB_CONTEXT}
  RE_JOB_SERIES: ${RE_JOB_SERIES}
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
  git clone https://github.com/rcbops/rpc-openstack /opt/rpc-openstack
else
  pushd /opt/rpc-openstack
    git fetch --all
  popd
fi

# Enter the RPC-O workspace
pushd /opt/rpc-openstack
  if [ "${RE_JOB_SERIES}" == "kilo" ]; then
    git_checkout "kilo"  # Last commit of Kilo
    (git submodule init && git submodule update) || true

    # NOTE(cloudnull): Run Kilo pre-setup functions
    pin_jinja
    kilo_caches
    allow_frontloading_vars
    get_ssh_role
    maas_tweaks
    spice_repo_fix
    spice_repo_fix_patch
    # NOTE(cloudnull): Pycrypto has to be limited.
    sed -i 's|pycrypto.*|pycrypto<=2.6.1|g' ${OSA_PATH}/requirements.txt

    # RLM-1338 Older versions of kilo that use older setuptools fail with install_requires
    # must be a string  or list of strings so use the latest version that will work
    if ! grep 'setuptools' ${OSA_PATH}/requirements.txt; then
      echo "setuptools==21.0.0" >> ${OSA_PATH}/requirements.txt
    fi

    # pin tornado to pre 5.x due to SSL issues
    if ! grep 'tornado' ${OSA_PATH}/requirements.txt; then
      echo "tornado==4.5.3" >> ${OSA_PATH}/requirements.txt
    fi

    # pin libvirt-python due to issues with 4.1.0
    # https://bugs.launchpad.net/openstack-requirements/+bug/1753539
    apt-get -y install libvirt-dev
    if ! grep 'libvirt-python' ${OSA_PATH}/requirements.txt; then
      echo "libvirt-python<=4.0.0" >> ${OSA_PATH}/requirements.txt
    fi

    # cmd2 0.9.0 and newer requires python3, pin at the point before to prevent breakage
    if ! grep 'cmd2' ${OSA_PATH}/requirements.txt; then
      echo "cmd2<0.9.0" >> ${OSA_PATH}/requirements.txt
    fi

    # NOTE(cloudnull): Early kilo versions forced repo-clone from our mirrors.
    #                  Sadly this takes forever and is largely broken. This
    #                  changes the default behaviour to build.
    echo -e "---\n- include: repo-server.yml\n- include: repo-build.yml" | tee ${OSA_PATH}/playbooks/repo-install.yml
    # don't attempt an elasticsearch upgrade on kilo
    export UPGRADE_ELASTICSEARCH="no"
  elif [ "${RE_JOB_SERIES}" == "liberty" ]; then
    git_checkout "liberty"  # Last commit of Liberty
    (git submodule init && git submodule update) || true

    # NOTE(cloudnull): Run Liberty pre-setup functions
    pin_jinja
    pin_galera "10.0"
    unset_affinity
    allow_frontloading_vars
    get_ssh_role
    fix_galera_apt_cache
    remove_xtrabackup_from_galera_client
    maas_tweaks
    spice_repo_fix
    spice_repo_fix_patch
    # NOTE(cloudnull): The global requirement pins for early Liberty are broken.
    #                  This pull the pins forward so that we can continue with
    #                  the AIO deployment for liberty
    echo -e "pip==9.0.1\nsetuptools==28.8.0\nwheel==0.26.0" | tee ${OSA_PATH}/global-requirement-pins.txt
  elif [ "${RE_JOB_SERIES}" == "mitaka" ]; then
    git_checkout "mitaka"  # Last commit of Mitaka
    (git submodule init && git submodule update) || true

    # NOTE(cloudnull): Run Mitaka pre-setup functions
    pin_jinja
    pin_galera "10.0"
    unset_affinity
    allow_frontloading_vars
    spice_repo_fix
  elif [ "${RE_JOB_SERIES}" == "newton" ]; then
    git_checkout "newton"  # Last commit of Newton
    (git submodule init && git submodule update) || true

    # NOTE(cloudnull): Run Newton pre-setup functions
    pin_jinja
    pin_galera "10.0"
    unset_affinity
    allow_frontloading_vars
  else
    if ! git_checkout ${RE_JOB_SERIES}; then
      echo "FAIL!"
      echo "This job requires the RE_JOB_CONTEXT or RE_JOB_SERIES to be a valid checkout within OSA"
      exit 99
    fi
  fi

  # Disable tempest on newer releases
  if [[ -f "tests/roles/bootstrap-host/templates/user_variables.aio.yml.j2" ]]; then
    sed -i 's|^tempest_install.*|tempest_install: no|g' tests/roles/bootstrap-host/templates/user_variables.aio.yml.j2
    sed -i 's|^tempest_run.*|tempest_run: no|g' tests/roles/bootstrap-host/templates/user_variables.aio.yml.j2
  fi

  # Disable tempest on older releases
  if [[ -f "${OSA_PATH}/scripts/gate-check-commit.sh" ]]; then
    sed -i '/.*run-tempest.sh.*/d' ${OSA_PATH}/scripts/gate-check-commit.sh  # Disable the tempest run
  fi

  # Run the upgrade job with gate specific vars
  set_gating_vars
popd
