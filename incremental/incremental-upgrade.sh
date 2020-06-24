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

set -ev

source lib/functions.sh
source lib/vars.sh

discover_code_version
require_ubuntu_version 16
ensure_working_dir

# if target not set, exit and inform user how to proceed
if [[ -z "$1" ]]; then
  echo "Please set the target to upgrade to:"
  echo "i.e ./incremental-upgrade queens"
  exit 99
fi
# convert target to lowercase
TARGET=${1,,}

# check if environment is already upgraded to desired target
if [[ ${TARGET} == ${CODE_UPGRADE_FROM} ]]; then
  echo "Nothing to do, you're already upgraded to ${TARGET^}."
  exit 99
elif [[ ${TARGET} == "ocata" ]]; then
  echo "Upgrade directly to Ocata is not supported."
  echo "Pike would be the next supported upgrade target."
  exit 99
fi

# iterate RELEASES and generate TODO list based on target set
for RELEASE in ${RELEASES}; do
  if [[ "${RELEASE}" == "${CODE_UPGRADE_FROM}" ]]; then
    STARTING_RELEASE=true
  elif [[ "${RELEASE}" != "${TARGET}" && "${STARTING_RELEASE}" == "true" ]]; then
    TODO+="${RELEASE} "
  fi
  if [[ "${RELEASE}" == "${TARGET}" && "${STARTING_RELEASE}" == "true" ]]; then
    TODO+="${RELEASE} "
    break
  fi
done

# validate desired target is valid in the RELEASES list
if ! echo ${TODO} | grep -w ${TARGET} > /dev/null; then
  echo Unable to upgrade to the specified target, please check the target and try again.
  echo Valid releases to use are:
  echo ${TODO}
  exit 99
fi

check_user_variables
prepare_config_for_upgrade

if [ "${SKIP_PREFLIGHT}" != "true" ]; then
  pre_flight
fi

# run through TODO list and run incremental upgrade scripts
for RELEASE_TO_DO in ${TODO}; do
  if [ ! -f ${UPGRADES_WORKING_DIR}/upgrade-to-${RELEASE_TO_DO}.complete ]; then
    echo "Starting upgrade to ${RELEASE_TO_DO^}..."
    sleep 5
    bash ubuntu${DETECTED_VERSION}-upgrade-to-${RELEASE_TO_DO}.sh
  else
    echo
    echo "*** Previous upgrade to ${RELEASE_TO_DO^} was completed, moving onto next in series in 10 seconds...***"
    echo
    sleep 10
  fi
done

cleanup
