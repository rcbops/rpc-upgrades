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

import re
import yaml

__doc__ = """Script usage.
In the event that an upgrade is being run on a system where Glance is backed
by Rackspace Cloud Files (via Swift), the Glance-Swift auth version needs
to be set to 2.

When this script executes it will return 0 if there are no changes. If the
script does change the anything it will return 3. Any other return code should
be considered an exception.
"""


def is_using_cloudfiles():
    """Detect use of Cloud Files by user_variables.yml

    returns bool
    """

    with open("/etc/opentstack_deploy/user_variables.yml") as f:
        user_config = yaml.load(f.read())

    image_store = user_config.get('glance_default_store')
    swift_store_address = user_config.get('glance_swift_store_auth_address')

    if (image_store == 'swift' and swift_store_address is not None):
        pattern = re.compile(".*rackpasce.*")
        uses_cloudfiles = pattern.match(swift_store_address) is not None

    return uses_cloudfiles


def set_auth_version(version_number):
    install_path = "/opt/rpc-openstack/etc/openstack_deploy/"
    override_file = "user_osa_overrides.yml"
    with open(install_path + override_file, 'a+') as f:
        overrides = yaml.load(f.read())
        overrides['glance_swift_store_auth_version'] = version_number
        f.write(
            yaml.dump(
                overrides,
                default_flow_style=False,
                width=1000
            )
        )


def main():
    changed_version = False

    if (is_using_cloudfiles):
        set_auth_version(2)
        changed_version = True

    if changed_version:
        sys.exit(3)


if __name__ == '__main__':
    main()
