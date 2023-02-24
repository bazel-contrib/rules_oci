readonly SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
readonly REGISTRY_BIN="${SCRIPT_DIR}/registry_/registry"

function start_registry() {
    local output="$2"
    local deadline="${3:-5}"

    "${REGISTRY_BIN}" >> $output 2>&1 &

    local timeout=$((SECONDS+${deadline}))

    while [ "${SECONDS}" -lt "${timeout}" ]; do
        local port=$(cat $output | sed -nr 's/port:([0-9]+)/\1/p')
        if [ -n "${port}" ]; then
            break
        fi
    done
    if [ -z "${port}" ]; then
        echo "registry didn't become ready within ${deadline}s." >&2
        return 1
    fi
    echo "127.0.0.1:${port}"
    return 0
}