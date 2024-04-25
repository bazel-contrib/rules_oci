#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly DOCKER_BUILDKIT="{{docker_buildkit}}"
readonly CONTAINER_NAME="{{container_name}}"
readonly IMAGE_TAR="{{base_image_tarball}}"

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

function is_container_running () {
    container_name=${1:-""}
    (docker ps --filter=name=${container_name} | grep -q ${container_name}) && return 0 || return 1
}

if [[ $(is_container_running $CONTAINER_NAME) -eq 0 ]]; then
    "${CONTAINER_CLI}" rm -f ${CONTAINER_NAME} 2>/dev/null || true
fi

IMAGE_NAME=$(docker load --quiet --input $IMAGE_TAR | grep -v 'already exists' | sed -e 's/Loaded image\: //g')
"${CONTAINER_CLI}" run --name $CONTAINER_NAME $IMAGE_NAME '{{command}}'

docker_container_tag="${CONTAINER_NAME}"

"${CONTAINER_CLI}" commit $CONTAINER_NAME $docker_container_tag

"${CONTAINER_CLI}" export $docker_container_tag --output={{output}}

if [[ $(is_container_running $CONTAINER_NAME) -eq 0 ]]; then
    "${CONTAINER_CLI}" rm -f ${CONTAINER_NAME} 2>/dev/null || true
fi