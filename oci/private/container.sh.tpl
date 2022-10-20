#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

# A wrapper for crane. It starts a registry instance by calling start_registry function exported by %registry_launcher_path%.
# Then invokes crane with arguments provided after substituting `oci:registry` with REGISTRY variable exported by start_registry.
# NB: --output argument is an option only understood by this wrapper and will pull artifact image into a oci layout.

silent_on_success() {
    CODE=$?
    if [ $CODE -ne 0 ]; then
        >&2 cat "${STDERR}"
    fi
}
trap "silent_on_success" EXIT

readonly REGISTRY_LAUNCHER="%registry_launcher_path%"
readonly CRANE="%crane_path%"
readonly STORAGE_DIR="%storage_dir%"
readonly STDERR=$(mktemp)

source "${REGISTRY_LAUNCHER}"
mkdir -p "${STORAGE_DIR}"
start_registry "${STORAGE_DIR}" "${STDERR}"

OUTPUT=""
FIXED_ARGS=()
for ARG in "$@"; do
    case "$ARG" in
        (oci:registry*) FIXED_ARGS+=("${ARG/oci:registry/$REGISTRY}") ;;
        (--output=*) OUTPUT="${ARG#--output=}" ;;
        (*) FIXED_ARGS+=( "$ARG" )
    esac
done

# TODO: dynamically get --platform from via config_setting
ARCH=$(uname -m)
FIXED_ARGS+=("--platform" "linux/${ARCH/x86_64/amd64}")

REF=$("${CRANE}" "${FIXED_ARGS[@]}" 2>> "${STDERR}")

if [ -n "$OUTPUT" ]; then
    "${CRANE}" pull "${REF}" "./${OUTPUT}" --format=oci 2>> "${STDERR}"
fi
