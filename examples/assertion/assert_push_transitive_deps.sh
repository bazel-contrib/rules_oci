#!/usr/bin/env bash

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

IMAGE_DIR="$(rlocation $1)"

# TODO: Does this test actually even have any meaning without runfiles active?

for blob in "$IMAGE_DIR/blobs/sha256"/*; do 
    blob_real_path=$(realpath "$blob")
    blob_real_path_relative="${blob_real_path##*bin/}"
    echo "$blob -> $blob_real_path_relative"
    if [[ ! -e "$blob_real_path_relative" ]]; then
        echo "$blob is not present in the sandbox."
        exit 1
    fi 
done
