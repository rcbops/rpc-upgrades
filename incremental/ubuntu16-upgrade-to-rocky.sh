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
source lib/vars.sh

require_ubuntu_version 16

export RPC_BRANCH=${RPC_BRANCH:-'r18.0.1'}
export OSA_SHA="stable/rocky"
export SKIP_INSTALL=${SKIP_INSTALL:-'no'}
export RPC_PRODUCT_RELEASE="rocky"
export RPC_ANSIBLE_VERSION="2.5.5"

mark_started
checkout_rpc_openstack
configure_rpc_openstack
ensure_osa_bootstrap
prepare_rocky
repo_rebuild
run_upgrade
mark_completed
