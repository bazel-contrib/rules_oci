load("@aspect_bazel_lib//lib:tar.bzl", "tar")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_tarball")

# These numbers were gathered on a `Apple M2 Pro`
# Darwin Kernel Version 23.2.0: Wed Nov 15 21:55:06 PST 2023; root:xnu-10002.61.3~2/RELEASE_ARM64_T6020
# 10 CPU x 32GB RAM

# 1- Create an image with 10 layers 3GiB each.
# Perf: `< 50s`
N_BASE_LAYERS = 10

genrule(
    name = "3gib_file",
    outs = ["3gib_file.out"],
    cmd = "head -c 314572800 < /dev/urandom > $@",
    local = True,
    tags = ["manual"],
)

[
    tar(
        name = "blayer_%s" % i,
        srcs = ["3gib_file"],
        compress = "gzip",
        mtree = [
            "%s.dat uid=0 gid=0 mode=0755 type=file contents=$(location :3gib_file)" % i,
        ],
        tags = ["manual"],
    )
    for i in range(0, 5)
]

[
    tar(
        name = "blayer_%s" % i,
        srcs = ["3gib_file"],
        compress = "zstd",
        mtree = [
            "%s.dat uid=0 gid=0 mode=0755 type=file contents=$(location :3gib_file)" % i,
        ],
        tags = ["manual"],
    )
    for i in range(5, 10)
]

oci_image(
    name = "base",
    architecture = "arm64",
    os = "linux",
    tags = ["manual"],
    tars = [":blayer_%s" % i for i in range(N_BASE_LAYERS)],
)

N_LAYERS = 5

oci_image(
    name = "extended",
    base = ":base",
    tags = ["manual"],
    tars = ["//examples/test1:layer_%s" % i for i in range(N_LAYERS)],
)
