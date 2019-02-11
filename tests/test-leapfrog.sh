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

set -evu

source tests/test-vault.sh

export VALIDATE_UPGRADE_INPUT=false
export AUTOMATIC_VAR_MIGRATE_FLAG="--for-testing-take-new-vars-only"
export RPC_TARGET_CHECKOUT=${RPC_TARGET_CHECKOUT:-'newton'}
export OS_DEPLOY_DIR="/etc/openstack_deploy"
export VAULT_ENCRYPTED_FILES="user_secrets.yml
                              user_extras_secrets.yml
                              user_osa_secrets.yml
                              user_rpco_secrets.yml"

setup_vault_test

# disable elasticsearch upgrade by default for gating
export UPGRADE_ELASTICSEARCH=no
export CONTAINERS_TO_DESTROY='all_containers:!galera_all:!neutron_agent:!ceph_all:!rsyslog_all'

# export the term to avoid unknown: I need something more specific error in jenkins
export TERM=linux

# disable ELK deploy
export DEPLOY_ELK="no"

# execute leapfrog
sudo --preserve-env $(readlink -e $(dirname ${0}))/../scripts/ubuntu14-leapfrog.sh

cleanup_vault_test
