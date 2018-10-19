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

export RE_JOB_SERIES=${RE_JOB_SERIES:-'newton'}

# determine incrementals to run depending on starting point
case "${RE_JOB_SERIES}" in
  newton)
  RELEASE_TO_DO="ocata pike queens"
  ;;
  ocata)
  RELEASE_TO_DO="pike queens"
  ;;
  pike)
  RELEASE_TO_DO="queens"
  ;;
  queens)
  echo "Queens is the latest upgrade available..."
  ;;
  *)
    echo "No valid RE_JOB_SERIES is to set."
    exit 99
  ;;
esac

if [[ ! -f /etc/openstack_deploy/user_variables.yml ]]; then
   echo "---" > /etc/openstack_deploy/user_variables.yml
   echo "default_bind_mount_logs: False" >> /etc/openstack_deploy/user_variables.yml
elif [[ -f /etc/openstack_deploy/user_variables.yml ]]; then
   if ! grep -i "default_bind_mount_logs" /etc/openstack_deploy/user_variables.yml; then
     echo "default_bind_mount_logs: False" >> /etc/openstack_deploy/user_variables.yml
   fi
fi

# run incremental upgrade scripts based on TODO list
pushd /opt/rpc-upgrades/incremental
  if [[ "${RELEASE_TO_DO}" =~ .*ocata.* ]]; then
    bash ubuntu16-newton-to-ocata.sh
  fi
  if [[ "${RELEASE_TO_DO}" =~ .*pike.* ]]; then
    bash ubuntu16-ocata-to-pike.sh
  fi
  if [[ "${RELEASE_TO_DO}" =~ .*queens.* ]]; then
    bash ubuntu16-pike-to-queens.sh
  fi
popd
