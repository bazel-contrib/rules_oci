"""
  An aspect that find's most transitive dependencies (target) of the given rule's attribute.

  Used to find all potential targets that can be evaluated as part of ${location} macro.
"""

DepTargetsInfo = provider(
    """All transitive dependencies of the considered target with respect to `DEP_ATTRS` attributes.""",
    fields = {
        "dep_targets": "list of transitive dep targets of a target",
    },
)

# This attributes are recursively considered as dependencies of the rule being evaluated.
DEP_ATTRS = ["tars", "deps", "runtime_deps", "data", "srcs", "files"]

def _deps_of_target(attr):
    if type(attr) == "list":
        return depset(
            transitive = [t[DepTargetsInfo].dep_targets for t in attr if DepTargetsInfo in t],
            direct = [t for t in attr if not DepTargetsInfo in t],
        )
    elif DepTargetsInfo in attr:
        return attr[DepTargetsInfo].dep_targets
    else:
        return depset()

def _collect_dep_targets_aspect_impl(target, ctx):
    accumulated = [_deps_of_target(getattr(ctx.rule.attr, attr)) for attr in DEP_ATTRS if hasattr(ctx.rule.attr, attr)]
    return [DepTargetsInfo(dep_targets = depset(
        direct = [target],
        transitive = accumulated,
    ))]

collect_dep_targets_aspect = aspect(
    implementation = _collect_dep_targets_aspect_impl,
    attr_aspects = DEP_ATTRS,
)
