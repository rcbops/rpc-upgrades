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

export RPC_BRANCH=${RPC_BRANCH:-'r16.2.4'}
export OSA_SHA="stable/pike"
export SKIP_INSTALL=${SKIP_INSTALL:-'no'}

function strip_install_steps {
  pushd /opt/openstack-ansible/scripts
    sed -i '/RUN_TASKS+=("[a-z]/d' run-upgrade.sh
    sed -i "/memcached-flush.yml/d" run-upgrade.sh
    sed -i "/galera-cluster-rolling-restart/d" run-upgrade.sh
  popd
}

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
  # remove once https://review.openstack.org/#/c/604804/ merges
  sed -i '/- name: os_keystone/,+3d' /opt/openstack-ansible/ansible-role-requirements.yml
  cat <<EOF >> /opt/openstack-ansible/ansible-role-requirements.yml
- name: os_keystone
  scm: git
  src: https://github.com/antonym/openstack-ansible-os_keystone.git
  version: b2af1b37090d18b1ecb2fabfa1b3178f3721d324
EOF
  scripts/bootstrap-ansible.sh
  source /usr/local/bin/openstack-ansible.rc

  if [[ "$SKIP_INSTALL" == "yes" ]]; then
    strip_install_steps
  fi

  export TERM=linux
  export I_REALLY_KNOW_WHAT_I_AM_DOING=true
  echo "YES" | bash scripts/run-upgrade.sh
popd
