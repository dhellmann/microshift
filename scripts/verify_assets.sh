#!/bin/bash

set -x

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
REPOROOT="$(readlink -f "${SCRIPT_DIR}/..")"
ASSETS_DIR="${REPOROOT}/assets"

MANIFEST_LIST="${SCRIPT_DIR}/manifests.txt"

# Ensure there are no files in the assets directory that are not in
# the manifests list.
actual_assets=$(mktemp --tmpdir actual.XXXX)
(cd "$ASSETS_DIR" && find -type f | grep -v bindata_timestamp.txt) > "${actual_assets}"

expected_assets=$(mktemp --tmpdir expected.XXXX)
cat "${SCRIPT_DIR}/manifests.txt" | grep -v -e '^#' -e '^$' | while read src dst; do
    echo "./${dst}/$(basename ${src})" >> "${expected_assets}"
done

diff "${expected_assets}" "${actual_assets}"
RC=$?

exit $RC
