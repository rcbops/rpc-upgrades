#!/usr/bin/env bash

# Copyright 2018, Rackspace US, Inc.
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

set -evu

export RPC_BRANCH=${RPC_BRANCH:-'ocata'}
export OSA_SHA="c68da48c15bec69b4b58530055941332c5395676"

pushd /opt/rpc-openstack
  git clean -df
  git reset --hard HEAD
  rm -rf openstack-ansible
  rm -rf scripts/artifacts-building/
  git checkout ${RPC_BRANCH}
# checkout openstack-ansible-ops
popd

if [ ! -d "/opt/openstack-ansible" ]; then
  git clone --recursive https://github.com/openstack/openstack-ansible /opt/openstack-ansible
else
  pushd /opt/openstack-ansible
    git fetch --all
  popd
fi

##### rpc-o newton to ocata openstack-ansible transition mods

touch /etc/openstack_deploy/user_secrets.yml
rm /etc/openstack_deploy/user_secrets.yml
ln -s /etc/openstack_deploy/user_osa_secrets.yml /etc/openstack_deploy/user_secrets.yml
if ! grep -i "ironic_galera_password" /etc/openstack_deploy/user_osa_secrets.yml; then
  echo "ironic_galera_password: blah" >> /etc/openstack_deploy/user_osa_secrets.yml
fi

# remove variables that will cause issues jumping to ocata
sed -i '/^openstack_release.*/d' /etc/openstack_deploy/user_osa_variables_defaults.yml
sed -i '/^neutron_lbaas_git_repo.*/d' /etc/openstack_deploy/user_osa_variables_defaults.yml
sed -i '/^neutron_lbaas_git_install_branch.*/d' /etc/openstack_deploy/user_osa_variables_defaults.yml
sed -i '/^# Use rcbops version of neutron-lbaas.*/d' /etc/openstack_deploy/user_osa_variables_defaults.yml

# 10.1 client doesn't exist on rackspace mirrors
#sed -i 's/^galera_client_apt_repo_url:.*/galera_client_apt_repo_url: http://ftp.utexas.edu/mariadb/repo/10.1/ubuntu/g' /etc/openstack_deploy/user_rpco_galera.yml
#sed -i 's/^galera_apt_repo_url:.*/galera_apt_repo_url: http://ftp.utexas.edu/mariadb/repo/10.1/ubuntu/g' /etc/openstack_deploy/user_rpco_galera.yml
touch /etc/openstack_deploy/user_rpco_galera.yml
rm /etc/openstack_deploy/user_rpco_galera.yml

# remove artifacts repo, NOTE: will need to run on all hosts on MNAIO
if [ -f "/etc/apt/sources.list.d/rpco.list" ]; then
  rm -f /etc/apt/sources.list.d/rpco.list
fi

##### end rpc-o to openstack-ansible transition mods

pushd /opt/openstack-ansible
  git checkout ${OSA_SHA}
  scripts/bootstrap-ansible.sh
  source /usr/local/bin/openstack-ansible.rc
  export TERM=linux
  export I_REALLY_KNOW_WHAT_I_AM_DOING=true
  echo "YES" | bash scripts/run-upgrade.sh
popd
