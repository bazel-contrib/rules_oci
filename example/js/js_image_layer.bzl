"This module contains container helper functions for js_binary"

load("@rules_pkg//:providers.bzl", "PackageFilegroupInfo", "PackageFilesInfo", "PackageSymlinkInfo")
load("@rules_pkg//:pkg.bzl", "pkg_tar")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@aspect_bazel_lib//lib:paths.bzl", "to_manifest_path")
load("@rules_python//python:defs.bzl", "py_binary")

# BAZEL_BINDIR has to be set to '.' so that js_binary preserves the PWD when running inside container.
# See https://github.com/aspect-build/rules_js/tree/dbb5af0d2a9a2bb50e4cf4a96dbc582b27567155#running-nodejs-programs
# for why this is needed.
_LAUNCHER_TMPL = """
export BAZEL_BINDIR=.
source {executable_path}
"""

def _write_laucher(ctx, executable_path):
    "Creates a call-through shell entrypoint which sets BAZEL_BINDIR to '.' then immediately invokes the original entrypoint."
    launcher = ctx.actions.declare_file("%s_launcher.sh" % ctx.label.package)

    ctx.actions.write(
        output = launcher,
        content = _LAUNCHER_TMPL.format(executable_path = executable_path),
        is_executable = True,
    )

    return launcher

def _runfile_path(ctx, file, runfiles_dir):
    return paths.join(runfiles_dir, to_manifest_path(ctx, file))

# Tests whether the destination string should be included
# When exclude is "" it is noop.
# When include is "" it indicates implicit include.
#
# destination = "/app/node_modules", include = "", exclude = "node_modules" will return False
# destination = "/app/node_modules", include = "node_modules", exclude = "" will return True
# destination = "/app/node_modules", include = "node_modules", exclude = "node_modules" will return False
def _should_include(destination, include, exclude):
    included = include in destination or include == ""
    excluded = exclude in destination and exclude != ""
    return included and not excluded

def _runfiles_impl(ctx):
    default_info = ctx.attr.binary[DefaultInfo]

    executable = default_info.files_to_run.executable
    executable_path = paths.join(ctx.attr.root, executable.short_path)
    original_executable_path = executable_path.replace(".sh", "_.sh")
    launcher = _write_laucher(ctx, original_executable_path)

    file_map = {}

    if _should_include(original_executable_path, ctx.attr.include, ctx.attr.exclude):
        file_map[original_executable_path] = executable

    if _should_include(executable_path, ctx.attr.include, ctx.attr.exclude):
        file_map[executable_path] = launcher

    manifest = default_info.files_to_run.runfiles_manifest
    runfiles_dir = paths.join(ctx.attr.root, manifest.short_path.replace(manifest.basename, "")[:-1])

    files = depset(transitive = [default_info.files, default_info.default_runfiles.files])

    for file in files.to_list():
        destination = _runfile_path(ctx, file, runfiles_dir)
        if _should_include(destination, ctx.attr.include, ctx.attr.exclude):
            file_map[destination] = file

    symlinks = []

    # NOTE: symlinks is different than root_symlinks. See: https://bazel.build/rules/rules#runfiles_symlinks for distinction between
    # root_symlinks and symlinks and why they have to be handled differently.
    for symlink in default_info.data_runfiles.symlinks.to_list():
        destination = paths.join(runfiles_dir, ctx.workspace_name, symlink.path)
        if not _should_include(destination, ctx.attr.include, ctx.attr.exclude):
            continue
        if hasattr(file_map, destination):
            file_map.pop(destination)
        info = PackageSymlinkInfo(
            target = "/{}".format(_runfile_path(ctx, symlink.target_file, runfiles_dir)),
            destination = destination,
            attributes = {"mode": "0777"},
        )
        symlinks.append([info, symlink.target_file.owner])

    for symlink in default_info.data_runfiles.root_symlinks.to_list():
        destination = paths.join(runfiles_dir, symlink.path)
        if not _should_include(destination, ctx.attr.include, ctx.attr.exclude):
            continue
        if hasattr(file_map, destination):
            file_map.pop(destination)
        info = PackageSymlinkInfo(
            target = "/{}".format(_runfile_path(ctx, symlink.target_file, runfiles_dir)),
            destination = destination,
            attributes = {"mode": "0777"},
        )
        symlinks.append([info, symlink.target_file.owner])

    return [
        PackageFilegroupInfo(
            pkg_dirs = [],
            pkg_files = [
                [PackageFilesInfo(
                    dest_src_map = file_map,
                    attributes = {},
                ), ctx.label],
            ],
            pkg_symlinks = symlinks,
        ),
        DefaultInfo(files = depset([executable, launcher], transitive = [files])),
    ]

runfiles = rule(
    implementation = _runfiles_impl,
    attrs = {
        "binary": attr.label(mandatory = True),
        "root": attr.string(),
        "include": attr.string(),
        "exclude": attr.string(),
    },
)

