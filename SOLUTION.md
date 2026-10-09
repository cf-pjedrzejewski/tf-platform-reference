# Solution

A GitHub Agentic Workflow (gh-aw) that adds or updates `terraform test` files for the Terraform modules a pull request changes, runs them, and reports risky module code for a person to decide.

## How it works

```text
pull_request (modules/** or stacks/**)
  -> steps        install the pinned Terraform, build the change context
  -> agent job    GitHub Copilot as terraform-test-agent, in a firewalled sandbox, read-only token
  -> detection    gh-aw checks the agent's output for secret leaks and malicious patches
  -> safe_outputs push the test files to the pull request branch, post one comment
```

The agent works only inside the pull request that started it. It opens no other pull request.

## Where things are

| What | Where |
| --- | --- |
| Workflow source and prompt | `.github/workflows/terraform-test-agent.md` |
| Compiled workflow (generated, do not edit) | `.github/workflows/terraform-test-agent.lock.yml` |
| Custom agent: purpose, limits, skills it uses | `.github/agents/terraform-test-agent.agent.md` |
| Skills | `.github/skills/change-impact-analysis/`, `terraform-test-authoring/`, `risk-findings/` |
| Scripts | `scripts/ci/build_context.py`, `scripts/ci/run_module_tests.sh` (installed as `run-module-tests`) |

The workflow names the agent with `engine.agent`, so gh-aw loads the definition. The definition tells the agent which skill file to read at each step. Paths and commands specific to this repository live in the skills and scripts, not in the workflow.

## Prerequisites

- GitHub Actions enabled for the repository.
- A repository secret `COPILOT_GITHUB_TOKEN`: a fine-grained personal access token from an account with an active GitHub Copilot license, with "Copilot Requests: Read". In an organization with centralized Copilot billing, `permissions: copilot-requests: write` can replace it.
- The `gh aw` extension to change the workflow: after editing the `.md` file, run `gh aw compile` and commit the `.lock.yml`.

## Main decisions

**gh-aw instead of a hand-built workflow.** It gives the separation I would otherwise have to build: the agent job has a read-only token, and anything it wants to write goes through a validated, permission-scoped job. The agent runs in a sandbox that only reaches allowed domains, and model traffic goes through an API proxy that gh-aw sets up. Trade-off: the workflow is a compiled artifact (a `.md` source and a generated lock file), and the platform is a technical preview whose syntax can change.

**The agent runs the tests itself.** Because the sandbox has no secrets and a limited network (`defaults`, `github`, `terraform`), the agent can run `terraform test` and fix its own tests in a real loop. The only command it may run for tests is `run-module-tests <module>` (the workflow installs `scripts/ci/run_module_tests.sh` under that name), plus read-only commands. It cannot run `apply`, `destroy` or `az`.

**Writes are narrow.** The agent can push only files matching `modules/*/tests/*.tftest.hcl`, enforced by `allowed-files` in the safe output job, not by the agent's own discipline. The platform checks the whole pull request branch, not only the agent's commit, so the pull request's own changes (module code, docs, scripts) would be refused. `excluded-files` removes those file types from that check, which also means the agent can never push module code. gh-aw also refuses changes to protected files such as `.github/` and agent instruction files.

**Risky module code is reported, not fixed.** A fixed scan (`build_context.py`) flags plan-time execution, public network defaults, relaxed FTPS and broad roles. The agent adds its own judgement, gives each finding a reason and a recommended change, and never edits module code. A test that would fail because of a weak default is left out, and the finding says which assertion is missing.

**Plan-time code is overridden in tests.** For a module with an `external` data source, the test uses `override_data` so the script does not run during `terraform test`.

**Two modes, one workflow.** Normally the agent writes tests only for behavior a pull request changes, and skips README-only or formatting changes with a reported reason. To cover existing untested modules, a maintainer adds the `backfill-tests` label to a pull request. The label is read into the context by `build_context.py`, and `change-impact-analysis` then treats every touched module without tests as `add`, even for a README-only change. Adding any other label does not start a run. This keeps backfill inside a pull request, so it uses the same checks, the same file allowlist and the same comment.

