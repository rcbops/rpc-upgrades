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

set -evu

export RPC_TARGET_CHECKOUT=${RPC_TARGET_CHECKOUT:-'master'}
export OSA_SHA="4db595ba96a939e88ec1786a4516f68f8bcf5e20"

pushd /opt/rpc-openstack
  git clean -df
  git reset --hard HEAD
  rm -rf openstack-ansible
  rm -rf scripts/artifacts-building/
  git checkout ${RPC_TARGET_CHECKOUT}
# checkout openstack-ansible-ops
popd

if [ ! -d "/opt/openstack-ansible" ]; then
  git clone --recursive https://github.com/openstack/openstack-ansible /opt/openstack-ansible
else
  pushd /opt/openstack-ansible
    git fetch --all
  popd
fi

pushd /opt/openstack-ansible
  git checkout ${OSA_SHA}
  export TERM=linux
  export I_REALLY_KNOW_WHAT_I_AM_DOING=true
  echo "YES" | bash scripts/run-upgrade.sh
popd
