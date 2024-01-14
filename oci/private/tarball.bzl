"""Create a tarball from oci_image that can be loaded by runtimes such as podman and docker.

For example, given an `:image` target, you could write

```
oci_tarball(
    name = "tarball",
    image = ":image",
    repo_tags = ["my-repository:latest"],
)
```

and then run it in a container like so:

```
bazel run :tarball
docker run --rm my-repository:latest
```
"""

load("//oci/private:util.bzl", "util")

doc = """Creates tarball from OCI layouts that can be loaded into docker daemon without needing to publish the image first.

Passing anything other than oci_image to the image attribute will lead to build time errors.
"""

attrs = {
    "format": attr.string(
        default = "docker",
        doc = "Format of image to generate. Options are: docker, oci. Currently, when the input image is an image_index, only oci is supported, and when the input image is an image, only docker is supported. Conversions between formats may be supported in the future.",
        values = ["docker", "oci"],
    ),
    "image": attr.label(mandatory = True, allow_single_file = True, doc = "Label of a directory containing an OCI layout, typically `oci_image`"),
    "repo_tags": attr.label(
        doc = """\
            a file containing repo_tags, one per line.
            """,
        allow_single_file = [".txt"],
        mandatory = True,
    ),
    "loader": attr.label(
        doc = """\
            Alternative target for a container cli tool that will be
            used to load the image into the local engine when using `bazel run` on this oci_tarball.

            By default, we look for `docker` or `podman` on the PATH, and run the `load` command.

            > Note that rules_docker has an "incremental loader" which has better performance, see
            > Follow https://github.com/bazel-contrib/rules_oci/issues/454 for similar behavior in rules_oci.

            See the _run_template attribute for the script that calls this loader tool.
            """,
        allow_single_file = True,
        mandatory = False,
        executable = True,
        cfg = "target",
    ),
    "_run_template": attr.label(
        default = Label("//oci/private:tarball_run.sh.tpl"),
        doc = """ \
              The template used to load the container when using `bazel run` on this oci_tarball.

              See the `loader` attribute to replace the tool which is called.
              Please reference the default template to see available substitutions.
        """,
        allow_single_file = True,
    ),
    "_tarball_sh": attr.label(allow_single_file = True, default = "//oci/private:tarball.sh.tpl"),
    "_windows_constraint": attr.label(default = "@platforms//os:windows"),
}

def _tarball_impl(ctx):
    image = ctx.file.image
    tarball = ctx.actions.declare_file("{}/tarball.tar".format(ctx.label.name))
    coreutils = ctx.toolchains["@aspect_bazel_lib//lib:coreutils_toolchain_type"]
    tar = ctx.toolchains["@aspect_bazel_lib//lib:tar_toolchain_type"]
    yq = ctx.toolchains["@aspect_bazel_lib//lib:yq_toolchain_type"]
    executable = ctx.actions.declare_file("{}/tarball.sh".format(ctx.label.name))
    repo_tags = ctx.file.repo_tags

    substitutions = {
        "{{format}}": ctx.attr.format,
        "{{coreutils_path}}": coreutils.coreutils_info.bin.path,
        "{{tar_path}}": tar.tarinfo.binary.path,
        "{{yq_path}}": yq.yqinfo.bin.path,
        "{{image_dir}}": image.path,
        "{{tarball_path}}": tarball.path,
    }

    if ctx.attr.repo_tags:
        substitutions["{{tags}}"] = repo_tags.path

    ctx.actions.expand_template(
        template = ctx.file._tarball_sh,
        output = executable,
        is_executable = True,
        substitutions = substitutions,
    )

    ctx.actions.run(
        executable = util.maybe_wrap_launcher_for_windows(ctx, executable),
        use_default_shell_env = True,
        inputs = [image, repo_tags, executable],
        outputs = [tarball],
        tools = [
            coreutils.coreutils_info.bin,
            tar.tarinfo.binary,
            yq.yqinfo.bin,
        ],
        mnemonic = "OCITarball",
        progress_message = "OCI Tarball %{label}",
    )

    exe = ctx.actions.declare_file(ctx.label.name + ".sh")

    ctx.actions.expand_template(
        template = ctx.file._run_template,
        output = exe,
        substitutions = {
            "{{image_path}}": tarball.short_path,
            "{{loader}}": ctx.file.loader.path if ctx.file.loader else "",
        },
        is_executable = True,
    )
    runfiles = [tarball]
    if ctx.file.loader:
        runfiles.append(ctx.file.loader)

    return [
        DefaultInfo(files = depset([tarball]), runfiles = ctx.runfiles(files = runfiles), executable = exe),
    ]

oci_tarball = rule(
    implementation = _tarball_impl,
    attrs = attrs,
    doc = doc,
    toolchains = [
        "@bazel_tools//tools/sh:toolchain_type",
        "@aspect_bazel_lib//lib:coreutils_toolchain_type",
        "@aspect_bazel_lib//lib:tar_toolchain_type",
        "@aspect_bazel_lib//lib:yq_toolchain_type",
    ],
    executable = True,
)
