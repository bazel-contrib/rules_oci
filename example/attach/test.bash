#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly COSIGN="$1"
readonly CRANE="$2"
readonly REGISTRY_LAUNCHER="$3"
readonly ATTACHER="$4"
readonly IMAGE_PATH="$5"
readonly SBOM_PATH="$6"

# Launch a registry instance at a random port
source "${REGISTRY_LAUNCHER}"
start_registry $TEST_TMPDIR $TEST_TMPDIR/output.log
echo "Registry is running at ${REGISTRY}"

readonly REPOSITORY="${REGISTRY}/local" 

# attach the sbom
"${ATTACHER}" --repository "${REPOSITORY}"

# due to https://github.com/sigstore/cosign/issues/2603 push the image 
REF=$(mktemp)
"${CRANE}" push "${IMAGE_PATH}" "${REPOSITORY}" --image-refs="${REF}"

# download the sbom
"${COSIGN}" download sbom $(cat $REF) > "$TEST_TMPDIR/download.sbom"

diff -u --ignore-space-change --strip-trailing-cr "$SBOM_PATH"  "$TEST_TMPDIR/download.sbom" || (echo "FAIL: downloaded SBOM does not match the original" && exit 1)