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

## OSA MNAIO Vars
export PARTITION_HOST="true"
export NETWORK_BASE="172.29"
export DNS_NAMESERVER="8.8.8.8"
export OVERRIDE_SOURCES="true"
export DEVICE_NAME="vda"
export DEFAULT_NETWORK="eth0"
export DEFAULT_IMAGE="ubuntu-14.04-amd64"
export DEFAULT_KERNEL="linux-image-generic"
export SETUP_HOST="true"
export SETUP_VIRSH_NET="true"
export VM_IMAGE_CREATE="true"
export DEPLOY_OSA="true"
export PRE_CONFIG_OSA="true"
export RUN_OSA="false"
export CONFIGURE_OPENSTACK="false"
export DATA_DISK_DEVICE="sdb"
export CONFIG_PREROUTING="false"
export OSA_PORTS="6080 6082 443 80 8443"
export RPC_BRANCH="${RE_JOB_CONTEXT}"
export DEFAULT_MIRROR_HOSTNAME=mirror.rackspace.com
export DEFAULT_MIRROR_DIR=/ubuntu

# ssh command used to execute tests on infra1
export MNAIO_SSH="ssh -ttt -oStrictHostKeyChecking=no root@infra1"
export RUN_UPGRADES="${RUN_UPGRADES:-yes}"

#export ADDITIONAL_COMPUTE_NODES=${env.ADDITIONAL_COMPUTE_NODES}
#export ADDITIONAL_VOLUME_NODES=${env.ADDITIONAL_VOLUME_NODES}

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

# set OSA branch
pushd /opt/rpc-openstack
  OSA_COMMIT=`git submodule status openstack-ansible | egrep --only-matching '[a-f0-9]{40}'`
  export OSA_BRANCH=${OSA_COMMIT}
popd

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

# Put configs in place on Infra1 and gather release state
ssh -T -o StrictHostKeyChecking=no infra1 << 'EOF'
set -xe
echo "+--------------- INFRA1 RELEASE AND KERNEL --------------+"
lsb_release -a
uname -a
echo "+--------------- INFRA1 RELEASE AND KERNEL --------------+"
sudo cp /etc/openstack_deploy/user_variables.yml /etc/openstack_deploy/user_variables.yml.bak
sudo cp -R /opt/rpc-openstack/openstack-ansible/etc/openstack_deploy /etc
sudo cp /etc/openstack_deploy/user_variables.yml.bak /etc/openstack_deploy/user_variables.yml
sudo cp /opt/rpc-openstack/rpcd/etc/openstack_deploy/user_*.yml /etc/openstack_deploy
sudo cp /opt/rpc-openstack/rpcd/etc/openstack_deploy/env.d/* /etc/openstack_deploy/env.d
sudo pip uninstall ansible -y
sudo rm /usr/local/bin/openstack-ansible
EOF

# split out to capture exit codes if scripts fail
# start the rpc-o install from infra1
${MNAIO_SSH} "source /opt/rpc-upgrades/RE_ENV; \
              source /opt/rpc-upgrades/ANSIBLE_RETRY; \
              source /opt/rpc-upgrades/tests/ansible-env.rc; \
              pushd /opt/rpc-openstack; \
              export DEPLOY_ELK=yes; \
              export DEPLOY_MAAS=no; \
              export DEPLOY_TELEGRAF=no; \
              export DEPLOY_INFLUX=no; \
              export DEPLOY_AIO=no; \
              export DEPLOY_HAPROXY=yes; \
              export DEPLOY_OA=yes; \
              export DEPLOY_TEMPEST=no; \
              export DEPLOY_CEILOMETER=no; \
              export DEPLOY_CEPH=no; \
              export DEPLOY_SWIFT=yes; \
              export DEPLOY_RPC=yes; \
              export ANSIBLE_FORCE_COLOR=true; \
              scripts/deploy.sh"

echo "MNAIO RPC-O deploy completed..."

# Install and Verify MaaS post deploy
${MNAIO_SSH} "source /opt/rpc-upgrades/RE_ENV; \
              source /opt/rpc-upgrades/ANSIBLE_RETRY; \
              source /opt/rpc-upgrades/tests/ansible-env.rc; \
              pushd /opt/rpc-upgrades; \
              tests/maas-install.sh"
echo "MaaS Install and Verify Post Deploy completed..."

# Run QC Tests
${MNAIO_SSH} "source /opt/rpc-upgrades/RE_ENV; \
              source /opt/rpc-upgrades/tests/ansible-env.rc; \
              pushd /opt/rpc-upgrades; \
              tests/qc-test.sh"
echo "QC Tests completed..."
