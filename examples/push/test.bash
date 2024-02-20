#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly CRANE="${1/external\//../}"
readonly REGISTRY_LAUNCHER="${2/external\//../}"

# Launch a registry instance at a random port
source "${REGISTRY_LAUNCHER}"
REGISTRY=$(start_registry $TEST_TMPDIR $TEST_TMPDIR/output.log)
echo "Registry is running at ${REGISTRY}"


readonly PUSH_IMAGE="$3"
readonly PUSH_IMAGE_INDEX="$4"
readonly PUSH_IMAGE_REPOSITORY_FILE="$5"
readonly PUSH_IMAGE_WO_TAGS="$6"


# should push image with default tags
REPOSITORY="${REGISTRY}/local" 
"${PUSH_IMAGE}" --repository "${REPOSITORY}"
"${CRANE}" digest "$REPOSITORY:latest"

# should write out the image digest in provided image_refs.
IMAGE_REFS="$(mktemp)"
"${PUSH_IMAGE}" --repository "${REPOSITORY}" --image-refs "${IMAGE_REFS}"
check_refs() {
  printf "Checking image refs... "
  local got="$(cat "${IMAGE_REFS}")"
  local pattern="^${REPOSITORY}@sha256:[0-9a-f]{64}$"
  [[ ${got} =~ ${pattern} ]] || \
    (printf "failed; want pattern '%s', got '%s'\n" "${pattern}" "${got}" && rm "${IMAGE_REFS}" && false)
  echo "passed"
}
check_refs
rm "${IMAGE_REFS}"

# should push image_index with default tags
REPOSITORY="${REGISTRY}/local-index" 
"${PUSH_IMAGE_INDEX}" --repository "${REPOSITORY}"
"${CRANE}" digest "$REPOSITORY:nightly"


# should push image without default tags
REPOSITORY="${REGISTRY}/local-wo-tags" 
"${PUSH_IMAGE_WO_TAGS}" --repository "${REPOSITORY}"
TAGS=$("${CRANE}" ls "$REPOSITORY")
if [ -n "${TAGS}" ]; then 
    echo "image is not supposed to have any tags but got"
    echo "${TAGS}"
    exit 1
fi


# should push image to the repository defined in the file
set -ex
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
