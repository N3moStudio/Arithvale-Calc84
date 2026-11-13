# Arithen handoff

## Latest follow-up — November 12, 2026

User reported duplicate glass bar, requested direct Files import for FlareStore, shorter settings, and explicitly confirmed locked erase/start-over. See DIRECT-FILES-AND-RESET.md and the feature map. Source validation uses validate.yml, without IPA packaging. The delivered 0.12.5 build 21 predates these follow-up changes. Keep the existing 160160 recovery entry; it never unlocks photos. Never perform a real reset on the user's library during testing. Native UI, file-provider behavior and FlareStore-signed runtime still require device acceptance.

## Current work — November 12, 2026

Target 0.12.5 build 21 on main. User authorized public repository and GitHub build; GitHub confirmed the repository is already public. New original additions have reserved rights, with historical MIT and third-party exclusions. This section supersedes older settings/surface/build instructions below.

Settings now use seven themes and Liquid Glass with accessibility fallbacks. Check a Backup remains directly in Backups. Albums owns its detail route independently. See SETTINGS-FEATURE-MAP.md and FOLDER-CONNECTION.md. Preserve explicit preference opt-outs and all backup/key formats.

Build evidence: .build/github-0.12.5-run.json and downloaded verification.json. Deliver only the verified Arithen-0.12.5.ipa to the Desktop IPA folder; physical-device validation remains separate.

## Current requested build — November 7, 2026

The user subsequently requested a GitHub IPA build of the settings changes and delivery to `C:\Users\naith\Desktop\ipa\My Projects (N3mo Studio)`. Target **0.12.4 build 20**, branch `codex/native-settings-0.12.4`, isolated build checkout `.build/ci-native-settings`. Keep the main checkout's existing uncommitted work intact. Use `.build/github-0.12.4-run.json`, `.build/delivery-0.12.4.json` and the downloaded verification report to establish completion. The source-only history below predates this build request.

Deliver only `Arithen-0.12.4.ipa` after native compilation, core/recovery tests and package verification succeed. Replace only older Arithen IPAs in that folder after the replacement is verified; preserve other projects' files. No public release or main merge is requested. Native settings layout, accessibility, gestures, permissions and real cloud/provider behavior still need physical-device acceptance; a CI pass does not establish them.

## Latest source-only settings adoption — November 7, 2026

The user explicitly requested adoption of the local Native Settings Kit while preserving all controls/state, and **no IPA, publishing or another-app changes**. Read `Docs/SETTINGS-FEATURE-MAP.md` and `Docs/SETTINGS-ADOPTION.md` plus the new repository `AGENTS.md`. The supplied kit is retained at `UI/NativeSettingsKit` as an unlinked reference; production adapts its patterns using existing Arithen tokens and stores.

Six existing Swift views plus `SettingsComponents.swift` and `BackupSettingsDetails.swift` implement the larger identity/appearance cards, native rows/theme tiles, solid themed lists, and focused backup/help pages. Existing Theme default is intentionally preserved alongside Solid and Liquid Glass. The calculator access/press handlers, cloud provider/recovery code and backup picker completion/cancellation remain unchanged. The eight changed/new app files and seven kit files pass syntax parsing; 59 protected source/config/test files match the tested 0.12.3 source; kit content/144 contrast checks pass. Evidence: `.build/settings-adoption-checks.json`. Native compilation, XCTest and device/simulator checks are **not run** for this pass; WSL availability timed out. Do not reuse the previous IPA's test result as proof of the new UI.

The delivered IPA remains 0.12.3 build 19; its Desktop delivery folder was not modified. The current source changes remain local and uncommitted, alongside earlier existing changes. No settings/data migration or package dependency was introduced.

## Previous build — November 6, 2026

The user requested completion of the half-second entry change, including a new tested IPA. Target: **0.12.3 build 19**, using the existing GitHub Mac workflow on `codex/quick-unlock-0.12.3`; local WSL remains unresponsive. Use `.build/github-0.12.3-run.json`, `.build/delivery-0.12.3.json`, and the downloaded verification report for the completed run's evidence. Do not infer success from this handoff alone. No public release or merge to main is requested.

`CalculatorView` now recognizes hold Equals at 0.5 seconds and disables only the successful full-screen opening animation. It keeps the native high-priority long press and normal Button tap/accessibility behavior, blocks overlapping requests, and rechecks direct-entry state after authentication. Credential verification, throttling, data, and backups are unchanged. Native gesture/timing checks remain pending. Deliver only the current IPA to `C:\Users\naith\Desktop\ipa\My Projects (N3mo Studio)`, keeping evidence in the workspace. Remove older copies of this same app from that delivery folder only after verification; preserve other projects.

## Previous backup-retention build

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


Validation completed: GitHub run [43373156776](https://github.com/N3moStudio/Arithvale-Calc84/actions/runs/43373156776), code commit `d911f52`. All 141 core tests and 13 independent recovery tests passed; the inverted reset guard was rejected and original source restored; iPhone compilation passed. Seven existing MEGA/C++ warnings remain. No IPA was packaged and no physical-device/simulator visual test was performed. The next requested IPA should use a new version/build (planned 0.12.6 / 22); the delivered 0.12.5 / 21 does not contain this follow-up.
