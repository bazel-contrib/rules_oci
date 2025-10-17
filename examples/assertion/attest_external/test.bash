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

readonly JQ="$(rlocation $1)"
readonly COSIGN="$(rlocation $2)"
readonly CRANE="$(rlocation $3)"
readonly ATTACHER="$(rlocation $4)"
readonly IMAGE_PATH="$(rlocation $5)"
readonly SBOM_PATH="$(rlocation $6)"

# start a registry
output=$(mktemp)
$CRANE registry serve --address=localhost:0 >> $output 2>&1 &
timeout=$((SECONDS+20))
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
"${COSIGN}" verify-attestation "$REF" --key=cosign.pub --type spdx | "${JQ}" -r '.payload' | tr -d '\r' | base64 --decode | "${JQ}" -r '.predicate' > "$TEST_TMPDIR/download.sbom"

diff -u --ignore-space-change --strip-trailing-cr "$SBOM_PATH"  "$TEST_TMPDIR/download.sbom" || (echo "FAIL: downloaded SBOM does not match the original" && exit 1)