#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly JQ="${1/external\//../}"
readonly COSIGN="${2/external\//../}"
readonly CRANE="${3/external\//../}"
readonly ATTACHER="$4"
readonly IMAGE_PATH="$5"
readonly SBOM_PATH="$6"

# start a registry
output=$(mktemp)
$CRANE registry serve --address=localhost:0 >> $output 2>&1 &
timeout=$((SECONDS+10))
while [ "${SECONDS}" -lt "${timeout}" ]; do
    port="$(cat $output | sed -nr 's/.+serving on port ([0-9]+)/\1/p')"
    [ -n "${port}" ] && break
done

readonly REPOSITORY="localhost:$port/local" 

# generate key
rm -f cosign.key
rm -f cosign.pub
COSIGN_PASSWORD=123 "${COSIGN}" generate-key-pair

REF=$("${CRANE}" push "${IMAGE_PATH}" "${REPOSITORY}")

# attach the sbom
COSIGN_PASSWORD=123 "${ATTACHER}" --repository "${REPOSITORY}" --key=cosign.key -y

# download the sbom
"${COSIGN}" verify-attestation $REF --key=cosign.pub --type spdx | "${JQ}" -r '.payload' | tr -d '\r' | base64 --decode | "${JQ}" -r '.predicate' > "$TEST_TMPDIR/download.sbom" 

diff -u --ignore-space-change --strip-trailing-cr "$SBOM_PATH"  "$TEST_TMPDIR/download.sbom" || (echo "FAIL: downloaded SBOM does not match the original" && exit 1)
