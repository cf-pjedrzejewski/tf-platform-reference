---
name: change-impact-analysis
description: Decide which Terraform modules a pull request affects and whether each one needs tests. Use at the start of every run, before writing any test.
---

# Change impact analysis

## When to use

At the start of a run, with `/tmp/gh-aw/context/context.json` available. It works for any repository that keeps modules in `modules/<name>/` and tests in `modules/<name>/tests/`.

## Context needed

`context.json`, and `diff.patch` for details.

## Steps

1. List the affected modules from `context.json`. Ignore anything outside `modules/`: stacks have no tests here.
2. For each module, classify the change:
   - **Interface**: `interface_changed` is true (variables or outputs changed). Existing tests and the stacks listed in `consumers` may break. Read each consumer's use of the module.
   - **Behavior**: resource arguments, defaults or validation changed. Tests must cover the new behavior.
   - **No behavior**: comments, descriptions, formatting, README. No tests needed.
3. Decide: `add` (the module has no tests), `update` (it has tests that the change affects), or `skip` (no behavior change, or the tests already cover it). Write a one-sentence reason for each.
4. Never write tests for a module the pull request did not touch.
5. **Backfill.** When `labels` in `context.json` contains `backfill-tests`, a maintainer wants coverage for existing code. Every affected module without tests is `add`, whatever kind of change it is (even README only). Say so in the reason. A module that already has tests follows the normal rules.

## Verify

Every affected module has exactly one decision with a reason. A `skip` names what makes it safe to skip.

## Output

Keep the decisions for the final comment: one row per module with the action and the reason.
