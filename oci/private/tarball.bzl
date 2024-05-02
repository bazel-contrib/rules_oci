"""Create a tarball from oci_image that can be loaded by runtimes such as podman and docker.
Intended for use with `bazel run`.

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

### Outputs

The default output is an mtree specification file.
This is because producing the tarball in `bazel build` is expensive, and should typically not be an input to any other build actions,
so producing it only creates unnecessary load on the action cache.

If needed, the `tarball` output group allows you to depend on the tar output from another rule.

On the command line, `bazel build //path/to:my_tarball --output_groups=tarball`

or in a BUILD file:

```starlark
oci_tarball(
    name = "my_tarball",
    ...
)
filegroup(
    name = "my_tarball.tar",
    srcs = [":my_tarball"],
    output_group = "tarball",
)
```
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
            
            > Note that rules_docker has an "incremental loader" which is faster than oci_tarball by design.
            > Something similar can be done for oci_tarball. 
            > See [loader.sh](/examples/incremental_loader/loader.sh) and explanation about [how](/examples/incremental_loader/README.md) it works.

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
    jq = ctx.toolchains["@aspect_bazel_lib//lib:jq_toolchain_type"].jqinfo

    image = ctx.file.image
    mtree_spec = ctx.actions.declare_file("{}/tarball.spec".format(ctx.label.name))
    bsdtar = ctx.toolchains["@aspect_bazel_lib//lib:tar_toolchain_type"]
    executable = ctx.actions.declare_file("{}/tarball.sh".format(ctx.label.name))

    # Represents either manifest.json or index.json depending on the image format
    image_json = ctx.actions.declare_file("{}/_tarball.json".format(ctx.label.name))
    repo_tags = ctx.file.repo_tags

    substitutions = {
        "{{format}}": ctx.attr.format,
        "{{jq_path}}": jq.bin.path,
        "{{tar}}": bsdtar.tarinfo.binary.path,
        "{{image_dir}}": image.path,
        "{{bindir}}": ctx.bin_dir.path,
        "{{output}}": mtree_spec.path,
        "{{json_out}}": image_json.path,
    }

    if ctx.attr.repo_tags:
        substitutions["{{tags}}"] = repo_tags.path

    ctx.actions.expand_template(
        template = ctx.file._tarball_sh,
        output = executable,
        is_executable = True,
        substitutions = substitutions,
    )

    mtree_inputs = depset(
        direct = [image, repo_tags, executable],
        transitive = [bsdtar.default.files],
    )
    mtree_outputs = [mtree_spec, image_json]
    ctx.actions.run(
        executable = util.maybe_wrap_launcher_for_windows(ctx, executable),
        inputs = mtree_inputs,
        outputs = mtree_outputs,
        tools = [jq.bin],
        mnemonic = "OCITarballManifest",
    )

    exe = ctx.actions.declare_file(ctx.label.name + ".sh")

    ctx.actions.expand_template(
        template = ctx.file._run_template,
        output = exe,
        substitutions = {
            "{{TAR}}": bsdtar.tarinfo.binary.short_path,
            "{{mtree_path}}": mtree_spec.short_path,
            "{{loader}}": ctx.file.loader.path if ctx.file.loader else "",
        },
        is_executable = True,
    )

    # This action produces a large output and should rarely be used as it puts load on the cache.
    # It will only run if the "tarball" output_group is explicitly requested
    tarball = ctx.actions.declare_file("{}/tarball.tar".format(ctx.label.name))
    tar_inputs = depset(direct = mtree_outputs, transitive = [mtree_inputs])
    tar_args = ctx.actions.args()
    tar_args.add_all(["--create", "--no-xattr", "--no-mac-metadata"])
    tar_args.add_all(["--cd", ctx.bin_dir.path])
    tar_args.add("--file", tarball)
    # To reference our mtree spec file, we have to undo the --cd by removing three path segments
    tar_args.add(mtree_spec, format = "@../../../%s")
    ctx.actions.run(
        executable = bsdtar.tarinfo.binary,
        inputs = tar_inputs,
        outputs = [tarball],
        arguments = [tar_args],
        mnemonic = "OCITarball",
    )

    return [
        DefaultInfo(
            files = depset([mtree_spec]),
            runfiles = ctx.runfiles(files = [ctx.file.loader] if ctx.file.loader else [], transitive_files = tar_inputs),
            executable = exe,
        ),
        OutputGroupInfo(tarball = depset([tarball])),
    ]

oci_tarball = rule(
    implementation = _tarball_impl,
    attrs = attrs,
    doc = doc,
    toolchains = [
        "@bazel_tools//tools/sh:toolchain_type",
        "@aspect_bazel_lib//lib:jq_toolchain_type",
        "@aspect_bazel_lib//lib:tar_toolchain_type",
    ],
    executable = True,
)
