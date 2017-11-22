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

.. code-block:: shell

    RE_JOB_ACTION=<from_version>_to_<to_version>_<upgrade_action>
    RE_JOB_ACTION=kilo_to_newton_leap ./run-tests.sh


If you wish to run the tests against a specific version, set the
from and to versions in `RE_JOB_ACTION` to the versions or branches
you wish to test with.

.. code-block:: shell

    RE_JOB_ACTION=r11.1.8_to_r14.4.1_leap ./run-tests.sh


When you executing the `run-tests.sh` script a full AIO will be
built and then the upgrade tools executed against it. This will
allow for the rapid testing and proto-typing within a localized
environment.
