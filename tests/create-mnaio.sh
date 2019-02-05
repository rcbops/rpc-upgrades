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

echo "Building a Multi Node AIO (MNAIO)"
echo "+-------------------- MNAIO ENV VARS --------------------+"
env
echo "+-------------------- MNAIO ENV VARS --------------------+"

## Gating Vars ----------------------------------------------------------------------
export RE_JOB_SERIES="${RE_JOB_SERIES:-master}"
export RE_JOB_CONTEXT="${RE_JOB_CONTEXT:-master}"
export RE_JOB_IMAGE_OS="${RE_JOB_IMAGE_OS:-trusty}"
export RE_JOB_IMAGE_TYPE="${RE_JOB_IMAGE_TYPE:-mnaio}"
export RE_JOB_IMAGE=${RE_JOB_IMAGE_OS}

# set guest OS based on RE_JOB_IMAGE
if [ ${RE_JOB_IMAGE} == "trusty" ]; then
  export DEFAULT_IMAGE="ubuntu-14.04-amd64"
elif [ ${RE_JOB_IMAGE} == "xenial" ]; then
  export DEFAULT_IMAGE="ubuntu-16.04-amd64"
elif [ ${RE_JOB_IMAGE} == "bionic" ]; then
  export DEFAULT_IMAGE="ubuntu-18.04-amd64"
fi

## OSA MNAIO Vars
export PARTITION_HOST="true"
export NETWORK_BASE="172.29"
export DNS_NAMESERVER="8.8.8.8"
export OVERRIDE_SOURCES="true"
export DEVICE_NAME="vda"
export DEFAULT_NETWORK="eth0"
export DEFAULT_IMAGE="${DEFAULT_IMAGE}"
export DEFAULT_KERNEL="linux-image-generic"
export SETUP_HOST="true"
export SETUP_VIRSH_NET="true"
export VM_IMAGE_CREATE="true"
export OSA_BRANCH="${OSA_RELEASE:-newton-eol}"
export DEPLOY_OSA="true"
export PRE_CONFIG_OSA="true"
export RUN_OSA="false"
export CONFIGURE_OPENSTACK="false"
export CONFIG_PREROUTING="false"
export OSA_PORTS="6080 6082 443 80 8443"
export RPC_BRANCH="${RE_JOB_CONTEXT}"
export DEFAULT_MIRROR_HOSTNAME=mirror.rackspace.com
export DEFAULT_MIRROR_DIR=/ubuntu
export INFRA_VM_SERVER_RAM=16384
export MNAIO_ANSIBLE_PARAMETERS="-e default_vm_disk_mode=file"

# If series is newton, use rcbops fork of OSA
if [ "${RE_JOB_SERIES}" == "newton" ]; then
  export OSA_REPO="https://github.com/rcbops/openstack-ansible.git"
fi

# ssh command used to execute tests on infra1
export MNAIO_SSH="ssh -ttt -oStrictHostKeyChecking=no root@infra1"
export RUN_UPGRADES="${RUN_UPGRADES:-yes}"

# place variable in file to be sourced by parent calling script 'run'
export MNAIO_VAR_FILE="${MNAIO_VAR_FILE:-/tmp/mnaio_vars}"
echo "export MNAIO_SSH=\"${MNAIO_SSH}\"" > "${MNAIO_VAR_FILE}"

# checkout openstack-ansible-ops
if [ ! -d "/opt/openstack-ansible-ops" ]; then
  git clone --recursive https://github.com/openstack/openstack-ansible-ops /opt/openstack-ansible-ops
else
  pushd /opt/openstack-ansible-ops
    git fetch --all
  popd
fi

# if rpc-o does not exist, prepare rpc-o directory
if [ ! -d "/opt/rpc-openstack" ]; then
  pushd /opt/rpc-upgrades
    ./tests/prepare-rpco.sh
  popd
fi

# apply various modifications for mnaio
pushd /opt/openstack-ansible-ops/multi-node-aio
  # The multi-node-aio tool is quite modest when it comes to allocating
  # RAM to VMs -- since we have RAM to spare we double that assigned to
  # infra nodes.
  echo "infra_vm_server_ram: 16384" | sudo tee -a playbooks/group_vars/all.yml
  # By default the MNAIO deploys metering services, so we override
  # osa_enable_meter to prevent those services from being deployed.
  sed -i 's/osa_enable_meter: true/osa_enable_meter: false/' playbooks/group_vars/all.yml
popd

# fixes ERROR! Unexpected Exception: module object has no attribute SSL_ST_INIT
# may need upstream
pip install pyOpenSSL==17.3.0

# build the multi node aio
pushd /opt/openstack-ansible-ops/multi-node-aio
  ./build.sh
popd
echo "Multi Node AIO setup completed..."

# RLM-434 Implement ansible retries for mitaka and below
# Copies into ANSIBLE_RETRY which will be sourced when initial deploy is ran
case "${RE_JOB_SERIES}" in
  kilo|liberty|mitaka)
    echo "export ANSIBLE_SSH_RETRIES=10" > /opt/rpc-upgrades/ANSIBLE_RETRY
    echo "export ANSIBLE_GIT_RELEASE=ssh_retry" >> /opt/rpc-upgrades/ANSIBLE_RETRY
    echo "export ANSIBLE_GIT_REPO=https://github.com/hughsaunders/ansible" >> /opt/rpc-upgrades/ANSIBLE_RETRY
    ;;
esac

# prepare rpc-o configs
set -xe
echo "+---------------- MNAIO RELEASE AND KERNEL --------------+"
lsb_release -a
uname -a
echo "+---------------- MNAIO RELEASE AND KERNEL --------------+"

