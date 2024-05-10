load("@aspect_bazel_lib//lib:tar.bzl", "tar")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_tarball")

package(default_visibility = ["//visibility:public"])

genrule(
    name = "3gib_file",
    outs = ["3gib_file.out"],
    cmd = "head -c 314572800 < /dev/urandom > $@",
    local = True,
    tags = ["manual"],
)

N_LAYERS = 5

[
    tar(
        name = "layer_%s" % i,
        srcs = ["3gib_file"],
        tags = ["manual"],
    )
    for i in range(N_LAYERS)
]
