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
* Queens to Rocky

Supported incremental upgrades (must be running on Ubuntu 18.04):

* Rocky to Stein
* Stein to Train
* Train to Ussuri


Job Testing
-----------

The status of supported versions can be viewed from the periodic jobs located on the
`RPC Jenkins <https://rpc.jenkins.cit.rackspace.net/view/Upgrades>`_ server.

Pre Upgrade Tasks
------------------

* Verify that the deployment is healthy and at the latest version.
* Perform database housekeeping to prevent unnecessary migrations.

Prestaging Apt Packages
-----------------------

For large environments it make be worth prestaging the apt packages that will be downloaded for infra hosts
and computes ahead of time to speed up the leapfrog deployment process.  This will prevent issues of
slamming the mirror servers and will hopefully decrease the time of the actual maintenance since the
packages may already be staged in the apt cache.  Since these are incremental, make sure to run the preload
for each version you will be upgrading to.  This will put the needed apt files in the cache.

.. code-block:: shell

    cd /opt/rpc-upgrades/playbooks
    openstack-ansible preload-apt-packages.yml -e target_release=pike
    openstack-ansible preload-apt-packages.yml -e target_release=queens
    openstack-ansible preload-apt-packages.yml -e target_release=rocky
    openstack-ansible preload-apt-packages.yml -e target_release=stein
    openstack-ansible preload-apt-packages.yml -e target_release=train
    openstack-ansible preload-apt-packages.yml -e target_release=ussuri

This will temporarily install the apt sources for the target_release and apt download packages for infra and
compute hosts.  It also removes any rpco and uca repos that are currently in place as the upgrade will install
those again.  This can be ran in production and will not install anything, only download so it can be ran
outside of a maintenance.

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
