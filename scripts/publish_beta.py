#!/usr/bin/env python3
"""Validate Windows and corpus artifacts, then publish one atomic draft release."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

from verify_corpus_packages import verify as verify_corpus


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_windows(root: Path, tag: str) -> list[Path]:
    installers = list(root.glob("Libase-x86_64-pc-windows-msvc*.exe"))
    if len(installers) != 1:
        raise ValueError("the Windows artifact must contain exactly one NSIS installer")
    refs = json.loads((root / "source-refs.json").read_text(encoding="utf-8"))
    if refs.get("intended_release_tag") != tag or refs.get("unsigned") is not True:
        raise ValueError("source-refs.json does not match this unsigned prerelease")
    evidence = json.loads((root / "evidence-verify.json").read_text(encoding="utf-8"))
    if evidence.get("ok") is not True or evidence.get("release_evidence_complete") is not True:
        raise ValueError("Desktop strict release evidence is incomplete")

    sums: dict[str, str] = {}
    for line in (root / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines():
        digest, separator, name = line.partition("  ")
        if not separator or name in sums or Path(name).name != name:
            raise ValueError("malformed SHA256SUMS.txt")
        sums[name] = digest
    expected_names = {path.name for path in root.iterdir() if path.is_file()} - {"SHA256SUMS.txt"}
    if set(sums) != expected_names:
        raise ValueError("SHA256SUMS.txt inventory does not match Windows artifacts")
    for name, expected in sums.items():
        if sha256(root / name) != expected:
            raise ValueError(f"Windows artifact checksum mismatch: {name}")
    return sorted(path for path in root.iterdir() if path.is_file())


def validate_corpus(root: Path) -> list[Path]:
    manifest = root / "spot64-corpus-manifest.json"
    result = verify_corpus(root, manifest)
    if result.get("ok") is not True:
        raise ValueError("corpus verification did not pass")
    declared = {item["asset"] for item in json.loads(manifest.read_text())["volumes"]}
    assets = {path.name for path in root.iterdir() if path.is_file()}
    if assets != declared | {manifest.name}:
        raise ValueError("corpus directory contains undeclared release assets")
    return sorted(path for path in root.iterdir() if path.is_file())


def run(command: list[str]) -> str:
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return result.stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--windows", type=Path, required=True)
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--repository", default="erodataM/spot64-releases")
    args = parser.parse_args()

    windows_root = args.windows.resolve()
    corpus_root = args.corpus.resolve()
    windows = validate_windows(windows_root, args.tag)
    corpus = validate_corpus(corpus_root)
    if run(["gh", "release", "list", "--repo", args.repository, "--json", "tagName", "--jq", ".[].tagName"]).splitlines().count(args.tag):
        parser.error(f"release already exists: {args.tag}")

    manifest = json.loads((corpus_root / "spot64-corpus-manifest.json").read_text())
    with tempfile.TemporaryDirectory(prefix="spot64-release-") as temporary:
        notes = Path(temporary) / "release-notes.md"
        notes.write_text(
            f"# Spot64 Windows beta {args.tag}\n\n"
            "Unsigned beta for named testers. Windows SmartScreen may require an explicit confirmation.\n\n"
            f"Corpus: {manifest['visible_games']:,} games, generation `{manifest['generation_id']}`.\n\n"
            "Download `install-spot64-beta.ps1` and run it with PowerShell; it verifies and installs "
            "the corpus before launching the application installer.\n",
            encoding="utf-8",
        )
        run([
            "gh", "release", "create", args.tag,
            *[str(path) for path in windows + corpus],
            "--repo", args.repository,
            "--target", "main",
            "--title", f"Spot64 {args.tag}",
            "--notes-file", str(notes),
            "--prerelease",
            "--draft",
        ])

    remote = json.loads(run([
        "gh", "release", "view", args.tag, "--repo", args.repository,
        "--json", "assets", "--jq", ".assets",
    ]))
    local = {path.name: path.stat().st_size for path in windows + corpus}
    uploaded = {item["name"]: item["size"] for item in remote}
    if uploaded != local:
        raise RuntimeError("draft release asset inventory differs from the validated local inventory")
    run(["gh", "release", "edit", args.tag, "--repo", args.repository, "--draft=false"])
    print(json.dumps({"published": True, "tag": args.tag, "assets": len(local)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
