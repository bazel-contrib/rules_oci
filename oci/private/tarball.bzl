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
bazel build //path/to:tarball
bazel run :tarball
```
"""

doc = """Creates tarball from OCI layouts that can be loaded into docker daemon without needing to publish the image first.

Passing anything other than oci_image to the image attribute will lead to build time errors.
"""

attrs = {
    "image": attr.label(mandatory = True, allow_single_file = True, doc = "Label of a directory containing an OCI layout, typically `oci_image`"),
    "repo_tags": attr.label(
        doc = """\
            a file containing repo_tags, one per line.
            """,
        allow_single_file = [".txt"],
    ),
    "run_template": attr.label(
        default = Label("//oci/private:tarball_run.sh.tpl"),
        doc = """ \
              The template used when running the container. The default template uses Docker, but this template could be replaced to use podman, runc, or another runtime. Please reference the default template to see available substitutions. 
        """,
        allow_single_file = True,
    ),    
    "runtime_args": attr.string_list(
        default = [],
        doc = """ \
        These arguments will be passed to the container runtime (the default template uses Docker) when running the container via 'bazel run'. You can use this to add things like additional port mappings, change the entrypoint, e.g.: ["-p", "5432:5432", "--entrypoint=/bin/my_app"]
        """,
    ),
    "_tarball_sh": attr.label(allow_single_file = True, default = "//oci/private:tarball.sh.tpl"),
}

def _tarball_impl(ctx):
    image = ctx.file.image
    tarball = ctx.actions.declare_file("{}/tarball.tar".format(ctx.label.name))
    yq_bin = ctx.toolchains["@aspect_bazel_lib//lib:yq_toolchain_type"].yqinfo.bin
    executable = ctx.actions.declare_file("{}/tarball.sh".format(ctx.label.name))
    repo_tags = ctx.file.repo_tags

    substitutions = {
        "{{yq}}": yq_bin.path,
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
        executable = executable,
        inputs = [image, repo_tags],
        outputs = [tarball],
        tools = [yq_bin],
        mnemonic = "OCITarball",
        progress_message = "OCI Tarball %{label}",
    )

    exe = ctx.actions.declare_file(ctx.label.name + ".sh")

    ctx.actions.expand_template(
        template = ctx.file.run_template,
        output = exe,
        substitutions = {
            "{{image_path}}": tarball.short_path,
            "{{tag_file}}": repo_tags.short_path,
            "{{runtime_args}}": " ".join(ctx.attr.runtime_args),
        },
        is_executable = True,
    )    

    return [
        DefaultInfo(files = depset([tarball]), runfiles = ctx.runfiles(files = [tarball, repo_tags]), executable = exe),
    ]

oci_tarball = rule(
    implementation = _tarball_impl,
    attrs = attrs,
    doc = doc,
    toolchains = [
        "@aspect_bazel_lib//lib:yq_toolchain_type",
    ],
    executable = True,
)
