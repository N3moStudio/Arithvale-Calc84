# Native Settings Kit adoption — Arithen

## November 8 correction map (before implementation)

The user requested independent Albums navigation, fewer duplicate routes, seven themes and Liquid Glass only. This supersedes the original surface-choice preservation below.

| Feature / existing owner | New home / behavior |
| --- | --- |
| Library/Albums/Search filters and selection, LibraryView | Independent tab screens and Albums path; Recently Deleted stays in Albums; reselecting Albums pops its path |
| BackupDocumentPicker / BackupFolder bookmark / VaultModel.connectBackupFolder | Connected Folder owns its visible picker and result; validate one external directory, bookmark round-trip and real write/read before connection; cancellation and unsupported-host guidance remain visible |
| Create/Import/RecoveryTestView | Main Backups: Create Backup, Import Backup, Check a Backup; check is nondestructive and not duplicated under Help |
| Last Saved Copy / RecoveryEvidenceStore | Backup Status shows the saved filename/date and matching verification evidence in place; remove redundant historical-test and nested copy pages |
| BackupCoverageView provider links | Direct CloudProviderView(provider:) links; provider credentials and policy unchanged |
| LibraryStorageView | Settings → Storage, no Recently Deleted navigation or Open Backup Center loop; app-specific storage wording |
| privateBackupReminders / cloudUseCellular | Default true for missing preferences; preserve explicit saved false values |
| Share receipt and import models | One compact instruction component with separate Direct install and LiveContainer routes; received-copy and key gates unchanged |
| ArithenTheme / ThemeSurface / AppearanceRoot | Seven selectable themes; retired Titanium decodes to Bloom; fixed Liquid Glass with accessibility/older-iOS fallback; old surface values remain decodable |
| Back/Done/lock/progress/error/cancel | Keep native Back, existing state and security gates; no duplicate navigation roots inside pushed settings |

Prepared before moving controls, November 7, 2026. Scope: presentation and navigation grouping only. Kit 0.1.0 is a reference; the app keeps its own palette, models, persistence, and navigation owner.

## Starting state

- Main checkout: `0a4d7f8`; current working source includes the already delivered 0.12.3/build 19 changes. The matching tested build branch ends at `49a9bb34b9fd85ea2827792f4ad20dc0456bb9d1`.
- Pre-existing changes: Brand.json, CHANGELOG.md, DEVICE-CHECKS.md, Docs/NEW-CHAT-HANDOFF.md, Docs/PROJECT-MAP.md, README.md, SETUP.md, BackupFolder.swift, CalculatorView.swift, Info.plist, VaultModel.swift, VaultSettingsView.swift, BackupCopy.swift, SharedFileInbox.swift, ThemeAndInboxTests.swift; untracked BACKUP-RETENTION.md, AutomaticFolderBackups.swift, AutomaticFolderBackupTests.swift. Preserve all of these changes.
- iOS 17+, SwiftUI/SwiftPM/xtool. Existing AppearanceRoot applies compact rounded typography once and preserves accessibility categories. No repository AGENTS.md existed when inspected; supplied chat instructions apply.
- This pass does not change version/build, build an IPA, push source, publish, or modify the source kit/Elsepin. Native validation is separate from syntax/content checks.

## Feature map

All model/store names below remain the production implementations. “Unchanged” means the destination, gate, handler, and error/cancellation behavior remain, with only shared surface/row styling changing. Rows group related actions on the same real page, not unrelated capabilities.

