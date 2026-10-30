#!/usr/bin/env python3
"""Check modules in their shared Bash context without executing the application."""
import json
import pathlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
for tool in ("bash", "shellcheck"):
    if not shutil.which(tool):
        sys.exit(f"{tool} is required; install it before running make lint")

entrypoint = root / "unleash"
source = entrypoint.read_text()
loader = re.search(r"^for _lib in ([a-z_ ]+); do\n.*?^done$", source, re.M | re.S)
if not loader:
    sys.exit("Cannot identify the module loader in unleash")
modules = [root / "lib" / (name + ".sh") for name in loader[1].split()]
if set(modules) != set((root / "lib").glob("*.sh")):
    sys.exit("The module loader and library files do not match")

# Literal sources let ShellCheck follow shared globals and report module locations.
# Keep the loader's line count so dispatcher diagnostics retain their real lines.
literal_sources = "; ".join("source " + shlex.quote(str(path)) for path in modules)
context = source[:loader.start()] + literal_sources
context += "\n" * loader[0].count("\n") + source[loader.end():]
examples = sorted((root / "examples").glob("*.sh"))
failed = False
for path in [entrypoint, *modules, *examples, root / "unleash-standalone.sh"]:
    result = subprocess.run(["bash", "-n", str(path)], check=False)
    failed |= result.returncode != 0

with tempfile.NamedTemporaryFile(mode="w", suffix=".sh") as temporary:
    temporary.write(context)
    temporary.flush()
    result = subprocess.run([
        "shellcheck", "--shell=bash", "--external-sources", "--check-sourced",
        "--format=json", temporary.name, *map(str, examples), str(root / "unleash-standalone.sh"),
    ], capture_output=True, text=True, check=False)
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="")
    failed |= result.returncode != 0
    findings = json.loads(result.stdout or "[]")
    seen = set()
    for finding in findings:
        path = finding["file"]
        if path == temporary.name:
            path = str(entrypoint)
        key = (path, finding["line"], finding["column"], finding["code"])
        if key in seen:
            continue
        seen.add(key)
        print(f"{path}:{finding['line']}:{finding['column']}: "
              f"{finding['level']} SC{finding['code']}: {finding['message']}")
sys.exit(1 if failed else 0)
