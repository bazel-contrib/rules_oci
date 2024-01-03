#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly IMAGE="{{image_path}}"
if [ -e "{{loader}}" ]; then
    CONTAINER_CLI="{{loader}}"
elif command -v docker &> /dev/null; then
    CONTAINER_CLI="docker"
elif command -v podman &> /dev/null; then
    CONTAINER_CLI="podman"
else
    echo >&2 "Neither docker or podman could be found."
    echo >&2 "To use a different container runtime, pass an executable to the 'loader' attribute of oci_tarball."
    exit 1
fi

"$CONTAINER_CLI" load --input "$IMAGE"
