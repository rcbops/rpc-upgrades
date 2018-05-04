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

## Notice:
# Please do not run this script separately. This script is meant to run
# Inside the OSA Leapfrog.

## Shell Opts ----------------------------------------------------------------
set -e -u -x
set -o pipefail

# The following must be "--for-testing-take-new-vars-only" to skip questions
export AUTOMATIC_VAR_MIGRATE_FLAG="${AUTOMATIC_VAR_MIGRATE_FLAG:-}"
export RPCD_DIR="${RPCD_DIR:-/opt/rpc-openstack/rpcd}"
export RPCD_OVERRIDES="${RPCD_OVERRIDES:-/etc/openstack_deploy/user_rpco_variables_overrides.yml}"
export OA_OVERRIDES="${OA_OVERRIDES:-/etc/openstack_deploy/user_osa_variables_overrides.yml}"

warning "Please DO NOT interrupt this process."
notice "Pre redeploy steps"
pushd ${LEAPFROG_DIR}
    if [ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/variable-migration.complete" ]; then
        # Following docs: https://pages.github.rackspace.com/rpc-internal/docs-rpc/rpc-upgrade-internal/rpc-upgrade-v12-v13-perform.html#migrate-variables
        if [ ! -d variables-backup ]; then
            mkdir variables-backup
        fi
        pushd variables-backup
            if [ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/user_extras_variables_migration.complete" ]; then
                cp /etc/openstack_deploy/user_extras_variables.yml ./
                pushd ${RPCO_DEFAULT_FOLDER}/scripts
                    "${RPCO_DEFAULT_FOLDER}"/scripts/migrate-yaml.py ${AUTOMATIC_VAR_MIGRATE_FLAG} \
                        --defaults "${RPCD_DIR}${RPCD_DEFAULTS}" \
                        --overrides /etc/openstack_deploy/user_extras_variables.yml \
                        --output-file ${RPCD_OVERRIDES}
                    rm -f /etc/openstack_deploy/user_extras_variables.yml
                popd
                rm -f /etc/openstack_deploy/user_extras_variables.yml
                log "user_extras_variables_migration" "ok"
            else
                log "user_extras_variables_migration" "skipped"
            fi

            if [ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/user_variables_migration.complete" ]; then
                cp /etc/openstack_deploy/user_variables.yml ./
                pushd ${RPCO_DEFAULT_FOLDER}/scripts
                    "${RPCO_DEFAULT_FOLDER}"/scripts/migrate-yaml.py ${AUTOMATIC_VAR_MIGRATE_FLAG} \
                        --defaults "${RPCD_DIR}${OA_DEFAULTS}" \
                        --overrides /etc/openstack_deploy/user_variables.yml \
                        --output-file ${OA_OVERRIDES}
                    rm -f /etc/openstack_deploy/user_variables.yml
                popd
                rm -f /etc/openstack_deploy/user_variables.yml
                log "user_variables_migration" "ok"
            else
                log "user_variables_migration" "skipped"
            fi

            if [ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/user_secrets_migration.complete" ]; then
                cp /etc/openstack_deploy/*_secrets.yml ./
                pushd ${RPCO_DEFAULT_FOLDER}
                    scripts/update-secrets.sh
                    if [ -f "/etc/openstack_deploy/user_secrets.yml" ]; then
                        mv /etc/openstack_deploy/user_secrets.yml \
                           /etc/openstack_deploy/user_osa_secrets.yml
                    fi
                popd
                rm -f /etc/openstack_deploy/user_extras_secrets.yml
                log "user_secrets_migration" "ok"
                cp -a ${RPCO_DEFAULT_FOLDER}/rpcd/etc/openstack_deploy/*defaults* /etc/openstack_deploy
            else
                log "user_secrets_migration" "skipped"
            fi
        popd
        log "variable-migration" "ok"
    else
        log "variable-migration" "skipped"
    fi
    if [ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/rebootstrap-ansible-for-rpc.complete" ]; then
        pushd ${RPCO_DEFAULT_FOLDER}
            scripts/bootstrap-ansible.sh
            source /usr/local/bin/openstack-ansible.rc
        popd
        log "rebootstrap-ansible-for-rpc" "ok"
    fi
popd

if [ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/configure-apt-sources-rpc.complete" ]; then
    pushd ${RPCO_DEFAULT_FOLDER}/rpcd/playbooks
        openstack-ansible configure-apt-sources.yml
    popd
    log "configure-apt-sources-rpc" "ok"
fi

pushd /etc/openstack_deploy/
    # RLM-322 Set openstack_domain to blank to preserve short hostnames,
    #         if not otherwise configured.
    grep -q 'openstack_domain:' user_*.yml 2>/dev/null || echo "openstack_domain: ''" |tee -a $OA_OVERRIDES

    # ensure user_leapfrog_overrides.yml is created
    # settings in this file will exist for the leapfrog upgrade and then be removed
    echo "---" > user_leapfrog_overrides.yml

    # RLM-1423 Increase apt cache timeout to cover time to run maintenance
    sed -i '/^cache_timeout.*/d' user_*.yml
    echo "cache_timeout: '21600'" | tee -a user_leapfrog_overrides.yml
popd

# RLM-1340 Remove serialization throttle due to 100% API down time
cat << EOF > /etc/openstack_deploy/user_leapfrog_overrides.yml
# Remove throttle for leapfrog
nova_compute_serial: '100%'
nova_conductor_serial: '100%'
nova_console_serial: '100%'
nova_scheduler_serial: '100%'
nova_api_serial: '100%'
neutron_agent_serial: '100%'
neutron_server_serial: '100%'
neutron_other_serial: '100%'
cinder_backend_serial: '100%'
cinder_scheduler_serial: '100%'
cinder_api_serial: '100%'
glance_api_serial: '100%'
glance_registry_rolling: '100%'
EOF

# RLM-1438 patch openstack_hosts fork into 14.7.0 to ensure RLM-322 works
if [ "${RPC_TARGET_CHECKOUT}" = "r14.7.0" -a ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/patch-rpc-o-14.7.0-ansible-role-requirements.complete" ]; then
   pushd ${RPCO_DEFAULT_FOLDER}
     patch -p1 < ${RPC_UPGRADES_DEFAULT_FOLDER}/playbooks/patches/newton/rpc-o-14.7.0-ansible-role-requirements.patch
     test $? -eq 0 && touch "${UPGRADE_LEAP_MARKER_FOLDER}/patch-rpc-o-14.7.0-ansible-role-requirements.complete"
   popd
fi

# RLM-1465 patch group_vars/lxc to get around resolv.conf issue
if [ "${RPC_TARGET_CHECKOUT}" = "r14.11.0" -a ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/patch-rpc-o-14.11.0-resolv.conf.complete" ]; then
   pushd ${RPCO_DEFAULT_FOLDER}
     patch -p1 < ${RPC_UPGRADES_DEFAULT_FOLDER}/playbooks/patches/newton/rpc-o-14.11.0-resolv.conf.patch
     test $? -eq 0 && touch "${UPGRADE_LEAP_MARKER_FOLDER}/patch-rpc-o-14.11.0-resolv.conf.complete"
   popd
fi
