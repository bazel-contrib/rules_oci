readonly SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
readonly ZOT="${SCRIPT_DIR}/zot"

function start_registry() {
    local storage_dir="$1"
    local output="$2"
    local deadline="${3:-5}"
    local config_path="$1/config.json"

    mkdir -p "${storage_dir}"
    cat > "${config_path}" <<EOF
{
    "storage": {"rootDirectory": "$1" },
    "http": { "port": "0", "address": "127.0.0.1" },
    "log": { "level": "info" }
}
EOF

    "${ZOT}" serve "${config_path}" >> $output 2>&1 &

    local timeout=$((SECONDS+${deadline}))

    while [ "${SECONDS}" -lt "${timeout}" ]; do
        local port=$(cat $output | sed -nr 's/.+"port":([0-9]+),.+/\1/p')
        if [ -n "${port}" ]; then
            break
        fi
    done
    if [ -z "${port}" ]; then
        echo "registry didn't become ready within ${deadline}s."
        exit 1
    fi
    echo "127.0.0.1:${port}"
}