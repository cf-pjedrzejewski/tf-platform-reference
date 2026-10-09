#!/usr/bin/env bash
# Checks formatting and runs `terraform test` for one module.
# Usage: run_module_tests.sh MODULE
# Prints a short result. Exits 1 if a check fails, or if the module has a test file with no runs.
set -uo pipefail

# Several modules in one call overloaded the agent sandbox proxy, so the model calls that followed failed.
if [ "$#" -ne 1 ]; then
  echo "Run one module per call: run-module-tests <module>. Run it again for the next module."
  exit 2
fi

status=0

# The agent sandbox proxy drops registry traffic; use providers prefetched by the workflow when present.
mirror="${TF_PROVIDER_MIRROR:-/tmp/gh-aw/tf-mirror}"
if [ -d "$mirror" ]; then
  cli_config=$(mktemp)
  printf 'provider_installation {\n  filesystem_mirror {\n    path = "%s"\n  }\n}\n' "$mirror" > "$cli_config"
  export TF_CLI_CONFIG_FILE="$cli_config"
fi

for name in "$@"; do
  dir="modules/$name"
  if [ ! -d "$dir" ]; then
    echo "$name: no such module"
    status=1
    continue
  fi

  if ! fmt=$(terraform fmt -check -recursive -no-color "$dir" 2>&1); then
    echo "$name: FORMAT: run terraform fmt on these files:"
    echo "$fmt"
    status=1
  fi

  if ! compgen -G "$dir/tests/*.tftest.hcl" > /dev/null; then
    echo "$name: no tests"
    continue
  fi

  log=$(mktemp)
  if (cd "$dir" && terraform init -backend=false -input=false -no-color > "$log" 2>&1 \
        && timeout 600 terraform test -no-color >> "$log" 2>&1) \
      && grep -Eq 'Success! [1-9][0-9]* passed' "$log"; then
    echo "$name: passed"
    tail -n 3 "$log"
  else
    echo "$name: FAILED (a test file with no runs also counts as failed)"
    tail -n 60 "$log"
    status=1
  fi
  rm -f "$log"
done

exit $status
