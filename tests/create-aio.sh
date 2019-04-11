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

echo "Building an All in One (AIO)"
echo "+-------------------- AIO ENV VARS --------------------+"
env
echo "+-------------------- AIO ENV VARS --------------------+"

## Gating Vars ----------------------------------------------------------------------
export RE_JOB_SERIES="${RE_JOB_SERIES:-master}"
export RE_JOB_CONTEXT="${RE_JOB_CONTEXT:-undefined}"
export RE_JOB_IMAGE_TYPE="${RE_JOB_IMAGE_TYPE:-aio}"

# if rpc-o does not exist, prepare rpc-o directory
if [ ! -d "/opt/rpc-openstack" ]; then
  pushd /opt/rpc-upgrades
    ./tests/prepare-rpco.sh
  popd
fi

# RLM-434 Implement ansible retries for mitaka and below
case "${RE_JOB_SERIES}" in
  kilo|liberty|mitaka)
    export ANSIBLE_SSH_RETRIES=10
    export ANSIBLE_GIT_RELEASE=ssh_retry
    export ANSIBLE_GIT_REPO=https://github.com/hughsaunders/ansible
    ;;
esac

echo "+---------------- AIO RELEASE AND KERNEL ---------------+"
lsb_release -a
uname -a
echo "+---------------- AIO RELEASE AND KERNEL ---------------+"

pushd /opt/rpc-openstack
  export DEPLOY_ELK="no"
  export DEPLOY_HAPROXY="yes"
  export DEPLOY_MAAS="false"
  export DEPLOY_AIO="yes"
  export DEPLOY_HARDENING="no"
  export DEPLOY_RPC="no"
  export RPC_APT_ARTIFACT_MODE="loose"
  scripts/deploy.sh
popd
