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
#
# (c) 2017, Jean-Philippe Evrard <jean-philippe.evrard@rackspace.co.uk>

## Shell Opts ----------------------------------------------------------------
set -e -u
set -o pipefail

# set encrypted vault files
export OS_DEPLOY_DIR="/etc/openstack_deploy"
export VAULT_ENCRYPTED_FILES="user_secrets.yml
                              user_osa_secrets.yml
                              user_rpco_secrets.yml"

# Preserve Elasticsearch data in the leap
export UPGRADE_ELASTICSEARCH=${UPGRADE_ELASTICSEARCH:-"yes"}
export CONTAINERS_TO_DESTROY=${CONTAINERS_TO_DESTROY:-'all_containers:!galera_all:!neutron_agent:!ceph_all:!rsyslog_all:!elasticsearch_all'}

# FLEEK-144 If password files have been encrypted by Ansible Vault, decrypt them during pre_leap
if [ -v ANSIBLE_VAULT_PASSWORD_FILE ]; then
  for FILENAME in ${VAULT_ENCRYPTED_FILES}; do
    echo "Checking to see if ${FILENAME} needs to be decrypted..."
    if [ -a "${OS_DEPLOY_DIR}/${FILENAME}" ]; then
      head -1 ${OS_DEPLOY_DIR}/${FILENAME} | grep -q \$ANSIBLE_VAULT \
      && ansible-vault decrypt ${OS_DEPLOY_DIR}/${FILENAME} --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE}
    fi
  done
else
  for FILENAME in ${VAULT_ENCRYPTED_FILES}; do
    # test to see if files are encrypted
    if [ -a "${OS_DEPLOY_DIR}/${FILENAME}" ]; then
      head -1 ${OS_DEPLOY_DIR}/${FILENAME} | grep -q \$ANSIBLE_VAULT \
      && echo "Password files are encrypted, please set location of Ansible \
      Vault File using export ANSIBLE_VAULT_PASSWORD_FILE=location_of_file" && exit 1
    fi
  done
fi

# Branches lower than Newton may have ansible_host: ansible_ssh_host mapping
# that will fail because ansible_ssh_host is undefined on ansible 2.1
# Strip it.
sed -i '/ansible_host/d' /etc/openstack_deploy/user*.yml

# Remove horizon static files variables from user_variables.yml as this is now
# maintained in group_vars.
if grep '^rackspace_static_files_folder\:' /etc/openstack_deploy/user_variables.yml; then
  sed -i '/^rackspace_static_files_folder:.*/d' /etc/openstack_deploy/user_variables.yml
fi

# Remove horizon_custom_uploads block from user_variables.yml as this is maintained in
# group_vars
if grep '^horizon_custom_uploads\:' /etc/openstack_deploy/user_variables.yml; then
  sed -i '/horizon_custom_uploads:/,/src:.*logo-splash.png/d' /etc/openstack_deploy/user_variables.yml
fi

# RLM-682 versions past 2.5.2 break things
echo "python-ldap==2.5.2" >> /opt/rpc-openstack/openstack-ansible/global-requirement-pins.txt

# remove setuptools and reinstall to avoid hitting a bug in setuptools 34.1.0
# this will be reinstalled fresh during the redeploy of ansible
pip uninstall -y setuptools
pip install setuptools==33.1.1 --isolated

# RLM-1375 Skip certain hardening tags during leap
export SKIP_HARDENING_TAGS="V-38462,V-38660"

# FLEEK-124 Older versions don't set the osa_secrets_file_name, if the osa_user_secrets.yml exists,
# then ensure that config option is set
if [ -f "/etc/openstack_deploy/user_osa_secrets.yml" ]; then
  if ! grep "^osa_secrets_file_name" /etc/openstack_deploy/user_osa_variables_defaults.yml; then
    echo 'osa_secrets_file_name: "user_osa_secrets.yml"' >> /etc/openstack_deploy/user_osa_variables_defaults.yml
  fi
fi
