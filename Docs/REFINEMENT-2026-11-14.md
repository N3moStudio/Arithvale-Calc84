# November 14 refinement

Source baseline: `1849f484f5006fb36ae286f76702ce6fc93fc391`, clean main checkout. The local delivery record and source-bound GitHub report establish that 0.12.6/build 22 was built and delivered; the version declaration alone does not. No physical-device acceptance is recorded. This task is local source work, with no IPA, source push, release, signing or other-app changes.

## Feature and state inventory, before edits

| Journey | Real owner / stored state | Location and preservation |
|---|---|---|
| Calculator input, clear/backspace, scientific functions, angle mode, history | CalculatorView session state; CalcCore Calculator | Calculator and its mode/history/settings sheets. Keep four-column keys, ordinary taps, session-only history and direct-entry guard. |
| Authenticated access / recovery / reset | VaultCode, DeviceAccess Keychain, VaultModel, SetupSession, identity-checked VaultRepository | Half-second hold Equals; 160160 opens setup/recovery only. Keep throttling, immediate successful reveal, typed ERASE and final confirmation. |
| Library/filter/search/sort | LibraryContentStore, LibraryQuery; libraryDateSource/libraryNewestFirst preferences | Existing tabs and filters; expose the same sort bindings as a visible menu. No new sort preference. |
| Albums/tags/favorites/Recently Deleted | LibraryTabNavigation, encrypted VaultItem metadata, AlbumTagEditor | Albums retains its own stack; reselect Albums returns home. Retain pin/cover/edit, restore and permanent-delete confirmation. |
| Selection/export | MemoryGrid, GridDragSelection, LibraryPane selection; ExportMediaView | Hold/sweep/tap selection and Share/Add to Album/Delete remain. Keep original/private-copy export and deletion checks. |
| Media open/page/zoom/details/return | MediaViewerController, MediaPagingState, MediaPreviewStore | Keep current-item return identity, native zoom/dismissal, swipe-up details, playback and lock cleanup. Add Details to existing options menu for discoverability. |
| Photos import and original deletion | PhotosPicker, VaultModel, PhotoResourceWriter, PhotoImportReview | Same permissions, 50-item picker batch, committed-only deletion candidates, system confirmation, cancel/retry and error feedback. |
| Files import/shared inbox | SharedFilesModel, encrypted SharedFileInbox, retained BackupSelection | Choose Files and share fallback both remain. Keep pending copies on failure and remove only committed imports. |
| Backup import / fresh setup / verification | BackupInputModel, BackupReviewModel, VaultModel, SetupSession | Direct picker and shared backup remain; authentication, temporary staging, source key and destination re-encryption unchanged. Split selection/key/activity into readable sections. |
| Backups/settings | VaultSettingsView, BackupSettingsView, PreparedBackup | Create / Import / Check stay together. Preserve export ownership, space estimate, picker cancellation/readback and native Back. |
| Connected folders / retention | BackupFolder bookmark, AutomaticFolderBackups journal; automaticFolderBackup | Dedicated folder page, real connection errors, daily foreground schedule and seven verified automatic copies; external/manual copies untouched. |
| Cloud | CloudBackupModel, credentials Keychain, encrypted per-provider policy | MEGA/Blomp dedicated details, manual/automatic selection, exclusions, cellular preference, Pause/retry/disconnect/recovery all retained. |
| OCR/storage/duplicates | LibraryTextSearch encrypted index, LibraryStorage, VaultModel | Privacy & Access → Photo Indexing; Settings → Storage. Preserve opt-outs, post-import scheduling, power gates, scan/cancel/review; no preselected duplicate deletion. |
| Lock/privacy/appearance/about | AppearanceRoot, ArithenTheme, existing defaults and app identity | Seven themes, standard Liquid Glass/accessibility fallback, larger appearance card, privacy controls and notices. No root replacement or new settings migration. |

## Evidence and priorities

Source-confirmed usability issues: sorting is only in the count's context menu; empty Photos/Videos/Favs queries use the new-library message; import status competes horizontally with cancellation at accessibility text sizes; backup file selection, key entry and activity are one dense section; the appearance card's VoiceOver hint still advertises retired surface choices. Calculator header width shrinks with keypad height in short windows; its combined display label has no explicit result value.

Already implemented, retain: per-tab native bar hiding and Albums navigation, authenticated encrypted staging, immediate privacy cleanup, native viewer continuity and Reduce Motion. Historical screenshots are not proof of the present render. No new animation or material treatment is justified without a rendered discrepancy.

Review risks requiring device verification: large text and narrow windows, native back/edge-swipe versus modal dismissal, theme changes with active imports or zoom, provider cancellation/denial, wrong-key/corrupt/low-space import feedback, and lock during loading. Real provider completion, smoothness and battery are not established by source inspection.

## Verification

Completed locally:

