def _impl(settings, attr):
    _ignore = (settings)
    if attr.docker_compatibility_required == -1:
        return {}
    return {"@rules_oci//oci/private/registry:docker_compatibility": attr.docker_compatibility_required}

docker_compatibility_transition = transition(
    implementation = _impl,
    inputs = [],
    outputs = ["@rules_oci//oci/private/registry:docker_compatibility"],
)

def _impll(ctx):
    return DefaultInfo(files = depset([ctx.file.src]))

docker_compatibility_outgoing_edge = rule(
    implementation = _impll,
    attrs = {
        "docker_compatibility_required": attr.int(values = [-1, 0, 1], default = -1),
        "src": attr.label(mandatory = True, allow_single_file = True),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    cfg = docker_compatibility_transition,
)
