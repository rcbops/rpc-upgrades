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
export RPC_TARGET_CHECKOUT=${RPC_TARGET_CHECKOUT:-'newton'}
export OS_DEPLOY_DIR="/etc/openstack_deploy"
export VAULT_ENCRYPTED_FILES="user_secrets.yml
                              user_extras_secrets.yml
                              user_osa_secrets.yml
                              user_rpco_secrets.yml"

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


# disable elasticsearch upgrade by default for gating
export UPGRADE_ELASTICSEARCH=no
export CONTAINERS_TO_DESTROY='all_containers:!galera_all:!neutron_agent:!ceph_all:!rsyslog_all'

# export the term to avoid unknown: I need something more specific error in jenkins
export TERM=linux

# disable ELK deploy
export DEPLOY_ELK="no"

# execute leapfrog
sudo --preserve-env $(readlink -e $(dirname ${0}))/../scripts/ubuntu14-leapfrog.sh

# FLEEK-144 Decrypt after upgrade testing to allow other gate jobs to function
for FILENAME in ${VAULT_ENCRYPTED_FILES}; do
  if [ -f ${OS_DEPLOY_DIR}/${FILENAME} ]; then
    ansible-vault decrypt ${OS_DEPLOY_DIR}/${FILENAME} --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE}
  fi
done
