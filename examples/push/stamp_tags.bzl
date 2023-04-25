"Helper for stamping version control info into the tag"

load("@aspect_bazel_lib//lib:jq.bzl", "jq")
load("@bazel_skylib//lib:types.bzl", "types")

def stamp_tags(name, repotags, **kwargs):
    """Wrapper macro around the [jq](https://docs.aspect.build/rules/aspect_bazel_lib/docs/jq) rule.

    Produces a text file that can be used with the `repotags` attribute of [`oci_push`](#oci_push).

    Each entry in `repotags` is typically either a constant like `my-repo:latest`, or can contain a stamp expression.
    The latter can use any key from `bazel-out/stable-status.txt` or `bazel-out/volatile-status.txt`.
    See https://docs.aspect.build/rules/aspect_bazel_lib/docs/stamping/ for details.

    The jq `//` default operator is useful for returning an alternative value for unstamped builds.

    For example, if you use the expression `($stamp.BUILD_EMBED_LABEL // "0.0.0")`, this resolves to
    "0.0.0" if stamping is not enabled. When built with `--stamp --embed_label=1.2.3` it will
    resolve to `1.2.3`.

    Args:
        name: name of the resulting jq target.
        repotags: list of jq expressions which result in a string value, see docs above
        **kwargs: additional named parameters to the jq rule.
    """
    if not types.is_list(repotags):
        fail("repotags should be a list")
    _maybe_quote = lambda x: x if "\"" in x else "\"{}\"".format(x)
    jq(
        name = name,
        srcs = [],
        out = "_{}.tags.txt".format(name),
        args = ["--raw-output"],
        filter = "|".join([
            "$ARGS.named.STAMP as $stamp",
            ",".join([_maybe_quote(t) for t in repotags]),
        ]),
        **kwargs
    )
