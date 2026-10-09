---
name: terraform-test-authoring
description: Write or update `terraform test` files for a module with a mocked provider and assertions that fail when the behavior breaks, run them, and fix them. Use for every module that change-impact-analysis marks `add` or `update`.
---

# Terraform test authoring

## When to use

For a module marked `add` or `update`. It works for any module in `modules/<name>/` with the standard files (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`).

## Context needed

The module's four files, its existing tests (if any), and the test file of a sibling module as a style example (for example `modules/network/tests/main.tftest.hcl`).

## Steps

1. Read the module. List its resources, variables with validation, defaults, `for_each` expressions and outputs.
2. Create or edit `modules/<name>/tests/main.tftest.hcl`. Keep the layout the existing tests use:
   - `mock_provider "azurerm" {}` at the top.
   - One `variables {}` block with the smallest valid input.
   - `command = plan` for every run.
3. Write runs that each check one behavior. Cover, where the module has them:
   - **Defaults that matter**: secure settings, identity, TLS, tags.
   - **Counts**: one resource per key of a `for_each` input.
   - **Names**: naming rules.
   - **Outputs**: values the stack depends on.
   - **Validation**: a run with `expect_failures = [var.<name>]` for each `validation` block.
4. Every assertion must fail if the behavior breaks. Never write `condition = true`, or an assertion that repeats the value the test just set.
5. A mock can return a value that breaks a plan (a fake ID in the wrong format, or a data source that needs the network). Add `override_data` or `override_resource` for that object and keep the assertion. If the module has an `external` data source or a provisioner, override it so the test does not run the module's script.
6. A weak or unsafe default (public network access on, broad roles, relaxed FTPS) is a finding, not a test. Do not assert the weak value as if it were wanted, and do not assert a secure value the module does not provide. Leave that assertion out and record a finding with the `risk-findings` skill.

## Verify

Run `bash scripts/ci/run_module_tests.sh <module>...` for the modules you touched. It checks formatting and runs `terraform test`. A test file with no runs counts as failed.

If it fails:

1. Read the output and fix the test, not the module.
2. Run it again.
3. Stop after 3 attempts per module. Keep the last version, and report in the final comment which check still fails and why.

Format as `terraform fmt` does: two spaces, aligned `=` in blocks.

## Output

Test files only, committed on the pull request's branch. Do not change module code.
