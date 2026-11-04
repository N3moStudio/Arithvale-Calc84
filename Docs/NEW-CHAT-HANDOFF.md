# Arithen handoff

## Scope and release state

Repository: `C:\Users\naith\Documents\GitHub\Calc 84`.
Branch: main, with local uncommitted redesign and polish work. Current local test build: 0.12.1 build 17. Older 0.12.0 build 16 contains the redesign but not the subsequent polish.

The user explicitly authorized **building the polished IPA and putting it in Downloads**. This authorizes local delivery of 0.12.1 build 17; no GitHub release, deployment, or Elsepin edits were requested. Do not push main casually: its workflow builds an IPA. Use `.build/verification/arithen-0.12.1-build17/verification.json` and the generated release kit's `BUILD-RESULT.json` for source-bound evidence and checksum. No branch proliferation or destructive cleanup is needed.

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
