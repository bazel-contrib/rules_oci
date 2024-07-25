"repos for buildx"

load("@aspect_bazel_lib//lib:repo_utils.bzl", "repo_utils")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")

def _impl_configure_buildx(rctx):
    has_docker = False
    # See if standard docker sock exists
    if not has_docker:
        r = rctx.execute(["stat", "/var/run/docker.sock"])
        if r.return_code == 0:
            has_docker = True

    compatible_with = "[]"
    builder_name = "builder-docker"
    if has_docker:
        buildx = rctx.path(Label("@buildx_%s//file:downloaded" % repo_utils.platform(rctx)))

        r = rctx.execute([buildx, "ls"])
        if not builder_name in r.stdout:
            r = rctx.execute([buildx, "create", "--name", builder_name, "--driver", "docker-container"])
            if r.return_code != 0:
                fail("Failed to create buildx driver %s: \nSTDERR:\n%s\nsSTDOUT:\n%s" % (builder_name, r.stderr, r.stdout))
        else:
            # buildifier: disable=print
            print("WARNING: BuildX driver `%s` already exists." % builder_name)

    else:
        compatible_with = '["@platforms//:incompatible"]'

    rctx.file("defs.bzl", """
# Generated by configure_buildx.bzl
TARGET_COMPATIBLE_WITH = %s
BUILDER_NAME = "%s"
""" % (compatible_with, builder_name))
    rctx.file("BUILD.bazel", 'exports_files(["defs.bzl"])')
    pass

configure_buildx = repository_rule(
    implementation = _impl_configure_buildx,
)

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

    configure_buildx(name = "configure_buildx")