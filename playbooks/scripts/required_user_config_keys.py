#!/usr/bin/env python

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

import sys

import yaml


__doc__ = """Script usage.
The "is_ssh_address" and "is_container_address" keys are required in the
[ openstack_user_config.yml ] file. These keys tell OpenStack-Ansible which
networks will be used for network connectivity and managing ssh sessions to the
containers and hosts. This script will look for the required keys. If the keys
are not found they will be appended to the "br-mgmt" network.

When this script executes it will return 0 if there are no changes. If the
script does change the anything it will return 3. Any other return code should
be considered an exception.
"""


def key_check_add(key, user_config_file, changed=False):
    """Add key if missing in the openstack_user_config.yml

    Check for a given key in the provider_networks section and add it if it's
    missing.

    :param key: str
    :param user_config_file: str
    :param changed: bool

    returns bool
    """

    with open(user_config_file) as f:
        user_config = yaml.load(f.read())

    print('Looking for "%s"' % key)
    provider_networks = user_config['global_overrides']['provider_networks']

    for network in provider_networks:
        net = network['network']
        if net.get(key):
            print('Key found.')
            break
    else:
        for network in provider_networks:
            net = network['network']
            if net['container_bridge'] == 'br-mgmt':
                net[key] = True
                changed = True
                print('Key set.')
                break

    if changed:
        with open(user_config_file, 'w') as f:
            f.write(
                yaml.dump(
                    user_config,
                    default_flow_style=False,
                    width=1000
                )
            )

    return changed


def main():
    user_config_file = '/etc/openstack_deploy/openstack_user_config.yml'

    changed_is_container_address = key_check_add(
        key='is_container_address',
        user_config_file=user_config_file
    )

    changed_is_ssh_address = key_check_add(
        key='is_ssh_address',
        user_config_file=user_config_file
    )

    if changed_is_ssh_address or changed_is_container_address:
        sys.exit(3)


if __name__ == '__main__':
    main()
