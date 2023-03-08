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

readonly DIGEST=$("{yq_path}" eval '.manifests[0].digest | sub(":"; "-")' "{image_path}/index.json")

exec "{st_path}" test {fixed_args} --default-image-tag "registry.structure_test.oci.local/image:$DIGEST" $@
"""

def _structure_test_impl(ctx):
    st_info = ctx.toolchains["@rules_oci//oci:st_toolchain_type"].st_info
    yq_info = ctx.toolchains["@aspect_bazel_lib//lib:yq_toolchain_type"].yqinfo

    fixed_args = [
        "--image-from-oci-layout",
        ctx.file.image.short_path,
    ]

    for arg in ctx.files.config:
        fixed_args.append("--config=%s" % arg.path)

    launcher = ctx.actions.declare_file("%s.sh" % ctx.label.name)
    ctx.actions.write(
        launcher,
        content = CMD.format(
            st_path = st_info.binary.short_path,
            fixed_args = " ".join(fixed_args),
            yq_path = yq_info.bin.short_path,
            image_path = ctx.file.image.short_path,
        ),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = ctx.files.image + ctx.files.config + [st_info.binary, yq_info.bin])

    return DefaultInfo(runfiles = runfiles, executable = launcher)

structure_test = rule(
    implementation = _structure_test_impl,
    attrs = _attrs,
    doc = _DOC,
    test = True,
    toolchains = [
        "@rules_oci//oci:st_toolchain_type",
        "@aspect_bazel_lib//lib:yq_toolchain_type",
    ],
)
