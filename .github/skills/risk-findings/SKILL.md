---
name: risk-findings
description: Report unsafe or surprising Terraform module code to the pull request reviewer, with a recommended change, without changing the module. Use for every hit in the risk scan and for anything else that looks unsafe.
---

# Risk findings

## When to use

After writing tests. It works for any module repository.

## Context needed

The `risks` list in `/tmp/gh-aw/context/context.json` (a fixed scan: plan-time execution, public network defaults, relaxed FTPS, broad roles) and the module code itself.

## Steps

1. For each risk hit, open the file and decide whether it is a real risk in context. A hit can be intended. If it is, say why in the finding and lower its severity.
2. Look beyond the scan: wide network rules, disabled encryption or TLS, shared keys, secrets in variables, missing purge protection.
3. For each real finding, write why it matters in one or two sentences and recommend a concrete change, as text.
4. Never edit module code. The recommendation is for a person to apply or reject.
5. A finding that blocks a test (you left an assertion out) says which assertion.
6. Code that runs during plan (an `external` data source, `local-exec`) is always a finding. Say that running `terraform plan` or `terraform test` executes it, and that the test overrides it.

## Verify

Every risk hit in the scan is either a finding or listed as `accepted` with a reason. No finding changes any file.

## Output

Keep the findings for the final comment, one bullet each:

`- **<severity>: <title>** (`<file>`). <why> Suggested change: <recommendation>`

`severity` is `high`, `medium` or `low`. If there are no findings, say so.
