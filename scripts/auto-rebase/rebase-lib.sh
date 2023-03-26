#!/usr/bin/env bash

declare -a ARCHS=("amd64" "arm64")
declare -A GOARCH_TO_UNAME_MAP=( ["amd64"]="x86_64" ["arm64"]="aarch64" )

PULL_SECRET_FILE="${HOME}/.pull-secret.json"
REPOROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../..")"

title() {
    echo -e "\n\E[34m$1\E[00m";
}


make_staging_dir() {
    title "# Cleaning ${STAGING_DIR}"
    rm -rf "${STAGING_DIR}"
    mkdir -p "${STAGING_DIR}"
}

# Clone a repo at a commit
clone_repo() {
    local repo="$1"
    local commit="$2"
    local destdir="$3"

    local repodir="${destdir}/${repo##*/}"

    if [[ -d "${repodir}" ]]
    then
        return
    fi

    title "## Cloning $repo"

    git init "${repodir}"
    pushd "${repodir}" >/dev/null
    git remote add origin "${repo}"
    git fetch origin --quiet  --filter=tree:0 --tags "${commit}"
    git checkout "${commit}"
    popd >/dev/null
}


# Determine the image info for one architecture
download_image_state() {
    local release_image="$1"
    local release_image_arch="$2"

    local release_info_file="release_${release_image_arch}.json"
    local commits_file="image-repos-commits-${release_image_arch}"
    local new_commits_file="new-commits.txt"

    # Determine the repos and commits for the repos that build the images
    cat "${release_info_file}" \
        | jq -j '.references.spec.tags[] | if .annotations["io.openshift.build.source-location"] != "" then .name," ",.annotations["io.openshift.build.source-location"]," ",.annotations["io.openshift.build.commit.id"] else "" end,"\n"' \
             | sort -u \
             | grep -v '^$' \
                    > "${commits_file}"

    # Get list of MicroShift's container images. The names are not
    # arch-specific, so we just use the x86_64 list.
    local images=$(jq -r '.images | keys[]' "${REPOROOT}/assets/release/release-x86_64.json" | xargs)

    # Clone the repos. We clone a copy of each repo for each arch in
    # case they're on different branches or would otherwise not have
    # the history for both images if we only cloned one.
    #
    # TODO: This is probably more wasteful than just cloning the
    # entire git repo.
    mkdir -p "${release_image_arch}"
    local image=""
    for image in $images
    do
        if ! grep -q "^${image} " "${commits_file}"
        then
            # some of the images we use do not come from the release payload
            echo "${image} not from release payload, skipping"
            echo
            continue
        fi
        local line=$(grep "^${image} " "${commits_file}")
        local repo=$(echo "$line" | cut -f2 -d' ')
        local commit=$(echo "$line" | cut -f3 -d' ')
        clone_repo "${repo}" "${commit}" "${release_image_arch}"
        echo "${repo} image-${release_image_arch} ${commit}" >> "${new_commits_file}"
    done
}
