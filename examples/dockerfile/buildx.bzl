"repos for buildx"

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")

def fetch_buildx():
    http_file(
        name = "buildx_linux_amd64",
        urls = [
            "https://github.com/docker/buildx/releases/download/v0.14.0/buildx-v0.14.0.linux-amd64",
        ],
        integrity = "sha256-Mvjxfso1vy7+bA5H9A5Gkqh280UxtCHvyYR5mltBIm4=",
        executable = True,
    )

    http_file(
        name = "buildx_darwin_arm64",
        urls = [
            "https://github.com/docker/buildx/releases/download/v0.14.0/buildx-v0.14.0.darwin-arm64",
        ],
        integrity = "sha256-3BdvI2ZgnMITKubwi7IZOjL5/ZNUv9Agz3+juNt0hA0=",
        executable = True,
    )

    http_file(
        name = "buildx_darwin_amd64",
        urls = [
            "https://github.com/docker/buildx/releases/download/v0.14.0/buildx-v0.14.0.darwin-amd64",
        ],
        integrity = "sha256-J6rZfENSvCzFBHDgnA8Oqq2FDXR+M9CTejhhg9DruPU=",
        executable = True,
    )
