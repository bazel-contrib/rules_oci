map(
    {
        "key": .tag_name,
        "value": .assets
            | map(select(.name | contains("tar.gz")))
            | map({
                "key": .name | split(".")[0] | ltrimstr("umoci_") | ascii_downcase,
                # We'll replace the url with the shasum of that referenced file in a later processing step
                "value": .browser_download_url | split("/")[-1]
            })
            | from_entries
    }
) | from_entries
