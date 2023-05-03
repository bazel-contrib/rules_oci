#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly YQ="{{yq}}"
readonly IMAGE_DIR="{{image_dir}}"
readonly BLOBS_DIR="{{blobs_dir}}"
readonly TAGS_FILE="{{tags}}"
readonly TARBALL_MANIFEST_PATH="{{manifest_path}}"

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
# TODO: https://github.com/bazel-contrib/rules_oci/issues/212 
# we can't use \n due to https://github.com/mikefarah/yq/issues/1430 and 
# we can't update YQ at the moment because structure_test depends on a specific version
repotags="${REPOTAGS/$'\n'/\%}" \
layers="${LAYERS}" \
"${YQ}" eval \
        --null-input '.[0] = {"Config": strenv(config), "RepoTags": "${repotags}" | envsubst | split("\%"), "Layers": env(layers) | map( "blobs/" + . + ".tar.gz") }' \
        --output-format json > "${TARBALL_MANIFEST_PATH}"
