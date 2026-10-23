# Arithvale 0.5.0 · build 6

## Changes

- Independent manual selection, automatic-all mode, and Never Upload lists for MEGA and Blomp. Missing/legacy preferences default to manual with no selections.
- Provider-specific encrypted catalogs omit excluded metadata and related resources. Full Files backups stay complete. Old cloud copies are retained.
- Gallery bulk cloud controls and per-item inclusion/block controls. Selection grids support tap and drag.
- Familiar calculator button placement, rounded keys, current-entry clear, and separate scientific/backspace controls. Existing blue colors and hidden hold-equals entry remain.
- Folder imports and optional recoverable Trash for successfully imported Files originals. Coordinated source snapshots, content checks, and encrypted-copy authentication guard removal; unsupported/changed sources are kept.
- Clearer Photos original-deletion action with the native confirmation and a nonisolated PhotoKit change block.
- New README, setup, cloud, and build guides.

Includes the 0.4.1 drag-selection, LiveContainer backup picker, hidden recovery-entry,
and calculator-help fixes. Existing library/recovery-key compatibility is retained.

## Validation

The release kit’s BUILD-RESULT.json contains exact automated test results, source
hashes, and IPA SHA-256. New regression cases cover provider separation, default
manual behavior, blocked resources/metadata, partial recovery, saved policies,
legacy decoding, folder enumeration, and calculator clear entry.

Native compilation does not establish device interaction correctness. The
Photos/Files confirmation flows, LiveContainer UI, live provider accounts,
accessibility layout, and background cancellation remain device checks.

Development stays on `codex/arithvale-0.4.0`; `main` is unchanged. This is a public
test prerelease, not an App Store release or production security certification.


Backup picker follow-up: Test and Restore now share an import-as-copy chooser with protected, coordinated staging. If the file is gray, use **Browse a Folder Instead**, choose its folder, tap Open, then select the filename inside Arithvale. Selection checks archive contents rather than the extension. Cancel preserves the previous selection; full recovery still authenticates the key and every record. Actual LiveContainer behavior remains a device check.
