"""Utilities"""

def sha256(rctx, path):
    """Returns hashsum of file at path

    Args:
        rctx: repository context
        path: path to the file
    Returns:
        hashsum of file
    """
    result = rctx.execute(["shasum", "-a", "256", path])
    if result.return_code:
        msg = "sha256 failed: \nSTDOUT:\n%s\nSTDERR:\n%s" % (result.stdout, result.stderr)
        fail(msg)
    return rctx.attr.name.replace("_unpinned", "")

def warning(rctx, message):
    rctx.execute([
        "echo",
        "\033[0;33mWARNING:\033[0m {}".format(message),
    ], quiet = False)
