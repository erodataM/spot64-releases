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
self-contained. Packaging records the generation's `position_max_ply`; beta
publication and installation require at least 40 plies (20 full moves).

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
`Spot64-Beta-Setup.exe` on one GitHub prerelease. A tester downloads that
single bootstrapper and double-clicks it. It displays download and verification
progress inside a standard Windows installer window; no terminal or execution
policy command is required. The PowerShell asset remains available only as an
operator recovery path.

The script downloads every corpus volume, verifies the archive and extracted
file hashes, installs the Store repository atomically under `%APPDATA%`, then
launches the NSIS installer. Existing corpus data is retained as a timestamped
backup until migration succeeds. Verified volume downloads are cached by
generation until installation succeeds, so extraction or reconstruction can
be retried without downloading completed volumes again.

For an application-only update, the installer first compares the published
corpus manifest with the repository already installed on the tester's machine.
It requires the same generation ID, every declared file with its exact size,
and matching hashes for the metadata files. When those checks pass, it skips
all corpus ZIP downloads and only downloads the checksummed NSIS installer. Any
missing, altered, linked, or differently versioned repository automatically
falls back to the complete download and atomic installation path.

When a corpus update replaces the generation used by an existing editable
primary database, the installer runs the Store's guarded empty-overlay rebase.
It is idempotent and refuses a non-empty user overlay. On refusal or any later
installation failure, the previous corpus is restored before the installer
returns an error. A successful migration removes the temporary backup.

This prerelease is unsigned. The bootstrapper explains that SmartScreen or
third-party antivirus software may intervene. Testers should prefer explicitly
allowing the downloaded installer or the `%LOCALAPPDATA%\Libase` directory. If
real-time protection must be paused for a named beta test, it must be restored
immediately after installation.
