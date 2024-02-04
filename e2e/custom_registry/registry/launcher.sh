readonly SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
readonly REGISTRY_BIN="${SCRIPT_DIR}/registry_/registry"

function start_registry() {
    local storage_dir="$1"
    local output="$2"
    local deadline="${3:-5}"
    local registry_pid="$1/proc.pid"

    mkdir -p "${storage_dir}"
    "${REGISTRY_BIN}" >> $output 2>&1 &
    echo "$!" > "${registry_pid}"

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

function stop_registry() {
    local storage_dir="$1"
    local registry_pid="$1/proc.pid"
    if [[ ! -f "${registry_pid}" ]]; then
        echo "Registry not started" >&2
        return 0
    fi
    kill -9 "$(cat "${registry_pid}")" || true
    rm -f "${registry_pid}"
    return 0
}
