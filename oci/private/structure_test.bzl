"""test rule running structure_test against an oci_image."""

_DOC = """Tests an oci_image by using [container-structure-test](https://github.com/GoogleContainerTools/container-structure-test).

By default, it relies on the container runtime already installed and running on the target.
By default, container-structure-test uses the socket available at /var/run/docker.sock. If the installation
creates the socket in a different path, use --test_env=DOCKER_HOST='unix://<path_to_sock>'.

To avoid putting this into the commandline or to instruct bazel to read it from terminal environment, 
simply drop `test --test_env=DOCKER_HOST` into the .bazelrc file.

Alternatively, use the `driver = "tar"` attribute to avoid the need for a container runtime, see
https://github.com/GoogleContainerTools/container-structure-test#running-file-tests-without-docker
"""

_attrs = {
    "image": attr.label(
        allow_single_file = True,
        doc = "Label to an oci_image target. Only works when `driver` is `docker`.",
        # TODO: restrict valid values using providers = ["OciImage"] when we have that.
    ),
    "image_tar": attr.label(
        allow_single_file = [".tar"],
        doc = "Label of an oci_tarball target. Only one of `image` and `image_tar` should be used.",
    ),
    "config": attr.label_list(allow_files = True, mandatory = True),
    "driver": attr.string(
        default = "docker",
        # https://github.com/GoogleContainerTools/container-structure-test/blob/5e347b66fcd06325e3caac75ef7dc999f1a9b614/pkg/drivers/driver.go#L26-L28
        values = ["docker", "tar", "host"],
        doc = "See https://github.com/GoogleContainerTools/container-structure-test#running-file-tests-without-docker",
    ),
}

CMD = """\
#!/usr/bin/env bash

readonly DIGEST=$("{yq_path}" eval '.manifests[0].digest | sub(":"; "-")' "{image_path}/index.json")

exec "{st_path}" test {fixed_args} --default-image-tag "registry.structure_test.oci.local/image:$DIGEST" $@
"""

def _structure_test_impl(ctx):
    st_info = ctx.toolchains["@rules_oci//oci:st_toolchain_type"].st_info
    yq_info = ctx.toolchains["@aspect_bazel_lib//lib:yq_toolchain_type"].yqinfo

    if ctx.attr.image and ctx.attr.image_tar:
        fail("Only one of 'image' and 'image_tar' attributes should be used.")

    # https://github.com/GoogleContainerTools/container-structure-test/blob/5e347b66fcd06325e3caac75ef7dc999f1a9b614/cmd/container-structure-test/app/cmd/test.go#L110
    if ctx.attr.image and ctx.attr.driver != "docker":
        fail("'image' attribute may only be used with 'driver=docker'")

    fixed_args = ["--driver", ctx.attr.driver]
    if ctx.file.image:
        image_path = ctx.file.image.short_path
        fixed_args.extend(["--image-from-oci-layout", image_path])
    else:
        image_path = ctx.file.image_tar.short_path
        fixed_args.extend(["--image", image_path])

    for arg in ctx.files.config:
        fixed_args.append("--config=%s" % arg.path)

    launcher = ctx.actions.declare_file("%s.sh" % ctx.label.name)
    ctx.actions.write(
        launcher,
        content = CMD.format(
            st_path = st_info.binary.short_path,
            fixed_args = " ".join(fixed_args),
            yq_path = yq_info.bin.short_path,
            image_path = image_path,
        ),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = ctx.files.image + ctx.files.image_tar + ctx.files.config + [st_info.binary, yq_info.bin])

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
