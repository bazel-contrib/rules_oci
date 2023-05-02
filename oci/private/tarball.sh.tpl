#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly YQ="{{yq}}"
readonly IMAGE_DIR="{{image_dir}}"
readonly BLOBS_DIR="{{blobs_dir}}"
readonly TAGS_FILE="{{tags}}"
readonly TARBALL_MANIFEST_PATH="{{manifest_path}}"

MANIFEST_DIGEST=$(${YQ} eval '.manifests[0].digest | sub(":"; "/")' "${IMAGE_DIR}/index.json")
MANIFEST_BLOB_PATH="${IMAGE_DIR}/blobs/${MANIFEST_DIGEST}"

CONFIG_DIGEST=$(${YQ} eval '.config.digest  | sub(":"; "/")' ${MANIFEST_BLOB_PATH})
CONFIG_BLOB_PATH="${IMAGE_DIR}/blobs/${CONFIG_DIGEST}"

LAYERS=$(${YQ} eval '.layers | map(.digest | sub(":"; "/"))' ${MANIFEST_BLOB_PATH})

mkdir -p $(dirname "${BLOBS_DIR}/${CONFIG_DIGEST}")
cp "${CONFIG_BLOB_PATH}" "${BLOBS_DIR}/${CONFIG_DIGEST}"

for LAYER in $(${YQ} ".[]" <<< $LAYERS); do 
    cp "${IMAGE_DIR}/blobs/${LAYER}" "${BLOBS_DIR}/${LAYER}.tar.gz"
done

# the repotags file is already space separated so just read it as an array
REPOTAGS=$(cat $TAGS_FILE)

# format the repotags as a json array:
if [ -z "$REPOTAGS" ]
then
    REPOTAGS_ARRAY=[]
else
    REPOTAGS_ARRAY=[
    for repotag in $REPOTAGS
    do
        REPOTAGS_ARRAY=$REPOTAGS_ARRAY\"
        REPOTAGS_ARRAY=$REPOTAGS_ARRAY$repotag
        REPOTAGS_ARRAY=$REPOTAGS_ARRAY\",
    done
    REPOTAGS_ARRAY=$REPOTAGS_ARRAY"]"
fi

config="blobs/${CONFIG_DIGEST}" \
repotags="$REPOTAGS_ARRAY" \
layers="${LAYERS}" \
"${YQ}" eval \
        --null-input '.[0] = {"Config": env(config), "RepoTags": env(repotags), "Layers": env(layers) | map( "blobs/" + . + ".tar.gz") }' \
        --output-format json > "${TARBALL_MANIFEST_PATH}"
