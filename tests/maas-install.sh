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
export RPCO_RELEASE=`cat /etc/openstack-release | grep DISTRIB_CODENAME | cut -d '"' -f2`
export RPC_MAAS_RELEASE=1.7.6
export SKIP_MAAS_PREFLIGHT="-e maas_pre_flight_metadata_check_enabled=false"

## Main ----------------------------------------------------------------------
# workaround for kilos incorrect code name
if [[ ${RPCO_RELEASE} == "1AndOne=11" ]]; then
  RPCO_RELEASE=kilo
fi

pushd /opt/rpc-upgrades/playbooks
  # checkout rpc-maas
  openstack-ansible maas-get.yml -e rpc_maas_release="${RPC_MAAS_RELEASE}" -e rpco_release="${RPCO_RELEASE}" -vv

  # install rpc-maas
  # if kilo and hasn't leaped, use a different swift_recon_path since kilo doesn't use venvs
  if [[ ${RE_JOB_SERIES} == "kilo" && ! -f /etc/openstack_deploy/upgrade-leap/osa-leap.complete ]]; then
    openstack-ansible /opt/rpc-maas/playbooks/site.yml -vv -e swift_recon_path="/usr/local/bin/" ${SKIP_MAAS_PREFLIGHT}
  else
   openstack-ansible /opt/rpc-maas/playbooks/site.yml -vv ${SKIP_MAAS_PREFLIGHT}
  fi

  # disabling as race condition appears to periodically allows to pass or fail
  # verify rpc-maas if leap has completed
  # if [[ -f /etc/openstack_deploy/upgrade-leap/osa-leap.complete ]]; then
  #   openstack-ansible /opt/rpc-maas/playbooks/maas-verify.yml -vv
  # fi
popd
