"""External fetches for OCI base images.

This file is similar to how bazel_gazelle can manage go_repository calls
by writing them to a generated macro in a .bzl file.
"""

load("@rules_oci//oci:pull.bzl", "oci_pull")

def fetch_images():
    "Fetch external images"

    # A single-arch base image
    oci_pull(
        name = "distroless_java",
        digest = "sha256:161a1d97d592b3f1919801578c3a47c8e932071168a96267698f4b669c24c76d",
        image = "gcr.io/distroless/java17",
    )

    # A multi-arch base image
    oci_pull(
        name = "distroless_static",
        digest = "sha256:c3c3d0230d487c0ad3a0d87ad03ee02ea2ff0b3dcce91ca06a1019e07de05f12",
        image = "gcr.io/distroless/static",
        platforms = [
            "linux/amd64",
            "linux/arm",
            "linux/arm64",
            "linux/ppc64le",
            "linux/s390x",
        ],
    )

    # Show that the digest is optional.
    # In this case, the dependency is "floating" and our build could break when a new
    # image is pushed to gcr.io with the 'debug' tag, so we document this by setting
    # reproducible = False.
    # This is more convenient, so you might decide the trade-off is worth it.
    oci_pull(
        name = "distroless_python",
        image = "gcr.io/distroless/python3",
        platforms = ["linux/amd64"],
        # Don't make a distroless_python_unpinned repo and print a warning about the tag
        reproducible = False,
        tag = "debug",
    )

    # You can copy-paste a typical image string from dockerhub search results.
    oci_pull(
        name = "debian_latest",
        image = "debian:latest",
        reproducible = False,
        platforms = ["linux/amd64", "linux/arm64/v8"],
    )

    # You can use a digest on the image name
    # https://hub.docker.com/layers/library/debian/stable/images/sha256-e822570981e13a6ef1efcf31870726fbd62e72d9abfdcf405a9d8f566e8d7028?context=explore
    oci_pull(
        name = "debian_stable",
        image = "debian@sha256:e822570981e13a6ef1efcf31870726fbd62e72d9abfdcf405a9d8f566e8d7028",
    )

    # Show the simple case of migrating from rules_docker, like
    # container_pull(
    #     name = "base",
    #     registry = "gcr.io",
    #     repository = "my-project/my-base",
    #     # 'tag' is also supported, but digest is encouraged for reproducibility.
    #     digest = "sha256:deadbeef",
    # )
    oci_pull(
        name = "from_rules_docker",
        registry = "gcr.io",
        repository = "distroless/nodejs18",
        digest = "sha256:1fd03807e02eeb78efaacb0e38e8e68ead0639733e92e7cc9a9e017cd9b50bbf",
        platforms = ["linux/amd64", "linux/arm64"],
    )

    oci_pull(
        name = "aws_lambda_python",
        # tag = "3.8"
        digest = "sha256:46b3b8614b31761b24f56be1bb8c7ba191d9b9b4624bbf7f53ed7ddc696c928b",
        image = "public.ecr.aws/lambda/python",
    )

    oci_pull(
        name = "debian",
        # Omits the "image." CNAME for dockerhub
        image = "docker.io/library/debian",
        platforms = [
            "linux/amd64",
            "linux/arm/v5",
            "linux/arm/v7",
            "linux/arm64/v8",
            "linux/386",
            "linux/mips64le",
            "linux/ppc64le",
            "linux/s390x",
        ],
        # Don't print a warning about the tag
        # reproducible = False,
        tag = "latest",
    )

    oci_pull(
        name = "ubuntu",
        image = "ubuntu",
        platforms = [
            "linux/arm64/v8",
            "linux/amd64",
        ],
        digest = "sha256:67211c14fa74f070d27cc59d69a7fa9aeff8e28ea118ef3babc295a0428a6d21",
    )

    oci_pull(
        name = "apollo_router",
        # tag = "v1.14.0",
        digest = "sha256:237c4d6a477b5013bae88549bfc50aaafd68974cab7d2dde2ba5431345e9c95d",
        image = "ghcr.io/apollographql/router",
        platforms = [
            "linux/amd64",
            "linux/arm64",
        ],
    )
