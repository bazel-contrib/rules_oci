#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

export HOME="$TEST_TMPDIR"

readonly JQ="${1/external\//../}"
readonly CRANE="${2/external\//../}"
readonly COSIGN="${3/external\//../}"
readonly IMAGE_SIGNER="$4"
readonly IMAGE="$5"

# Launch a registry instance at a random port
output=$(mktemp)
$CRANE registry serve --address=localhost:0 >> $output 2>&1 &
timeout=$((SECONDS+10))
while [ "${SECONDS}" -lt "${timeout}" ]; do
    port="$(cat $output | sed -nr 's/.+serving on port ([0-9]+)/\1/p')"
    if [ -n "${port}" ]; then
        break
    fi
done
REGISTRY="localhost:$port"
echo "Registry is running at ${REGISTRY}"


readonly REPOSITORY="${REGISTRY}/local" 
readonly DIGEST=$("$JQ" -r '.manifests[0].digest' "$IMAGE/index.json")

# TODO: make this test sign by digest once https://github.com/sigstore/cosign/issues/1905 is fixed.
"${CRANE}" push "${IMAGE}" "${REPOSITORY}@${DIGEST}"

# Create key-pair
COSIGN_PASSWORD=123 "${COSIGN}" generate-key-pair 

# Sign the image at remote registry
COSIGN_PASSWORD=123 "${IMAGE_SIGNER}" --repository="${REPOSITORY}" --key=cosign.key -y

# Now push the image
REF=$(mktemp)
"${CRANE}" push "${IMAGE}" "${REPOSITORY}" --image-refs="${REF}"

# Verify using the Tag
"${COSIGN}" verify "${REPOSITORY}:latest" --key=cosign.pub

# Verify using the Digest
"${COSIGN}" verify "$(cat ${REF})" --key=cosign.pub
