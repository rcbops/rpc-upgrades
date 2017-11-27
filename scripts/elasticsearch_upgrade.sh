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
set -e -u -x
set -o pipefail

pushd /opt/rpc-upgrades/playbooks
    # Update pip.conf on Elasticsearch container
    openstack-ansible elasticsearch-postleap-pip-upgrade.yml

    # Stop logstash service on Logstash container
    openstack-ansible logstash-stop.yml
popd

pushd /opt/rpc-openstack/rpcd/playbooks
    # Run elasticsearch upgrade playbook
    openstack-ansible -e 'logging_upgrade=true' --tags 'reindex-wrapper,elasticsearch-upgrade' elasticsearch.yml
popd

pushd /opt/rpc-upgrades/playbooks
    # Restore logstash service on Logstash container
    openstack-ansible logstash-start.yml
popd
