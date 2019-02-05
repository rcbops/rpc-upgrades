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

# remove snap from RE_JOB_IMAGE_TYPE var so that we can grab the proper image
export RE_JOB_IMAGE_TYPE="${RE_JOB_IMAGE_TYPE//-snap}"

export RPC_RELEASE="${RE_JOB_CONTEXT:-}"
export RPCU_ARTIFACT_URL="https://ed2cc5ce4ea792952a06-5946b1c04934c7963c5365082354649f.ssl.cf5.rackcdn.com"
export RPCU_IMAGE_MANIFEST_URL="${RPCU_ARTIFACT_URL}/${RE_JOB_CONTEXT}-${RE_JOB_IMAGE_OS}_${RE_JOB_IMAGE_TYPE}-${RE_JOB_SCENARIO}/manifest.json"
export RPCO_ARTIFACT_URL="https://a5ce27333a8948d82738-b28e2b85e22a27f072118ea786afca3a.ssl.cf5.rackcdn.com"
export RPCO_IMAGE_MANIFEST_URL="${RPCO_ARTIFACT_URL}/${RE_JOB_CONTEXT}-${RE_JOB_IMAGE}-${RE_JOB_SCENARIO}/manifest.json"

# set guest OS based on RE_JOB_IMAGE_OS
if [ ${RE_JOB_IMAGE_OS} == "trusty" ]; then
  export DEFAULT_IMAGE="ubuntu-14.04-amd64"
elif [ ${RE_JOB_IMAGE_OS} == "xenial" ]; then
  export DEFAULT_IMAGE="ubuntu-16.04-amd64"
elif [ ${RE_JOB_IMAGE_OS} == "bionic" ]; then
  export DEFAULT_IMAGE="ubuntu-18.04-amd64"
fi

function determine_manifest {
   # check and see if specific version is present and set RPCO_IMAGE_MANIFEST_URL
   # if not, then attempt to fall back and boot from latest version to attempt upgrade
   if curl --output /dev/null --silent --head --fail "${RPCU_IMAGE_MANIFEST_URL}"; then
     echo "RPCU_IMAGE_MANIFEST_URL is valid and exists for ${RE_JOB_CONTEXT}."
     echo "RPCU_IMAGE_MANIFEST_URL set to ${RPCU_IMAGE_MANIFEST_URL}."
     export MNAIO_MANIFEST_URL=${RPCU_IMAGE_MANIFEST_URL}
   elif curl --output /dev/null --silent --head --fail "${RPCO_IMAGE_MANIFEST_URL}"; then
     echo "RPCO_IMAGE_MANIFEST_URL is valid and exists for ${RE_JOB_CONTEXT}."
     echo "RPCO_IMAGE_MANIFEST_URL set to ${RPCO_IMAGE_MANIFEST_URL}."
     export MNAIO_MANIFEST_URL=${RPCO_IMAGE_MANIFEST_URL}
   else
     echo "Requested RE_JOB_SERIES not found for ${RE_JOB_CONTEXT}, falling back to latest available."
     # normally would fail and exit here, but we'll need to build up library of snapshots
     # exit 1
     if [ "${RE_JOB_SERIES}" == "rocky" ]; then
       export MNAIO_MANIFEST_URL="${RPCO_ARTIFACT_URL}/r18.0.0-xenial_mnaio_no_artifacts-swift/manifest.json"
     elif [ "${RE_JOB_SERIES}" == "queens" ]; then
       export MNAIO_MANIFEST_URL="${RPCO_ARTIFACT_URL}/r17.1.5-xenial_mnaio_no_artifacts-swift/manifest.json"
     elif [ "${RE_JOB_SERIES}" == "pike" ]; then
       export MNAIO_MANIFEST_URL="${RPCO_ARTIFACT_URL}/r16.2.9-xenial_mnaio_no_artifacts-swift/manifest.json"
     elif [ "${RE_JOB_SERIES}" == "newton" ]; then
       export MNAIO_MANIFEST_URL="${RPCO_ARTIFACT_URL}/r14.23.0-xenial_mnaio_loose_artifacts-swift/manifest.json"
     else
       exit 1
     fi
     export DEPLOY_VMS="false"
     echo "RPCO_IMAGE_MANIFEST_URL set to ${RPCO_IMAGE_MANIFEST_URL}."
  fi
}

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

# fixes ERROR! Unexpected Exception: module object has no attribute SSL_ST_INIT
# may need upstream
pip install pyOpenSSL==17.3.0

pushd /opt/openstack-ansible-ops/multi-node-aio
  if [ -f /opt/rpc-openstack/scripts/functions.sh ]; then
    source /opt/rpc-openstack/scripts/functions.sh
  fi
  if [ -f /opt/rpc-openstack/gating/mnaio_vars.sh ]; then
    source /opt/rpc-openstack/gating/mnaio_vars.sh
  else
    source /opt/rpc-upgrades/gating/mnaio_vars.sh
  fi
  source bootstrap.sh
  source ansible-env.rc
  determine_manifest
  run_mnaio_playbook playbooks/setup-host.yml
  run_mnaio_playbook playbooks/deploy-acng.yml
  run_mnaio_playbook playbooks/deploy-pxe.yml
  run_mnaio_playbook playbooks/deploy-dhcp.yml
  run_mnaio_playbook playbooks/download-vms.yml -e manifest_url=${MNAIO_MANIFEST_URL}
  run_mnaio_playbook playbooks/deploy-vms.yml
popd
echo "Multi Node AIO setup from snapshots completed..."

# RLM-434 Implement ansible retries for mitaka and below
# Copies into ANSIBLE_RETRY which will be sourced when initial deploy is ran
case "${RE_JOB_SERIES}" in
  kilo|liberty|mitaka)
    echo "export ANSIBLE_SSH_RETRIES=10" > /opt/rpc-upgrades/ANSIBLE_RETRY
    echo "export ANSIBLE_GIT_RELEASE=ssh_retry" >> /opt/rpc-upgrades/ANSIBLE_RETRY
    echo "export ANSIBLE_GIT_REPO=https://github.com/hughsaunders/ansible" >> /opt/rpc-upgrades/ANSIBLE_RETRY
    ;;
esac

set -xe
echo "+---------------- MNAIO RELEASE AND KERNEL --------------+"
lsb_release -a
uname -a
echo "+---------------- MNAIO RELEASE AND KERNEL --------------+"
scp -r -o StrictHostKeyChecking=no /opt/rpc-upgrades infra1:/opt/
scp -r -o StrictHostKeyChecking=no /opt/rpc-openstack infra1:/opt/
scp -r -o StrictHostKeyChecking=no /etc/openstack_deploy/user_rpco_upgrade.yml infra1:/etc/openstack_deploy/
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
EOF

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
