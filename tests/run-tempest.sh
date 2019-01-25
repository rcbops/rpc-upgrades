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

# remove tempest settings from openstack_deploy variable files
if [ -f /etc/openstack_deploy/user_variables.yml ]; then
  sed -i '/^tempest/d' /etc/openstack_deploy/user_variables.yml
fi
if [ -f /etc/openstack_deploy/user_rpco_variables_overrides.yml ]; then
  sed -i '/^tempest/d' /etc/openstack_deploy/user_rpco_variables_overrides.yml
fi
# remove tempest_images block as it doesn't contain format and we'll use the vars in tempest
if [ -f /etc/openstack_deploy/user_osa_variables_overrides.yml ]; then
  sed -i '/tempest_images:/,/.*x86_64-uec.tar.gz/d' /etc/openstack_deploy/user_osa_variables_overrides.yml
fi

# generate tempest tests
cat > /etc/openstack_deploy/user_rpco_tempest.yml <<EOF
---
tempest_install: yes
tempest_run: yes
# RI-357 Tempest Overrides
tempest_test_whitelist:
  - "{{ (tempest_service_available_ceilometer | bool) | ternary('tempest.api.telemetry', '') }}"
  - "{{ (tempest_service_available_heat | bool) | ternary('tempest.api.orchestration.stacks.test_non_empty_stack', '') }}"
  - "{{ (tempest_service_available_nova | bool) | ternary('tempest.scenario.test_server_basic_ops', '') }}"
  - "{{ (tempest_service_available_swift | bool) | ternary('tempest.scenario.test_object_storage_basic_ops', '') }}"
  - "{{ (tempest_volume_multi_backend_enabled | bool) | ternary('tempest.api.volume.admin.test_multi_backend', '') }}"
#  - "{{ (tempest_volume_backup_enabled | bool) | ternary('tempest.api.volume.admin.test_volumes_backup', '') }}"
EOF

if [ -d "/opt/openstack-ansible/playbooks" ]; then
  export TEMPEST_DIR="/opt/openstack-ansible/playbooks"
elif [ -d "/opt/rpc-openstack/openstack-ansible/playbooks" ]; then
  export TEMPEST_DIR="/opt/rpc-openstack/openstack-ansible/playbooks"
fi

pushd ${TEMPEST_DIR}
  # TODO: establish any overrides
  # install and run tempest
  openstack-ansible os-tempest-install.yml --skip-tags=rsyslog -vv
popd
