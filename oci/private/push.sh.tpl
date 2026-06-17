#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

{{BASH_RLOCATION_FUNCTION}}

runfiles_export_envvars

readonly CRANE="$(rlocation "{{crane_path}}")"
readonly JQ="$(rlocation "{{jq_path}}")"
readonly IMAGE_DIR="$(rlocation "{{image_dir}}")"
readonly TAGS_FILE="$(rlocation "{{tags}}")"
readonly FIXED_ARGS=({{fixed_args}})
readonly REPOSITORY_FILE="$(rlocation "{{repository_file}}")"

REPOSITORY=""
if [ -f "$REPOSITORY_FILE" ] ; then
  REPOSITORY=$(tr -d '\n' < "$REPOSITORY_FILE")
fi

# set $@ to be FIXED_ARGS+$@
ALL_ARGS=(${FIXED_ARGS[@]+"${FIXED_ARGS[@]}"} $@)
if [[ ${#ALL_ARGS[@]} -gt 0 ]]; then
  set -- ${ALL_ARGS[@]}
fi

TAGS=()

# global crane flags to be passed with every crane invocation
GLOBAL_FLAGS=()

# tag platform specific images as ${tag}-${os}-${arch} (for use with
# AWS Lambda and other platforms that cannot handle multiarch OCI images).
TAG_PLATFORM_IMAGES="{{tag_platform_images}}"

# this will hold args specific to `crane push``
ARGS=()

while (( $# > 0 )); do
  case $1 in
    (--allow-nondistributable-artifacts|--insecure|-v|--verbose)
      GLOBAL_FLAGS+=( "$1" )
      shift;;
    (-i|--tag-platform-images)
      TAG_PLATFORM_IMAGES=1
      shift;;
    (--platform)
      GLOBAL_FLAGS+=( "--platform" "$2" )
      shift
      shift;;
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

if [[ -z "${REPOSITORY}" ]]; then
  echo "ERROR: repository not set. Please pass --repository flag." >&2
  exit 1
fi

MANIFEST_DIGEST=$("${JQ}" -r '.manifests[0].digest' "${IMAGE_DIR}/index.json")
MANIFEST_FILE="${IMAGE_DIR}/blobs/${MANIFEST_DIGEST%%:*}/${MANIFEST_DIGEST##*:}"
IMAGE_DIGESTS=$(${JQ} -r '.manifests[]? | [ .digest, .platform.os, .platform.architecture ] | @tsv ' "${MANIFEST_FILE}")

REFS=$(mktemp)
"${CRANE}" push "${GLOBAL_FLAGS[@]+"${GLOBAL_FLAGS[@]}"}" "${IMAGE_DIR}" "${REPOSITORY}@${MANIFEST_DIGEST}" "${ARGS[@]+"${ARGS[@]}"}" --image-refs "${REFS}"

for tag in "${TAGS[@]+"${TAGS[@]}"}"
do
  "${CRANE}" tag "${GLOBAL_FLAGS[@]+"${GLOBAL_FLAGS[@]}"}" $(cat "${REFS}") "${tag}"
  if [[ ${TAG_PLATFORM_IMAGES} -eq 1 ]]; then
    echo "${IMAGE_DIGESTS}" | while read digest os arch ; do
      if [[ -n "${os}" && -n "${arch}" ]]; then
        "${CRANE}" tag "${REPOSITORY}@${digest}" "${tag}-${os}-${arch}"
      fi
    done
  fi
done

if [[ -e "${TAGS_FILE:-}" ]]; then
  readarray -t tags < "${TAGS_FILE}"
  for tag in "${tags[@]}"; do
    if [[ -z "${tag}" ]]; then
        continue
    fi
    "${CRANE}" tag "${GLOBAL_FLAGS[@]+"${GLOBAL_FLAGS[@]}"}" $(cat "${REFS}") "${tag}"
    if [[ ${TAG_PLATFORM_IMAGES} -eq 1 ]]; then
      echo "${IMAGE_DIGESTS}" | while read digest os arch ; do
        if [[ -n "${os}" && -n "${arch}" ]]; then
          "${CRANE}" tag "${REPOSITORY}@${digest}" "${tag}-${os}-${arch}"
        fi
      done
    fi
  done
fi
