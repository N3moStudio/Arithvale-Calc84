# Compact library redesign — 0.12.0 build 16

Local test IPA delivery was requested after the original source-only redesign pass. Use the generated release kit's `BUILD-RESULT.json` for the delivered IPA checksum and source-bound validation. No public release, push, deployment, or Elsepin modification is included.

## Current design

- Bloom on new installs and reset. Eight complete palettes from the read-only Elsepin reference: Glacier, Afterhours, Porcelain, Ion, Ember, Bloom, Blueprint, Titanium. The library follows the selected theme.
- Theme and Surfaces are the only appearance settings. Theme default resolves to Solid; a chosen Solid/Liquid Glass override survives theme changes. Reduce Transparency and increased contrast use opaque surfaces; iOS 17–25 has a material fallback.
- Rounded typography, one standard Dynamic Type step smaller, minimum xSmall. Accessibility categories are unchanged. SwiftUI applies this once at the app root; the separately presented media host applies it once to its own root. UIKit grid labels use the already-resolved category, not another compact step.
- Calculator retains its existing familiar button positions and behavior. Key numerals are at most 29 pt and the result is 52 pt with aligned digits; touch targets remain at least 44 pt. Reference: [Apple Calculator](https://support.apple.com/en-gb/guide/iphone/iph1ac0b5cc/ios).
- Four portrait grid columns (two for accessibility text), 1 pt separators, compact Snaps count and Photos / Videos / Favs filters. Tap the count to show all; its context menu retains date/sort choices.
- Hold a cell to select, then drag across cells. The normal selection bar has Share, Add to Album, Delete. Empty selection or Cancel exits. VoiceOver has Select Snap. Recently Deleted retains its necessary Restore action and separate permanent-deletion confirmation.
- Floating Library / Albums / Search dock. Albums has no Files category; stored files remain accessible through the complete library and search. Recently Deleted is a grouped row with a count.
- Media uses the whole viewer area without changing original aspect ratios or tinting media. Close, quick lock, and an ellipsis menu overlay the top. Share/Favorite live in the menu. Swipe up for information; a VoiceOver action provides the same access. Upward recognition is disabled while zoomed or paging; UIKit retains downward dismissal.
- Settings has Backups, Cloud Copies, Privacy & Access, Appearance, and About. Recovery-key help and storage are in Backups. Privacy & Access holds code changes and Photo Indexing. No Library Tools group.

## Imports and compatibility

Photos & Videos uses the native picker and starts import after selection, without the old Review Import screen. Runtime disk checks, cancellation, full original-resource handling, and readback verification remain. Completion uses a compact themed card; only eligible, successfully verified originals can be offered for deletion, with system Photos confirmation.

Import from Files combines file/folder intake through shared URLs. Its one instruction is: “In Files, share the files to LiveContainer, choose Arithen, then unlock the library.” The Import button remains disabled until the received batch is ready. The host must deliver actual local file URLs; receiving a collaboration link or enabling a host toggle alone does not establish delivery.

Pending ordinary files and their filenames are encrypted using the existing authenticated stream and metadata primitives. Their separate random key lives in device-only Keychain storage. These are temporary incoming copies, not portable backups. Preparing them reserves the library operation; locking cancels preparation. Each file's receipt is authenticated individually, avoiding repeated whole-queue scans for large imports. Only successfully committed items are removed from the inbox. Failed items remain available, and provider originals are never deleted by this sharing route. Decrypted working copies are file-protected and cleaned after import/cancellation/failure or next launch.

Add from Backup uses the received encrypted archive, its original key, and Import. It authenticates the archive before adding active items and skips exact duplicates. Choose File/Folder, Just Test, and the intermediate selection screen are absent on this route; dedicated recovery testing and setup retain their separate flows. The original archive remains in Files.

No library format, bundle identity, app name/icon, existing recovery key, credential, cloud policy, album, or calculator engine was migrated. Existing backup decoders remain. Legacy appearance preferences/assets are left on disk but are no longer presented or used by the app UI. Legacy Abyss resolves to Bloom. Theme changes do not introduce a view `.id`, recreate the calculator/viewer, or clear user state.

Photo Indexing defaults on when no local preference exists. An explicit opt-out is stored separately from deletion of the rebuildable index, and survives relaunch. Older builds did not persist a distinction between never-enabled and disabled-and-cleared indexing; those installations receive the newly requested on default. The encrypted on-device index is not part of portable/cloud backups. Work starts after imports and original-review decisions finish, and pauses for active operations, lock, inactivity, Low Power Mode, or heat. Failed recognition can be retried manually.

## Validation

### Source and automated checks

- All 120 Swift core tests passed on Linux, including encrypted incoming-file round trips, tampering/wrong-key rejection, per-receipt authentication, same-name receipts, theme migration, and compact/accessibility policies.
- Fresh recovery fixtures passed all 13 independent Python recovery tests. Existing archive formats and cryptographic primitives were retained.
- All eight light/dark palette arrays match the Elsepin reference source. Elsepin remains unmodified.
- The iOS arm64 app-only compile passed with Swift 6.4 and the iOS 27.1 SDK. There were six existing vendor MEGA CMake-input warnings and no Swift diagnostics. This produced an `.app` for compile validation, not an IPA.
- The final source hashes, native binary checks, logs, and whitespace check are recorded locally under `.build/redesign-*`. No IPA packaging or release workflow was run.

These initial source-only checks do not establish physical-device layout, accessibility, gesture fluidity, battery use, or actual Files-to-LiveContainer delivery. Those remain the acceptance checks below. The subsequently requested IPA has a separate fresh verification report and package inspection in its generated release kit. Source changes remain local and uncommitted.

## iPhone / LiveContainer acceptance still required

1. Compare light/dark themes, Bloom defaults/reset, all surface choices, Reduce Transparency/contrast, and VoiceOver/accessibility sizes. Change theme while retaining a calculation, selection, and open navigation path.
2. Hold/select/drag/deselect/Cancel; verify only the intended normal selection actions. Check Recently Deleted restore/permanent delete, album membership, date sorting, and cloud exclusions.
3. Open portrait/landscape photos, swipe between videos/photos, pinch/pan, swipe up for info, downward dismiss, ellipsis Share/Favorite, and quick lock. Confirm media and video controls are not cropped or obscured.
4. Photos import must skip the pre-review, show accurate progress/completion, and offer deletion only after verification. Test partial failure, cancellation, limited Photos access, iCloud Photos confirmation, and dismissal with large text.
5. Share a regular file, a supported folder URL, several same-named files, and a backup through the actual host. Verify disabled/enabled Import, wrong keys, low disk, interrupted receipt/import, locking while preparing, retry, and importing another archive after setup.
6. Verify Photo Indexing defaults on, stays off after opting out/relaunch, starts after imports, and defers with Low Power Mode/heat. Measure large-library scrolling, frame pacing, and battery on hardware.

The supplied screenshots were used only as layout references. No personal media or recovery keys were copied into repository fixtures.
