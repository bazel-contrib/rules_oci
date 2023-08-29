#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
RUNFILES="$SCRIPT_DIR/$(basename $0).runfiles"

TMP=$(mktemp -d)
export HOME="$TMP"

readonly OUTPUT="${1}"
readonly TARBALL="${2}"
readonly CRANE="${RUNFILES}/${3#"external/"}"
readonly REGISTRY_LAUNCHER=${RUNFILES}/${4#"external/"}


# Launch a registry instance at a random port
source "${REGISTRY_LAUNCHER}"
REGISTRY=$(start_registry $TMP $TMP/output.log)

readonly REPOSITORY="${REGISTRY}/local" 


REF=$(mktemp)
"${CRANE}" push "${TARBALL}" "${REPOSITORY}" --image-refs="${REF}"

"${CRANE}" pull "$(cat $REF)" "${OUTPUT}" --format=oci