# pkg_tar has poor support for symlinks due to bazel not providing enough information about symlinks.
#
# ```starlark
#   actual_file = ctx.actions.declare_file("thefile.txt")
#   symlink_file = ctx.actions.declare_file("this_is_a_symlink.txt")
#   ctx.actions.symlink(symlink_file, target_file = actual_file)
# ```
# to determine a file is file or directory pkg_tar checks `is_directory` if it is false then it makes the assumption
# that the file is in fact is a file which not true for `symlink_file` above. this is where pkg_tar fails to build
# a correct tar file.
# In order to fix this, manifest written pkg_tar should be fixed by looking for files that are symlink instead of file.

# TODO(thesayyn): remove this once pkg_tar is fixed.
#
# See: https://github.com/bazelbuild/rules_pkg/issues/115#issuecomment-1190494335
BUILD_TAR = """
import os
import sys
import json
import subprocess
from rules_python.python.runfiles import runfiles
r = runfiles.Create()
build_tar_path = r.Rlocation("rules_pkg/pkg/private/tar/build_tar")
manifest_path = next((argv.replace("--manifest=", "") for argv in sys.argv if argv.startswith("--manifest=")), None)
with open(manifest_path, "r") as manifest_fp:
    manifest = json.load(manifest_fp)
def strip_execroot(p):
    parts = p.split(os.sep)
    i = parts.index("execroot") 
    return os.sep.join(parts[i+2:]) 
def get_runfiles_path(p):
    for entry in manifest:
        if entry[2] == p:
            return entry[1]
    raise Exception("could not find a corresponding file for %s within manifest.")
for entry in manifest:
    p = entry[2]
    if "node_modules" in p and os.path.islink(p):
        link_to = os.path.realpath(p)
        link_to_execroot_stripped = strip_execroot(link_to)
        overwritten_to = get_runfiles_path(link_to_execroot_stripped)
        # fix it!
        entry[0] = 1 # make it a symlink
        entry[2] = "/%s" % overwritten_to
        entry[3] = "0777"
os.remove(manifest_path)
with open(manifest_path, "w") as manifest_w:
    manifest_w.write(json.dumps(manifest))
r = subprocess.run([build_tar_path] + sys.argv[1:])
sys.exit(r.returncode)
"""

def js_image_layer(name, binary, root = None, **kwargs):
    """Creates two tar files `:<name>/app.tar` and `:<name>/node_modules.tar`

    Final directory tree will look like below
    /{root of js_image_layer}/{package_name() if any}/{name of js_binary}.sh -> entrypoint
    /{root of js_image_layer}/{package_name() if any}/{name of js_binary}.sh.runfiles -> runfiles directory (almost identical to one bazel lays out)
    Args:
        name: name for this target. Not reflected anywhere in the final tar.
        binary: label to js_image target
        root: Path where the js_binary will reside inside the final container image.
        **kwargs: Passed to pkg_tar. See: https://github.com/bazelbuild/rules_pkg/blob/main/docs/0.7.0/reference.md#pkg_tar
    """
    if root != None and not root.startswith("/"):
        fail("root path must start with '/' but got '{root}', expected '/{root}'".format(root = root))

    if kwargs.pop("package_dir", None):
        fail("use 'root' attribute instead of 'package_dir'.")

    entrypoint_name = "%s_build_tar_entrypoint.py" % name

    write_file(
        name = "%s.build_tar_entrypoint" % name,
        out = entrypoint_name,
        content = [BUILD_TAR],
        tags = ["manual"],
    )

    py_binary(
        name = "%s.build_tar" % name,
        srcs = [entrypoint_name],
        main = entrypoint_name,
        deps = ["@rules_python//python/runfiles"],
        data = [
            "@rules_pkg//pkg/private/tar:build_tar",
        ],
        tags = ["manual"],
    )

    common_kwargs = {
        "tags": kwargs.pop("tags", None),
        "visibility": kwargs.pop("visibility", None),
    }

    runfiles_kwargs = dict(
        common_kwargs,
        binary = binary,
        root = root,
    )

    pkg_tar_kwargs = dict(
        kwargs,
        # WARNING: Changing the strip_prefix tag might lead to unexpected behaviors.
        # See: https://github.com/bazelbuild/rules_pkg/issues?q=strip_prefix
        strip_prefix = kwargs.pop("strip_prefix", "."),
        build_tar = "%s.build_tar" % name,
        **common_kwargs
    )

    runfiles(
        name = "%s/app/runfiles" % name,
        exclude = "/node_modules/",
        **runfiles_kwargs
    )

    pkg_tar(
        name = "%s/app" % name,
        srcs = ["%s/app/runfiles" % name],
        **pkg_tar_kwargs
    )

    runfiles(
        name = "%s/node_modules/runfiles" % name,
        include = "/node_modules/",
        **runfiles_kwargs
    )

    pkg_tar(
        name = "%s/node_modules" % name,
        srcs = ["%s/node_modules/runfiles" % name],
        **pkg_tar_kwargs
    )

    native.filegroup(
        name = name,
        srcs = [
            "%s/node_modules" % name,
            "%s/app" % name,
        ],
        **common_kwargs
    )
