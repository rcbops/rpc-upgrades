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

export VALIDATE_UPGRADE_INPUT=false
export AUTOMATIC_VAR_MIGRATE_FLAG="--for-testing-take-new-vars-only"
export RPC_TARGET_CHECKOUT=${RE_JOB_UPGRADE_TO:-'newton'}

if [ "${RE_JOB_SERIES}" == "kilo" ]; then
  export OA_OPS_REPO_BRANCH="50f3fd6df7579006748a00c271bb03d22b17ae89"
  export UPGRADE_ELASTICSEARCH=no
  export CONTAINERS_TO_DESTROY='all_containers:!galera_all:!neutron_agent:!ceph_all:!rsyslog_all'
elif [ "${RE_JOB_SERIES}" == "liberty" ]; then
  export UPGRADE_ELASTICSEARCH=no
  export CONTAINERS_TO_DESTROY='all_containers:!galera_all:!neutron_agent:!ceph_all:!rsyslog_all'
fi

# export the term to avoid unknown: I need something more specific error in jenkins
export TERM=linux

# execute leapfrog
sudo --preserve-env $(readlink -e $(dirname ${0}))/../scripts/ubuntu14-leapfrog.sh
