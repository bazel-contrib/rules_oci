#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

# A wrapper for crane. It starts a registry instance by calling start_registry function exported by %registry_launcher_path%.
# Then invokes crane with arguments provided after substituting `oci:registry` with REGISTRY variable exported by start_registry.
# NB: --output argument is an option only understood by this wrapper and will pull artifact image into a oci layout.

readonly REGISTRY_LAUNCHER="{{registry_launcher_path}}"
readonly CRANE="{{crane_path}}"
readonly JQ="{{jq_path}}"
readonly STORAGE_DIR="{{storage_dir}}"

readonly STDERR=$(mktemp)

silent_on_success() {
    CODE=$?
    if [ "${CODE}" -ne 0 ]; then
        cat "${STDERR}" >&1
    fi
}
trap "silent_on_success" EXIT

function get_option() {
    local name=$1
    shift
    for ARG in "$@"; do
        case "$ARG" in
            ($name=*) echo ${ARG#$name=};; 
        esac
    done
}


function empty_base() {
    local registry=$1
    local ref="$registry/oci/empty_base:latest"
    ref="$("${CRANE}" append --oci-empty-base -t "${ref}" -f {{empty_tar}})"
    ref=$("${CRANE}" config "${ref}" | "${JQ}"  ".rootfs.diff_ids = [] | .history = []" | "${CRANE}" edit config "${ref}")
    ref=$("${CRANE}" manifest "${ref}" | "${JQ}"  ".layers = []" | "${CRANE}" edit manifest "${ref}")

    local raw_platform=$(get_option --platform $@)
    IFS='/' read -r -a platform <<< "$raw_platform"

    local filter='.os = $os | .architecture = $arch'
    local -a args=( "--arg" "os" "${platform[0]}" "--arg" "arch" "${platform[1]}" )

    if [ -n "${platform[2]:-}" ]; then
        filter+=' | .variant = $variant'
        args+=("--arg" "variant" "${platform[2]}")
    fi
    "${CRANE}" config "${ref}" | "${JQ}" ${args[@]} "${filter}" | "${CRANE}" edit config "${ref}"
}

function base_from_layout() {
    # TODO: https://github.com/google/go-containerregistry/issues/1514
    local refs=$(mktemp)
    local output=$(mktemp)
    local oci_layout_path=$1
    local registry=$2

    "${CRANE}" push "${oci_layout_path}" "${registry}/oci/layout:latest" --image-refs "${refs}" > "${output}" 2>&1

    cat "${output}" >&2

    if grep -q "MANIFEST_INVALID" "${output}"; then
    cat >&2 << EOF

zot registry does not support docker manifests. 

crane registry does support both oci and docker images, but is more memory hungry.

If you want to use the crane registry, remove "zot_version" from "oci_register_toolchains". 

EOF

        exit 1
    fi

    cat "${refs}"
}

# this will redirect stderr(2) to stderr file.
{
source "${REGISTRY_LAUNCHER}"
readonly REGISTRY=$(start_registry "${STORAGE_DIR}" "${STDERR}")

OUTPUT=""
WORKDIR=""
FIXED_ARGS=()
ENV_EXPANSIONS=()

for ARG in "$@"; do
    case "$ARG" in
        (oci:registry*) FIXED_ARGS+=("${ARG/oci:registry/$REGISTRY}") ;;
        (oci:empty_base) FIXED_ARGS+=("$(empty_base $REGISTRY $@)") ;;
        (oci:layout*) FIXED_ARGS+=("$(base_from_layout ${ARG/oci:layout\/} $REGISTRY)") ;;
        (--output=*) OUTPUT="${ARG#--output=}" ;;
        (--workdir=*) WORKDIR="${ARG#--workdir=}" ;;
        (--env-file=*)
          # NB: the '|| [-n $in]' expression is needed to process the final line, in case the input
          # file doesn't have a trailing newline.
          while IFS= read -r in || [ -n "$in" ]; do
            if [[ "${in}" = *\$* ]]; then
              ENV_EXPANSIONS+=( "${in}" )
            else
              FIXED_ARGS+=( "--env=${in}" )
            fi
          done <"${ARG#--env-file=}"
          ;;
        (--labels-file=*)
          # NB: the '|| [-n $in]' expression is needed to process the final line, in case the input
          # file doesn't have a trailing newline.
          while IFS= read -r in || [ -n "$in" ]; do
            FIXED_ARGS+=("--label=$in")
          done <"${ARG#--labels-file=}"
          ;;
          # NB: the '|| [-n $in]' expression is needed to process the final line, in case the input
          # file doesn't have a trailing newline.
        (--annotations-file=*)
          while IFS= read -r in || [ -n "$in" ]; do
            FIXED_ARGS+=("--annotation=$in")
          done <"${ARG#--annotations-file=}"
          ;;
        (*) FIXED_ARGS+=( "${ARG}" )
    esac
done

REF=$("${CRANE}" "${FIXED_ARGS[@]}")

if [ ${#ENV_EXPANSIONS[@]} -ne 0 ]; then 
    env_expansion_filter=\
'[$raw | match("\\${?([a-zA-Z0-9_]+)}?"; "gm")] | reduce .[] as $match (
    {parts: [], prev: 0}; 
    {parts: (.parts + [$raw[.prev:$match.offset], $envs[$match.captures[0].string]]), prev: ($match.offset + $match.length)}
) | .parts + [$raw[.prev:]] | join("")'
    base_config=$("${CRANE}" config "${REF}")
    base_env=$("${JQ}" -r '.config.Env | map(. | split("=") | {"key": .[0], "value": .[1]}) | from_entries' <<< "${base_config}")
    environment_args=()
    for expansion in "${ENV_EXPANSIONS[@]}"
    do
        IFS="=" read -r key value <<< "${expansion}"
        value_from_base=$("${JQ}" -nr --arg raw "${value}" --argjson envs "${base_env}" "${env_expansion_filter}")
        environment_args+=( --env "${key}=${value_from_base}" )
    done
    REF=$("${CRANE}" mutate "${REF}" ${environment_args[@]})
fi

# TODO: https://github.com/google/go-containerregistry/issues/1515
if [ -n "${WORKDIR}" ]; then 
    REF=$("${CRANE}" config "${REF}" | "${JQ}"  --arg workdir "${WORKDIR}" '.config.WorkingDir = $workdir' | "${CRANE}" edit config "${REF}")
fi

if [ -n "$OUTPUT" ]; then
    "${CRANE}" pull "${REF}" "./${OUTPUT}" --format=oci
fi

} 2>> "${STDERR}"
