#!/usr/bin/env python3
"""Verify corpus volumes, archive inventory, and every extracted file hash."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_name(name: str) -> bool:
    path = PurePosixPath(name)
    return bool(name) and not path.is_absolute() and ".." not in path.parts and "\\" not in name


def verify(root: Path, manifest_path: Path) -> dict:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1 or manifest.get("kind") != "spot64-corpus":
        raise ValueError("unsupported corpus manifest")
    files = manifest.get("files")
    volumes = manifest.get("volumes")
    if not isinstance(files, list) or not isinstance(volumes, list) or not files or not volumes:
        raise ValueError("empty corpus manifest")
    expected = {item["path"]: item for item in files}
    if len(expected) != len(files) or not all(safe_name(name) for name in expected):
        raise ValueError("duplicate or unsafe file path")

    seen: set[str] = set()
    with tempfile.TemporaryDirectory(prefix="spot64-corpus-verify-") as temporary:
        extraction = Path(temporary)
        for volume in volumes:
            asset = volume.get("asset")
            archive = root / asset if isinstance(asset, str) else root / "invalid"
            if archive.is_symlink() or not archive.is_file():
                raise ValueError(f"missing volume: {asset}")
            if archive.stat().st_size != volume.get("size_bytes") or sha256(archive) != volume.get("sha256"):
                raise ValueError(f"volume checksum mismatch: {asset}")
            with zipfile.ZipFile(archive) as bundle:
                names = bundle.namelist()
                if len(names) != len(set(names)) or not all(safe_name(name) for name in names):
                    raise ValueError(f"unsafe archive inventory: {asset}")
                for name in names:
                    if name not in expected or expected[name].get("volume") != asset or name in seen:
                        raise ValueError(f"undeclared or duplicate archive member: {name}")
                    destination = extraction / Path(*PurePosixPath(name).parts)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    with bundle.open(name) as source, destination.open("wb") as target:
                        while chunk := source.read(8 * 1024 * 1024):
                            target.write(chunk)
                    entry = expected[name]
                    if destination.stat().st_size != entry.get("size_bytes") or sha256(destination) != entry.get("sha256"):
                        raise ValueError(f"file checksum mismatch: {name}")
                    seen.add(name)
    if seen != set(expected):
        raise ValueError("one or more declared files are absent from the volumes")
    return {"ok": True, "generation_id": manifest["generation_id"], "files": len(seen), "volumes": len(volumes)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.root.resolve(), args.manifest.resolve()), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
