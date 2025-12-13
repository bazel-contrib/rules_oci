# Standalone script — usage:
#   python3 tools/fetch_cosign_3x.py --token $GITHUB_TOKEN --concurrency 8 > cosign_versions_3x.bzl
# Fetch all sigstore/cosign releases matching v3.* and print a BZL-style mapping with base64 sha256 hashes.
import argparse
import base64
import hashlib
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

DEFAULT_PLATFORMS = [
    "darwin-amd64",
    "darwin-arm64",
    "linux-amd64",
    "linux-arm",
    "linux-arm64",
    "linux-ppc64le",
    "linux-s390x",
]

GITHUB_API = "https://api.github.com"


def list_releases(session, owner="sigstore", repo="cosign"):
    releases = []
    page = 1
    per_page = 100
    while True:
        url = f"{GITHUB_API}/repos/{owner}/{repo}/releases"
        r = session.get(url, params={"page": page, "per_page": per_page}, timeout=30)
        r.raise_for_status()
        page_items = r.json()
        if not page_items:
            break
        releases.extend(page_items)
        page += 1
    return releases


def find_asset_for_platform(assets, plat):
    os_name, arch_name = plat.split("-", 1)
    need_os = os_name.lower()
    need_arch = arch_name.lower()
    for a in assets:
        name = a.get("name", "").lower().replace("_", "-")
        if need_os in name and need_arch in name:
            return a
    return None


def sha256_b64_from_url(session, url):
    h = hashlib.sha256()
    with session.get(url, stream=True, timeout=60) as r:
        r.raise_for_status()
        for chunk in r.iter_content(64 * 1024):
            if chunk:
                h.update(chunk)
    return base64.b64encode(h.digest()).decode()


def process_release(session, release, platforms):
    tag = release.get("tag_name")
    assets = release.get("assets", [])
    results = {}
    for plat in platforms:
        asset = find_asset_for_platform(assets, plat)
        if not asset:
            results[plat] = None
            continue
        url = asset.get("browser_download_url")
        try:
            b64 = sha256_b64_from_url(session, url)
            results[plat] = f"sha256-{b64}"
        except Exception as e:
            results[plat] = f"ERROR: {e}"
    return tag, results


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--token", "-t", help="GitHub token (optional, increases rate limit)")
    p.add_argument(
        "--concurrency", "-c", default=8, type=int, help="Number of concurrent downloads"
    )
    p.add_argument(
        "--platforms", "-p", nargs="*", default=DEFAULT_PLATFORMS, help="Platform keys"
    )
    args = p.parse_args()

    session = requests.Session()
    headers = {"User-Agent": "cosign-fetcher"}
    if args.token:
        headers["Authorization"] = f"token {args.token}"
    session.headers.update(headers)

    releases = list_releases(session)
    # filter v3.x releases and sort by tag (best-effort)
    rels_3x = [r for r in releases if r.get("tag_name", "").startswith("v3.")]
    rels_3x.sort(key=lambda r: r.get("tag_name"), reverse=True)

    # concurrent processing of releases (each release will download multiple assets sequentially)
    results = {}
    with ThreadPoolExecutor(max_workers=args.concurrency) as ex:
        futures = {ex.submit(process_release, session, r, args.platforms): r for r in rels_3x}
        for fut in as_completed(futures):
            r = futures[fut]
            try:
                tag, mapping = fut.result()
                if tag:
                    results[tag] = mapping
            except Exception as e:
                print(f"# error processing release {r.get('tag_name')}: {e}", file=sys.stderr)

    # print BZL-style mapping
    print("COSIGN_VERSIONS = {")
    for tag in sorted(results.keys()):
        print(f'    "{tag}": {{')
        mapping = results[tag]
        for plat in args.platforms:
            val = mapping.get(plat)
            if val is None:
                print(f'        "{plat}": "sha256-REPLACE_NOT_FOUND",')
            elif val.startswith("ERROR:"):
                esc = val.replace('"', '\\"')
                print(f'        "{plat}": "sha256-ERROR",  # {esc}')
            else:
                print(f'        "{plat}": "{val}",')
        print("    },")
    print("}")

if __name__ == "__main__":
    main()