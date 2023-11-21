#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly FORMAT="{{format}}"
readonly STAGING_DIR=$(mktemp -d)
readonly JQ="{{jq_path}}"
readonly IMAGE_DIR="{{image_dir}}"
readonly BLOBS_DIR="${STAGING_DIR}/blobs"
readonly TARBALL_PATH="{{tarball_path}}"
readonly REPOTAGS=($(cat "{{tags}}"))
readonly INDEX_FILE="${IMAGE_DIR}/index.json"

cp_f_with_mkdir() {
  SRC="$1"
  DST="$2"
  mkdir -p "$(dirname "${DST}")"
  cp -f "${SRC}" "${DST}"
}

MANIFEST_DIGEST=$(${JQ} -r '.manifests[0].digest | sub(":"; "/")' "${INDEX_FILE}" | tr  -d '"')

MANIFESTS_LENGTH=$("${JQ}" -r '.manifests | length' "${INDEX_FILE}")
if [[ "${MANIFESTS_LENGTH}" != 1 ]]; then
  echo >&2 "Expected exactly one manifest in ${INDEX_FILE}"
  exit 1
fi

MEDIA_TYPE=$("${JQ}" -r ".manifests[0].mediaType" "${INDEX_FILE}")

# Check that we know how to generate the output format given the input format.
# We may expand the supported options here in the future, but for now,
if [[ "${FORMAT}" != "docker" && "${FORMAT}" != "oci" ]]; then
  echo >&2 "Unknown format: ${FORMAT}. Only support docker|oci"
  exit 1
fi
if [[ "${FORMAT}" == "oci" && "${MEDIA_TYPE}" != "application/vnd.oci.image.index.v1+json" && "${MEDIA_TYPE}" != "application/vnd.docker.distribution.manifest.v2+json" ]]; then
  echo >&2 "Format oci is only supported for oci_image_index targets but saw ${MEDIA_TYPE}"
  exit 1
fi
if [[ "${FORMAT}" == "docker" && "${MEDIA_TYPE}" != "application/vnd.oci.image.manifest.v1+json" && "${MEDIA_TYPE}" != "application/vnd.docker.distribution.manifest.v2+json" ]]; then
  echo >&2 "Format docker is only supported for oci_image targets but saw ${MEDIA_TYPE}"
  exit 1
fi

if [[ "${FORMAT}" == "oci" ]]; then
  # Handle multi-architecture image indexes.
  # Ideally the toolchains we rely on would output these for us, but they don't seem to.

  echo -n '{"imageLayoutVersion": "1.0.0"}' > "${STAGING_DIR}/oci-layout"

  INDEX_FILE_MANIFEST_DIGEST=$("${JQ}" -r '.manifests[0].digest | sub(":"; "/")' "${INDEX_FILE}" | tr  -d '"')
  INDEX_FILE_MANIFEST_BLOB_PATH="${IMAGE_DIR}/blobs/${INDEX_FILE_MANIFEST_DIGEST}"

  cp_f_with_mkdir "${INDEX_FILE_MANIFEST_BLOB_PATH}" "${BLOBS_DIR}/${INDEX_FILE_MANIFEST_DIGEST}"

  IMAGE_MANIFESTS_DIGESTS=($("${JQ}" -r '.manifests[] | .digest | sub(":"; "/")' "${INDEX_FILE_MANIFEST_BLOB_PATH}"))

  for IMAGE_MANIFEST_DIGEST in "${IMAGE_MANIFESTS_DIGESTS[@]}"; do
    IMAGE_MANIFEST_BLOB_PATH="${IMAGE_DIR}/blobs/${IMAGE_MANIFEST_DIGEST}"
    cp_f_with_mkdir "${IMAGE_MANIFEST_BLOB_PATH}" "${BLOBS_DIR}/${IMAGE_MANIFEST_DIGEST}"

    CONFIG_DIGEST=$("${JQ}" -r '.config.digest  | sub(":"; "/")' ${IMAGE_MANIFEST_BLOB_PATH})
    CONFIG_BLOB_PATH="${IMAGE_DIR}/blobs/${CONFIG_DIGEST}"
    cp_f_with_mkdir "${CONFIG_BLOB_PATH}" "${BLOBS_DIR}/${CONFIG_DIGEST}"

    LAYER_DIGESTS=$("${JQ}" -r '.layers | map(.digest | sub(":"; "/"))' "${IMAGE_MANIFEST_BLOB_PATH}")
    for LAYER_DIGEST in $("${JQ}" -r ".[]" <<< $LAYER_DIGESTS); do
      cp_f_with_mkdir "${IMAGE_DIR}/blobs/${LAYER_DIGEST}" ${BLOBS_DIR}/${LAYER_DIGEST}
    done
  done


  # Repeat the first manifest entry once per repo tag.
  repotags="${REPOTAGS[@]+"${REPOTAGS[@]}"}"
  "${JQ}" -r --arg repo_tags "$repotags" \
   '.manifests[0] as $manifest | .manifests = ($repo_tags | split(" ") | map($manifest * {annotations:{"org.opencontainers.image.ref.name":.}}))' "${INDEX_FILE}" > "${STAGING_DIR}/index.json"

  tar -C "${STAGING_DIR}" -cf "${TARBALL_PATH}" index.json blobs oci-layout
  exit 0
fi

MANIFEST_DIGEST=$(${JQ} -r '.manifests[0].digest | sub(":"; "/")' "${IMAGE_DIR}/index.json" | tr  -d '"')
MANIFEST_BLOB_PATH="${IMAGE_DIR}/blobs/${MANIFEST_DIGEST}"

CONFIG_DIGEST=$(${JQ} -r '.config.digest  | sub(":"; "/")' ${MANIFEST_BLOB_PATH})
CONFIG_BLOB_PATH="${IMAGE_DIR}/blobs/${CONFIG_DIGEST}"

LAYERS=$(${JQ} -cr '.layers | map(.digest | sub(":"; "/"))' ${MANIFEST_BLOB_PATH})

cp_f_with_mkdir "${CONFIG_BLOB_PATH}" "${BLOBS_DIR}/${CONFIG_DIGEST}"

for LAYER in $(${JQ} -r ".[]" <<< $LAYERS); do 
  cp_f_with_mkdir "${IMAGE_DIR}/blobs/${LAYER}" "${BLOBS_DIR}/${LAYER}.tar.gz"
done


repotags="${REPOTAGS[@]+"${REPOTAGS[@]}"}"
"${JQ}" -n '.[0] = {"Config": $config, "RepoTags": ($repo_tags | split(" ") | map(select(. != ""))), "Layers": $layers | map( "blobs/" + . + ".tar.gz") }' \
        --arg repo_tags "$repotags" \
        --arg config "blobs/${CONFIG_DIGEST}" \
        --argjson layers "${LAYERS}" > "${STAGING_DIR}/manifest.json"

# TODO: https://github.com/bazel-contrib/rules_oci/issues/217
tar -C "${STAGING_DIR}" -cf "${TARBALL_PATH}" manifest.json blobs
