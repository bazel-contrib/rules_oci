#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

{{BASH_RLOCATION_FUNCTION}}

runfiles_export_envvars

readonly TAR="$(rlocation "{{tar}}")"
readonly MTREE="$(rlocation "{{mtree_path}}")"
readonly LOADER="$(rlocation "{{loader}}")"

if [ -f "$LOADER" ]; then
    CONTAINER_CLI="$LOADER"
elif command -v docker &> /dev/null; then
    CONTAINER_CLI="docker"
elif command -v podman &> /dev/null; then
    CONTAINER_CLI="podman"
elif command -v nerdctl &> /dev/null; then
    CONTAINER_CLI="nerdctl"
else
    echo >&2 "Neither docker or podman or nerdctl could be found."
    echo >&2 "To use a different container runtime, pass an executable to the 'loader' attribute of oci_tarball."
    exit 1
fi

# Strip manifest root and image root from mtree to make it compatible with runfiles layout.
image_root="{{image_root}}/"
manifest_root="{{manifest_root}}/"
image_runfiles_prefix="{{image_runfiles_prefix}}"
manifest_runfiles_prefix="{{manifest_runfiles_prefix}}"
mtree_contents="$(cat $MTREE)"
mtree_contents="${mtree_contents//"$image_root"/$image_runfiles_prefix}"
mtree_contents="${mtree_contents//"$manifest_root"/$manifest_runfiles_prefix}"


"$CONTAINER_CLI" load --input <(
    "$TAR" --cd "$RUNFILES_DIR" --create --no-xattr --no-mac-metadata @- <<< "$mtree_contents"
)
