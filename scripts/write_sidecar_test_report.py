#!/usr/bin/env python3
"""Write evidence after the native Store sidecar suite has passed."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


TESTS = [
    "startup_and_health",
    "graceful_terminate",
    "parent_watchdog",
    "occupied_port",
    "repeated_start_stop",
    "real_endpoints_against_packaged_binary",
    "fixture_not_locked_after_forced_kill",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sidecar", type=Path, required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.sidecar.is_symlink() or not args.sidecar.is_file():
        parser.error("--sidecar must be a regular file")
    report = {
        "schema_version": 1,
        "platform_triple": args.target,
        "sidecar_basename": args.sidecar.name,
        "sidecar_sha256": sha256(args.sidecar),
        "suite": "tests/test_sidecar_store_qualification.py",
        "runtime_profile": "native",
        "tests_run": TESTS,
        "status": "pass",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