**Model, turns and time.** The model is set in the workflow (`haiku`, a gh-aw alias for the Claude Haiku models served through Copilot), with at most 80 agent turns, 3 fix attempts per module (in the agent's instructions) and a 20 minute limit for the agent step. A tests-writing task is structured and bounded, and the agent gets clear skills and a runner that checks its work, so a small, cheap model is enough. A larger model such as `sonnet` would be the first change if the tests turn out too shallow. Pull requests that change nothing under `modules/` or `stacks/` do not start the workflow.

## Security measures

- The agent job has `contents: read` and `pull-requests: read` only. Writes happen in `safe_outputs`.
- Fork pull requests do not run the workflow (a compiled condition checks the head repository). A contributor from a fork gets no agent run.
- The workflow does not use `pull_request_target`.
- The agent's network is limited to `defaults`, `github` and `terraform` domains.
- The third-party action (`hashicorp/setup-terraform`) is pinned to a full commit SHA, and gh-aw pins the actions it adds.
- Pull request content is data for the agent (the prompt and the agent definition say so). The prompt contains no pull request title, description or comment text.
- gh-aw sanitizes the agent's comment (mentions, HTML, links) before posting.

## Reliability

- One comment per pull request: `hide-older-comments` hides the previous comment from the same workflow, so only the latest report is visible.
- `concurrency` cancels an older run when a new commit arrives.
- If the agent or the model call fails, the run fails, and gh-aw reports the failure in an issue. If tests still fail after 3 attempts, the comment says which checks fail.
- Pushes made with the workflow token do not start other workflows, so the agent does not trigger itself.

## What the tests can and cannot show

The tests use `mock_provider "azurerm"`. They check what a module's plan contains: defaults, counts, names, outputs, validation. They do not show how a provider behaves, whether Azure accepts the settings, Azure Policy results, or how a change interacts with an existing environment. Real behavior needs a plan or deployment against a subscription.

## Assumptions

- People who can push branches to this repository are trusted. The agent checks out their code and the module tests execute it inside the sandbox (for example the `external` script in `function-app`) unless a test overrides it.
- Modules live in `modules/<name>/` and tests in `modules/<name>/tests/`.

## Limitations

- Stacks have no tests. A change in a stack is analysed and reported, but no tests are written for it.
- The risk scan uses patterns. It finds the common cases, not every unsafe default.
- A fork contributor gets no agent run.
- A pull request that changes file types other than `.tf`, `.tfvars`, `.md`, `.sh`, `stacks/`, `scripts/` and `.github/` would still be refused by the push check. Add the types to `excluded-files` as needed.
- The fix limit and the comment format are instructions to the model, not enforced by the platform. The turn cap and the file allowlist are enforced.
- gh-aw is in technical preview. Some behavior, for example how the agent checks out the pull request branch before pushing, should be confirmed on a first run.

## With many more modules, teams or repositories

- Move the workflow to a shared reusable workflow in one place, so each repository only calls it.
- Run the agent per module in a matrix so large pull requests finish faster, and cache provider downloads.
- Keep the scripts and the agent definition in one versioned repository, not copied.
- Use organization billing for Copilot requests and set budgets per repository.
- Add policy checks (for example `tflint` or `checkov`) as fixed steps next to the agent, so common findings do not depend on the model.

## For a production version

- A separate, trusted pipeline that runs a real `terraform plan` against a subscription, with short-lived federated credentials, and never on untrusted pull requests.
- Tests for the stacks, for example plan checks of the combined configuration.
- Metrics on cost and success rate per run, and a review of the agent's findings that people rejected.

## Example run

See pull request #1: https://github.com/cf-pjedrzejewski/tf-platform-reference/pull/1

The tests the agent pushed are in the pull request's changed files (`modules/*/tests/main.tftest.hcl`).

The agent ran in both modes on this pull request, which added READMEs to five modules and a `versioning_enabled` option to `storage-account`:

1. **Changed code.** With `change-impact-analysis` it skipped the five README-only modules with a reason each and marked `storage-account` as `update`. With `terraform-test-authoring` it added a run for the new option, ran `run-module-tests storage-account` (4 runs passed) and pushed the test to the pull request branch. With `risk-findings` it posted seven findings about risky module code for a person to decide. It did not change any module code.
2. **Backfill.** After the `backfill-tests` label was added, `change-impact-analysis` marked the five untested modules as `add`. For each module, one at a time, `terraform-test-authoring` wrote `tests/main.tftest.hcl` with `mock_provider "azurerm"`, ran `run-module-tests <module>`, fixed what failed (for example an assertion that compared a list to a set) and moved on. For `function-app` it used `override_data` so the module's `external` data source (`build-info.sh`) does not run during the test. Weak defaults it found were reported with `risk-findings` and left out of the assertions.

Each comment lists the decisions, the result per module with the cases it covers, and the findings.
