#!/usr/bin/env python3
"""Build the ad-hoc signed macOS beta installer application and ZIP."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def copy_executable(source: Path, destination: Path) -> None:
    shutil.copy2(source, destination)
    destination.chmod(0o755)


def build(output: Path, icon: Path | None) -> Path:
    output.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="spot64-macos-installer-") as temp:
        app = Path(temp) / "Installer Spot64 Beta.app"
        contents = app / "Contents"
        macos = contents / "MacOS"
        resources = contents / "Resources"
        macos.mkdir(parents=True)
        resources.mkdir(parents=True)

        shutil.copy2(ROOT / "installer/macos/Info.plist", contents / "Info.plist")
        copy_executable(
            ROOT / "installer/macos/launcher.sh",
            macos / "Installer Spot64 Beta",
        )
        copy_executable(
            ROOT / "scripts/install-spot64-beta-macos.sh",
            resources / "install-spot64-beta.command",
        )
        shutil.copy2(
            ROOT / "installer/macos/corpus-files.sha256",
            resources / "corpus-files.sha256",
        )
        if icon is not None:
            shutil.copy2(icon, resources / "icon.icns")

        subprocess.run(
            ["codesign", "--force", "--deep", "--sign", "-", os.fspath(app)],
            check=True,
        )
        subprocess.run(
            ["codesign", "--verify", "--deep", "--strict", os.fspath(app)],
            check=True,
        )
        subprocess.run(
            [
                "ditto",
                "-c",
                "-k",
                "--sequesterRsrc",
                "--keepParent",
                os.fspath(app),
                os.fspath(output),
            ],
            check=True,
        )

    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "dist/macos/Installer-Spot64-Beta-macOS-Apple-Silicon.zip",
    )
    parser.add_argument("--icon", type=Path)
    args = parser.parse_args()

    if args.icon is not None and not args.icon.is_file():
        parser.error(f"icon does not exist: {args.icon}")
    result = build(args.output.resolve(), args.icon)
    print(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
