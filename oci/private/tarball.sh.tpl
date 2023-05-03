#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly STAGING_DIR=$(mktemp -d)
readonly YQ="{{yq}}"
readonly IMAGE_DIR="{{image_dir}}"
readonly BLOBS_DIR="${STAGING_DIR}/blobs"
readonly TARBALL_PATH="{{tarball_path}}"
readonly TAGS_FILE="{{tags}}"

REPOTAGS="$(cat "${TAGS_FILE}")"

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

config="blobs/${CONFIG_DIGEST}" \
repotags="${REPOTAGS}" \
layers="${LAYERS}" \
"${YQ}" eval \
        --null-input '.[0] = {"Config": strenv(config), "RepoTags": strenv(repotags) | split("\n"), "Layers": env(layers) | map( "blobs/" + . + ".tar.gz") }' \
        --output-format json > "${STAGING_DIR}/manifest.json"

tar -C "${STAGING_DIR}" -cf "${TARBALL_PATH}" .
