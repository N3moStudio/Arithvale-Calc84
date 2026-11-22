# Reliability pass — November 21, 2026

Initial checkpoint: Arithen 0.12.8/build 24. The user subsequently authorized a replacement backup format; the delivered 0.13.0/build 25 includes these fixes plus the researched replacement in [BACKUP-DESIGN-2026-11-22.md](BACKUP-DESIGN-2026-11-22.md). Installed library keys, bundle identity, themes and preferences remain intact.

## Findings and disposition

| Finding | Change / evidence |
| --- | --- |
| Backup lock strands busy; stale completion can clear later work | Token-owned serial operation gate; lock hides content immediately while storage drains. Native integration test interrupts actual backup and verifies original bytes. |
| Old cloud receipt shown for new vault | Library-scoped receipts on every status surface; reset local receipts only, preserving credentials and remote recovery copies. |
| Damaged received entry blocks entire inbox | Per-entry isolation, confirmed removal of unreadable received copies even without inbox key; never remove originals. |
| Blomp short downloads/temp cleanup | Bounded HEAD/GET/local length checks; only request-owned output is cleaned on failure. |
| Export lifetime | ActivitySheet gains idempotent completion/teardown cleanup of its own folder. Files export already had cleanup. No blanket temp purge on inactivity. |
| Batch delete/update repeated writes | Single atomic manifest transaction and single UI publication; asset removal follows successful manifest commit. Failure tests preserve assets. |
| Accessibility chrome | Compact dock with native Large Content Viewer; selection actions adapt vertically; calculator title gets a separate accessibility row. The backup reminder wraps at full accessibility size with a separate 44-point dismissal target. Body/settings retain full accessibility sizing. |
| Theme updates | Explicit environment dependencies for previously implicit palette reads. Theme color scheme also applies at library/settings presentation boundaries so native status-bar contrast follows dark themes. |
| Video inactive audio | Pause on willResignActive; preserve position, no automatic resume. |
| Scrolling/album work | Single-pass album grouping, avoid repeated sorting/month text measurement. No measured battery/frame-rate claim. |
| Unlock throttle feedback | Keep ordinary calculator attempts private; explain cooldown in explicit Change Code only. |
| Misleading backup checks | Distinguish verified copied bytes from optional authenticated recovery check. |
| README drift | Correct version/build to 0.12.8/24. |
| Failed replacement selection | Clear previous prepared backup before preparing replacement; an invalid new file cannot leave old archive actionable. |
| Restored media chronology | Stored capture dates win; older items recover embedded EXIF/QuickTime dates instead of being assigned the vault import date. Parse offset/subsecond/GPS for new file imports. Do not explicitly resurrect absent saved GPS. Native JPEG/MOV and real Photos restore tests added November 22. |

## File picker / FlareStore research

Apple's document picker supports copying selected files and opening security-scoped folders. Arithen keeps broad data selection, authenticates archive bytes separately, retains permission through asynchronous coordination/copy, and keeps sharing as fallback. Connected folders now use single selection, matching the one-bookmark contract. Do not change app identity or expose private Documents to try to repair a signing host.

Primary references (reviewed November 21):
- https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller
- https://developer.apple.com/documentation/uikit/providing-access-to-directories
- https://developer.apple.com/documentation/foundation/nsurl
- https://flarestore.app/guide/ios/
- https://flarestore.app/faq/

FlareStore documents signing/installing and editable app identity; it does not establish that this user's particular signed app/profile/provider works. A certificate-tier-specific Files fix is not established. Simulator tests cannot validate FlareStore signing or third-party/iCloud grants. Preserve same identity/container when updating; no credentials were requested or used.

## Validation plan and limits

GitHub runs fresh core and independent recovery tests, device compilation/package checks, plus real-source simulator app-host tests and UI journeys. App-host tests exercise coordinated backup staging, actual authenticated recovery/wrong key, corrupt replacement, cancellation/retry, stale picker callbacks, real interrupted backup ownership and export cleanup. Media fixtures cover EXIF offsets/subseconds/GPS and QuickTime metadata; actual simulator Photos writes check restored photo/video capture dates after source files/vaults are removed. The UI journey grants Photos access through the system dialog in the disposable simulator before the native asset tests. UI tests open/cancel the real Files picker, import a disposable seeded photo, and retain setup/auth/calculator/tab/settings/large-text/theme checks. Test-only code lives in Tests and generated simulator host, not the IPA.

The completed source-bound results are below. Live MEGA/Blomp accounts, FlareStore-signed installation, real provider selection/connection and physical-device media/performance remain separate acceptance checks. Existing core recovery fixtures cover legacy/wrong-key/tampered/truncated inputs, retention and destination-key imports; no real user media was used.

## Completed verification and delivery

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
