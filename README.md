# Spot64 beta releases

Public distribution repository for Spot64 beta installers. Application source
stays in the private Libase repositories; this repository contains only build
orchestration, checksums, release evidence, and public installation assets.

## Windows beta

The manual `windows-beta` workflow builds on GitHub's free Windows runner. It
checks out exact source commits through read-only deploy keys, builds the real
Store, native API sidecar, and Tauri NSIS installer, then runs the Store-only
API and packaged-startup qualification suites.

The workflow never uploads source checkouts and never publishes a release by
itself. Publication is a separate gate that requires both the Windows artifact
and a fully verified corpus. See [`docs/windows-beta.md`](docs/windows-beta.md)
for the operator procedure and the unsigned-beta limitations.

## Corpus

`scripts/package_corpus.py` packages one active Libase Store generation into
independently checksummed ZIP volumes below GitHub Releases' per-asset limit.
`scripts/install-spot64-beta.ps1` downloads and verifies those volumes before
atomically installing the repository in the current Windows user's app-data
directory.
