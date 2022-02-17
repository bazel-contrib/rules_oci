"""Do not depend on this rule."""
_ATTRS = {
    "reference": attr.string(
        mandatory = True
    ),
    "registry": attr.string(
        default = "index.docker.io"
    ),
    "digest": attr.string()
}

def _impl(ctx):
    toolchain = ctx.toolchains["@aspect_rules_container//container:toolchain_type"].containerinfo

    image = ctx.actions.declare_directory(ctx.attr.name)

    reference = "%s/%s@%s" % (ctx.attr.registry, ctx.attr.reference, ctx.attr.digest)

    args = ctx.actions.args()
    args.add_all([
        "pull",
        reference,
        image.path,
        "--format",
        "oci",
        "--convert",
        "oci"
    ])

    cmd = """
{crane} $@
{umoci} tag --image {image}:{current_ref} {new_ref}
{umoci} remove --image {image}:{current_ref}
    """.format(
        crane = toolchain.crane_path,
        umoci = toolchain.umoci_path,
        image = image.path,
        current_ref = reference,
        new_ref = ctx.label.name,
    )

    ctx.actions.run_shell(
        command = cmd,
        arguments = [args],
        tools = toolchain.crane_files + toolchain.umoci_files,
        outputs = [image],
        progress_message = "Pulling image %{label}",
        execution_requirements = {
            "requires-network": "1"   
        }
    )

    return [
        DefaultInfo(files = depset([image]))
    ]

image_pull = rule(
    implementation = _impl,
    attrs = _ATTRS,
    toolchains = ["@aspect_rules_container//container:toolchain_type"],
)
