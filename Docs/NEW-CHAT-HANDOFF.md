# Arithen handoff

## Scope and release state

Repository: `C:\Users\naith\Documents\GitHub\Calc 84`.
Branch: main, with local uncommitted backup-retention work. Current local test build: 0.12.2 build 18. Older 0.12.1 build 17 contains the redesign and polish but not daily backup retention.

The user explicitly authorized **limiting automatic backup accumulation while protecting verified older copies, building the IPA, and putting it in Downloads**. This authorizes delivery of 0.12.2 build 18; no GitHub release, deployment, or Elsepin edits were requested. The local WSL environment stalled on restart, so the existing GitHub Actions workflow is the build fallback on `codex/backup-retention-0.12.2`. Keep main unchanged until integration is requested. Use the downloaded workflow verification report and release kit's `BUILD-RESULT.json` for source-bound evidence and checksum. Local evidence/delivery records are under `.build/`; do not confuse the successful earlier focused tests with the final full build.

Read `Docs/BACKUP-RETENTION.md` first for the latest change. Automatic connected-folder saves are limited to one per 24 hours after changes, keep seven tracked copies, and recheck retained/candidate hashes before deletion. Manual/pre-existing/other-installation backups and MEGA/Blomp objects are outside cleanup. Journals are private and scoped to folder plus library. Permission, corruption, journal, cancellation, and delete errors fail safe; extra copies may remain. No live-account or iPhone acceptance has been established. The earlier evidence below is historical; use the 0.12.2 verification report for this build.

Read `Docs/UI-REDESIGN.md`, the 0.12.0 changelog, and `Docs/PROJECT-MAP.md`. The user confirmed **the library follows the selected theme**, not a permanently white canvas. The latest instructions replace the previous Clear Glass default/video wallpaper/gallery-layout settings: eight themes, Bloom default, only Theme and Surfaces, solid theme defaults, rounded compact text with accessibility preserved.

## Main implementation points

The eleven complementary design skills were checked and the focused changes are documented in `Docs/POLISH-2026-10-30.md`: five UI files, no data or theme migration. They are included in the requested 0.12.1 build 17 IPA. Initial native compile evidence is under `.build/polish-2026-10-30/`; physical-device acceptance remains pending.

- `CalcCore/ArithenTheme.swift`: exact reference palettes, default/migration, surface/compact policies.
- `Calc84/Appearance.swift`: stable-root presentation, native category mapping, themed app-owned forms/lists. `ArithenGlass` resolves surfaces and accessibility fallback.
- `LibraryView`, `MemoryGrid`, `AlbumLibraryView`: compact Snaps layout, filters/dock, hold-to-select, three normal actions, selection exit, Recently Deleted.
- `MediaBrowser`: full-area media, ellipsis actions, zoom/paging-aware upward details gesture, VoiceOver equivalents. Existing privacy/preview/pager ownership stays intact.
- `SharedFileInbox` + `SharedFilesImportView`: encrypted pending-file queue with a separate device-only Keychain key. Do not discard failed received copies or provider originals. The completion callback only reports committed file URLs.
- `BackupImportView`: shared archive + original key + Import. Still uses existing authenticated restore/import routines and duplicate/cloud-exclusion handling. Setup/test flows remain separate.
- `VaultModel` + `LibraryTextSearch`: direct imports, batched updates, verified optional original deletion, automatic post-import indexing with persisted opt-out/power gates. Source decoder/keys/formats remain unchanged.
- `VaultSettingsView`: Photo Indexing and Change Code in Privacy & Access; About separately; storage/recovery in Backups.

## Evidence

- `.build/redesign-core.log`: 120 Swift core tests passed on Linux, 0 failures.
- `.build/redesign-native-final.log`: final native app-only compile passed (no `--ipa`).
- `.build/redesign-fixtures.log`: fresh independent-recovery fixture generation.
- `.build/redesign-recovery.log`: all 13 independent Python recovery tests passed.
- `.build/redesign-source.json`: hashes used to check the tested source stayed unchanged.
- `.build/inbox-review-job.json`: bounded external review packet; reviewer suggestions were assessed, not treated as test evidence. Main agent fixed receiving/preparation overlap and cancellation ownership.

The final native compile passed with six existing MEGA CMake input warnings and no Swift diagnostics; evidence is recorded in UI-REDESIGN.md and `.build/redesign-validation.json`. Physical-device UI, host share delivery, gestures, accessibility, account/provider behavior, and battery remain unverified. Use the focused device checklist before any delivery claim.

Elsepin was read as a reference only and remained clean. Branding/icon/bundle ID were preserved; legacy appearance assets were not deleted. No user media was added to the repo.
