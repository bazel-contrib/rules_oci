#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly CRANE="{{crane_path}}"
readonly YQ="{{yq_path}}"
readonly IMAGE_DIR="{{image_dir}}"
readonly TAGS_FILE="{{tags}}"
readonly FIXED_ARGS=({{fixed_args}})
readonly REPOSITORY_FILE="{{repository_file}}"

REPOSITORY=""
if [ -f $REPOSITORY_FILE ] ; then
  REPOSITORY=$(tr -d '\n' < "$REPOSITORY_FILE")
fi

# set $@ to be FIXED_ARGS+$@
ALL_ARGS=(${FIXED_ARGS[@]} $@)
set -- ${ALL_ARGS[@]}

TAGS=()
ARGS=()

while (( $# > 0 )); do
  case $1 in
    (-t|--tag)
      TAGS+=( "$2" )
      shift
      shift;;
    (--tag=*) 
      TAGS+=( "${1#--tag=}" )
      shift;;
    (-r|--repository)
      REPOSITORY="$2"
      shift
      shift;;
    (--repository=*)
      REPOSITORY="${1#--repository=}"
      shift;;
    (*) 
      ARGS+=( "$1" )
      shift;;
  esac
done

DIGEST=$("${YQ}" eval '.manifests[0].digest' "${IMAGE_DIR}/index.json")

REFS=$(mktemp)
"${CRANE}" push "${IMAGE_DIR}" "${REPOSITORY}@${DIGEST}" "${ARGS[@]+"${ARGS[@]}"}" --image-refs "${REFS}"

for tag in "${TAGS[@]+"${TAGS[@]}"}"
do
  "${CRANE}" tag $(cat "${REFS}") "${tag}"
done

if [[ -e "${TAGS_FILE:-}" ]]; then
  cat "${TAGS_FILE}" | xargs -n1 "${CRANE}" tag $(cat "${REFS}")
fi
