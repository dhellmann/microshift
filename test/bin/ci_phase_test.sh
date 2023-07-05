#!/bin/bash
#
# This script runs on the CI cluster, from the metal-tests step.

set -xeuo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPTDIR}/common.sh"

cd "${TESTDIR}"

for scenario in ./scenarios/*.sh; do
    scenario_name="$(basename "${scenario}" .sh)"
    logfile="${SCENARIO_INFO_DIR}/${scenario_name}/run.log"
    mkdir -p "$(dirname "${logfile}")"
    bash -x ./bin/scenario.sh run "${scenario}" >"${logfile}" 2>&1 &
done

FAIL=0
for job in $(jobs -p) ; do
    jobs -l
    echo "Waiting for job: ${job}"
    wait "${job}" || ((FAIL+=1))
done

echo "Test phase complete"
if [[ ${FAIL} -ne 0 ]]; then
    exit 1
fi
