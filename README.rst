==================================
Rackspace Private Cloud - Upgrades
==================================

Overview
--------

Incremental
-----------

Incremental upgrades are major version to major version upgrades that leverage the upstream 
run-upgrade.sh script provided in each release of Openstack Ansible.  They are used for
releases for releases Newton and on.  They allow a stairstep approach to upgrading the
environment.

Supported incremental upgrades:

Ubuntu 16.04 required:

* Newton to Pike (Ocata is skipped)
* Newton to Queens
* Queens to Rocky

Ubuntu 18.04 required:

* Rocky to Stein (testing)
* Stein to Train (testing)

Full docs for Incremental upgrades are `here <incremental.rst>`_.

Leapfrog
--------
A Leapfrog upgrade is a major upgrade that skips at least one release. Currently
rpc-upgrades repo supports:

Leapfrog upgrades from:

* kilo to r14.23.0 (newton)
* liberty to r14.23.0 (newton)
* mitaka to r14.23.0 (newton)

Full docs for Leapfrog upgrades are `here <leapfrog.rst>`_.

Job Testing
-----------

The status of supported versions can be viewed from the periodic jobs located on the
`RPC Jenkins <https://rpc.jenkins.cit.rackspace.net/view/Upgrades>`_ server.
