# Native Settings Kit adoption

November 7, 2026 · 0.12.4/build 20 target. The user subsequently requested a GitHub IPA build and delivery. The earlier 0.12.3/build 19 IPA does not contain these settings changes.

## Implementation

The inventory was recorded before moving controls in [SETTINGS-FEATURE-MAP.md](SETTINGS-FEATURE-MAP.md). No setting was replaced with preview/demo data. No existing preference or backup schema was migrated.

- Calculator Settings and private Settings start with the larger branded appearance card: existing Arithen artwork at 70pt, a semantic title, and the current theme/surface summary. About has the larger identity treatment too. At accessibility text sizes, art and text stack vertically.
- Native rows share simple accent symbols and wrapping semantic text. Related rows share an opaque themed panel rather than each having a separate rounded icon/background. Spacing is consistent across themes; normal rows keep a minimum 52pt height and custom controls a 44pt hit area.
- Appearance uses larger adaptive theme tiles, one column at accessibility sizes, and selected-state announcements. Solid and Liquid Glass appear first. This **existing** app also retains Theme default and its original Bloom/theme reset semantics; no stored choice is normalized or overwritten merely by visiting the page.
- Backup Center keeps Create, Import and Test at the top, plus current progress/errors and the actual free-space estimate. Connected Folder, Backup Status, Backup Reminders and Backup Help now have focused native detail pages. Last Saved Copy, recovery-key guidance, restore instructions, provider coverage and every original action remain reachable.
- The export preparation task, `PreparedBackup`, file-picker sheet, security-scoped result lifetime and completion/cancellation callbacks remain owned by `BackupSettingsView`. The connected-folder page invokes its parent's picker action; it does not create another picker/model owner.
- Cloud account/policy/recovery controls stay in their original views. Provider labels use the shared row treatment and long cloud guidance has a focused help page. About's help pages use the same surfaces.
- The existing AppearanceRoot remains the single compact-typography owner, including its accessibility passthrough. There is no `.id(theme)`, new navigation root, database, sample settings store, global UIKit appearance change or extra timer/task.

## Reuse and compatibility

`UI/NativeSettingsKit` retains the supplied kit and its documentation/notices as a reference package. It is **not linked into the production target**. `SettingsComponents.swift` adapts its row, identity-card and theme-tile patterns to Arithen's existing `ArithenPalette`, `ArithenTheme`, `ThemeSurface`, `ThemedList` and `AppearanceRoot`, avoiding two live appearance systems. Both inherited notices are retained verbatim and also included in the app's existing notices resources.

No change to app ID, icon, calculator state/entry handlers, device credentials, cloud credentials, encryption, automatic backup retention, media/import/export models, backup formats, cloud selection/policy, permissions, destructive confirmations or source-file deletion rules. Retired background/video/tint settings remain stored and are not reintroduced or deleted. Existing immediate toggles and explicit Save flows keep those semantics.

## Checks performed

- Kit portable validator passed: eight themes, 144 solid-token contrast pairs (minimum 5.09:1), 28 local documentation links, ownership/navigation checks. Arithen's eight palette pairs were independently compared with the kit and match exactly; the contrast evidence therefore applies to those solid token pairs, not every system/translucent render.
- Eight changed/new app Swift files and all seven kit Swift files passed the Tree-sitter Swift grammar parser. This is syntax evidence only, not type-checking/API availability or an iOS build.
- Source comparison against the tested 0.12.3 commit `49a9bb34b9fd85ea2827792f4ad20dc0456bb9d1` confirmed 59 protected data/security/model/test/configuration files are unchanged. It also checked unchanged calculator access/evaluation handlers, cloud provider/recovery implementation, export picker completion/cancellation, root typography, and existing settings keys/defaults.
- `git diff --check` passed. The local evidence and exact changed-source digests are in `.build/settings-adoption-checks.json`; scripts/logs remain in `.build/`.

**At the end of the source-only adoption pass:** native iOS compilation, new XCTest execution, simulator screenshots, physical-device interaction/permissions/provider tests and battery measurements had not run. Windows has no native Swift/Xcode environment; the bounded WSL availability check timed out. The prior 137 core/13 recovery test result belongs to the earlier 0.12.3 build, not this new UI.

**Requested build follow-up:** run the existing GitHub Mac workflow on `codex/native-settings-0.12.4`, then verify its source-bound report and IPA before delivery. The run and delivery records are `.build/github-0.12.4-run.json` and `.build/delivery-0.12.4.json`; their presence and successful results, not this plan, establish completion. No public release, main merge or other-app modification is requested. Simulator/device acceptance below remains separate.

## Native acceptance still required

1. Compile the receiving app through its supported native build path without `--ipa` unless an IPA is requested. Run the relevant existing suites in that environment.
2. Inspect Bloom/Solid, Ion, selected Liquid Glass, Reduce Transparency, Increase Contrast, a narrow phone, iPad/landscape, RTL and accessibility5. Check wrapping, tile selection announcements, identity size and native Back/edge swipe.
3. Change themes and surfaces while several settings levels are pushed; confirm the path, calculator state, selected items, imports and drafts survive. Reopen settings and confirm saved choices and reset semantics.
4. Exercise Create Backup, cancel preparation/picker, save successfully, connect/change/cancel/disconnect a folder from the new detail, and manual/automatic saves with error feedback. Check that old/current backups and provider permissions remain valid.
5. Visit every feature-map destination, including conditional provider sign-in/policy/recovery controls, index pause/error actions, storage scans/cancellation, deletion confirmations, and About links. Check Quick Lock during work and the tap-Equals-then-hold block.

## Reversal

Revert only this presentation pass relative to the tested 0.12.3 source: six modified Swift views, the two new settings presentation files, documentation/pointer and copied kit/notices. Do not revert the pre-existing backup retention or half-second unlock changes. No persisted-data rollback is necessary because this pass has no migration.
