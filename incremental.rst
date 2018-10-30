==============================================
Rackspace Private Cloud - Incremental Upgrades
==============================================

Overview
--------

Incremental
-----------

Incremental upgrades are major version to major version upgrades that leverage the upstream
run-upgrade.sh script provided in each release of Openstack Ansible.  They are used for
releases for releases Newton and on.  They allow a stairstep approach to upgrading the
environment.

Supported incremental upgrades (must be running on Ubuntu 16.04):

* Newton to Pike (Ocata is skipped)
* Newton to Queens

Job Testing
-----------

The status of supported versions can be viewed from the periodic jobs located on the
`RPC Jenkins <https://rpc.jenkins.cit.rackspace.net/view/Upgrades>`_ server.

Pre Upgrade Tasks
------------------

* Verify that the deployment is healthy and at the latest version.
* Perform database housekeeping to prevent unnecessary migrations.

Executing an incremental upgrade
----------------------------

The first step is to checkout the rpc-upgrades repo.

.. code-block:: shell

    git clone https://github.com/rcbops/rpc-upgrades.git /opt/rpc-upgrades


The next step is to execute the incremental upgrade script and follow the prompts:

.. code-block:: shell

    cd /opt/rpc-upgrades/incremental
    ./incremental-upgrade.sh <target release>
    
The target release will be the destination release you want to upgrade to.

Testing
-------

In the event you would like to simulate an incremental upgrade, follow the
instructions in the `testing document 
<https://github.com/rcbops/rpc-upgrades/blob/master/testing.rst>`_.  Using
vagrant, it will set up an AIO deployment of the desired version which can then
be leapfrog upgraded.  This allows you to test the scenario in the lab or
development environment before actually running the upgrade on a production
deployment.
