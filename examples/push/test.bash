#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: runfiles.bash initializer cannot find $f. An executable rule may have forgotten to expose it in the runfiles, or the binary may require RUNFILES_DIR to be set."; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

readonly CRANE="$(rlocation $1)"
readonly PUSH_IMAGE="$(rlocation $2)"
readonly PUSH_IMAGE_INDEX="$(rlocation $3)"
readonly PUSH_IMAGE_REPOSITORY_FILE="$(rlocation $4)"
readonly PUSH_IMAGE_WO_TAGS="$(rlocation $5)"
readonly PUSH_IMAGE_WO_REPOSITORY="$(rlocation $6)"

# start a registry
output=$(mktemp)
$CRANE registry serve --address=localhost:0 >> $output 2>&1 &
timeout=$((SECONDS+10))
while [ "${SECONDS}" -lt "${timeout}" ]; do
    port="$(cat $output | sed -nr 's/.+serving on port ([0-9]+)/\1/p')"
    [ -n "${port}" ] && break
done
REGISTRY="localhost:$port"

# should push image with default tags
REPOSITORY="${REGISTRY}/local" 
"${PUSH_IMAGE}" --repository "${REPOSITORY}"
"${CRANE}" digest "$REPOSITORY:latest"

# should push image_index with default tags
REPOSITORY="${REGISTRY}/local-index" 
"${PUSH_IMAGE_INDEX}" --repository "${REPOSITORY}"
"${CRANE}" digest "$REPOSITORY:nightly"


# should push image without default tags
REPOSITORY="${REGISTRY}/local-wo-tags" 
"${PUSH_IMAGE_WO_TAGS}" --repository "${REPOSITORY}"
TAGS=$("${CRANE}" ls "$REPOSITORY")
if [ -n "${TAGS:-}" ]; then 
    echo "image is not supposed to have any tags but got"
    echo "${TAGS}"
    exit 1
fi


# should push image to the repository defined in the file
set -e
REPOSITORY="${REGISTRY}/repository-file"
"${PUSH_IMAGE_REPOSITORY_FILE}" --repository "${REPOSITORY}"
"${CRANE}" digest "$REPOSITORY:latest"


# should push image with the --tag flag.
REPOSITORY="${REGISTRY}/local-flag-tag" 
"${PUSH_IMAGE_WO_TAGS}" --repository "${REPOSITORY}" --tag "custom"
TAGS=$("${CRANE}" ls "$REPOSITORY")
if [ "${TAGS}" != "custom" ]; then 
    echo "image is supposed to have custom tag but got"
    echo "${TAGS}"
    exit 1
fi

# should push image without repository with default tags
REPOSITORY="${REGISTRY}/local-wo-repository"
"${PUSH_IMAGE_WO_REPOSITORY}" --repository "${REPOSITORY}"
"${CRANE}" digest "$REPOSITORY:latest"
