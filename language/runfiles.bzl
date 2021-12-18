load("@rules_pkg//:providers.bzl", "PackageFilesInfo", "PackageSymlinkInfo", "PackageFilegroupInfo")


def _runfile_path(ctx, file, runfiles_dir):
    path = file.short_path
    if path.startswith(".."):
        return path.replace("..", runfiles_dir)
    if not file.owner.workspace_name:
        return "/".join([runfiles_dir, ctx.workspace_name, path])
    return path

def _runfiles_impl(ctx):

    default = ctx.attr.binary[DefaultInfo]

    executable = default.files_to_run.executable
    manifest = default.files_to_run.runfiles_manifest
    runfiles_dir = manifest.short_path.replace(manifest.basename, "")[:-1]

    files = depset(transitive = [default.files, default.default_runfiles.files])
    fileMap = { 
       executable.short_path: executable
    }


    for file in files.to_list(): 
       fileMap[_runfile_path(ctx, file, runfiles_dir)] = file


    files = depset([executable], transitive = [files])

    symlinks = []
    for symlink in default.data_runfiles.root_symlinks.to_list():
        info = PackageSymlinkInfo(
            source = "/%s" % _runfile_path(ctx, symlink.target_file, runfiles_dir), 
            destination = "/%s" % "/".join([runfiles_dir, symlink.path]),
            attributes = { "mode": "0777" }
        )  
        symlinks.append([info, ctx.label])

    return [
        PackageFilegroupInfo(
            pkg_dirs = [],
            pkg_files = [
                [PackageFilesInfo(
                    dest_src_map = fileMap,
                    attributes = {},
                ), ctx.label]
            ],
            pkg_symlinks = symlinks,
        ),
        DefaultInfo(files = files),
    ]

expand_runfiles = rule(
    implementation = _runfiles_impl,
    attrs = {
        "binary": attr.label()
    }
)