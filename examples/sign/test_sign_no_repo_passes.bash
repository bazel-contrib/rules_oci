#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly JQ="${1/external\//../}"
readonly CRANE="${2/external\//../}"
readonly COSIGN="${3/external\//../}"
readonly IMAGE_SIGNER_NO_REPO="$4"
readonly IMAGE="$5"

# start a registry
output=$(mktemp)
$CRANE registry serve --address=localhost:0 >> "$output" 2>&1 &
timeout=$((SECONDS+10))
while [ "${SECONDS}" -lt "${timeout}" ]; do
    port="$(sed -nr 's/.+serving on port ([0-9]+)/\1/p' < "$output")"
    [ -n "${port}" ] && break
done

readonly REPOSITORY="localhost:$port/local" 
DIGEST=""
DIGEST=$("$JQ" -r '.manifests[0].digest' "$IMAGE/index.json")
readonly DIGEST

# TODO: make this test sign by digest once https://github.com/sigstore/cosign/issues/1905 is fixed.
"${CRANE}" push "${IMAGE}" "${REPOSITORY}@${DIGEST}"

# Create key-pair
COSIGN_PASSWORD=123 "${COSIGN}" generate-key-pair 

# Sign the image at remote registry
echo "y" | COSIGN_PASSWORD=123 "${IMAGE_SIGNER_NO_REPO}" --repository="${REPOSITORY}" --key=cosign.key

# Now push the image
REF=$("${CRANE}" push "${IMAGE}" "${REPOSITORY}")

# Verify using the Tag
"${COSIGN}" verify "${REPOSITORY}:latest" --key=cosign.pub

# Verify using the Digest
"${COSIGN}" verify "${REF}" --key=cosign.pub
