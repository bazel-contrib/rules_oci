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
    """Wrapper around the [jq](https://docs.aspect.build/rules/aspect_bazel_lib/docs/jq) rule.

    Produces a text file that can be used with the `image_tags` attribute of [`oci_push`](#oci_push).

    Args:
        name: name of the resulting jq target.
        image_tags: jq expressions, typically either a stamp-aware value like
            `($stamp.BUILD_EMBED_LABEL // "0.0.0")` or a constant like `"latest"`.
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
    """Macro wrapper around the [oci_push_rule](#oci_push_rule).

    Allows the metadata attribute to be a dictionary.

    Args:
        name: name of resulting oci_push_rule
        image_tags: a list of tags to apply to the image after pushing,
            or a label of a file containing tags one-per-line
        **kwargs: other named arguments to oci_push_rule
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
