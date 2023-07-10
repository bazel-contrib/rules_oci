set -o pipefail -o errexit -o nounset

readonly IMAGE="{{image_path}}"
readonly TAGS_FILE="{{tag_file}}"
readonly RUNTIME_ARGS="{{runtime_args}}"

REPOTAGS="$(head "${TAGS_FILE}")"
docker load --input "$IMAGE"
docker run --rm --pull=never $RUNTIME_ARGS "$REPOTAGS"
