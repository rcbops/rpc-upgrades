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
set -e -u -x
set -o pipefail

function get_latest_maas_release {
  if [ ! -d "/opt/rpc-maas" ]; then
    git clone https://github.com/rcbops/rpc-maas /opt/rpc-maas
  fi
  pushd /opt/rpc-maas
    LATEST_MAAS_TAG="$(git tag -l |grep -v '[a-zA-Z]\|^\(9\.\|10\.\)' |sort -n |tail -n 1)"
  popd
}

echo "POST LEAP STEPS"

if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/deploy-rpc.complete" ]]; then
  pushd ${RPCO_DEFAULT_FOLDER}/rpcd/playbooks/
    unset ANSIBLE_INVENTORY
    sed -i 's#export ANSIBLE_INVENTORY=.*#export ANSIBLE_INVENTORY="${ANSIBLE_INVENTORY:-/opt/rpc-openstack/openstack-ansible/playbooks/inventory}"#g' /usr/local/bin/openstack-ansible.rc
    sed -i 's#\*"/opt/openstack-ansible"\*#\*"/opt/rpc-openstack/openstack-ansible"\*#' /usr/local/bin/ansible
    # get latest maas_release and update config variable
    get_latest_maas_release
    sed -i 's/^maas_release:.*/maas_release: ${LATEST_MAAS_TAG}/g' /etc/openstack_deploy/user_rpco_variables_defaults.yml
    # TODO(remove the following hack to restart the neutron agents, when fixed upstream)
    ansible -m shell -a "restart neutron-linuxbridge-agent" nova_compute -i /opt/rpc-openstack/openstack-ansible/playbooks/inventory/dynamic_inventory.py
    openstack-ansible ${RPC_UPGRADES_DEFAULT_FOLDER}/playbooks/remove-old-agents-from-maas.yml
    . ${RPCO_DEFAULT_FOLDER}/scripts/deploy-rpc-playbooks.sh
  popd
  log "deploy-rpc" "ok"
else
  log "deploy-rpc" "skipped"
fi

# remove user_leapfrog_overrides.yml as it contains values used during the leapfrog process
rm -f /etc/openstack_deploy/user_leapfrog_overrides.yml

if [ "QC_TEST" == "yes" ]; then
  . /opt/rpc-upgrades/tests/test-qc.sh
fi

if [ "$UPGRADE_ELASTICSEARCH" == "yes" ]; then
  pushd /opt/rpc-upgrades/playbooks
    openstack-ansible elasticsearch-reindex.yml
  popd
fi

echo "LEAPFROG COMPLETE."
