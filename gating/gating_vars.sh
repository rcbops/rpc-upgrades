# These vars are set by the CI environment, but are given defaults
# here to cater for situations where someone is executing the test
# outside of the CI environment.
export RE_JOB_NAME="${RE_JOB_NAME:-}"
export RE_JOB_IMAGE="${RE_JOB_IMAGE:-trusty_aio}"
export RE_JOB_SCENARIO="${RE_JOB_SCENARIO:-swift}"
export RE_JOB_ACTION="${RE_JOB_ACTION:-undefined}"
export RE_JOB_FLAVOR="${RE_JOB_FLAVOR:-}"
export RE_JOB_TRIGGER="${RE_JOB_TRIGGER:-PR}"
export RE_HOOK_ARTIFACT_DIR="${RE_HOOK_ARTIFACT_DIR:-/tmp/artifacts}"
export RE_HOOK_RESULT_DIR="${RE_HOOK_RESULT_DIR:-/tmp/results}"
