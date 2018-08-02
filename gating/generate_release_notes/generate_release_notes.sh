#!/bin/bash -x

# This script is run within a docker container to generate release notes.

/generate_reno_report.sh $NEW_TAG reno_report.md
report_status=$?

if [[ ${report_status} == 0 ]]; then
	cat reno_report.md > all_notes.md
else
	cat reno_report.md.err
fi

exit ${report_status}
