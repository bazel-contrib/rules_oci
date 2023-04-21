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
readonly PUSH_IMAGE_WO_TAGS="$5"

# should push image with default tags
REPOSITORY="${REGISTRY}/local"
REPOTAGS_PATH="examples/push/_push_image.tags.txt"
REPOTAGS="$(cat $REPOTAGS_PATH)"
REPOTAGS="${REPOTAGS//index.docker.io\/<ORG>\/image/$REPOSITORY}"
rm "$REPOTAGS_PATH"
echo "$REPOTAGS" > "$REPOTAGS_PATH"
"${PUSH_IMAGE}"
"${CRANE}" digest "$REPOSITORY:latest"

# should push image_index with default tags
REPOSITORY="${REGISTRY}/local-index" 
REPOTAGS_PATH="examples/push/_stamped.tags.txt"
REPOTAGS="$(cat $REPOTAGS_PATH)"
REPOTAGS="${REPOTAGS//index.docker.io\/<ORG>\/image/$REPOSITORY}"
rm "$REPOTAGS_PATH"
echo "$REPOTAGS" > "$REPOTAGS_PATH"
"${PUSH_IMAGE_INDEX}"
"${CRANE}" digest "$REPOSITORY:nightly"


# should push image without tags
REPOSITORY="${REGISTRY}/local-wo-tags" 
"${PUSH_IMAGE_WO_TAGS}" --repotag "${REPOSITORY}"
TAGS=$("${CRANE}" ls "$REPOSITORY")
if [ -n "${TAGS}" ]; then 
    echo "image is not supposed to have any tags but got"
    echo "${TAGS}"
    exit 1
fi

# should push image with the --repotag flag.
REPOSITORY="${REGISTRY}/local-flag-tag" 
"${PUSH_IMAGE_WO_TAGS}" --repotag "${REPOSITORY}:custom"
TAGS=$("${CRANE}" ls "$REPOSITORY")
if [ "${TAGS}" != "custom" ]; then 
    echo "image is supposed to have custom tag but got"
    echo "${TAGS}"
    exit 1
fi
