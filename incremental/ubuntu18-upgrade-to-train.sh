#!/usr/bin/env bash

# Copyright 2019, Rackspace US, Inc.
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
source lib/vars.sh

require_ubuntu_version 18

export OSA_SHA="20.1.2"
export SKIP_INSTALL=${SKIP_INSTALL:-'no'}
export RPC_PRODUCT_RELEASE="train"
export RPC_ANSIBLE_VERSION="2.8.8"

check_rpc_config
mark_started
checkout_openstack_ansible
ensure_osa_bootstrap
prepare_train
run_upgrade
mark_completed
