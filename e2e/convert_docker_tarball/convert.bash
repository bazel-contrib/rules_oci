#!/usr/bin/env bash
# Most rules_oci users will use oci_pull to fetch base layers from a remote registry.
# However, you might build docker-format tarballs and uploaded them to Artifactory for example.
# rules_oci expects an OCI format base image, so these need to be converted.
#
# This just requires push'ing the tarball into a locally-running registry which
# understands both formats, then pull'ing back out in the oci format.
#
# Note, this is suboptimal because Bazel will still have to execute an action that has the entire
# base image as an input. Large inputs cause network delays with remote execution.

set -o pipefail -o errexit -o nounset

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
RUNFILES="$SCRIPT_DIR/$(basename $0).runfiles"

TMP=$(mktemp -d)
export HOME="$TMP"

readonly OUTPUT="${1}"
readonly TARBALL="${2}"
readonly CRANE="${RUNFILES}/${3#"external/"}"


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

REF=$(mktemp)
"${CRANE}" push "${TARBALL}" "${REPOSITORY}" --image-refs="${REF}"

"${CRANE}" pull "$(cat $REF)" "${OUTPUT}" --format=oci