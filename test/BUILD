load("@io_bazel_rules_terraform//terraform:terraform.bzl", "terraform_plan", "terraform_version")

terraform_plan(
    name = "test",
    srcs = glob(["**/*.tf"])
)


terraform_version(name="version")
