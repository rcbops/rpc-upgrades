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

pushd /opt/rpc-upgrades/playbooks
  # install maas
  openstack-ansible maas-get.yml -vv
  openstack-ansible /opt/rpc-maas/playbooks/site.yml -vv
  # verify maax is running
  openstack-ansible /opt/rpc-maas/playbooks/maas-verify.yml -vv
popd