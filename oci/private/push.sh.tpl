#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly CRANE="{{crane_path}}"
readonly YQ="{{yq_path}}"
readonly IMAGE_DIR="{{image_dir}}"
readonly TAGS_FILE="{{tags}}"

# TODO: should we allow per registry control over insecure registries. It can be enabled with args = ["--insecure"] currently.
function parse_reference() {
  local ref=$1

  if [[ "$ref" = *"@"* ]]; then 
    echo "ERROR: repotags references can not contain digests: $ref"
    return 1
  fi
  
  # the `%` will remove everything after the last `:`
  before_colon="${ref%":"*}"
  colon=${#before_colon}
  after_colon="${ref:$colon+1}"
  
  # it has no tag
  if [[ $colon -gt 0  && "$after_colon" = *"/"* ]]; then 
    echo "$ref"
    echo ""
    return 0
  fi

  echo "$before_colon"
  echo "$after_colon"
}

REPOTAGS=()
ARGS=()

# process flags
while (( $# > 0 )); do
  case $1 in
    (-t|--repotag)
      REPOTAGS+=( "$2" )
      shift
      shift;;
    (--repotag=*) 
      REPOTAGS+=( "${1#--repotag=}" )
      shift;;
    (*) 
      ARGS+=( "$1" )
      shift;;
  esac
done

# read repotags file as array and prepend it to REPOTAGS array.
IFS=$'\n' REPOTAGSFILE=($(cat "$TAGS_FILE"))
REPOTAGS=(${REPOTAGSFILE[@]+"${REPOTAGSFILE[@]}"} ${REPOTAGS[@]+"${REPOTAGS[@]}"})

if [[ ${#REPOTAGS[@]} -lt 1 ]]; then 
  echo "ERROR: at least one repotags must be provided."
  exit 1
fi 


# parse repotags by leaving out tags the and uniqify the result to prevent unnecessary pushes.
REFERENCES=($(
  for REPO in "${REPOTAGS[@]+"${REPOTAGS[@]}"}"; do
    IFS=$'\n' reference=($(parse_reference "$REPO"))
    echo "${reference[0]}"
  done | sort -u
))

echo ${REFERENCES[@]}

# get digest of the image
DIGEST=$("${YQ}" eval '.manifests[0].digest' "${IMAGE_DIR}/index.json")

# push the first reference with image digest
"${CRANE}" push "${IMAGE_DIR}" "${REFERENCES[0]}@${DIGEST}" "${ARGS[@]+"${ARGS[@]}"}"

# copy from first registry to others
# reason cp is preferred over pushing is cross-repository/registry blob mounting which minimizes network usage if 
# the registry supports blob mounting. crane will silently fallback to pull&push if the registry misbehaves.
for REFERENCE in "${REFERENCES[@]:1}"; do 
  "${CRANE}" cp "${REFERENCES[0]}@${DIGEST}" "${REFERENCE}@${DIGEST}" "${ARGS[@]+"${ARGS[@]}"}"
done


# now apply tags to images by digest at their respective registries
for REPO in "${REPOTAGS[@]+"${REPOTAGS[@]}"}"; do
  IFS=$'\n' REFERENCE=($(parse_reference "$REPO"))
  if [[ ${#REFERENCE[@]} -eq 1 ]]; then 
    continue
  fi
  "${CRANE}" tag "${REFERENCE[0]}@$DIGEST" "${REFERENCE[1]}" "${ARGS[@]+"${ARGS[@]}"}"
done
  