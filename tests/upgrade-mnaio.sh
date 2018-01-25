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

## Shell Opts ----------------------------------------------------------------

set -evu

# ssh command used to execute tests on infra1
export MNAIO_SSH="ssh -ttt -oStrictHostKeyChecking=no root@infra1"

# Run Leapfrog upgrade
${MNAIO_SSH} "source /opt/rpc-upgrades/RE_ENV; \
              source /opt/rpc-upgrades/tests/ansible-env.rc; \
              pushd /opt/rpc-upgrades; \
              tests/test-upgrade.sh"
echo "Leapfrog completed..."

# Install and Verify MaaS post leapfrog
${MNAIO_SSH} "source /opt/rpc-upgrades/RE_ENV; \
              source /opt/rpc-upgrades/tests/ansible-env.rc; \
              pushd /opt/rpc-upgrades; \
              tests/maas-install.sh"
echo "MaaS Install and Verify Post Leapfrog completed..."

# Run QC Tests
${MNAIO_SSH} "source /opt/rpc-upgrades/RE_ENV; \
              source /opt/rpc-upgrades/tests/ansible-env.rc; \
              pushd /opt/rpc-upgrades; \
              tests/qc-test.sh"
echo "QC Tests completed..."
