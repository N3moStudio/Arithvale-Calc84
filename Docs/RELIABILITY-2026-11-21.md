# Reliability pass — November 21, 2026

Target: Arithen 0.12.8/build 24. Preserve bundle identity, recovery keys, C84B0001/2 and C84F0002 formats, all old backups, seven themes and stored preferences. No new encryption system is warranted by the supplied reviews.

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

Await current CI result before claiming success. Live MEGA/Blomp accounts, FlareStore-signed installation, real provider selection/connection and physical-device media/performance remain separate acceptance checks. Existing core recovery fixtures cover legacy/wrong-key/tampered/truncated inputs, retention and destination-key imports; no real user media was used.