lsb_release -a
uname -a
scp -r -o StrictHostKeyChecking=no /opt/rpc-openstack infra1:/opt/
scp -r -o StrictHostKeyChecking=no /opt/rpc-upgrades infra1:/opt/
scp -r -o StrictHostKeyChecking=no /etc/openstack_deploy/user_rpco_upgrade.yml infra1:/etc/openstack_deploy/
if [ -f /etc/openstack_deploy/user_gating_fixes.yml ]; then
  scp -r -o StrictHostKeyChecking=no /etc/openstack_deploy/user_gating_fixes.yml infra1:/etc/openstack_deploy/
fi
if [ -f /etc/openstack_deploy/user_osa_variables_spice.yml ]; then
  scp -r -o StrictHostKeyChecking=no /etc/openstack_deploy/user_osa_variables_spice.yml infra1:/etc/openstack_deploy/
fi
# Put configs in place on Infra1 and gather release state
ssh -T -o StrictHostKeyChecking=no infra1 << 'EOF'
set -xe
echo "+--------------- INFRA1 RELEASE AND KERNEL --------------+"
lsb_release -a
uname -a
echo "+--------------- INFRA1 RELEASE AND KERNEL --------------+"
# backup mnaio variables
sudo cp /etc/openstack_deploy/user_mnaio_variables.yml /etc/openstack_deploy/user_mnaio_variables.yml.bak

# install release openstack-ansible deploy files from known locations
if [ -d "/opt/rpc-openstack/openstack-ansible" ]; then
  sudo cp -R /opt/rpc-openstack/openstack-ansible/etc/openstack_deploy /etc
elif [ -d "/opt/openstack-ansible" ]; then
  sudo cp -R /opt/openstack-ansible/etc/openstack_deploy /etc
fi

# install rpc-o specific config files from known locations
if [ -d "/opt/rpc-openstack/rpcd/etc/openstack_deploy" ]; then
  sudo cp -R /opt/rpc-openstack/rpcd/etc/openstack_deploy/* /etc/openstack_deploy
elif [ -d "/opt/rpc-openstack/etc/openstack_deploy" ]; then
  sudo cp -R /opt/rpc-openstack/etc/openstack_deploy/* /etc/openstack_deploy
fi

# remove user_variables.yml as we don't utilize this on initial builds
sudo rm /etc/openstack_deploy/user_variables.yml

# restore mnaio variables
sudo cp /etc/openstack_deploy/user_mnaio_variables.yml.bak /etc/openstack_deploy/user_mnaio_variables.yml

# install libvirt-dev on infra1 because pinning to libvirt-python requires it
sudo apt-get -y install libvirt-dev
EOF

# Pre Newton and Post Newton RPC-O deployments are different so
# this tunes out the specifics for each type
case "${RE_JOB_SERIES}" in
  kilo|liberty|mitaka|newton)
    ${MNAIO_SSH} "source /opt/rpc-upgrades/RE_ENV; \
                  source /opt/rpc-upgrades/ANSIBLE_RETRY; \
                  source /opt/rpc-upgrades/tests/ansible-env.rc; \
                  pushd /opt/rpc-openstack; \
                  export DEPLOY_ELK=no; \
                  export DEPLOY_MAAS=false; \
                  export DEPLOY_TELEGRAF=no; \
                  export DEPLOY_INFLUX=no; \
                  export DEPLOY_AIO=false; \
                  export DEPLOY_HAPROXY=yes; \
                  export DEPLOY_OA=yes; \
                  export DEPLOY_TEMPEST=no; \
                  export DEPLOY_CEILOMETER=no; \
                  export DEPLOY_CEPH=no; \
                  export DEPLOY_SWIFT=yes; \
                  export DEPLOY_RPC=yes; \
                  export ANSIBLE_FORCE_COLOR=true; \
                  export RPC_APT_ARTIFACT_MODE="loose"; \
                  scripts/deploy.sh"
  ;;
  ocata|pike|queens|rocky|stein)
    ${MNAIO_SSH} "source /opt/rpc-upgrades/RE_ENV; \
                  pushd /opt/rpc-openstack; \
                  export DEPLOY_AIO=false; \
                  export RPC_PRODUCT_RELEASE="${RE_JOB_SERIES}"; \
                  export DEPLOY_MAAS=false; \
                  export ANSIBLE_FORCE_COLOR=true; \
                  scripts/deploy.sh; \
                  /opt/rpc-ansible/bin/ansible-playbook -i 'localhost,' playbooks/openstack-ansible-install.yml; \
                  popd; \
                  pushd /opt/openstack-ansible/scripts; \
                  cp /opt/openstack-ansible/etc/openstack_deploy/user_secrets.yml /etc/openstack_deploy/
                  python pw-token-gen.py --file /etc/openstack_deploy/user_secrets.yml; \
                  popd; \
                  pushd /opt/openstack-ansible/playbooks; \
                  openstack-ansible setup-hosts.yml setup-infrastructure.yml setup-openstack.yml"
  ;;
  *)
    echo "Unable to detect current OpenStack version, failing...."
    exit 1
  ;;
esac

echo "MNAIO RPC-O deploy completed..."

# Install and Verify MaaS post deploy
#${MNAIO_SSH} "source /opt/rpc-upgrades/RE_ENV; \
#              source /opt/rpc-upgrades/ANSIBLE_RETRY; \
#              source /opt/rpc-upgrades/tests/ansible-env.rc; \
#              pushd /opt/rpc-upgrades; \
#              tests/maas-install.sh"
#echo "MaaS Install and Verify Post Deploy completed..."

# Run QC Tests
${MNAIO_SSH} "source /opt/rpc-upgrades/RE_ENV; \
              source /opt/rpc-upgrades/tests/ansible-env.rc; \
              pushd /opt/rpc-upgrades; \
              tests/qc-test.sh"
echo "QC Tests completed..."
