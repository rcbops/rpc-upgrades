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

export OS_DEPLOY_DIR="/etc/openstack_deploy"
export VAULT_ENCRYPTED_FILES="user_secrets.yml
                              user_osa_secrets.yml
                              user_rpco_secrets.yml"

export RPC_TARGET_CHECKOUT=${RE_JOB_UPGRADE_TO:-'newton'}
if [[ ${RE_JOB_UPGRADE_TO} == "r14.current" ]]; then
  pushd /opt/rpc-openstack
    echo "Getting latest tagged release for r14.current..."
    git fetch --tags
    RPC_TARGET_CHECKOUT=`git for-each-ref refs/tags --sort=-taggerdate --format='%(tag)' | grep r14. | head -1`
    echo "Upgrading to latest release of ${RPC_TARGET_CHECKOUT} (Newton)..."
  popd
fi


# FLEEK-144 Simulate ansible vault encrypted password files
export ANSIBLE_VAULT_PASSWORD_FILE=/root/.vault_pass.txt
if [ ! -f /root/.vault_pass.txt ]; then
  openssl rand -base64 64 > /root/.vault_pass.txt
fi

# encrypt before testing upgrades
for FILENAME in ${VAULT_ENCRYPTED_FILES}; do
  if [ -f ${OS_DEPLOY_DIR}/${FILENAME} ]; then
    ansible-vault encrypt ${OS_DEPLOY_DIR}/${FILENAME} --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE}
  fi
done

if [ "${RE_JOB_UPGRADE_ACTION}" == "leap" ]; then
  tests/test-leapfrog.sh
elif [ "${RE_JOB_UPGRADE_ACTION}" == "major" ]; then
  tests/test-major.sh
elif [ "${RE_JOB_UPGRADE_ACTION}" == "minor" ]; then
  tests/test-minor.sh
elif [ "${RE_JOB_UPGRADE_ACTION}" == "incremental" ] ; then
  tests/test-incremental.sh
else
  echo "FAIL!"
  echo "RE_JOB_UPGRADE_ACTION '${RE_JOB_UPGRADE_ACTION}' is not supported."
  exit 99
fi

# FLEEK-144 Decrypt after upgrade testing to allow other gate jobs to function
for FILENAME in ${VAULT_ENCRYPTED_FILES}; do
  if [ -f ${OS_DEPLOY_DIR}/${FILENAME} ]; then
    ansible-vault decrypt ${OS_DEPLOY_DIR}/${FILENAME} --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE}
  fi
done
