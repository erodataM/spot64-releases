# Spot64 macOS beta

## Supported Macs

This beta is for Apple Silicon Macs (`M1`, `M2`, `M3`, `M4` and later) running
macOS 12 or later. It needs about 18 GB of free disk space during installation.
The final application and corpus use about 10 GB.

## Tester procedure

1. Download `Installer-Spot64-Beta-macOS-Apple-Silicon.zip` from the release.
2. Open the ZIP.
3. Control-click `Installer Spot64 Beta.app`, choose **Open**, then confirm
   **Open**. This override is required because the private beta is not
   notarized with a paid Apple Developer certificate.
4. Keep the Terminal window open while the six corpus parts download. The
   installer resumes interrupted downloads and verifies every file.
5. Enter the Mac administrator password when macOS asks permission to copy the
   application into `/Applications`.
6. Spot64 opens automatically when installation completes.

The installer downloads about 5 GB and installs a verified 10 GB corpus with
11,157,455 games and a 40-ply position index. It never activates a partially
downloaded or unverified corpus. A previous corpus is moved to a timestamped
backup before the new one is activated.

## Gatekeeper

The app is ad-hoc signed and integrity-checked, but this private beta is not
Apple-notarized. If macOS blocks the installer:

1. Open **System Settings > Privacy & Security**.
2. Find the message about `Installer Spot64 Beta`.
3. Click **Open Anyway**, then confirm.

No Terminal command needs to be copied or pasted.

