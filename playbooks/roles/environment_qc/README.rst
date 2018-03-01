=======================
Environment Quality Control
=======================

An Ansible role that runs quaity control procedures for Environment

These procedures include:

* Verify all hosts (hosts, containers, etc.) are up and pinging
* Verify Disk Space on physical storage hosts

.. note:

  This role is intentionally littered with debug tasks. This is to help the operator
  with any questions they may have about the values being checked.

Adding tasks to this role
~~~~~~~~~~~~~~~~~~~~~~~~

If at any point you would like to see a task added to this role, please submit an issue to
rpc-upgrades explaining what you would like to add, and why. Issues can be submitted
`here <https://github.com/rcbops/rpc-upgrades/issues>`_.
