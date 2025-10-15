"Implementation details for attest rule"

load("@aspect_bazel_lib//lib:paths.bzl", "BASH_RLOCATION_FUNCTION", "to_rlocation_path")
load("@aspect_bazel_lib//lib:windows_utils.bzl", "create_windows_native_launcher_script")

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

You can also omit the `repository` attribute and provide it at runtime.
```starlark
cosign_attest(
    name = "attest_no_repo",
    image = ":image",
    predicate = "image.sbom.spdx.json",
    type = "spdx",
)
```
Then run `bazel run :attest_no_repo -- --repository=index.docker.io/org/test`
"""

_attrs = {
    "image": attr.label(allow_single_file = True, mandatory = True, doc = "Label to an oci_image"),
    "type": attr.string(values = ["slsaprovenance", "link", "spdx", "vuln", "custom"], mandatory = True, doc = "Type of predicate. Acceptable values are (slsaprovenance|link|spdx|vuln|custom)"),
    "predicate": attr.label(allow_single_file = True, mandatory = True, doc = "Label to the predicate file. Only files are allowed. eg: sbom.spdx, in-toto.json"),
    "repository": attr.string(doc = """        Repository URL where the image will be signed at, e.g.: `index.docker.io/<user>/image`.
        Digests and tags are not allowed. If this attribute is not set, the repository must be passed at runtime via the `--repository` flag.
    """),
    "_attest_sh_tpl": attr.label(default = "attest.sh.tpl", allow_single_file = True),
    "_runfiles": attr.label(default = "@bazel_tools//tools/bash/runfiles"),
}

def _windows_host(ctx):
    """Returns true if the host platform is windows.
    
    The typical approach using ctx.target_platform_has_constraint does not work for transitioned
    build targets. We need to know the host platform, not the target platform.
    """
    return ctx.configuration.host_path_separator == ";"

def _cosign_attest_impl(ctx):
    cosign = ctx.toolchains["@rules_oci//cosign:toolchain_type"]
    jq = ctx.toolchains["@aspect_bazel_lib//lib:jq_toolchain_type"]

    if ctx.attr.repository and (ctx.attr.repository.find(":") != -1 or ctx.attr.repository.find("@") != -1):
        fail("repository attribute should not contain digest or tag.")

    fixed_args = [
        "--predicate",
        to_rlocation_path(ctx, ctx.file.predicate),
        "--type",
        ctx.attr.type,
    ]
    if ctx.attr.repository:
        fixed_args.extend(["--repository", ctx.attr.repository])

    bash_launcher = ctx.actions.declare_file("cosign_attest_{}.sh".format(ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._attest_sh_tpl,
        output = bash_launcher,
        is_executable = True,
        substitutions = {
            "{{BASH_RLOCATION_FUNCTION}}": BASH_RLOCATION_FUNCTION,
            "{{cosign_path}}": to_rlocation_path(ctx, cosign.cosign_info.binary),
            "{{jq_path}}": to_rlocation_path(ctx, jq.jqinfo.bin),
            "{{image_dir}}": to_rlocation_path(ctx, ctx.file.image),
            "{{fixed_args}}": " ".join(fixed_args),
            "{{type}}": ctx.attr.type,
        },
    )

    executable = create_windows_native_launcher_script(ctx, bash_launcher) if _windows_host(ctx) else bash_launcher
    runfiles = ctx.runfiles(files = [ctx.file.image, ctx.file.predicate, bash_launcher])
    runfiles = runfiles.merge(ctx.attr.image[DefaultInfo].default_runfiles)
    runfiles = runfiles.merge(jq.default.default_runfiles)
    runfiles = runfiles.merge(cosign.default.default_runfiles)
    runfiles = runfiles.merge(ctx.attr._runfiles.default_runfiles)

    return DefaultInfo(executable = executable, runfiles = runfiles)

cosign_attest = rule(
    implementation = _cosign_attest_impl,
    attrs = _attrs,
    doc = _DOC,
    executable = True,
    toolchains = [
        "@bazel_tools//tools/sh:toolchain_type",
        "@rules_oci//cosign:toolchain_type",
        "@aspect_bazel_lib//lib:jq_toolchain_type",
    ],
)
