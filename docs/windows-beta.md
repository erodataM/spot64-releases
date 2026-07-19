# Windows beta release procedure

## Cost and trust model

The release builder is public, so its standard GitHub-hosted Windows runner is
free. Source repositories remain private and are cloned with three independent,
read-only deploy keys. Workflow artifacts contain installers and evidence only;
source checkouts are never uploaded.

The beta is currently unsigned. Windows SmartScreen may therefore display an
unknown-publisher warning. This is acceptable for named beta testers, but not
for a public stable release. SHA-256 evidence protects against accidental
corruption; it is not a substitute for Authenticode signing.

## Build gate

1. Update the three pinned commits in `windows-beta.yml` deliberately.
2. Dispatch `windows-beta` for the intended prerelease tag.
3. Require the native Store build/tests, native-profile API qualification,
   Desktop checks, NSIS build, packaged-startup smoke, and strict evidence
   verification to pass.
4. Download and test the workflow artifact on a clean Windows account.
5. Package and verify the corpus locally.
6. Create a prerelease only after both the application and corpus gates pass.

## Corpus packaging

```bash
python3 scripts/package_corpus.py \
  --repository "$HOME/Library/Application Support/org.libase.desktop/libase-store" \
  --output dist/corpus

python3 scripts/verify_corpus_packages.py \
  --root dist/corpus \
  --manifest dist/corpus/spot64-corpus-manifest.json
```

Only the active generation is included. `current.json` may retain the ID of a
previous generation for rollback history; the Store CLI accepts the repository
when that older generation is absent, and the active generation remains fully
self-contained.

After downloading the successful `spot64-windows-beta` workflow artifact:

```bash
python3 scripts/publish_beta.py \
  --tag v0.1.0-beta.1 \
  --windows /path/to/spot64-windows-beta \
  --corpus dist/corpus
```

Publication starts as a draft. The script compares every uploaded asset name
and byte count with the locally validated inventory, then makes the prerelease
visible. A failed upload therefore never exposes a partial beta to testers.

## Tester installation

Publish the NSIS installer, corpus manifest, every corpus ZIP volume, and
`install-spot64-beta.ps1` on one GitHub prerelease. A tester can then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-spot64-beta.ps1 -Tag TAG
```

The script downloads every corpus volume, verifies the archive and extracted
file hashes, installs the Store repository atomically under `%APPDATA%`, then
launches the NSIS installer. Existing corpus data is retained as a timestamped
backup rather than deleted.
