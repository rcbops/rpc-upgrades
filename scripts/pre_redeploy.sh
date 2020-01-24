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

# if this is a MITAKA v13 to v14 upgrade, prep the upgrade
if [ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/fixup-mitaka-leap.complete" ]; then
    if [ ${CODE_UPGRADE_FROM} == "MITAKA" ]; then
        # skip the variable migration for MITAKA
        touch /etc/openstack_deploy/upgrade-leap/variable-migration.complete
        # remove user_osa_variables_defaults as existing settings will not work in newton
        if [ -f "/etc/openstack_deploy/user_osa_variables_defaults.yml" ]; then
            rm /etc/openstack_deploy/user_osa_variables_defaults.yml
            # add needed variables back to user_osa_variables_defaults.yml
            echo -e '---\n\nosa_secrets_file_name: "user_osa_secrets.yml"' > /etc/openstack_deploy/user_osa_variables_defaults.yml
            echo 'openstack_release: "{{ rpc_release }}"' >> /etc/openstack_deploy/user_osa_variables_defaults.yml
        fi
        # disable ceilometer on AIOS, swift breaks because it depends on ceilometer running
        if [ -f /etc/openstack_deploy/user_osa_aio_variables.yml ]; then
            if grep -i "_ceilometer_enabled" /etc/openstack_deploy/user_osa_aio_variables.yml; then
                sed -i '/_ceilometer_enabled/d' /etc/openstack_deploy/user_osa_aio_variables.yml
            fi
        fi
    fi
    log "fixup-mitaka-leap" "ok"
else
    log "fixup-mitaka-leap" "skipped"
fi

# for everything pre v13
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

# rsync group_vars from RPC-O repo
if [ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/rpco-group-vars-sync.complete" ]; then
  rsync -av --delete ${RPCO_DEFAULT_FOLDER}/group_vars /etc/openstack_deploy/
  touch "${UPGRADE_LEAP_MARKER_FOLDER}/rpco-group-vars-sync.complete"
fi
