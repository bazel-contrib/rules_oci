"Analysis tests for the .bat wrappers created when the exec platform is Windows"

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _bat_outputs(env):
    return sorted([
        out.short_path
        for action in analysistest.target_actions(env)
        for out in action.outputs.to_list()
        if out.extension == "bat"
    ])

def _windows_wrappers_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.equals(env, ctx.attr.expected_wrappers, _bat_outputs(env))
    return analysistest.end(env)

windows_wrappers_test = analysistest.make(
    _windows_wrappers_test_impl,
    attrs = {
        "expected_wrappers": attr.string_list(),
    },
    config_settings = {
        "//command_line_option:extra_execution_platforms": str(Label("//oci/tests:windows_exec")),
    },
)
