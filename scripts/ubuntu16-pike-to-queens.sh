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

export RPC_BRANCH=${RPC_BRANCH:-'r17.1.0'}
export OSA_SHA="stable/queens"

pushd /opt/rpc-openstack
  git clean -df
  git reset --hard HEAD
  rm -rf openstack-ansible
  rm -rf scripts/artifacts-building/
  git checkout ${RPC_BRANCH}
# checkout openstack-ansible-ops
popd

if [ ! -d "/opt/openstack-ansible" ]; then
  git clone --recursive https://github.com/openstack/openstack-ansible /opt/openstack-ansible
else
  pushd /opt/openstack-ansible
    git reset --hard HEAD
    git fetch --all
  popd
fi

pushd /opt/openstack-ansible
  git checkout ${OSA_SHA}
  scripts/bootstrap-ansible.sh
  source /usr/local/bin/openstack-ansible.rc
  export TERM=linux
  export I_REALLY_KNOW_WHAT_I_AM_DOING=true
  # use fork of queens run-upgrade.sh script until fix merges in:
  # https://review.openstack.org/#/c/597977/ merges in
  cp /opt/rpc-upgrades/scripts/run-upgrade/queens/run-upgrade.sh scripts/run-upgrade.sh
  echo "YES" | bash scripts/run-upgrade.sh
popd

# ensure inventory is cleaned up from old containers and reset ansible_facts cache
pushd /opt/rpc-upgrades/playbooks
  openstack-ansible cleanup-queens-inventory.yml
popd
