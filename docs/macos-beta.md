# Spot64 macOS beta

## Supported Macs

This beta is for Apple Silicon Macs (`M1`, `M2`, `M3`, `M4` and later) running
macOS 12 or later. A first installation needs about 24 GB of free disk space.
An application-only update reuses the verified corpus and needs about 2 GB.
The final application and corpus use about 17 GB.

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

On a first installation, the installer downloads about 5 GB and installs a
verified 17 GB corpus with 11,157,455 games and a 40-ply position index. It
never activates a partially downloaded or unverified corpus. On later
application updates, a byte-verified matching corpus is reused without being
downloaded or extracted again. A different previous corpus is moved to a
timestamped backup before a replacement is activated.

## Gatekeeper

The app is ad-hoc signed and integrity-checked, but this private beta is not
Apple-notarized. If macOS blocks the installer:

1. Open **System Settings > Privacy & Security**.
2. Find the message about `Installer Spot64 Beta`.
3. Click **Open Anyway**, then confirm.

No Terminal command needs to be copied or pasted.
