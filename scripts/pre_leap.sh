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

# Preserve Elasticsearch data in the leap
export UPGRADE_ELASTICSEARCH=${UPGRADE_ELASTICSEARCH:-"yes"}
export CONTAINERS_TO_DESTROY='"'"${CONTAINERS_TO_DESTROY:-all_containers:!galera_all:!neutron_agent:!ceph_all:!rsyslog_all:!elasticsearch_all}"'"'

# Branches lower than Newton may have ansible_host: ansible_ssh_host mapping
# that will fail because ansible_ssh_host is undefined on ansible 2.1
# Strip it.
if [[ -f /etc/openstack_deploy/user_rpcm_default_variables.yml ]]; then
    sed -i '/ansible_host/d' /etc/openstack_deploy/user_rpcm_default_variables.yml
fi

# Check for ceph
pushd "/opt/rpc-openstack/openstack-ansible"
    if ! scripts/inventory-manage.py -g | grep ceph > /dev/null; then
        echo "No ceph found, we can continue"
    else
        echo "Ceph group found, the leapfrog can't continue"
        exit 1
    fi
popd

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
