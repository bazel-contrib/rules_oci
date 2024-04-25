load("//oci:defs.bzl", "oci_image", "oci_tarball", "container_run_and_save")

oci_image(
    name = "example_ubuntu_base",
    base = "@ubuntu",
    entrypoint = ["/bin/bash", "-c"],
    env = {
        "TZDATA": "Etc/Utc",
        "DEBIAN_FRONTEND": "noninteractive",
    },
)

oci_tarball(
    name = "example_ubuntu_base_tarball",
    image = ":example_ubuntu_base",
    repo_tags = ["example-ubuntu-base:latest"]
)

container_run_and_save(
    name = "update_packages",
    base_tarball = ":example_ubuntu_base_tarball",
    cmd = "apt update; apt upgrade -y"
)

oci_image(
    name = "image",
    base = ":example_ubuntu_base",
    tars = [
        ":update_packages",
    ]
)

oci_tarball(
    name = "tarball",
    image = ":image",
    repo_tags = ["updated-ubuntu-base:latest"]
)
