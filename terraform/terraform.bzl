
toolchains = {
    "darwin_amd64": {
        "os": "darwin",
        "arch": "amd64",
        "sha": "893050bcfc5e7445acd3a30f1500227b989b29cbd958ca64a8233589194a198d",
        "exec_compatible_with": [
            "@platforms//os:osx",
            "@platforms//cpu:x86_64",
        ],
        "target_compatible_with": [
            "@platforms//os:osx",
            "@platforms//cpu:x86_64",
        ],
    },
    "linux_i386": {
        "os": "linux",
        "arch": "386",
        "sha": "1c489282d86b16f2d5f89f38071c6dabd948a4ca7cc4e42915e604b82564f3a6",
        "exec_compatible_with": [
            "@platforms//os:linux",
            "@platforms//cpu:i386",
        ],
        "target_compatible_with": [
            "@platforms//os:linux",
            "@platforms//cpu:i386",
        ],
    },
    "linux_amd64": {
        "os": "linux",
        "arch": "amd64",
        "sha": "be99da1439a60942b8d23f63eba1ea05ff42160744116e84f46fc24f1a8011b6",
        "exec_compatible_with": [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
        "target_compatible_with": [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
    },
    "windows_amd64": {
        "os": "windows",
        "arch": "amd64",
        "sha": "cd524b5b6b7cd9eec9c4e49aa37cbcb34ed1395876c212f6dde84c6e57d6ce1c",
        "exec_compatible_with": [
            "@platforms//os:windows",
            "@platforms//cpu:x86_64",
        ],
        "target_compatible_with": [
            "@platforms//os:windows",
            "@platforms//cpu:x86_64",
        ],
    },
}

url_template = "https://releases.hashicorp.com/terraform/{version}/terraform_{version}_{os}_{arch}.zip"

TerraformInfo = provider(
    doc = "Information about how to invoke Terraform.",
    fields = ["sha", "url"],
)

def _terraform_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        barcinfo = TerraformInfo(
            sha = ctx.attr.sha,
            url = ctx.attr.url,
        ),
    )
    return [toolchain_info]

terraform_toolchain = rule(
    implementation = _terraform_toolchain_impl,
    attrs = {
        "sha": attr.string(),
        "url": attr.string(),
    },
)
def _format_url(version, os, arch):
    return url_template.format(version = version, os = os, arch = arch)


def declare_terraform_toolchains(version = "0.12.28"):
    for key, info in toolchains.items():
        url =_format_url(version, info["os"], info["arch"])
        name = "terraform_{}".format(key)
        toolchain_name = "{}_toolchain".format(name)

        terraform_toolchain(
            name = name,
            url = url,
            sha = info["sha"],
        )
        native.toolchain(
            name = toolchain_name,
            exec_compatible_with = info["exec_compatible_with"],
            target_compatible_with = info["target_compatible_with"],
            toolchain = name,
            toolchain_type = "@io_bazel_rules_terraform//:toolchain_type",
        )

def _detect_platform_arch(ctx):
    if ctx.os.name == "linux":
        platform = "linux"
        res = ctx.execute(["uname", "-m"])
        if res.return_code == 0:
            uname = res.stdout.strip()
            if uname not in ["x86_64", "i386"]:
                fail("Unable to determing processor architecture.")

            arch = "amd64" if uname == "x86_64" else "i386"
        else:
            fail("Unable to determing processor architecture.")
    elif ctx.os.name == "mac os x":
        platform, arch = "darwin", "amd64"
    elif ctx.os.name.startswith("windows"):
        platform, arch = "windows", "amd64"
    else:
        fail("Unsupported operating system: " + ctx.os.name)

    return platform, arch

def _terraform_build_file(ctx, platform, version):
    ctx.file("ROOT")
    ctx.template(
        "BUILD.bazel",
        Label("@io_bazel_rules_terraform//terraform:BUILD.terraform.bazel"),
        executable = False,
        substitutions = {
            "{name}": "terraform_executable",
            "{exe}": ".exe" if platform == "windows" else "",
            "{version}": version
        },
    )

def _remote_terraform(ctx, url, sha):
    ctx.download_and_extract(
        url = url,
        sha256 = sha,
        type = "zip",
        output = "terraform"
    )

def _terraform_register_toolchains_impl(ctx):
    platform, arch = _detect_platform_arch(ctx)
    version = ctx.attr.version
    _terraform_build_file(ctx, platform, version)

    host = "{}_{}".format(platform, arch)
    info = toolchains[host]
    url = _format_url(version, info["os"], info["arch"])
    _remote_terraform(ctx, url, info["sha"])

_terraform_register_toolchains = repository_rule(
    _terraform_register_toolchains_impl,
    attrs = {
        "version": attr.string(),
    },
)

def terraform_register_toolchains(version = None):
    _terraform_register_toolchains(
        name = "register_terraform_toolchains",
        version = version,
    )

def _terraform_plan(ctx):
    deps = depset(ctx.files.srcs)
    ctx.actions.run(
        executable = ctx.executable._exec,
        inputs = deps.to_list(),
        outputs = [ctx.outputs.out],
        mnemonic = "TerraformInitialize",
        arguments = [
            "plan",
            "-out={0}".format(ctx.outputs.out.path),
            deps.to_list()[0].dirname,
        ],
    )

terraform_plan = rule(
    implementation = _terraform_plan,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = True,
        ),
        "_exec": attr.label(
            default = Label("@register_terraform_toolchains//:terraform_executable"),
            allow_files = True,
            executable = True,
            cfg = "host",
        ),
    },
    outputs = {"out": "%{name}.out"},
)

def _terraform_version(ctx):
    output = ctx.actions.declare_file("version.out")
    ctx.actions.run(
            executable = ctx.executable._exec,
            arguments = [
                    "version",
                    ],
            outputs = [output],
            )

terraform_version = rule(
        implementation = _terraform_version,
        attrs = {
                 "_exec": attr.label(
            default = Label("@register_terraform_toolchains//:terraform_executable"),
            allow_files = True,
            executable = True,
            cfg = "host"),
        },
 )
