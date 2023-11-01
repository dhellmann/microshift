#!/bin/bash

# Sourced from scenario.sh and uses functions defined there.

SKIP_GREENBOOT=true
TEST_RANDOMIZATION=none

scenario_create_vms() {
    prepare_kickstart host1 kickstart-liveimg.ks.template ""
    launch_vm host1 "rhel-9.2"

    if [ -f /tmp/subscription-manager-org ]; then
        # CI workflow
        cat <<EOF > /tmp/sub.sh
#!/bin/bash
set -xeuo pipefail

if ! sudo subscription-manager status >&/dev/null; then
    sudo subscription-manager register \
        --org="\$(cat /tmp/subscription-manager-org)" \
        --activationkey="\$(cat /tmp/subscription-manager-act-key)"
fi
EOF
        copy_file_to_vm host1 /tmp/sub.sh /tmp/sub.sh
        copy_file_to_vm host1 /tmp/subscription-manager-org /tmp/subscription-manager-org
        copy_file_to_vm host1 /tmp/subscription-manager-act-key /tmp/subscription-manager-act-key
        run_command_on_vm host1 "chmod +x /tmp/sub.sh && sudo /tmp/sub.sh"
    else
        # Local developer workflow
        run_command_on_vm host1 "sudo subscription-manager register"
    fi
}

scenario_remove_vms() {
    remove_vm host1
}

scenario_run_tests() {
    local -r source_reponame=$(basename "${LOCAL_REPO}")

    # Determine the version of the RPM in the local repo so we can use it
    # in the blueprint templates.
    if [ ! -d "${LOCAL_REPO}" ]; then
        error "Run ${SCRIPTDIR}/create_local_repo.sh before building images."
        return 1
    fi
    local -r release_info_rpm=$(find "${LOCAL_REPO}" -name 'microshift-release-info-*.rpm' | sort | tail -n 1)
    if [ -z "${release_info_rpm}" ]; then
        error "Failed to find microshift-release-info RPM in ${LOCAL_REPO}"
        return 1
    fi
    local -r release_info_rpm_base=$(find "${BASE_REPO}" -name 'microshift-release-info-*.rpm' | sort | tail -n 1)
    if [ -z "${release_info_rpm_base}" ]; then
        error "Failed to find microshift-release-info RPM in ${BASE_REPO}"
        return 1
    fi
    local -r SOURCE_VERSION=$(rpm -q --queryformat '%{version}' "${release_info_rpm}")
    local -r CURRENT_VERSION=$(echo "${SOURCE_VERSION}" | cut -f1-2 -d.)
    local -r MINOR_VERSION=$(echo "${CURRENT_VERSION}" | cut -f2 -d.)
    local -r PREVIOUS_MINOR_VERSION=$(( "${MINOR_VERSION}" - 1 ))

    run_tests host1 \
        --variable "SOURCE_REPO_URL:${WEB_SERVER_URL}/rpm-repos/${source_reponame}" \
        --variable "DEPENDENCY_VERSION:4.${PREVIOUS_MINOR_VERSION}" \
        --variable "PREVIOUS_MINOR_VERSION:${PREVIOUS_MINOR_VERSION}" \
        --variable "TARGET_VERSION:${SOURCE_VERSION}" \
        suites/rpm/install-successful.robot
}
