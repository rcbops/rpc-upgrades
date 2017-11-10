===================
Creating a test AIO
===================

Leapfrog AIO test Process
-------------------------

Build virtual instance with at least 6vcpu, 15GB RAM, 160gb SDD
The flavor ID: 7 (15GB Standard Instance) works well using the
`Ubuntu 14.04 LTS (Trusty Tahr) (PVHVM)` image.

Once the test VM is online, simply clone this repo, checkout your
desired branch, set the RE_JOB_CONTEXT and run the script
`run-tests.sh`.

.. code-block:: shell

    RE_JOB_SERIES=kilo ./run-tests.sh


If you wish to run the tests against a specific checkout within a
given context set the variable `RE_JOB_SERIES` to the checkout you
wish to test with.

.. code-block:: shell

    # Build the environment using the kilo context
    #  Use RPC-O version r11.1.1 to create our AIO.
    RE_JOB_CONTEXT=r11.1.1 RE_JOB_SERIES=kilo ./run-tests.sh


When you executing the `run-tests.sh` script a full AIO will be
built and then the leapfrog tools executed against it. This will
allow for the rapid testing and proto-typing within a localized
environment.
