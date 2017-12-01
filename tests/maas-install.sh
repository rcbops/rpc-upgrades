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

## Vars ----------------------------------------------------------------------
export RE_JOB_SERIES="${RE_JOB_SERIES:-newton}"

# sets the desired maas_release to test
MAAS_RELEASE=master

pushd /opt/rpc-upgrades/playbooks
  # checkout rpc-maas
  if [ ! -d "/opt/rpc-maas" ]; then
    openstack-ansible maas-get.yml -e maas_release="${MAAS_RELEASE}" -vv
  fi

  # install rpc-maas
  # if kilo and hasn't leaped, use a different swift_recon_path since kilo doesn't use venvs
  if [[ ${RE_JOB_SERIES} == "kilo" && ! -f /etc/openstack_deploy/upgrade-leap/osa-leap.complete ]]; then
    openstack-ansible /opt/rpc-maas/playbooks/site.yml -e swift_recon_path="/usr/local/bin/" -vv
  else
   openstack-ansible /opt/rpc-maas/playbooks/site.yml -vv
  fi

  # verify rpc-maas
  openstack-ansible /opt/rpc-maas/playbooks/maas-verify.yml -vv
popd
