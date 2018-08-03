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

export RPC_TARGET_CHECKOUT=${RPC_TARGET_CHECKOUT:-'r14.16.0'}

pushd /opt/rpc-openstack
  git clean -df
  git reset --hard HEAD
  rm -rf openstack-ansible
  git checkout ${RPC_TARGET_CHECKOUT}
  (git submodule init && git submodule update) || true
popd
pushd /opt/rpc-openstack/openstack-ansible
  export TERM=linux
  export I_REALLY_KNOW_WHAT_I_AM_DOING=true
  # remove all ansible_ssh_host entries
  sed -i '/ansible_host/d' /etc/openstack_deploy/user*.yml
  # upgrade looks for user_variables so drop one in place for upgrade
  if [[ ! -f /etc/openstack_deploy/user_variables.yml ]]; then
     echo "---" > /etc/openstack_deploy/user_variables.yml
     echo "default_bind_mount_logs: False" >> /etc/openstack_deploy/user_variables.yml
  elif [[ -f /etc/openstack_deploy/user_variables.yml ]]; then
     if ! grep -i "default_bind_mount_logs" /etc/openstack_deploy/user_variables.yml; then
       echo "default_bind_mount_logs: False" >> /etc/openstack_deploy/user_variables.yml
     fi
  fi
  # ensure lxc workarounds are in place as they aren't in newton and this upgrade method skips rpc-o
  if ! grep -i "lxc_cache_prep" /etc/openstack_deploy/user_variables.yml; then
     echo 'lxc_cache_prep_pre_commands: "rm -f /etc/resolv.conf || true"' >> /etc/openstack_deploy/user_variables.yml
     echo 'lxc_cache_prep_post_commands: "ln -s ../run/resolvconf/resolv.conf /etc/resolv.conf -f"' >> /etc/openstack_deploy/user_variables.yml
  fi
  bash scripts/run-upgrade.sh
popd
