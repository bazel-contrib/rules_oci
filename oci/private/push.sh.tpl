#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly CRANE="{{crane_path}}"
readonly YQ="{{yq_path}}"
readonly IMAGE_DIR="{{image_dir}}"
readonly TAGS_FILE="{{tags}}"

REPOSITORY="$(cat {{repository}})"
if [[ "$REPOSITORY" == *[:@]* ]]; then
  echo >&2 "ERROR: found ':' or '@' character in $REPOSITORY"
  echo >&2 "The repository (or repository_file) attribute should not contain a digest or tag."
  exit 1
fi

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
