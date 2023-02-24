readonly SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
REGISTRY="${SCRIPT_DIR}/_registry"

function start_registry() {
    local output="$2"
    local deadline="${3:-5}"

    "${REGISTRY}" >> $output 2>&1 &

    local timeout=$((SECONDS+${deadline}))

    while [ "${SECONDS}" -lt "${timeout}" ]; do
        local port=$(cat $output)
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