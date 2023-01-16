"""test rule running structure_test against an oci_image."""

_DOC = """Tests an oci_image in a container runtime by using GoogleContainerTools/container-structure-test.

It relies on the container runtime already installed and running on the target. 

By default, container-structure-test uses the socket available at /var/run/docker.sock. If the installation
creates the socket in a different path, use --test_env=DOCKER_HOST='unix://<path_to_sock>'.

To avoid putting this into the commandline or to instruct bazel to read it from terminal environment, 
simply drop `test --test_env=DOCKER_HOST` into the .bazelrc file.
"""

_attrs = {
    "image": attr.label(mandatory = True, allow_single_file = True, doc = "Label to an oci_image target"),
    "config": attr.label_list(allow_files = True, mandatory = True),
}

CMD = """\
#!/usr/bin/env bash
exec "{st_path}" test {fixed_args} "$@"
"""

def _structure_test_impl(ctx):
    st_info = ctx.toolchains["@contrib_rules_oci//oci:st_toolchain_type"].st_info

    default_image_tag = "{workspace}.local/{package}/{name}:latest".format(
        workspace = ctx.workspace_name,
        package = ctx.label.package.replace("/", "_"),
        name = ctx.label.name,
    )

    fixed_args = [
        "--image-from-oci-layout",
        ctx.file.image.short_path,
        "--default-image-tag",
        default_image_tag,
    ]

    for arg in ctx.files.config:
        fixed_args.append("--config=%s" % arg.path)

    launcher = ctx.actions.declare_file("%s.sh" % ctx.label.name)
    ctx.actions.write(
        launcher,
        content = CMD.format(
            st_path = st_info.binary.short_path,
            fixed_args = " ".join(fixed_args),
        ),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = ctx.files.image + ctx.files.config + [st_info.binary])

    return DefaultInfo(runfiles = runfiles, executable = launcher)

structure_test = rule(
    implementation = _structure_test_impl,
    attrs = _attrs,
    doc = _DOC,
    test = True,
    toolchains = [
        "@contrib_rules_oci//oci:st_toolchain_type",
    ],
)
