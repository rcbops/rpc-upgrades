#!/usr/bin/env bash

# Copyright 2022, Rackspace US, Inc.
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

source lib/vars.sh
source lib/functions.sh

require_ubuntu_version 20

export OSA_SHA="23.4.4"
export SKIP_INSTALL=${SKIP_INSTALL:-'no'}
export RPC_PRODUCT_RELEASE="wallaby"
export RPC_ANSIBLE_VERSION="2.10.10"

# Skip OSA env.d check as RPC deploys custom env.d configurations
test -f /etc/openstack_deploy/env.d/cephrgwdummy.yml 2>&1 && export SKIP_CUSTOM_ENVD_CHECK=true

check_rpc_config
mark_started
checkout_openstack_ansible
ensure_osa_bootstrap
prepare_wallaby
run_upgrade
mark_completed
