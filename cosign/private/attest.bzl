"Implementation details for attest rule"

_DOC = """Attest an oci_image using cosign binary at a remote registry.

```starlark
oci_image(
    name = "image"
)

cosign_attest(
    name = "attest_spdx",
    type = "spdx"
    predicate = "image.sbom.spdx.json",
    repository = "index.docker.io/org/image"
)
```

`repository` attribute can be overridden using the `--repository` flag.

```starlark
oci_image(
    name = "image"
)

cosign_attest(
    name = "attest_spdx",
    type = "spdx"
    attestment = "image.sbom.spdx.json",
    repository = "index.docker.io/org/image"
)
```

via `bazel run :attest_spdx -- --repository=index.docker.io/org/test`
"""

_attrs = {
    "image": attr.label(allow_single_file = True, mandatory = True, doc = "Label to an oci_image"),
    "type": attr.string(values = ["slsaprovenance", "link", "spdx", "vuln", "custom"], mandatory = True, doc = "Type of predicate. Acceptable values are (slsaprovenance|link|spdx|vuln|custom)"),
    "predicate": attr.label(allow_single_file = True, mandatory = True, doc = "Label to the predicate file. Only files are allowed. eg: sbom.spdx, in-toto.json"),
    "repository": attr.string(mandatory = True, doc = """\
        Repository URL where the image will be signed at, e.g.: `index.docker.io/<user>/image`.
        Digests and tags are not allowed.
    """),
    "_attest_sh_tpl": attr.label(default = "attest.sh.tpl", allow_single_file = True),
}

def _cosign_attest_impl(ctx):
    cosign = ctx.toolchains["@rules_oci//cosign:toolchain_type"]
    jq = ctx.toolchains["@aspect_bazel_lib//lib:jq_toolchain_type"]

    if ctx.attr.repository.find(":") != -1 or ctx.attr.repository.find("@") != -1:
        fail("repository attribute should not contain digest or tag.")

    fixed_args = [
        "--repository",
        ctx.attr.repository,
        "--predicate",
        ctx.file.predicate.short_path,
        "--type",
        ctx.attr.type,
    ]

    executable = ctx.actions.declare_file("cosign_attest_{}.sh".format(ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._attest_sh_tpl,
        output = executable,
        is_executable = True,
        substitutions = {
            "{{cosign_path}}": cosign.cosign_info.binary.short_path,
            "{{jq_path}}": jq.jqinfo.bin.short_path,
            "{{image_dir}}": ctx.file.image.short_path,
            "{{fixed_args}}": " ".join(fixed_args),
            "{{type}}": ctx.attr.type,
        },
    )

    runfiles = ctx.runfiles(files = [ctx.file.image, ctx.file.predicate])
    runfiles = runfiles.merge(jq.default.default_runfiles)
    runfiles = runfiles.merge(cosign.default.default_runfiles)

    return DefaultInfo(executable = executable, runfiles = runfiles)

cosign_attest = rule(
    implementation = _cosign_attest_impl,
    attrs = _attrs,
    doc = _DOC,
    executable = True,
    toolchains = [
        "@rules_oci//cosign:toolchain_type",
        "@aspect_bazel_lib//lib:jq_toolchain_type",
    ],
)
