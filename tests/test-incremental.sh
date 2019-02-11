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

source tests/test-vault.sh

export RE_JOB_UPGRADE_TO=${RE_JOB_UPGRADE_TO:-'queens'}

setup_vault_test

pushd /opt/rpc-upgrades/incremental
  export SKIP_PREFLIGHT=true
  ./incremental-upgrade.sh ${RE_JOB_UPGRADE_TO}
popd

cleanup_vault_test
