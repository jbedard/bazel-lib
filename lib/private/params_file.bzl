"params_file rule"

load("//lib/private:expand_make_vars.bzl", "expand_locations")

_ATTRS = {
    "args": attr.string_list(),
    "data": attr.label_list(allow_files = True),
    "is_windows": attr.bool(mandatory = True),
    "newline": attr.string(
        values = ["unix", "windows", "auto"],
        default = "auto",
    ),
    "out": attr.output(mandatory = True),
}

def _expand_locations(ctx, s):
    # `.split(" ")` is a work-around https://github.com/bazelbuild/bazel/issues/10309
    # TODO: If the string has intentional spaces or if one or more of the expanded file
    # locations has a space in the name, we will incorrectly split it into multiple arguments
    return expand_locations(ctx, s, targets = ctx.attr.data).split(" ")

def _impl(ctx):
    if ctx.attr.newline == "auto":
        newline = "\r\n" if ctx.attr.is_windows else "\n"
    elif ctx.attr.newline == "windows":
        newline = "\r\n"
    else:
        newline = "\n"

    expanded_args = []

    # First expand predefined source/output path variables
    for a in ctx.attr.args:
        expanded_args += _expand_locations(ctx, a)

    # Next expand predefined variables & custom variables
    expanded_args = [ctx.expand_make_variables("args", e, {}) for e in expanded_args]

    # ctx.actions.write creates a FileWriteAction which uses UTF-8 encoding.
    ctx.actions.write(
        output = ctx.outputs.out,
        content = newline.join(expanded_args),
        is_executable = False,
    )
    files = depset(direct = [ctx.outputs.out])
    runfiles = ctx.runfiles(files = [ctx.outputs.out])
    return [DefaultInfo(files = files, runfiles = runfiles)]

params_file = rule(
    implementation = _impl,
    provides = [DefaultInfo],
    attrs = _ATTRS,
)
