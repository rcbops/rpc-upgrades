===================
Creating a test AIO
===================

Leapfrog AIO test Process
-------------------------

Build virtual instance with at least 6vcpu, 15GB RAM, 160gb SDD
The flavor ID: 7 (15GB Standard Instance) works well using the
`Ubuntu 14.04 LTS (Trusty Tahr) (PVHVM)` image.

Once the test VM is online, simply clone this repo, checkout your
desired branch, set the RE_JOB_ACTION and run the script
`run-tests.sh`. This will perform the upgrade exactly as gating
job hooks will.

It should follow this format:

.. code-block:: shell

    RE_JOB_ACTION=<from_version>_to_<to_version>_<upgrade_action>

An example would be:

.. code-block:: shell

    export RE_JOB_ACTION=kilo_to_newton_leap ./run-tests.sh


If you wish to run the tests against a specific version, set the
from and to versions in `RE_JOB_ACTION` to the versions or branches
you wish to test with.

.. code-block:: shell

    export RE_JOB_ACTION=r12.2.8_to_r14.18.0_leap
    ./run-tests.sh


When you executing the `run-tests.sh` script a full AIO will be
built and then the upgrade tools executed against it. This will
allow for the rapid testing and proto-typing within a localized
environment.

======================================
Creating a test MNAIO (Multi Node AIO)
======================================

Leapfrog MNAIO Test Process
---------------------------

Build an OnMetal server using the flavor onmetal-io1 and running
Ubuntu 16.04 LTS.

You'll need to set the RE_JOB_IMAGE to trusty_mnaio in order to
trigger the mnaio code path.  Then set the action to set the
leap you want to test.

.. code-block:: shell

    export RE_JOB_IMAGE=trusty_mnaio
    export RE_JOB_ACTION=kilo_to_newton_leap
    ./run-tests.sh


This should kick off the Multi Node AIO build, then prep the
rpc-openstack, push the configs to infra1 and boot start the
RPC-O deploy from there.  By default an Ubuntu 14.04 LTS
(trusty) image is used for the VMs for all leapfrog jobs.

Incremental MNAIO Test Process
------------------------------
For testing Incremental upgrades for builds past Newton, build
an OnMetal server using the flavor onmetal-io1/io2 and running
Ubuntu 16.04/18.04 LTS.

If you want to build a Newton Deployment from scratch export
these variables:

.. code-block:: shell

    export RE_JOB_ACTION="newton_to_queens_incremental"
    export RE_JOB_IMAGE="xenial_mnaio"
    ./run-tests.sh

If you want to utilize a Snapshot Build which uses a prebuilt VMs and
already has the version to be upgraded from deployed, then use:

.. code-block:: shell

    export RE_JOB_ACTION="newton_to_queens_incremental"
    export RE_JOB_IMAGE="xenial_mnaio-snap"
    ./run-tests.sh

The snapshot builds can save 2-3 hours of deployment time on average.