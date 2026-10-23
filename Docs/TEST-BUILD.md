# Arithvale 0.4.0 test build

This branch is for testing the rename and reliability work before merging it into main. Uploading the branch does not publish an app release or submit anything to Apple. The existing repository name and main branch are unchanged.

## Changes

- Arithvale is the installed and visible product name. The calculator appearance stays discreet. Bundle identity, Keychain records, encrypted storage and backup formats remain compatible.
- Setup retains one recovery key until cancellation or completion and never enables creation with an empty key.
- Cloud discovery loads bounded pages, preserves valid backups alongside damaged catalogs, and distinguishes account/network failures from damage.
- Backup summaries include Files, MEGA and Blomp. Recovery checks identify the selected backup.
- Imports continue past individual failures, allow retry/cancellation, and show the import review before automatic backup. PhotoKit resources stream into protected files.
- Tapping Equals only calculates. Enter the existing code and hold Equals to open the private library.
- Media browsing adds Previous/Next, Live Photo playback, clearer accessibility labels and optional photo copies without source metadata.
- Free-space estimates, About/recovery/privacy information, a privacy manifest, a source map and repeatable release checks are included.

## Verified build

Verification completed 2026-10-23 at 06:59 UTC against unchanged source inputs:

| Check | Result |
| --- | --- |
| Swift core tests | 44 passed, 0 failures |
| Independent Python recovery/interoperability tests | 11 passed, 0 failures |
| Release iOS arm64 compilation and IPA packaging | Passed |
| IPA metadata, compatibility identifiers, privacy manifest and archive integrity | Passed |
| Physical iPhone installation and interface behavior | Pending |
| Real MEGA/Blomp account transfer round trips | Pending |

IPA: `Arithvale-0.4.0-test.ipa`, build 4, minimum iOS 17.0.

SHA-256: `1a42f5994bd84f204267dee313122a152eaed57db4c1e1ee8415fac78523128a`.

The ignored test kit is in `Releases/Arithvale-0.4.0-test-1a42f599/`. It includes the IPA, source ZIP, full test/build logs, per-input hashes and `BUILD-RESULT.json`. The evidence records the base commit at the start of testing; the file hashes bind it to the changed source used for this build.

## Installation and remaining work

The IPA is unsigned. Use the existing signing installer, signing identity and data container when updating; do not uninstall the current library. Follow `DEVICE-CHECKS.md` using disposable media first. A successful compile cannot verify PhotoKit, Keychain, gestures, permissions or cloud credentials at runtime.

The earlier review also proposed optional biometrics, a larger onboarding redesign, localization and editing during active backups. Those remain future work. Backups still serialize library edits, and byte progress advances when each resource finishes its transfer/check. Public store/website branding is drafted in `Docs/STORE-LISTING.md`; nothing has been submitted or published, and search ranking is not guaranteed.
