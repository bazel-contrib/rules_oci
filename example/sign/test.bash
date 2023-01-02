#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly CRANE="$1"
readonly COSIGN="$2"
readonly REGISTRY_LAUNCHER="$3"
readonly IMAGE_SIGNER="$4"
readonly IMAGE="$5"

# Launch a registry instance at a random port
source "${REGISTRY_LAUNCHER}"
start_registry $TEST_TMPDIR $TEST_TMPDIR/output.log
echo "Registry is running at ${REGISTRY}"

readonly REPOSITORY="${REGISTRY}/local" 

# Create key-pair
COSIGN_PASSWORD=123 "${COSIGN}" generate-key-pair 

# Sign the image at remote registry
COSIGN_PASSWORD=123 "${IMAGE_SIGNER}" --repository="${REPOSITORY}" --key=cosign.key


# Now push the image
REF=$(mktemp)
"${CRANE}" push "${IMAGE}" "${REPOSITORY}" --image-refs="${REF}"

# Verify using the Tag
"${COSIGN}" verify "${REPOSITORY}:latest" --key=cosign.pub

# Verify using the Digest
"${COSIGN}" verify "$(cat ${REF})" --key=cosign.pub
