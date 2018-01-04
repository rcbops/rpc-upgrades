# Gating Automation for rpc-upgrades

## Currently Running Jobs

Currently rpc-upgrades runs two types of gating tests located in the gating directory:

* Pre Merge Tests - Tests are fired off on Pull Requests to validate that the change does not break any jobs.
* Post Merge Tests - Tests are fired off periodically on the various versions of upgrades that are supported to validate that the upgrades are still valid and that nothing has broken over time.

These gating jobs follow the guidelines set forth by the Release Engineering team [here](https://rpc-openstack.atlassian.net/wiki/spaces/RE/pages/19005457/RE+for+Projects).

### Upgrade types supported by rpc-upgrades

* Leapfrog Upgrade - Upgrades the private cloud from multiple releases behind.  i.e. (Kilo -> Newton)
* Major Upgrade - Upgrades a private cloud from the previous release i.e (Mitaka -> Newton)
* Minor Upgrade - Upgrades a private cloud from an earlier release of the same release.

##  Job Configurations

Jobs in Jenkins are configured [here](https://github.com/rcbops/rpc-gating/blob/master/rpc_jobs/rpc_upgrades.yml) and then generated inside our Jenkins infrastructure on the [Upgrades](https://rpc.jenkins.cit.rackspace.net/view/Upgrades/) view.

## Repo hooks

* gating/pre_merge_test/pre: Used for initial setup of environment, installs packages, etc.
* gating/pre_merge_test/run: Used for the actual deploy, upgrade and test of the upgrade job
* gating/pre_merge_test/post: Used for gathering artifacts, logs, and post job activities

## Job Name Formats

Jobs are set up in the following format:

    'PR_{repo_name}-{series}-{image}-{scenario}-{action}'
    'PM_{repo_name}-{branch}-{image}-{scenario}-{action}'

We use multiple variables in the action variable to determine what type of job we want to run as seen [here](https://github.com/rcbops/rpc-gating/blob/master/rpc_jobs/rpc_upgrades.yml#L42).  An action would be set as:

     "release-version-deployed_to_target-release_action"

so "r12.2.8_to_r14.6.0_leap" would mean, deploy r12.2.8 of rpc-openstack, and then leap to r14.6.0.  If you need to change the target release version to be tested, you would modify the second release value in the action.

Image is used to define whether the job is an AIO (All-in-One) job or a MNAIO (Multi Node AIO) job.
