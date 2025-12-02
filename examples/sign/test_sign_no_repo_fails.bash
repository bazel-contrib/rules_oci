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

readonly IMAGE_SIGNER="$(rlocation $1)"

# Run the cosign_sign target and check that it fails with the expected error message.
if ! "$IMAGE_SIGNER" &> output.txt; then
  cat output.txt
  grep "ERROR: repository not set. Please pass --repository flag or set the 'repository' attribute in the rule." output.txt
else
  echo "Expected cosign_sign to fail, but it succeeded."
  exit 1
fi
