"Implementation details for attach rule"

_DOC = """Attach an attachment to an oci_image at a remote registry using cosign.

```starlark
oci_image(
    name = "image"
)

cosign_attach(
    name = "attach_sbom",
    type = "sbom"
    attachment = "image.sbom.spdx.json",
    repository = "index.docker.io/org/image"
)
```

`repository` attribute can be overridden using the `--repository` flag.

```starlark
oci_image(
    name = "image"
)

cosign_attach(
    name = "attach_sbom",
    type = "sbom"
    attachment = "image.sbom.spdx.json",
    repository = "index.docker.io/org/image"
)
```

via `bazel run :attach_sbom -- --repository=index.docker.io/org/test`
"""

_attrs = {
    "image": attr.label(allow_single_file = True, mandatory = True, doc = "Label to an oci_image"),
    "type": attr.string(values = ["attestation", "sbom", "signature"], mandatory = True, doc = "Type of attachment. Acceptable values are: `attestation`, `sbom`, and `signature`"),
    "attachment": attr.label(allow_single_file = True, mandatory = True, doc = "Label to the attachment. Only files are allowed. eg: sbom.spdx, in-toto.json"),
    "repository": attr.string(mandatory = True, doc = """\
        Repository URL where the image will be signed at, e.g.: `index.docker.io/<user>/image`.
        Digests and tags are not allowed.
    """),
    "_attach_sh_tpl": attr.label(default = "attach.sh.tpl", allow_single_file = True),
}

def _cosign_attach_impl(ctx):
    cosign = ctx.toolchains["@contrib_rules_oci//cosign:toolchain_type"]
    yq = ctx.toolchains["@aspect_bazel_lib//lib:yq_toolchain_type"]

    if ctx.attr.repository.find(":") != -1 or ctx.attr.repository.find("@") != -1:
        fail("repository attribute should not contain digest or tag.")

    fixed_args = ["--repository", ctx.attr.repository]

    if ctx.attr.type == "sbom":
        fixed_args.extend(["--sbom", ctx.file.attachment.short_path])
    elif ctx.attr.type == "attestation":
        fixed_args.extend(["--attestation", ctx.file.attachment.short_path])
    else:
        fixed_args.extend(["--signature", ctx.file.attachment.short_path])

    executable = ctx.actions.declare_file("cosign_attach_{}.sh".format(ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._attach_sh_tpl,
        output = executable,
        is_executable = True,
        substitutions = {
            "{{cosign_path}}": cosign.cosign_info.binary.short_path,
            "{{yq_path}}": yq.yqinfo.bin.short_path,
            "{{image_dir}}": ctx.file.image.short_path,
            "{{fixed_args}}": " ".join(fixed_args),
            "{{type}}": ctx.attr.type,
        },
    )

    runfiles = ctx.runfiles(files = [ctx.file.image, ctx.file.attachment])
    runfiles = runfiles.merge(yq.default.default_runfiles)
    runfiles = runfiles.merge(cosign.default.default_runfiles)

    return DefaultInfo(executable = executable, runfiles = runfiles)

cosign_attach = rule(
    implementation = _cosign_attach_impl,
    attrs = _attrs,
    doc = _DOC,
    executable = True,
    toolchains = [
        "@contrib_rules_oci//cosign:toolchain_type",
        "@aspect_bazel_lib//lib:yq_toolchain_type",
    ],
)
