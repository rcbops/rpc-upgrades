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

source lib/functions.sh

require_ubuntu_version 16

#export RPC_BRANCH=${RPC_BRANCH:-'r16.2.6'}
export RPC_BRANCH=${RPC_BRANCH:-'pike'}
export OSA_SHA="stable/pike"
export SKIP_INSTALL=${SKIP_INSTALL:-'no'}

echo "Starting Ocata to Pike Upgrade..."

checkout_rpc_openstack
checkout_openstack_ansible
set_secrets_file
disable_hardening
set_keystone_flush_memcache
prepare_pike

if [[ "$SKIP_INSTALL" == "yes" ]]; then
  strip_install_steps
fi

set_rpc_release
run_upgrade


echo "Ocata to Pike Upgrade completed..."
