#!/usr/bin/env python3
"""Build the context the agent reads: changed files, affected modules and risk hits.

Usage: build_context.py BASE_SHA HEAD_SHA OUT_DIR
Writes OUT_DIR/context.json and OUT_DIR/diff.patch. Prints needs_agent=true|false.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

MAX_DIFF_BYTES = 200_000

RISK_PATTERNS = [
    ("plan-time-execution", "high", re.compile(r'data\s+"external"|local-exec|remote-exec|provisioner\s+"')),
    ("relaxed-ftps", "medium", re.compile(r'ftps_state\s*=\s*"AllAllowed"')),
    ("broad-role", "medium", re.compile(r'role_definition_name\s*=\s*"(Owner|Contributor|User Access Administrator|Storage Blob Data Owner)"')),
]
PUBLIC_DEFAULT = re.compile(r'variable\s+"([^"]*public[^"]*)"\s*\{[^}]*?default\s*=\s*true', re.S)


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def module_of(path):
    parts = Path(path).parts
    return parts[1] if len(parts) > 2 and parts[0] == "modules" else None


def scan_module(name):
    hits = []
    for tf in sorted(Path("modules", name).glob("*.tf")):
        text = tf.read_text(encoding="utf-8")
        for rule, severity, pattern in RISK_PATTERNS:
            for match in pattern.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                hits.append({"module": name, "file": tf.as_posix(), "line": line, "rule": rule, "severity": severity})
        for match in PUBLIC_DEFAULT.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            hits.append({"module": name, "file": tf.as_posix(), "line": line, "rule": "public-network-default", "severity": "medium"})
    return hits


def consumers_of(name):
    pattern = re.compile(r'source\s*=\s*"\.\./\.\./modules/' + re.escape(name) + r'"')
    found = set()
    for tf in Path("stacks").rglob("*.tf"):
        if pattern.search(tf.read_text(encoding="utf-8")):
            found.add(tf.parent.as_posix())
    return sorted(found)


def main(base, head, out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    changed = [p for p in git("diff", "--name-only", f"{base}...{head}").splitlines() if p]
    names = sorted({m for m in map(module_of, changed) if m})
    interface_files = {"variables.tf", "outputs.tf"}

    modules = []
    risks = []
    for name in names:
        files = [p for p in changed if module_of(p) == name]
        modules.append({
            "name": name,
            "changed_files": files,
            "has_tests": any(Path("modules", name, "tests").glob("*.tftest.hcl")),
            "interface_changed": any(Path(p).name in interface_files for p in files),
            "consumers": consumers_of(name),
        })
        risks.extend(scan_module(name))

    context = {
        "base": base,
        "head": head,
        "changed_files": changed,
        "modules": modules,
        "stack_changes": sorted({p for p in changed if p.startswith("stacks/")}),
        "risks": risks,
    }
    (out / "context.json").write_text(json.dumps(context, indent=2) + "\n", encoding="utf-8")

    diff = git("diff", f"{base}...{head}", "--", "modules", "stacks")
    (out / "diff.patch").write_text(diff.encode()[:MAX_DIFF_BYTES].decode(errors="ignore"), encoding="utf-8")

    print(f"needs_agent={'true' if modules else 'false'}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: build_context.py BASE_SHA HEAD_SHA OUT_DIR")
    main(*sys.argv[1:])
