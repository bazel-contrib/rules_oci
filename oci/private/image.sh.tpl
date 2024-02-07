#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly OUTPUT="{{output_path}}"
readonly STDERR=$(mktemp)
readonly REF="oci.local/intermediate"
readonly jq="{{jq_path}}"

function crane() {
  "{{crane_path}}" $@ --local $OUTPUT
}

function empty_base() {
    echo '{"manifests":[]}' > "$OUTPUT/index.json"
    crane append --oci-empty-base -t $REF

    local raw_platform=$1
    IFS='/' read -r -a platform <<< "$raw_platform"

    local filter='.os = $os | .architecture = $arch'
    local -a args=( "--arg" "os" "${platform[0]}" "--arg" "arch" "${platform[1]}" )

    if [ -n "${platform[2]:-}" ]; then
        filter+=' | .variant = $variant'
        args+=("--arg" "variant" "${platform[2]}")
    fi
    crane config $REF | $jq ${args[@]} "${filter}" | crane edit config $REF
}

function base_from_local() {
    local path=$1
    # TODO: https://github.com/bazelbuild/bazel/issues/20891
    cp -r "$path/blobs" "$OUTPUT/blobs"
    cp "$path/oci-layout" "$OUTPUT/oci-layout"
    $jq --arg ref $REF '.manifests[0].annotations["org.opencontainers.image.ref.name"] = $ref' "$path/index.json" > "$OUTPUT/index.json"
}


ARGS=()
ENV_EXPANSIONS=()

for ARG in "$@"; do
    case "$ARG" in
        (--empty-base=*) empty_base "${ARG#--empty-base=}"; ARGS+=($REF);;
        (--local=*) base_from_local "${ARG#--local=}"; ARGS+=($REF);;
        (--env-file=*)
          # NB: the '|| [-n $in]' expression is needed to process the final line, in case the input
          # file doesn't have a trailing newline.
          while IFS= read -r in || [ -n "$in" ]; do
            if [[ "${in}" = *\$* ]]; then
              ENV_EXPANSIONS+=( "${in}" )
            else
              ARGS+=( "--env=${in}" )
            fi
          done <"${ARG#--env-file=}"
          ;;
        (--labels-file=*)
          while IFS= read -r in || [ -n "$in" ]; do
            ARGS+=("--label=$in")
          done <"${ARG#--labels-file=}"
          ;;
        (--annotations-file=*)
          while IFS= read -r in || [ -n "$in" ]; do
            ARGS+=("--annotation=$in")
          done <"${ARG#--annotations-file=}"
          ;;
        (--cmd-file=*)
          while IFS= read -r in || [ -n "$in" ]; do
            ARGS+=("--cmd" "$in")
          done <"${ARG#--cmd-file=}"
          ;;
        (--entrypoint-file=*)
          while IFS= read -r in || [ -n "$in" ]; do
            ARGS+=("--entrypoint=$in")
          done <"${ARG#--entrypoint-file=}"
          ;;
        (--exposed-ports-file=*)
          while IFS= read -r in || [ -n "$in" ]; do
            ARGS+=("--exposed-ports=$in")
          done <"${ARG#--exposed-ports-file=}"
          ;;
          (*) ARGS+=( "${ARG}" )
    esac
done

if [ ${#ENV_EXPANSIONS[@]} -ne 0 ]; then 
    env_expansion_filter=\
'[$raw | match("\\${?([a-zA-Z0-9_]+)}?"; "gm")] | reduce .[] as $match (
    {parts: [], prev: 0}; 
    {parts: (.parts + [$raw[.prev:$match.offset], $envs[$match.captures[0].string]]), prev: ($match.offset + $match.length)}
) | .parts + [$raw[.prev:]] | join("")'
    base_config=$(crane config "${REF}")
    base_env=$($jq -r '.config.Env | map(. | split("=") | {"key": .[0], "value": .[1]}) | from_entries' <<< "${base_config}")
    for expansion in "${ENV_EXPANSIONS[@]}"
    do
        IFS="=" read -r key value <<< "${expansion}"
        value_from_base=$($jq -nr --arg raw "${value}" --argjson envs "${base_env}" "${env_expansion_filter}")
        ARGS+=( --env "${key}=${value_from_base}" )
    done
fi

"{{crane_path}}" "${ARGS[@]}" --local $OUTPUT

mv "${OUTPUT}/index.json" "${OUTPUT}/temp.json"
# ".manifests |= [.[-1]] | del(.manifests[].annotations)"
$jq --arg ref "${REF}" ".manifests |= [.[-1]] | del(.manifests[].annotations)" "${OUTPUT}/temp.json" >  "${OUTPUT}/index.json"
rm "${OUTPUT}/temp.json"
crane layout gc "./${OUTPUT}"