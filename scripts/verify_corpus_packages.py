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
    if manifest.get("schema_version") != 2 or manifest.get("kind") != "spot64-corpus":
        raise ValueError("unsupported corpus manifest")
    position_max_ply = manifest.get("position_max_ply")
    if (
        not isinstance(position_max_ply, int)
        or isinstance(position_max_ply, bool)
        or not 1 <= position_max_ply <= 65_535
    ):
        raise ValueError("invalid corpus position horizon")
    files = manifest.get("files")
    volumes = manifest.get("volumes")
    if not isinstance(files, list) or not isinstance(volumes, list) or not files or not volumes:
        raise ValueError("empty corpus manifest")
    expected = {item["path"]: item for item in files}
    if len(expected) != len(files) or not all(safe_name(name) for name in expected):
        raise ValueError("duplicate or unsafe file path")

    archive_entries: dict[str, tuple[dict, str]] = {}
    for logical_path, entry in expected.items():
        if (
            not isinstance(entry.get("size_bytes"), int)
            or entry["size_bytes"] < 0
            or not isinstance(entry.get("sha256"), str)
            or not SHA256_RE.fullmatch(entry["sha256"])
        ):
            raise ValueError(f"invalid file declaration: {logical_path}")
        parts = entry.get("parts")
        if parts is None:
            parts = [{
                "path": logical_path,
                "offset_bytes": 0,
                "size_bytes": entry["size_bytes"],
                "sha256": entry["sha256"],
                "volume": entry.get("volume"),
            }]
        if not isinstance(parts, list) or not parts:
            raise ValueError(f"empty file parts: {logical_path}")
        expected_offset = 0
        for part in sorted(parts, key=lambda item: item.get("offset_bytes", -1)):
            archive_path = part.get("path")
            size = part.get("size_bytes")
            if (
                not isinstance(archive_path, str)
                or not safe_name(archive_path)
                or archive_path in archive_entries
                or part.get("offset_bytes") != expected_offset
                or not isinstance(size, int)
                or size < 0
                or not isinstance(part.get("sha256"), str)
                or not SHA256_RE.fullmatch(part["sha256"])
                or not isinstance(part.get("volume"), str)
            ):
                raise ValueError(f"invalid file part: {logical_path}")
            archive_entries[archive_path] = (part, logical_path)
            expected_offset += size
        if expected_offset != entry["size_bytes"]:
            raise ValueError(f"file parts do not cover declared size: {logical_path}")

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
                    declared = archive_entries.get(name)
                    if declared is None or declared[0].get("volume") != asset or name in seen:
                        raise ValueError(f"undeclared or duplicate archive member: {name}")
                    destination = extraction / Path(*PurePosixPath(name).parts)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    with bundle.open(name) as source, destination.open("wb") as target:
                        while chunk := source.read(8 * 1024 * 1024):
                            target.write(chunk)
                    part = declared[0]
                    if destination.stat().st_size != part.get("size_bytes") or sha256(destination) != part.get("sha256"):
                        raise ValueError(f"file checksum mismatch: {name}")
                    seen.add(name)
        if seen != set(archive_entries):
            raise ValueError("one or more declared file parts are absent from the volumes")
        for logical_path, entry in expected.items():
            parts = entry.get("parts")
            if parts is None:
                if sha256(extraction / Path(*PurePosixPath(logical_path).parts)) != entry["sha256"]:
                    raise ValueError(f"logical file checksum mismatch: {logical_path}")
                continue
            digest = hashlib.sha256()
            total = 0
            for part in sorted(parts, key=lambda item: item["offset_bytes"]):
                path = extraction / Path(*PurePosixPath(part["path"]).parts)
                with path.open("rb") as stream:
                    for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
                        digest.update(chunk)
                        total += len(chunk)
            if total != entry["size_bytes"] or digest.hexdigest() != entry["sha256"]:
                raise ValueError(f"reassembled file checksum mismatch: {logical_path}")
    return {
        "ok": True,
        "generation_id": manifest["generation_id"],
        "position_max_ply": position_max_ply,
        "files": len(expected),
        "parts": len(seen),
        "volumes": len(volumes),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.root.resolve(), args.manifest.resolve()), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
