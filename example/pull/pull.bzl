"a repository rule fetching container images using crane"
_PULL_TMPL = """\
# based on https://github.com/bazel-contrib/rules_oci/blob/b900a6322ae4e68b431f7d65ebfef604657bd030/example/BUILD.bazel#L19-L43

genrule(
    name = "image",
    outs = ["layout"],
    cmd = "$(CRANE_BIN) pull {image} $@ --format=oci --platform=linux/{architecture}",
    message = "Pulling {image} for linux/{architecture}",
    output_to_bindir = True,
    local = True, # needs to run locally to able to use credential helpers
    toolchains = [
        "@oci_crane_toolchains//:current_toolchain",
    ],
    visibility = ["//visibility:public"],
)
"""

def _pull_impl(rctx):
    rctx.file("BUILD.bazel", _PULL_TMPL.format(
        architecture = rctx.attr.architecture,
        image = rctx.attr.image,
    ))

oci_pull = repository_rule(
    implementation = _pull_impl,
    attrs = {
        "image": attr.string(mandatory = True),
        "architecture": attr.string(mandatory = True),
    },
)
