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
    if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/variable-migration.complete" ]]; then
        # Following docs: https://pages.github.rackspace.com/rpc-internal/docs-rpc/rpc-upgrade-internal/rpc-upgrade-v12-v13-perform.html#migrate-variables
        if [[ ! -d variables-backup ]]; then
            mkdir variables-backup
        fi
        pushd variables-backup
            if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/user_extras_variables_migration.complete" ]]; then
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

            if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/user_variables_migration.complete" ]]; then
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

            if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/user_secrets_migration.complete" ]]; then
                cp /etc/openstack_deploy/*_secrets.yml ./
                pushd ${RPCO_DEFAULT_FOLDER}
                    scripts/update-secrets.sh
                    if [[ -f "/etc/openstack_deploy/user_secrets.yml" ]]; then
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
        # This message only needs to appears the first time the user variable migration was successful
        # This way, if a user mistakenly Ctrl-C, the variable migration process will be skipped on
        # the next run
        if [ "${VALIDATE_UPGRADE_INPUT}" != false ]; then
            notice "Please verify your migrated secrets in /etc/openstack_deploy"
            warning "DO NOT CTRL-C this process to verify your secrets."
            read -p "Press enter to continue when ready"
        fi
    else
        log "variable-migration" "skipped"
    fi
    if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/rebootstrap-ansible-for-rpc.complete" ]]; then
        pushd ${RPCO_DEFAULT_FOLDER}
            scripts/bootstrap-ansible.sh
            source /usr/local/bin/openstack-ansible.rc
        popd
        log "rebootstrap-ansible-for-rpc" "ok"
    fi
popd
pushd ${RPCO_DEFAULT_FOLDER}/rpcd/playbooks
    openstack-ansible configure-apt-sources.yml
popd
# Fix hostname with fixed period mark
if [[ -f "/etc/ansible/roles/openstack_hosts/templates/openstack-host-hostfile-setup.sh.j2" ]]; then
    pushd /etc/ansible/roles/openstack_hosts/templates/
        if grep -F '${RFCHOSTNAME}.${DOMAINNAME}' openstack-host-hostfile-setup.sh.j2 > /dev/null; then
            sed -i 's/${RFCHOSTNAME}.${DOMAINNAME}/${RFCHOSTNAME}${DOMAINNAME}/g' openstack-host-hostfile-setup.sh.j2
        fi
    popd
fi
