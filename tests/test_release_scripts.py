from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load(name: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


package_corpus = load("package_corpus")
verify_corpus_packages = load("verify_corpus_packages")


class CorpusPackageTests(unittest.TestCase):
    def test_round_trip_multiple_volumes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo = root / "repo"
            generation_id = "a" * 64
            generation = repo / "generations" / generation_id
            generation.mkdir(parents=True)
            (repo / "current.json").write_text(json.dumps({"currentGenerationId": generation_id}))
            (generation / "manifest.json").write_text(json.dumps({"visibleGames": 3}))
            (generation / "index-policy.json").write_text(
                json.dumps({"schemaVersion": 1, "positionMaxPly": 40})
            )
            (generation / "empty.bin").write_bytes(b"")
            (generation / "one.bin").write_bytes(b"a" * 700_000)
            (generation / "two.bin").write_bytes(b"b" * 700_000)
            output = root / "output"
            manifest = package_corpus.build(repo, output, 1_048_576)
            self.assertGreaterEqual(len(manifest["volumes"]), 2)
            self.assertEqual(manifest["position_max_ply"], 40)
            result = verify_corpus_packages.verify(output, output / "spot64-corpus-manifest.json")
            self.assertTrue(result["ok"])
            self.assertEqual(result["position_max_ply"], 40)

            archive = next(output.glob("*.zip"))
            with archive.open("r+b") as stream:
                stream.seek(-1, 2)
                stream.write(b"x")
            with self.assertRaises(ValueError):
                verify_corpus_packages.verify(output, output / "spot64-corpus-manifest.json")

    def test_round_trip_file_larger_than_one_volume(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo = root / "repo"
            generation_id = "b" * 64
            generation = repo / "generations" / generation_id
            generation.mkdir(parents=True)
            (repo / "current.json").write_text(json.dumps({"currentGenerationId": generation_id}))
            (generation / "manifest.json").write_text(json.dumps({"visibleGames": 1}))
            (generation / "index-policy.json").write_text(
                json.dumps({"schemaVersion": 1, "positionMaxPly": 40})
            )
            payload = (b"position-index-" * 120_000)[:1_500_000]
            (generation / "position.dir").write_bytes(payload)

            output = root / "output"
            manifest = package_corpus.build(repo, output, 1_048_576)
            position_entry = next(
                item for item in manifest["files"] if item["path"].endswith("position.dir")
            )
            self.assertEqual(len(position_entry["parts"]), 2)
            self.assertEqual(
                sum(item["size_bytes"] for item in position_entry["parts"]),
                len(payload),
            )
            result = verify_corpus_packages.verify(
                output, output / "spot64-corpus-manifest.json"
            )
            self.assertEqual(result["parts"], len(manifest["files"]) + 1)

    def test_rejects_oversized_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "large"
            source.write_bytes(b"x" * 20)
            with self.assertRaises(ValueError):
                package_corpus.pack([(source, "large", 20)], 10)

    def test_rejects_unsafe_archive_name(self) -> None:
        self.assertFalse(verify_corpus_packages.safe_name("../escape"))
        self.assertFalse(verify_corpus_packages.safe_name("C:\\escape"))


class InstallerContractTests(unittest.TestCase):
    def test_windows_workflow_runs_incremental_installer_tests_first(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "windows-beta.yml").read_text()
        installer_test = workflow.index("Test incremental beta installer")
        private_sources = workflow.index("Configure isolated read-only source keys")
        self.assertLess(installer_test, private_sources)
        self.assertIn("./release/tests/test_installer.ps1", workflow)

    def test_installer_retains_full_download_fallback(self) -> None:
        script = (ROOT / "scripts" / "install-spot64-beta.ps1").read_text()
        self.assertIn("function Test-InstalledCorpus", script)
        self.assertIn("[int]$manifest.position_max_ply -lt 40", script)
        self.assertIn("skipping corpus download", script)
        self.assertIn("Reusing verified download", script)
        self.assertIn("function Test-CachedVolume", script)
        self.assertIn("Downloading $($volume.asset)", script)
        self.assertIn("Expand-Archive", script)


if __name__ == "__main__":
    unittest.main()
