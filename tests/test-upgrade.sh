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

export RPC_TARGET_CHECKOUT=${RE_JOB_UPGRADE_TO:-'newton'}
if [[ ${RE_JOB_UPGRADE_TO} == "r14.current" ]]; then
  pushd /opt/rpc-openstack
    echo "Getting latest tagged release for r14.current..."
    git fetch --all
    RPC_TARGET_CHECKOUT=`git for-each-ref refs/tags --sort=-taggerdate --format='%(tag)' | grep r14. | head -1`
    echo "Upgrading to latest release of ${RPC_TARGET_CHECKOUT} (Newton)..."
  popd
else
  echo "Ensure we have the latest version of the repo..."
  pushd /opt/rpc-openstack
    git fetch --all
  popd
fi

if [ "${RE_JOB_UPGRADE_ACTION}" == "leap" ]; then
  tests/test-leapfrog.sh
elif [ "${RE_JOB_UPGRADE_ACTION}" == "major" ]; then
  tests/test-major.sh
elif [ "${RE_JOB_UPGRADE_ACTION}" == "minor" ]; then
  tests/test-minor.sh
elif [ "${RE_JOB_UPGRADE_ACTION}" == "inc" ] ; then
  tests/test-incremental.sh
else
  echo "FAIL!"
  echo "RE_JOB_UPGRADE_ACTION '${RE_JOB_UPGRADE_ACTION}' is not supported."
  exit 99
fi
