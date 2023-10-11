readonly SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
readonly ZOT="${SCRIPT_DIR}/zot"

function start_registry() {
    local storage_dir="$1"
    local output="$2"
    local deadline="${3:-5}"
    local config_path="$storage_dir/config.json"

    echo "$storage_dir" >&2
    cat > "${config_path}" <<EOF
{
    "storage": { "rootDirectory": "$storage_dir/..", "dedupe": false, "commit": true },
    "http":{ "port": "0", "address": "127.0.0.1" },
    "log":{ "level": "info" }
}
EOF
    HOME="${TMPDIR}" "${ZOT}" serve "${config_path}" >> $output 2>&1 &

    local timeout=$((SECONDS+${deadline}))

    while [ "${SECONDS}" -lt "${timeout}" ]; do
        local port=$(cat $output | sed -nr 's/.+"port":([0-9]+),.+/\1/p')
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
    rm -rf "${storage_dir}/.uploads"
    rm -r "${storage_dir}/config.json"
}