#! /usr/bin/env bash
#   Copyright 2023 The MicroShift authors
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

shopt -s expand_aliases
shopt -s extglob

trap 'echo "Script exited with error."' ERR

#debugging options
#trap 'echo "#L$LINENO: $BASH_COMMAND" >&2' DEBUG
#set -xo functrace
#PS4='+ $LINENO  '

SCRIPTDIR=$(dirname "${BASH_SOURCE[0]}")
source "$SCRIPTDIR/rebase-lib.sh"

STAGING_DIR="$REPOROOT/_output/okd-staging"


usage() {
    cat - 1>&2 <<EOF
Usage:
  $(basename $0) to RELEASE_IMAGE_INTEL

    Performs all the steps to rebase to a release image. Specify both
    amd64 and arm64 ocp releases, and multi-arch lvms operator bundle
    image.

  $(basename $0) download RELEASE_IMAGE_INTEL

    Downloads the content of a release image to disk in preparation
    for rebasing. Specify both amd64 and arm64 and multi-arch lvms
    operator bundle image.

EOF
}


get_image_list() {
    local release_image_amd64="$1"

    authentication=""
    if [ -f "${PULL_SECRET_FILE}" ]; then
        authentication="-a ${PULL_SECRET_FILE}"
    else
        >&2 echo "Warning: no pull secret found at ${PULL_SECRET_FILE}"
    fi

    title "# Fetching release info for ${release_image_amd64} (amd64)"
    oc adm release info ${authentication} "${release_image_amd64}" -o json > release_amd64.json

    title "# Cloning ${release_image_amd64} image repos"
    download_image_state "${release_image_amd64}" "amd64"
}


download_release() {
    local release_image_amd64="$1"

    make_staging_dir
    pushd "${STAGING_DIR}" >/dev/null

    get_image_list "$release_image_amd64"
}


# Updates the image digests in pkg/release/release*.go
update_images() {
    if [ ! -f "${STAGING_DIR}/release_amd64.json" ]; then
        >&2 echo "No release found in ${STAGING_DIR}, you need to download one first."
        exit 1
    fi
    pushd "${STAGING_DIR}" >/dev/null

    title "Rebasing okd_*.json"
    # no arm64 builds, yet
    for goarch in amd64; do
        arch=${GOARCH_TO_UNAME_MAP["${goarch}"]:-noarch}

        # Update the base release
        base_release=$(jq -r ".metadata.version" "${STAGING_DIR}/release_${goarch}.json")
        jq --arg base "${base_release}" '
            .release.base = $base
            ' "${REPOROOT}/assets/okd/release-${arch}.json" > "${REPOROOT}/assets/okd/release-${arch}.json.tmp"
        mv "${REPOROOT}/assets/okd/release-${arch}.json.tmp" "${REPOROOT}/assets/okd/release-${arch}.json"

        # Get list of MicroShift's container images
        images=$(jq -r '.images | keys[]' "${REPOROOT}/assets/okd/release-${arch}.json" | xargs)

        # Extract the pullspecs for these images from OCP's release info
        jq --arg images "$images" '
            reduce .references.spec.tags[] as $img ({}; . + {($img.name): $img.from.name})
            | with_entries(select(.key == ($images | split(" ")[])))
            ' "release_${goarch}.json" > "update_${goarch}.json"

        # Update MicroShift's release info with these pullspecs
        jq --slurpfile updates "update_${goarch}.json" '
            .images += $updates[0]
            ' "${REPOROOT}/assets/okd/release-${arch}.json" > "${REPOROOT}/assets/okd/release-${arch}.json.tmp"
        mv "${REPOROOT}/assets/okd/release-${arch}.json.tmp" "${REPOROOT}/assets/okd/release-${arch}.json"

        # Update crio's pause image
        pause_image_digest=$(jq -r '
            .references.spec.tags[] | select(.name == "pod") | .from.name
            ' "release_${goarch}.json")
        sed -i "s|pause_image =.*|pause_image = \"${pause_image_digest}\"|g" \
            "${REPOROOT}/packaging/crio.conf.d/microshift_okd_${goarch}.conf"
    done

    # 2023-03-02: Freeze ovn-kubernetes-microshift-rhel-9 to avoid using image "double metrics registration panic" issue
    # TODO: Remove when issue is fixed
    jq -e '.images."ovn-kubernetes-microshift-rhel-9" = "quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:5ab6561dbe5a00a9b96e1c29818d8376c8e871e6757875c9cf7f48e333425065"' \
        "${REPOROOT}/assets/okd/release-x86_64.json" > "${REPOROOT}/assets/okd/release-x86_64.json.tmp"
    mv "${REPOROOT}/assets/okd/release-x86_64.json.tmp" "${REPOROOT}/assets/okd/release-x86_64.json"

    popd >/dev/null
}


# Updates a script to record the last rebase that was run to make it
# easier to reproduce issues and to test changes to the rebase script
# against the same set of images.
update_last_rebase() {
    local release_image_amd64=$1

    title "## Updating last_okd_rebase.sh"

    local last_rebase_script="${REPOROOT}/scripts/auto-rebase/last_okd_rebase.sh"

    rm -f "${last_rebase_script}"
    cat - >"${last_rebase_script}" <<EOF
#!/bin/bash -x
./scripts/auto-rebase/rebase-okd.sh to "${release_image_amd64}"
EOF
    chmod +x "${last_rebase_script}"

    # (cd "${REPOROOT}" && \
    #      test -n "$(git status -s scripts/auto-rebase/last_rebase.sh)" && \
    #      title "## Committing changes to last_rebase.sh" && \
    #      git add scripts/auto-rebase/last_rebase.sh && \
    #      git commit -m "update last_rebase.sh" || true)
}


rebase_to() {
    local release_image_amd64="$1"

    download_release "$release_image_amd64"
    update_images
    update_last_rebase "$release_image_amd64"
}


command=${1:-help}
case "$command" in
    to)
        [[ $# -ne 2 ]] && usage
        rebase_to "$2"
        ;;
    download)
        [[ $# -ne 2 ]] && usage
        download_release "$2"
        ;;
    *) usage;;
esac