- All **9 changed Swift files** pass Tree-sitter syntax parsing. **134 source/config/test files** match the source-bound 0.12.6 verification manifest (normalizing checkout line endings). Targeted comparisons also confirm unchanged calculator state/authentication/evaluation, backup authentication and completion, encrypted-inbox models/picker callbacks, media paging/playback/privacy lifecycle, independent tabs and selection/export handlers. Existing saved preference declarations remain identical. Evidence: `.build/refinement-source-checks.json`, reproducible with `.build/refinement-check.py` and the local parser environment.
- **13 independent recovery tests passed**, using current `Scripts/test_recovery.py`/`recover.py` with retained synthetic `.build/redesign-fixtures`. This covers wrong-key/tampered/truncated/legacy input, safe output cleanup, original bytes/dates/albums, cloud-folder fixtures and destination-key exports. These are fixtures, not real provider accounts. Log: `.build/refinement-recovery.log`.
- The pinned `cryptography==50.0.2` dependency could not be installed for this Windows environment (no matching distribution). The additional recovery run used an isolated **cryptography 46.0.3** wheel; requirements and app dependencies were not changed. This is compatibility evidence, not a successful reproduction of the pinned CI environment or fresh Swift fixture generation.
- Tracked text encoding, expected package UI literals and `git diff --check` passed. No native Swift compilation, XCTest rerun, simulator screenshots, physical-device testing, performance measurement or IPA packaging occurred. The previous build's 141 core-test result belongs to its source baseline only.

The available Codebase Memory index matched the relevant source paths before edits. Later graph queries lost the transport; focused source reads supplied the remaining evidence. Axiom/Apple Look/native-design suite directories were not available in the personal skills inventory, so the installed SwiftUI UI Patterns and Liquid Glass guides supplemented Impeccable's polish workflow. No external AI service or design variant was needed.

### Remaining native acceptance

1. Small phone, short landscape window and iPad; Bloom, Ion and Glacier light/dark; maximum accessibility size, VoiceOver, Reduce Motion, Reduce Transparency and Increase Contrast. Verify count/filter/sort layout, readable errors, calculator value, large selection count, progress/cancel reachability and exactly one dock.
2. Hold/sweep select, deselect last item, Cancel; open and page/zoom/video/Live Photo, show Details both ways, return to the settled item. Switch Library/Albums/Search; Recently Deleted stays in Albums; reselect Albums returns home.
3. Direct Files picker and shared intake: cancel each stage, wrong key, corrupt archive, insufficient space, provider denial, partial import/retry and verified-original deletion. Confirm originals/received retry copies survive failures. Check a Backup must not change library contents.
4. Change theme with an open draft, selection, viewer zoom or import. Lock/background during slow decode, file preparation and cloud work; private UI must hide immediately and stale callbacks must not reopen it. Exercise only disposable libraries for reset/recovery.
5. Real folder/provider permissions, interrupted saves and daily rotation remain device/provider checks. No claim of reliable cloud upload, lower battery use or smoother frame pacing was made from this source-only pass.

Apple guidance supports keeping glass in the controls/navigation layer and preserving useful, accessibility-aware motion:
- https://developer.apple.com/design/human-interface-guidelines/materials
- https://developer.apple.com/design/human-interface-guidelines/motion
- https://developer.apple.com/documentation/swiftui/viewthatfits

## Subsequent authorized GitHub build and simulator result

The user subsequently authorized the IPA and simulator job. Run [43657145638](https://github.com/N3moStudio/Arithvale-Calc84/actions/runs/43657145638), source `ffb987ff55eea2fc495d6a72110f05697d886f24`, passed **141 core / 13 independent recovery tests**, native device compilation/package validation and **1 complete simulator UI test (0 failed, 0 skipped)** on iPhone 17 Pro / iOS 26.2. CI used the pinned recovery dependency. Eleven planned screenshots were reviewed. Build 23 was delivered as Arithen-0.12.7.ipa, replacing only this app's old IPA.

The UI journey covers normal setup/authentication, calculator evaluation and stale-entry hold protection, filter/sort controls, Recently Deleted tab retention and Albums reselect, settings/import/check screens, privacy indexing, lock/unlock, relaunch, largest text and an Ion theme change. It does not populate/import media or exercise real providers.

It exposed a real Swift exclusivity crash during Albums reselect. `MemoryGrid.tearDown` wrote an unused `@Published` presentation flag while SwiftUI invalidated its graph. Remove the write-only flags and their writers in MemoryGrid, AlbumLibraryView and VaultModel; keep immediate media close/image clearing and real lock logic intact. The passing final journey exercises the previously crashing route. Also replace the missing calculator mode symbol. MEGA's existing HTTP-parser/zxcvbn sources are now explicitly linked for simulator Debug builds.

Visual limitation: at maximum accessibility size, bottom tab labels wrap awkwardly and header controls are crowded. These are not marked as visually accepted merely because navigation tests pass. Physical-device/provider/media/performance checks above remain open. The extra attachment named failure-screen is a teardown timing artifact; authoritative xcresult reports Passed, 1 passed, 0 failed.

Internal evidence: `.build/simulator-0.12.7-evidence.json`, `.build/delivery-0.12.7.json`, downloaded source-bound verification report and xcresult/screenshots. No public release was published.
