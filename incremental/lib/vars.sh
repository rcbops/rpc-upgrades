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

# vars for incremental upgrades
RELEASES="newton
          ocata
          pike
          queens
          rocky"

STARTING_RELEASE=false
SKIP_PREFLIGHT=${SKIP_PREFLIGHT:-false}
UPGRADES_WORKING_DIR=/etc/openstack_deploy/rpc-upgrades
OS_DEPLOY_DIR=${OS_DEPLOY_DIR:-/etc/openstack_deploy}
VAULT_ENCRYPTED_FILES="user_secrets.yml
                       user_osa_secrets.yml
                       user_rpco_secrets.yml
                       user_extras_secrets.yml"
