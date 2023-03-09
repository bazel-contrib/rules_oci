"Public API"

load("@aspect_bazel_lib//lib:jq.bzl", "jq")
load("//oci/private:tarball.bzl", _oci_tarball = "oci_tarball")
load("//oci/private:image.bzl", _oci_image = "oci_image")
load("//oci/private:image_index.bzl", _oci_image_index = "oci_image_index")
load("//oci/private:push.bzl", _oci_push = "oci_push")
load("//oci/private:structure_test.bzl", _structure_test = "structure_test")
load("@bazel_skylib//lib:types.bzl", "types")
load("@bazel_skylib//rules:write_file.bzl", "write_file")

oci_tarball = _oci_tarball
oci_image = _oci_image
oci_image_index = _oci_image_index
oci_push_rule = _oci_push
structure_test = _structure_test

def stamped_tags(name, image_tags, **kwargs):
    """Wrapper macro around the [jq](https://docs.aspect.build/rules/aspect_bazel_lib/docs/jq) rule.

    Produces a text file that can be used with the `image_tags` attribute of [`oci_push`](#oci_push).

    Each entry in `image_tags` is typically either a constant like `latest`, or a stamp expression.
    The latter can use any key from `bazel-out/stable-status.txt` or `bazel-out/volatile-status.txt`.
    See https://docs.aspect.build/rules/aspect_bazel_lib/docs/stamping/ for details.

    The jq `//` default operator is useful for returning an alternative value for unstamped builds.

    For example, if you use the expression `($stamp.BUILD_EMBED_LABEL // "0.0.0")`, this resolves to
    "0.0.0" if stamping is not enabled. When built with `--stamp --embed_label=1.2.3` it will
    resolve to `1.2.3`.

    Args:
        name: name of the resulting jq target.
        image_tags: list of jq expressions which result in a string value, see docs above
        **kwargs: additional named parameters to the jq rule.
    """
    if not types.is_list(image_tags):
        fail("image_tags should be a list")
    _maybe_quote = lambda x: x if "\"" in x else "\"{}\"".format(x)
    jq(
        name = name,
        srcs = [],
        out = "tags.txt",
        args = ["--raw-output"],
        filter = "|".join([
            "$ARGS.named.STAMP as $stamp",
            ",".join([_maybe_quote(t) for t in image_tags]),
        ]),
    )

def oci_push(name, image_tags = None, **kwargs):
    """Macro wrapper around [oci_push_rule](#oci_push_rule).

    Allows the tags attribute to be a list of strings in addition to a text file.

    Args:
        name: name of resulting oci_push_rule
        image_tags: a list of tags to apply to the image after pushing,
            or a label of a file containing tags one-per-line.
            See [stamped_tags](#stamped_tags) as one example of a way to produce such a file.
        **kwargs: other named arguments to [oci_push_rule](#oci_push_rule).
    """
    if types.is_list(image_tags):
        tags_label = "_{}_write_tags".format(name)
        write_file(
            name = tags_label,
            out = "_{}_tags.txt".format(name),
            content = image_tags,
        )
        image_tags = tags_label

    oci_push_rule(
        name = name,
        image_tags = image_tags,
        **kwargs
    )