| Setting/action | Current location → adopted location | Model/storage | Preserved behavior and gates |
|---|---|---|---|
| Theme: all eight choices | Calculator/Library Settings → Appearance; now reached by larger appearance card | `arithen.theme.v1`, `ArithenTheme` | Immediate write only on selection; Bloom fallback/legacy Abyss decoding unchanged; theme never recreates root/navigation |
| Solid, Liquid Glass, Theme default | Appearance → Surfaces, larger native rows | `arithen.surface.v1`, `ThemeSurface` | Retain all three existing choices, reorder Solid/Glass first; no write on read or theme change; opaque accessibility fallback unchanged |
| Reset Appearance | Appearance → same page, separate reset section | Existing Bloom + `theme` defaults | Same explicit reset action; no automatic reset/migration |
| Scientific buttons / degrees | Calculator Settings → same Calculator group | CalculatorView `@State scientific/degrees` bindings | Original immediate, session-scoped semantics; no new fake persistence |
| Calculator mode menu/history/clear/evaluation/hold Equals | Calculator → unchanged | CalculatorView, Calculator, DeviceAccess/VaultCode | Outside settings adoption; half-second hold, evaluated-entry guard, throttling, history and lock preserved |
| App name/icon/version | Calculator Settings/About → larger appearance card + About identity; calculator version retained below controls | AppBrand, bundled ArithenIcon | Branding and identity unchanged; no icon-switch or signing behavior added |
| Backups / Cloud Copies / Privacy & Access | Settings → Library group | Existing NavigationLinks and environment objects | Native push/Back/edge-swipe; no nested stacks |
| About/help | Settings → About in Help group | AboutView, AppBrand | Same help destinations and URLs |
| Done | Settings/Calculator Settings toolbar → unchanged | Existing dismiss/Boolean closures | Dismisses original presentation; does not reconstruct settings state |
| Lock & Return to Calculator | Settings → dedicated bottom row | `vault.lock(); dismiss()` | Clears private state and closes original sheet |
| Create Backup / Files export | Backup Center → top actions | `prepareBackupForFiles`, `PreparedBackup`, sheet/activeExport/picked/preparation | Original busy gate, storage checks, save picker, onDismiss finalization/readback, cancel preparation and access lifetime retained in BackupSettingsView |
| Import Backup | Backup Center → top actions | BackupImportView, BackupInputModel, shared encrypted inbox, VaultModel | Busy gate, shared receipt, source key, import validation, progress/errors/cancellation unchanged |
| Test Backup | Backup Center → top actions | RecoveryTestView, BackupInputModel, `vault.verifyBackup` | Existing key/selection/busy gates, temporary check, feedback, secret cleanup and alert retained |
| Files/cloud backup coverage | Backup Center inline → Backup Status detail | BackupCoverageView; lastEncryptedExport/libraryNeedsBackup/lastBackupDigest/lastBackupLibraryID/lastBackupFilename; RecoveryEvidenceStore | Same-library/snapshot matching, no false cloud-upload claim, live progress; Manage provider/Back Up Now actions retained |
| Last Saved Copy | Backup Center → Backup Status → Last Saved Copy | lastEncryptedExport, lastBackupFilename, lastBackupFolder, libraryNeedsBackup | Original date/path/filename, selectable text, missing-copy and pending-changes feedback |
| Last recovery test | Backup Center → Backup Status | lastRecoveryTest, lastRecoveryTestIdentity | Keep historical-unidentified test wording; exact-snapshot caveat remains |
| Connected Folder | Backup Center → Save & Status group → Connected Folder | BackupFolder bookmark, backupFolderName | Real provider picker and coordinated/security-scoped access; parent continues owning picker and cancellation |
| Connect / Reconnect or Change Folder | Connected Folder → unchanged | `vault.connectBackupFolder`, `BackupFolder.configured` | Disabled while busy; original sheet receipt/finalization retained |
| Back Up to Connected Folder | Connected Folder → unchanged | `vault.backup()` | Manual save bypasses daily schedule; existing busy gate/errors/progress |
| Automatic Daily Backup | Connected Folder → unchanged | automaticFolderBackup, `scheduleAutomaticBackup()` | Existing 24-hour/7-copy policy and safety checks unchanged; no permission or backup success inferred from toggle |
| Disconnect Folder | Connected Folder → unchanged | `BackupFolder.forget()` | Existing busy gate; same action and confirmation semantics |
| Private Backup Reminders | Backup Center inline → Backup Reminders detail | privateBackupReminders; existing library reminder/snooze storage | Same immediate toggle, private-only reminder, week/snooze semantics; no notification permission added |
| Storage | Backup Center → same overview link | LibraryStorageView, vault.engine, storage snapshot | Real measurement, largest items, Recently Deleted, duplicate scan/cancel/retry/group review retained |
| Storage item selection/restore/delete | Storage detail → unchanged | StorageItemsView, `vault.updateMany`/permanent delete | Selection and destructive confirmation, busy checks, cancellation remain |
| Export space estimate | Backup Center help area → actions footer | StorageEstimateView, resource byte counts | Real storage estimate remains visible before export; engine checks unchanged |
| How to Import from Files | Backup Center → Backup Help → same guide | SharedBackupGuide, system share flow | Instructions/received backups/host handoff unchanged |
| Recovery Key / Test a Backup & Key | Backup Center → Backup Help → Recovery Key | RecoveryKeyHelpView, RecoveryTestView | No viewable key introduced; old/new key semantics and test action preserved |
| Restore after reinstalling | Backup Center → Backup Help → same instructions | Existing informational destination | All original recovery/update/key guidance retained |
| Backup progress/errors | Backup Center and folder operation → visible status sections | vault.busy/status/message | Remains visible on overview and connected-folder page; existing settings alert and picker cancellation retained |
| Change Calculator Code | Privacy & Access → same detail | ChangeCodeView drafts; `vault.changeCode`, DeviceAccess Keychain | Current/new/repeat fields, valid-code/busy gates, save, dismiss, secret cleanup unchanged |
| Photo Indexing toggle / scan / pause / clear damaged index | Privacy & Access → same detail | `vault.textSearch`, encrypted PrivateSearchIndex, existing enabled preference | Original state/task owner, busy/power/unlocked gates, errors, post-import scheduling; no data sent to providers |
| Private storage/export-location guidance | Privacy & Access → same grouped information | Existing static text | Keep actual privacy limitations |
| Cloud Back Up Now / Pause / progress/error | Cloud Copies → unchanged | CloudBackupModel | Existing connection/busy gates, retries, pause and job ownership preserved |
| MEGA / Blomp connection and saved status | Cloud Copies → same provider rows with shared row label | cloud.connected/receipts, CloudCredentials Keychain | Real account state; no mock connection data |
| Allow cellular data | Cloud Copies → unchanged | cloudUseCellular, `cloud.connectionChanged()` | Immediate preference semantics and busy gate preserved |
| Cloud “How it works” | Cloud Copies long footer → How Cloud Copies Work detail | Existing text | Full eligibility, foreground, retention, verification and free-space guidance retained |
| Provider sign-in | Provider detail → unchanged | Email/password/appKey/OTP drafts, CloudBackupModel/Keychain | MEGA app-key link and warning, secure fields, sign-in gates, secret cleanup, failures unchanged |
| Provider backup / Recheck All / Test Recovery | Connected provider detail → unchanged | `cloud.backup`, CloudRestoreView | Provider-specific verification, busy gates, recovery key and test-only restrictions |
| Provider disconnect | Provider detail → unchanged | `cloud.disconnect` | Destructive confirmation retained; existing remote objects untouched |
| Manual/automatic policy / Choose Items / Never Upload | Provider detail → unchanged | CloudPolicySection, encrypted cloudPreferences, CloudSelectionView | Draft selection, Select All/Clear, explicit Save, disabled gates and blocks-overrides semantics remain |
| Find backups / choose snapshot / Load More / restore or test | Cloud recovery detail → unchanged | cloud.snapshots/nextPage, SetupSession, recovery/code drafts | Test vs fresh-library gates, pagination, source/new keys, Pause/errors/secret cleanup unchanged |
| About storage totals / support / recovery / privacy / notices | About → same destinations, larger identity | Vault resource totals/limits, AppBrand.support, bundled notices | URLs, selectable notices, recovery and screenshot/export limitations preserved |
| Retired tint/video/wallpaper types and preferences | No active settings route → still no route | SurfaceAppearanceSettings, legacy storage/assets | Not reintroduced or deleted; source/decoding compatibility stays intact |

## Validation record

Fill in Docs/SETTINGS-ADOPTION.md after checks. Source/token/syntax validation is not proof of native layout, permission flow, provider access, or actual gestures. Device acceptance must cover every moved destination, especially export picker cancellation, connected-folder actions, theme changes during navigation, large accessibility text, and Back/edge-swipe.


November 12 integration: Check a Backup stays in main Backups; shared-file guidance distinguishes direct installation and LiveContainer. Folder connection verifies the resolved bookmark before replacing saved access. The model defaults preserve explicit opt-outs. Regression coverage: SettingsNavigationTests and ThemeAndInboxTests.
