def _container_run_and_save_impl(ctx):
    name = ctx.label.name
    base_tarball = ctx.attr.base_tarball

    tar_output = ctx.actions.declare_file("layer_%s.tar" % name)

    script_output = ctx.actions.declare_file("run_%s.sh" % name)

    file_list = []
    file_list_str = []

    for i in base_tarball[DefaultInfo].files.to_list():
        if "tar" in i.path:
            file_list.append(i)
            file_list_str.append(i.path)

    ctx.actions.expand_template(
        template = ctx.file._run_sh_tpl,
        output = script_output,
        is_executable = True,
        substitutions = {
            "{{base_image_tarball}}": " ".join(file_list_str),
            "{{container_name}}": "%s_container" % name,
            "{{command}}": ctx.attr.cmd,
            "{{output}}": tar_output.path,
            "{{docker_buildkit}}": "1" if ctx.attr.buildkit else "0",
            "{{loader}}":  ctx.file.loader.path if ctx.file.loader else "",
        },
    )

    ctx.actions.run(
        executable = script_output,
        outputs = [tar_output],
        mnemonic = "OCIExecLayer",
        tools = file_list,
    )

    return [
        DefaultInfo(
            files = depset([tar_output]),
            executable = tar_output,
        ),
    ]

_container_run_and_save_attrs = {
    "base_tarball": attr.label(allow_single_file = True),
    "cmd": attr.string(
        doc = """\
            Command to execute inside of the container.
        """,
        mandatory = True,
    ),
    "buildkit": attr.bool(
        doc = """\
            Enable/disable the use of BuildKit when running.
        """,
        mandatory = False,
        default = True
    ),
    "loader": attr.label(
        doc = """\
            Alternative target for a container cli tool that will be
            used to load the image into the local engine when using `bazel run` on this container_run_and_save.

            By default, we look for `docker` or `podman` on the PATH, and run the `load` command.

            See the _run_sh_tpl attribute for the script that calls this loader tool.
            """,
        allow_single_file = True,
        mandatory = False,
        executable = True,
        cfg = "target",
    ),
    "_run_sh_tpl": attr.label(default = "container_run_and_save.sh.tpl", allow_single_file = True),
}

container_run_and_save = rule(
    implementation = _container_run_and_save_impl,
    attrs = _container_run_and_save_attrs,
    executable = True,
)