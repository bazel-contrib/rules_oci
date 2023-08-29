#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

TMP=$(mktemp -d)
export HOME="$TMP"

readonly CRANE="${1/external\//../}"
readonly REGISTRY_LAUNCHER="${2/external\//../}"
readonly IMAGE_PATH="$3"

# Launch a registry instance at a random port
source "${REGISTRY_LAUNCHER}"
REGISTRY=$(start_registry $TMP $TMP/output.log)
echo "Registry is running at ${REGISTRY}"

readonly REPOSITORY="${REGISTRY}/local" 

REF=$(mktemp)
"${CRANE}" push "${IMAGE_PATH}" "${REPOSITORY}" --image-refs="${REF}"
