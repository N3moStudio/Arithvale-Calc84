# Arithen handoff

## Delivered 0.13.0/build 25 — November 22, 2026

The user authorized the review fixes, a researched replacement backup format, GitHub build/simulator tests and replacement of the Desktop Arithen IPA. New `.arithenbackup` exports use redundant authenticated catalogs and explicit intact-file recovery; standard AES-GCM and installed library keys remain. Cloud catalogs authenticate their inventory before recovery downloads. Read the backup-design and reliability reports for decisions and limits. This supersedes the older current-build statements below.

GitHub run [45008145545](https://github.com/N3moStudio/Arithvale-Calc84/actions/runs/45008145545) passed all three jobs at source **72fbf92c86ec0ae02d53d316601daf113013d3f3**:

- **176 core tests** and **27 independent Python recovery tests** passed on macOS. Swift-created new archives were recovered independently in Python; old-format fixtures still passed. The same 27 recovery tests also passed on Windows against Swift fixtures from the preceding fully passing `aafabee` revision (`.build/windows-recovery-0.13.0.log`); the final follow-up changes only decorative icon sizing and filename hints.
- **20 simulator tests** passed on iPhone 17 Pro / iOS 26.2, including the production app's recovery-confirmation/cancellation model, Files coordination, interrupted backup/lock, export cleanup, JPEG/MOV metadata and actual Photos saves after source removal.
- One end-to-end UI journey covered ordinary setup/authentication, evaluated-code hold protection, calculator, Albums route retention, settings, two real Files open/cancel paths, a seeded Photos import, lock/reopen and accessibility/theme screens. **15 planned screenshots** were visually reviewed.
- Native arm64 IPA compilation and package checks passed. Source and artifact provenance were verified before delivery. Screenshot review prompted an image-only Dynamic Type cap to prevent decorative settings icons crowding fully scaled accessibility labels; the final screenshots verify that spacing fix.
- Delivered only `C:\Users\naith\Desktop\ipa\My Projects (N3mo Studio)\Arithen-0.13.0.ipa`; older Arithen copies were replaced after verification and other apps preserved. No public release.

Evidence: `.build/delivery-0.13.0.json`, `.build/simulator-0.13.0-evidence.json`, `.build/core-0.13.0-evidence.json` and GitHub artifacts. Later documentation-only commits do not change tested implementation.

Native testing caught two old tests that corrupted the now-redundant footer and expected total failure. They now damage media payloads, retaining strict rejection/rollback assertions; separate tests prove spare-catalog recovery. Review also found that an open vault could export a damaged or stale disk index; export now authenticates and compares the committed index before output, with regression tests. The first 0.13.0 run failed and is retained as evidence, not counted as a pass.

Earlier simulator automation/permission failures are distinct from app acceptance. The final workflow runs the real Photos permission/import journey before native Photos tests, retains both result bundles and merges their results. Test-only code remains outside the IPA.

**Still unverified:** live MEGA/Blomp accounts, FlareStore-signed installation, real iCloud/third-party selection and persistent folder grants, physical-device media playback, large-library frame pacing and battery. Real Files open/cancel plus app-host staging is narrower evidence than completing a real-provider selection. Partial-recovery model tests do not substitute for every visual recovery-screen/device interaction. No real user media or credentials were used. Existing MEGA dependency deprecation warnings are retained.

## Delivered 0.12.7/build 23 — November 14, 2026

GitHub run [43657145638](https://github.com/N3moStudio/Arithvale-Calc84/actions/runs/43657145638) passed both jobs at source **ffb987ff55eea2fc495d6a72110f05697d886f24**: 141 core tests, 13 recovery tests, native IPA/package checks and one complete XCTest UI journey on iPhone 17 Pro / iOS 26.2. Eleven planned screenshots were visually reviewed. The source and artifact manifests match. Evidence is in `.build/delivery-0.12.7.json`, `.build/simulator-0.12.7-evidence.json` and the GitHub artifacts. Later documentation-only commits do not change the tested source.

Delivered `C:\Users\naith\Desktop\ipa\My Projects (N3mo Studio)\Arithen-0.12.7.ipa`; removed the older 0.12.6 IPA only after verification. Other projects preserved. No public release. This supersedes all historical current-build/source-only statements below.

The simulator exposed and verified a fix for an actual Albums reselect crash: unused published presentation flags were written during SwiftUI teardown. Their removal preserves synchronous media close/clear and actual lock state. The calculator mode symbol is now visible. Simulator setup uses ordinary credentials, no test-only access bypass.

Remaining: maximum accessibility text has awkward bottom-tab wrapping and crowded header controls. The passing journey establishes functional navigation, not perfect layout. Real Files/folder provider completion, signed-device behavior, populated media paging/playback, live MEGA/Blomp, battery and frame pacing remain unverified. Never claim all of these passed from the empty disposable simulator vault.

## Requested GitHub build and simulator validation — November 14, 2026

The user now authorizes pushing this refinement for a GitHub build, running a simulator job, and replacing the prior Arithen IPA in `C:\Users\naith\Desktop\ipa\My Projects (N3mo Studio)`. Target **0.12.7/build 23**. This supersedes the preceding source-only stop below. Deliver only the verified IPA after both jobs succeed; preserve other apps. No GitHub release is requested.

`ipa.yml` runs the original device/core/recovery pipeline plus a separate real-source simulator Xcode host generated by `Scripts/prepare_simulator.py`. The simulator uses the pinned MEGA simulator slice and ordinary app setup/authentication, not an unlock bypass. `Tests/ArithenUITests` checks calculator evaluation/hold-entry protection, disposable-vault setup, filtering/sorting, Albums route retention, backup/import navigation, lock/unlock and large-text/theme screens. Test reports and screenshots are artifacts, not proof of real-provider or signed-device behavior. Use the current workflow result and `.build/delivery-0.12.7.json` for final status; version metadata is not proof of success.

## Current local refinement — November 14, 2026

Read [REFINEMENT-2026-11-14.md](REFINEMENT-2026-11-14.md) for the feature/state map, decisions, source evidence and device checklist. The request explicitly forbids IPA packaging/delivery, publishing, signing changes and other-app edits. Changes remain local on main; version/build and the delivery folder are unchanged.

Nine UI source files refine sort discoverability, empty filters, accessible progress, calculator width/VoiceOver, viewer Details access and import/backup hierarchy. Encryption, keys, reset, retained backup policy, model handlers and stored defaults remain unchanged. Native compilation/layout checks are not available on this Windows host; do not present syntax checks as device acceptance.

The last delivered IPA is **0.12.6/build 22**, from `1849f484f5006fb36ae286f76702ce6fc93fc391`, GitHub run **43383774456**. Local `.build/delivery-0.12.6.json` and the source-bound verification report confirm 141 core/13 recovery tests and native/package success. This supersedes older statements below that 0.12.6 was merely planned or that 0.12.5 was the latest delivery. It does not prove the new local refinements compile or render correctly.

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
