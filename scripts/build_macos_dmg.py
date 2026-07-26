#!/usr/bin/env python3
"""Build and verify the ad-hoc signed Spot64 macOS application DMG."""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run(*arguments: str) -> None:
    subprocess.run(arguments, check=True)


def build(source_app: Path, output: Path) -> tuple[Path, str]:
    if not source_app.is_dir() or source_app.is_symlink():
        raise ValueError(f"application bundle is not a plain directory: {source_app}")
    if source_app.name != "Libase.app":
        raise ValueError(f"expected Libase.app, got: {source_app.name}")

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="spot64-macos-dmg-") as temporary:
        root = Path(temporary)
        image_root = root / "image"
        staged_app = image_root / "Libase.app"
        mount_point = root / "mount"
        temporary_dmg = root / "Spot64.dmg"
        image_root.mkdir()
        mount_point.mkdir()

        run("ditto", os.fspath(source_app), os.fspath(staged_app))
        (image_root / "Applications").symlink_to("/Applications")
        run("codesign", "--force", "--deep", "--sign", "-", os.fspath(staged_app))
        run("codesign", "--verify", "--deep", "--strict", os.fspath(staged_app))
        run(
            "hdiutil",
            "create",
            "-volname",
            "Spot64 Beta",
            "-srcfolder",
            os.fspath(image_root),
            "-format",
            "UDZO",
            "-ov",
            os.fspath(temporary_dmg),
        )

        mounted = False
        try:
            run(
                "hdiutil",
                "attach",
                os.fspath(temporary_dmg),
                "-nobrowse",
                "-readonly",
                "-mountpoint",
                os.fspath(mount_point),
                "-quiet",
            )
            mounted = True
            mounted_app = mount_point / "Libase.app"
            if not mounted_app.is_dir():
                raise RuntimeError("Libase.app is absent from the finished DMG")
            run(
                "codesign",
                "--verify",
                "--deep",
                "--strict",
                os.fspath(mounted_app),
            )
        finally:
            if mounted:
                run("hdiutil", "detach", os.fspath(mount_point), "-quiet")

        shutil.move(temporary_dmg, output)

    return output, sha256(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    result, digest = build(args.app.resolve(), args.output.resolve())
    print(f"{digest}  {result}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
