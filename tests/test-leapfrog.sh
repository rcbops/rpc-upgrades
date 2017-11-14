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

export VALIDATE_UPGRADE_INPUT=false
export AUTOMATIC_VAR_MIGRATE_FLAG="--for-testing-take-new-vars-only"
export MNAIO_SSH="ssh -oStrictHostKeyChecking=no root@infra1"
export RE_JOB_IMAGE_TYPE="${RE_JOB_IMAGE_TYPE:-aio}"

if [ "${RE_JOB_SERIES}" == "kilo" ]; then
  export RPC_TARGET_CHECKOUT="r14.2.0"
  export OA_OPS_REPO_BRANCH="50f3fd6df7579006748a00c271bb03d22b17ae89"
elif [ "${RE_JOB_SERIES}" == "liberty" ]; then
  export RPC_TARGET_CHECKOUT="newton"
  export OA_OPS_REPO_BRANCH="0690bb608527b90596e5522cc852ffa655228807"
elif [ "${RE_JOB_SERIES}" == "mitaka" ]; then
  export RPC_TARGET_CHECKOUT="newton"
  export OA_OPS_REPO_BRANCH="0690bb608527b90596e5522cc852ffa655228807"
fi

function aio_leap {
  sudo --preserve-env $(readlink -e $(dirname ${0}))/../scripts/ubuntu14-leapfrog.sh

  # if rpc-maas repo exists, run maas-verify
  if [ -d "/opt/rpc-maas" ]; then
    pushd /opt/rpc-maas/playbooks
      openstack-ansible maas-verify.yml -vv
    popd
  fi
}

function mnaio_leap {
  scp -r -o StrictHostKeyChecking=no /opt/rpc-upgrades infra1:/opt/

  # start the rpc-o leapfrog upgrade from infra1
  ${MNAIO_SSH} "pushd /opt/rpc-upgrades ; \
                export TERM=linux ; \
                export RPC_TARGET_CHECKOUT=${RPC_TARGET_CHECKOUT}; \
                export OA_OPS_REPO_BRANCH=${OA_OPS_REPO_BRANCH}; \
                export VALIDATE_UPGRADE_INPUT=false; \
                export AUTOMATIC_VAR_MIGRATE_FLAG=${AUTOMATIC_VAR_MIGRATE_FLAG}; \
                export ANSIBLE_FORCE_COLOR=true; \
                echo 'neutron_legacy_ha_tool_enabled: true' >> /etc/openstack_deploy/user_variables.yml; \
                ./scripts/ubuntu14-leapfrog.sh"
  ssh -T -o StrictHostKeyChecking=no infra1 << 'EOF'
set -xe
# if rpc-maas repo exists, run maas-verify
if [ -d "/opt/rpc-maas" ]; then
  pushd /opt/rpc-maas/playbooks
    openstack-ansible maas-verify.yml -vv
  popd
fi
EOF
}

if [ "${RE_JOB_IMAGE_TYPE}" = "mnaio" ]; then
  mnaio_leap
else
  aio_leap
fi
