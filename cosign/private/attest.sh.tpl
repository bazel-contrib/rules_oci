#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly COSIGN="{{cosign_path}}"
readonly JQ="{{jq_path}}"
readonly IMAGE_DIR="{{image_dir}}"
readonly DIGEST=$("${JQ}" -r '.manifests[].digest' "${IMAGE_DIR}/index.json")
readonly FIXED_ARGS=({{fixed_args}})


# set $@ to be FIXED_ARGS+$@
ARGS=(${FIXED_ARGS[@]} $@)
set -- ${ARGS[@]}

REPOSITORY=""
ARGS=()

while (( $# > 0 )); do
    case "$1" in
    --repository) shift; REPOSITORY="$1"; shift ;;
    (--repository=*) REPOSITORY="${1#--repository=}"; shift ;;
    *) ARGS+=( "$1" ); shift ;;
    esac
done

exec "${COSIGN}" attest "${REPOSITORY}@${DIGEST}" ${ARGS[@]+"${ARGS[@]}"}

