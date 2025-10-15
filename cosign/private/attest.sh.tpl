#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

{{BASH_RLOCATION_FUNCTION}}

readonly COSIGN="$(rlocation "{{cosign_path}}")"
readonly JQ="$(rlocation "{{jq_path}}")"
readonly IMAGE_DIR="$(rlocation "{{image_dir}}")"
readonly DIGEST=$("${JQ}" -r '.manifests[].digest' "${IMAGE_DIR}/index.json")
readonly FIXED_ARGS=({{fixed_args}})

# set $@ to be FIXED_ARGS+$@
ALL_ARGS=(${FIXED_ARGS[@]+"${FIXED_ARGS[@]}"} "$@")
if [[ ${#ALL_ARGS[@]} -gt 0 ]]; then
  set -- "${ALL_ARGS[@]}"
fi

REPOSITORY=""
ARGS=()
PREDICATE=""

while (( $# > 0 )); do
    case "$1" in
    --repository) shift; REPOSITORY="$1"; shift ;;
    (--repository=*) REPOSITORY="${1#--repository=}"; shift ;;
    --predicate) shift; PREDICATE="$(rlocation "$1")"; shift ;;
    (--predicate=*) PREDICATE="$(rlocation "${1#--predicate=}")"; shift ;;
    *) ARGS+=( "$1" ); shift ;;
    esac
done

if [[ -z "${REPOSITORY}" ]]; then
    echo "ERROR: repository not set. Please pass --repository flag or set the 'repository' attribute in the rule." >&2
    exit 1
fi

exec "${COSIGN}" attest "${REPOSITORY}@${DIGEST}" --predicate "${PREDICATE}" ${ARGS[@]+"${ARGS[@]}"}

