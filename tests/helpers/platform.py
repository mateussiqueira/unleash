#!/usr/bin/env python3
"""Inert macOS command fixtures; mutable plist operations stay in the suite root."""
import json
import os
import pathlib
import plistlib
import shlex
import subprocess
import sys

name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
root = pathlib.Path(os.environ["UNLEASH_TEST_ROOT"]).resolve()
with (root / "platform-calls.jsonl").open("a") as log:
    log.write(json.dumps([name, *args]) + "\n")

def fixture_path(value):
    path = pathlib.Path(value).resolve()
    active_test = pathlib.Path(os.environ["BATS_TEST_TMPDIR"]).resolve()
    if not (path.is_relative_to(root) or path.is_relative_to(active_test)):
        sys.exit(f"Fixture refused path outside the suite: {path}")
    return path

if name == "sudo":
    if len(args) >= 2 and ((args[0] == "profiles" and args[1] in ("-C", "status"))
                 or (args[0] == "security" and args[1] == "find-identity")):
        sys.exit(subprocess.call([str(pathlib.Path(sys.argv[0]).with_name(args[0])), *args[1:]]))
elif name == "profiles":
    if args[:1] == ["-C"]:
        sys.stdout.buffer.write(plistlib.dumps([]))
        sys.exit(0)
    if args[:1] == ["status"]:
        print("MDM enrollment: No")
        sys.exit(0)
elif name == "security" and args[:1] == ["find-identity"]:
    sys.exit(0)
elif name == "plutil" and args[:4] == ["-convert", "xml1", "-o", "-"]:
    sys.stdout.buffer.write(plistlib.dumps(plistlib.loads(fixture_path(args[-1]).read_bytes())))
    sys.exit(0)
elif name == "PlistBuddy":
    path = fixture_path(args[-1])
    data = plistlib.loads(path.read_bytes())
    command = shlex.split(args[1])
    action = command[0]
    key = command[1].lstrip(":") if len(command) > 1 else None
    if action == "Print":
        if key:
            print(str(data[key]).lower())
        else:
            sys.stdout.buffer.write(plistlib.dumps(data))
        sys.exit(0)
    if action == "Add" and key in data:
        sys.exit(1)
    if action == "Set" and key not in data:
        sys.exit(1)
    if action in ("Add", "Set"):
        data[key] = command[-1] == "true"
    elif action == "Delete":
        data.pop(key, None)
    else:
        sys.exit(97)
    path.write_bytes(plistlib.dumps(data))
    sys.exit(0)
elif name == "launchctl" and args[:1] in (["load"], ["unload"]):
    fixture_path(args[-1])
    sys.exit(0)
elif name == "host" and args[:2] == ["-t", "a"]:
    print(f"{args[2]} has address 203.0.113.10")
    sys.exit(0)
elif name == "dscl":
    fixture_path(args[1])
    sys.exit(1)
elif name in ("diskutil", "pgrep", "pkill", "curl", "pfctl", "host"):
    sys.exit(1)

print(f"Blocked platform operation in test: {name} {' '.join(args)}", file=sys.stderr)
sys.exit(97)
