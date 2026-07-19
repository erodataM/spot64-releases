#!/usr/bin/env python3
"""Package the active Store generation into bounded, verified ZIP volumes."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

SCHEMA_VERSION = 1
DEFAULT_MAX_VOLUME_BYTES = 1_900_000_000


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def regular_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for directory, directory_names, file_names in os.walk(root):
        directory_names.sort()
        file_names.sort()
        base = Path(directory)
        for name in file_names:
            path = base / name
            if path.is_symlink() or not path.is_file():
                raise ValueError(f"unsafe corpus entry: {path}")
            files.append(path)
    return files


def pack(files: list[tuple[Path, str, int]], limit: int) -> list[list[tuple[Path, str, int]]]:
    volumes: list[list[tuple[Path, str, int]]] = []
    sizes: list[int] = []
    for item in sorted(files, key=lambda value: (-value[2], value[1])):
        if item[2] > limit:
            raise ValueError(f"{item[1]} exceeds the volume limit ({item[2]} > {limit})")
        destination = next((index for index, size in enumerate(sizes) if size + item[2] <= limit), None)
        if destination is None:
            volumes.append([item])
            sizes.append(item[2])
        else:
            volumes[destination].append(item)
            sizes[destination] += item[2]
    return volumes


def build(repository: Path, output: Path, max_volume_bytes: int) -> dict:
    state_path = repository / "current.json"
    if state_path.is_symlink() or not state_path.is_file():
        raise ValueError("repository current.json is missing or unsafe")
    initial_state = state_path.read_bytes()
    state = json.loads(initial_state)
    generation_id = state.get("currentGenerationId")
    if not isinstance(generation_id, str) or len(generation_id) != 64:
        raise ValueError("currentGenerationId is malformed")
    generation = repository / "generations" / generation_id
    if generation.is_symlink() or not generation.is_dir():
        raise ValueError("active generation is missing or unsafe")
    if output.exists():
        raise ValueError(f"output already exists: {output}")

    source_files = [state_path, *regular_files(generation)]
    inventory: list[tuple[Path, str, int]] = []
    for source in source_files:
        if source == state_path:
            relative = "libase-store/current.json"
        else:
            relative = f"libase-store/generations/{generation_id}/{source.relative_to(generation).as_posix()}"
        inventory.append((source, relative, source.stat().st_size))
    volumes = pack(inventory, max_volume_bytes)

    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix=f".{output.name}.", dir=output.parent))
    try:
        file_entries: list[dict] = []
        volume_entries: list[dict] = []
        for index, volume in enumerate(volumes, start=1):
            name = f"spot64-corpus-{generation_id[:12]}-part-{index:02d}.zip"
            archive = temporary / name
            with zipfile.ZipFile(
                archive,
                "w",
                compression=zipfile.ZIP_DEFLATED,
                compresslevel=1,
                allowZip64=True,
            ) as bundle:
                for source, relative, size in sorted(volume, key=lambda value: value[1]):
                    bundle.write(source, PurePosixPath(relative).as_posix())
                    file_entries.append({
                        "path": relative,
                        "size_bytes": size,
                        "sha256": sha256(source),
                        "volume": name,
                    })
            volume_entries.append({
                "asset": name,
                "size_bytes": archive.stat().st_size,
                "sha256": sha256(archive),
            })

        manifest = {
            "schema_version": SCHEMA_VERSION,
            "kind": "spot64-corpus",
            "generation_id": generation_id,
            "visible_games": json.loads((generation / "manifest.json").read_text(encoding="utf-8")).get("visibleGames"),
            "unpacked_bytes": sum(item[2] for item in inventory),
            "volumes": volume_entries,
            "files": sorted(file_entries, key=lambda item: item["path"]),
        }
        manifest_path = temporary / "spot64-corpus-manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        if state_path.read_bytes() != initial_state:
            raise ValueError("repository activation changed while the corpus was being packaged")
        os.replace(temporary, output)
        return manifest
    except Exception:
        shutil.rmtree(temporary, ignore_errors=True)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--max-volume-bytes", type=int, default=DEFAULT_MAX_VOLUME_BYTES)
    args = parser.parse_args()
    if args.max_volume_bytes < 1024 * 1024:
        parser.error("--max-volume-bytes must be at least 1 MiB")
    manifest = build(args.repository.resolve(), args.output.resolve(), args.max_volume_bytes)
    print(json.dumps({
        "generation_id": manifest["generation_id"],
        "visible_games": manifest["visible_games"],
        "volumes": len(manifest["volumes"]),
        "unpacked_bytes": manifest["unpacked_bytes"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
