#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly RUNFILES_ROOT="$PWD"
readonly COSIGN="$RUNFILES_ROOT/{{cosign_path}}"
readonly YQ="$RUNFILES_ROOT/{{yq_path}}"
readonly IMAGE_DIR="$RUNFILES_ROOT/{{image_dir}}"

DIGEST=$("${YQ}" '.manifests[].digest' "${IMAGE_DIR}/index.json")
REPOSITORY="{{repository}}"

ARGS=()

for ARG in "$@"; do
    case "$ARG" in
        (--repository=*) REPOSITORY="${ARG#--repository=}" ;;
        (*) ARGS+=( "${ARG}" )
    esac
done


if [ -n "${BUILD_WORKING_DIRECTORY:-}" ]; then
    # Change pwd to working directory of the parent terminal to allow users to type relative paths for options.
    cd $BUILD_WORKING_DIRECTORY
fi

exec "${COSIGN}" sign "${REPOSITORY}@${DIGEST}" ${ARGS[@]+"${ARGS[@]}"}


