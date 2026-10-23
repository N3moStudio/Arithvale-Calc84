# Arithvale · phone test guide
Version 0.4.0 alpha · Build 4

## Cloud backup checks

Use disposable samples first. Do not delete your only library to test recovery.

1. Update over the old app using the same installer/signing identity. Check that the existing calculator code, photos, videos, and recovery key still work.
2. Open Settings → Backup & Recovery → MEGA & Blomp. Sign in to your own service. MEGA also asks for a developer app key from https://mega.nz/sdk; this is not a recovery key. Blomp must pass HTTPS checks; stop and use another destination if it reports a certificate error.
3. Import one old-dated photo, one video, and a Live Photo if available. Back Up Now. Wait for the completed catalog, not just an individual upload. Open a photo → Backup Status; check the provider and saved time.
4. Check the cloud account in its own website/app. Files under c84/v1 should be opaque encrypted objects, with no ordinary media thumbnails or original filenames. Save the Arithvale recovery key separately.
5. Add another sample. Back up again: it should upload only new resource objects plus a catalog. Recheck All Remote Files also downloads unchanged files and consumes bandwidth.
6. Interrupt a transfer with Pause, app backgrounding, and loss of Wi-Fi. Unlock and retry. No interrupted catalog should replace an older complete backup. Completed files should be reusable; the currently interrupted file can restart from the beginning.
7. Confirm Wi-Fi-only behavior; then explicitly test the cellular toggle. Verify MEGA transfer-limit errors leave a usable app and retry path.
8. Cloud Backup → service → Test Cloud Recovery. Choose a completed snapshot and its original recovery key. A wrong key must fail before media download. A correct test authenticates files without replacing the library. Allow up to 3× the backup size in free phone space for this alpha.
9. With a separate test installation/container, choose Restore from Cloud before creating a new library. Connect the same account, select the snapshot, enter its original Arithvale key, and choose a new calculator code. Compare media, albums, favorites, original dates and Live Photo pairing.
10. Save the old-dated photo/video back to Photos. Check chronological date order, then separately inspect Recently Added (which can show today). Check that original bytes and metadata were retained; do not infer date correctness just from the displayed filename.
11. Delete a sample locally and back up. An older remote snapshot must still restore it. No automatic cloud cleanup is implemented, so retained history uses storage.
12. Disconnect a provider. Its cloud data must remain, while this phone requires sign-in again. Download a complete cloud library folder to a computer and test Scripts/recover.py on one snapshots/*.c84cloud file for independent recovery.

Computer tests passed against a local fixture, not logged-in Blomp/MEGA accounts. The documented Blomp storage host failed a certificate check from the build environment. Neither service nor the IPA is verified on an iPhone yet.

## Gallery and Files backup checks

This build includes the Memories gallery and backup updates. Phone checks remain pending. Keep the same library/container when installing the update.

- Gallery: check the four-column tall grid, clear headers at each month, and continuous scroll. Drag the right-edge handle through long and short months: the badge must match the visible photos. Test one month, an empty library, and many months.
- Try Photos/Videos/Favorites/Albums, search, selecting several items, select all, Save / Share, album moves, deletion, and restoration. Check 2/3/4 columns, rotation, dark mode, larger text, and VoiceOver's adjustable date control.
- Settings → Backup & Recovery → **Save Backup to Files**: choose iCloud Drive or another location outside the app/container. Complete the save, check the exact filename, then **Test a Backup** with the old key. A provider save without successful read-back must say it needs checking.
- Cancel the save picker. Last checked backup and its filename must not advance. Close Settings during preparation and verify another attempt works. Lock the phone during preparation and during the picker; returning must require unlocking the vault again.
- **Connect Backup Folder**: open a folder and tap Open. The picker should close, show Checking folder access, then either confirm connection or show an error. No backup should be marked saved at this stage. Back Up to Connected Folder must create and verify a separate snapshot.
- Test a read-only/unavailable provider and a disconnected/reselected folder. The direct Save Backup to Files route must remain available without a folder connection. The app must preserve previous snapshots and the local library on failure.
- Compare direct SideStore and LiveContainer behavior. If tapping Open still leaves the picker stuck, record which provider was used and whether direct Save Backup to Files succeeds; host/provider callbacks cannot be verified by the desktop compile check.

The checks below cover both new and existing features.

**Use disposable samples and keep originals. Do not delete an existing app/container or your only copy to test recovery.** These phone checks are pending; compilation does not prove them.

## 1. Install and enter

- Install Arithvale-0.4.0-test.ipa directly with SideStore. No extension is included. Keep your normal signing/refresh process.
- Launch: calculator first, no photo permission request.
- Type 160160 and hold =. Save the recovery key outside the app, confirm its final eight characters, and choose a unique 6–12 digit code.
- Lock; your new code and hold = should reopen it. The public starter must no longer open the configured library.
- Check 2+3×4 = 14, (2+3)×4 = 20, sin(30) = 0.5 in DEG, plus AC, backspace, sign change, scientific controls, and RAD.
- A calculation whose answer equals your code must not unlock the library. Long-pressing the answer must do nothing special.

Already used 0.1? Export a backup using the old app first. Update with the same signing identity, use Help → Restore or Recover Library, enter the old long password, and enroll a new code. Do not uninstall to upgrade.

## 2. Access and privacy

- Wrong code: calculator remains visible, library remains closed.
- After five failures, wait at least 30 seconds before the correct code; further failures increase the delay up to five minutes. No wipe occurs.
- Settings → Change Calculator Code: old code fails, new code works. Recovery key/backups still work.
- Help → Restore or Recover Library must require the recovery secret before enrolling a new code.
- With a photo, video, Settings, or export sheet open: open the app switcher, lock the phone, and return. The switcher should show a neutral calculator cover. Returning from background must require your code.
- Repeat while importing, unlocking, backing up, or exporting. A stale operation must not reopen the vault after locking.
- Force quit/relaunch: calculator first.
- System pickers and permission dialogs must remain usable. Report any private snapshot or cover that obstructs a system dialog.

## 3. Import and organization

Prepare an old photo, a photo whose date you adjusted in Photos, a screenshot, a short video, a video over 128 MB, a Live Photo, and a PDF/text file.

- Import photos/videos using Import; other files using the folder button.
- Test Selected Photos access, full access if desired, and denied access.
- Confirm counts, image zoom, video audio/seeking, PDF viewing, and that originals remain.
- A Live Photo should say its paired video is retained; hold the preview to play its motion; try the VoiceOver Play Live Photo action too.
- Cancel pickers. Try a cloud-only photo with and without connectivity. A failed import must retain the source.
- Interrupt an import. Completed items may remain; an incomplete Live Photo must not appear as fully imported.
- After a successful Photos import, choose Keep Originals: sources and vault copies must both remain. Dismiss the review sheet for the same result.
- Import disposable samples again and choose Delete Imported Originals. Cancel iOS's confirmation first; sources must remain. Retry and confirm; only those originals should move to Photos → Recently Deleted, with vault copies still viewable.
- Import a mix with an unavailable cloud item: only completed imports may be offered for deletion. All failed/unprocessed originals must remain.
- Edited photos, alternate/RAW resources, missing asset identifiers, and limited-access fallback imports must be excluded from in-app deletion. Files imports must never offer this action.
- Change an original in Photos, revoke access, or remove/corrupt a disposable vault copy before deletion: the request must be refused. Background/lock during verification must not start a stale deletion request. Once an OS-confirmed Photos transaction has begun, iOS controls its completion.
- For a Live Photo, confirm both vault resources work before confirming deletion. Check iCloud Photos propagation on a disposable sample; Arithvale must never empty Recently Deleted.
- Change Vault Timeline / Photos Layout, grid size, date source, and oldest/newest.
- Check capture month/day against the samples. Unknown dates should use import date and say so in preview.
- Favorite items, move multiple items to an album, search names/albums, and remove from album.
- Delete disposable samples, restore from Albums → Recently Deleted, and test permanent deletion with confirmation.
- Lock/relaunch: organization persists. Older backups still contain files deleted afterward.

## 4. Save and share

From Share or Save:
- Save to Photos: inspect Info date, quality, video duration/audio. Check placement with Photos sorted by capture date; Recently Added is separate.
- Save the adjusted-date sample and compare against the date stored in the vault.
- Save a Live Photo, then hold it in Photos to confirm motion.
- Save Originals to Files: open the files. Compare SHA-256 hashes with original source files when practical.
- Share/AirDrop to another device; also cancel and retry. Recipient apps can change metadata or sort by receipt time.
- Live Photos sent through Files/Share include image + video; automatic pairing at the destination is not guaranteed.
- Test a multiple selection and a large video. Report memory-related closure or unresponsive controls.
- Deny Add Photos permission: an error should appear without changing the vault copy.

Exports are plain media and may include GPS. Original resources do not include every Photos-only crop/filter. Source deletion is optional after verified Photos imports and always requires an explicit choice and iOS confirmation.

## 5. External backups

1. Choose your own iCloud Drive or other external folder, outside Arithvale/LiveContainer.
2. Back Up Now; wait for completion and record the displayed filename/date.
3. In Files, locate the .c84backup. It must not open as ordinary photos/videos. Its existence remains visible.
4. Check provider upload status; keep a second copy on a computer/external drive for important files.
5. Settings → Test a Backup: choose that exact file, enter the secret, and run the check. The current library must remain intact.
6. Try the wrong secret. It must fail safely.
7. Import another sample: Backup needed should appear. Back up again; old snapshots must remain.
8. Optionally enable Back Up After Changes, change a favorite/album, and leave the app open. Verify a new snapshot.
9. Disconnect/revoke the provider: failure must leave the local library intact. Re-select the folder to recover permission.

Each snapshot is full-sized. Export/restore/testing can need several times your library size in free space. Automatic backup cannot guarantee completion after backgrounding. A saved copy does not prove cloud upload.

## 6. Restore and change phones

Prefer a second device or separate empty app-data container while keeping the original installation.

1. Keep the external backup and its secret.
2. Empty installation: 160160 and hold = → Restore an Existing Backup.
3. Select backup, enter key (or original 0.1 password), choose a new calculator code.
4. Check samples, dates, albums, favorites, Recently Deleted, videos, and Live Photo re-save.
5. Lock/relaunch and repeat. Re-select the backup folder.
6. With another Apple Account, transfer the encrypted backup independently; do not depend on Keychain transfer.
7. Test computer recovery below.

Only after passing with disposable samples should you test uninstall/reinstall on a copy containing nothing irreplaceable. Uninstalling removes the private local library. Changing signing identity or LiveContainer configuration can act like a new installation.

## 7. Recover on a computer

- Extract the source ZIP. Install Python 3.10+ and run:
  python -m pip install -r Scripts/recovery-requirements.txt
- Open Recover Vault.cmd on Windows, or use README commands.
- First use --verify-only.
- Recover to a brand-new folder. Check original bytes and metadata.json.
- Test a wrong key and a deliberately damaged COPY of the sample backup. No completed output folder should appear.
- Existing output folders must never be overwritten.
- Keep the tool/source ZIP as part of your backup plan; keep the key separately.

Recovered media are unencrypted. The sidecar retains app metadata; importing into another photo app may need dates from that sidecar if the originals lacked them.

## 8. UI and installation compatibility

- Light/dark; Reduce Motion; Reduce Transparency; Increase Contrast.
- Smallest/largest text; portrait/landscape; every control reachable by scrolling.
- VoiceOver: digits, Equals, selection, setting labels, code/recovery forms.
- Both gallery styles, empty library, long names, and multi-select.
- SideStore direct first; LiveContainer separately if intended. Repeat Keychain, app-switcher, folder access, and restore tests in each.
- Calculator works offline. No Arithvale account, analytics, or subscription is required. Cloud backups use your optional provider accounts.

## Send useful results

Include build number, iOS version, installer/host, exact steps, expected result, and actual result. Use disposable samples in screenshots. Never send your recovery key, private originals, or unredacted backups.

Mark each group passed/failed after your own run. Computer tests are separate from these real-device checks.

## 0.4.0 regression checks — pending on a real phone

1. Update over an existing installation without uninstalling. The Home Screen, permission prompts, calculator and About must say Arithvale; existing code/recovery files still work. Enter the code and hold Equals.
2. On a fresh disposable container, visit cloud recovery and Back repeatedly. The setup key must stay identical and usable; cancel/background then reopen creates a fresh setup session. An empty key can never enable Create.
3. With disposable cloud catalogs, place a corrupt catalog between two valid ones. Both valid rows remain selectable; skipped damage is explained. Try Next Page and refresh; an account/network failure offers retry and never pretends the account has no backups.
4. Complete MEGA-only, Blomp-only and Files-only backups. Gallery reports an actual checked destination. Change an item; the corresponding destinations must say changes need backup. Disconnecting does not imply the files were deleted.
5. Import accessible / unavailable / accessible samples. Both accessible samples finish. Retry only the failures; cancel an iCloud resource download and background midway. No source deletion should be offered for unverified items and abandoned temporary files should disappear.
6. Import review appears before automatic backup. Dismiss it and check that rapid edits coalesce into one later backup. Pause cloud transfers from the gallery. Byte totals describe completed resource checks; a single resource is still counted after its transfer/check finishes.
7. Enter six ordinary six-digit numbers and TAP Equals; later enter the real code and HOLD Equals. Normal calculations must not consume the PIN retry allowance. An incorrect held code must still be throttled.
8. Open a middle gallery item, use Previous/Next, favorite it, play a Live Photo, open Share and return, then lock. Check for stuck playback, stale images and temporary plaintext after each exit. Try small screens, landscape, largest text and VoiceOver.
9. Share Photo Copies without Metadata from a disposable GPS-tagged photo. Inspect the JPEG for GPS/EXIF and confirm <=4096 pixels, upright orientation and unchanged encrypted original. Live Photos become stills in this mode; videos keep original-only export.
10. Low storage must fail before substantial staging when an estimate is available, preserve the library, and leave retry available. Test recovery records the selected snapshot/filename digest, not a blanket assurance about every backup.

These checks require a signed installation. Linux core tests and an arm64 compile cannot execute UIKit, PhotoKit, Keychain, UI gestures or actual provider login.

## 0.4.1 regression checks — pending in LiveContainer

1. Tap Select. Drag sideways across photos/videos, continue down several rows and across date headers. Check immediate checkmarks/count and that fast drags do not miss items. Reverse direction; preselected items outside the shortened range must retain their previous state.
2. Start a drag on a selected item to deselect a range. Hold at either grid edge to scroll into further items. Lift, cancel, rotate, change filters or lock; scrolling must stop. In Select mode, ordinary vertical swipes still scroll. Repeat both layouts, 2–6 columns, reverse sort and VoiceOver taps.
3. Test a Backup → Choose Backup: select the saved .c84backup from iCloud Drive and On My iPhone. Unknown extensions should not be gray. Selecting its folder must explain that the file is needed. Cancel preserves the earlier choice. Test with the correct key, wrong key and a damaged disposable copy. Repeat in fresh-install Files restore.
4. Calculator → three-dot Help shows only calculator guidance. Personal code + hold Equals unlocks. 160160 + hold Equals opens a locked recovery form; wrong/blank recovery keys cannot reveal an existing library. Verify a correct recovery key can reset a forgotten calculator code without losing media.


## 0.5.0 selection, import, and calculator checks

- [ ] Update the same LiveContainer guest; unlock the existing library and verify the existing recovery key still works.
- [ ] Both providers start manual/empty for a legacy library. Choose different samples for each and inspect/test both recovered snapshots.
- [ ] Block a Live Photo for MEGA, enable automatic-all there, import another sample, and confirm only eligible primary/thumbnail/paired records upload. Blomp’s choices must stay independent.
- [ ] Block/unblock with gallery bulk actions and individual controls. Save and reopen the selection grids. Pause an active upload before changing policy.
- [ ] Partial cloud recovery contains only selected items and starts manual/empty. Full Files recovery retains all items and provider choices.
- [ ] Empty selection gives a clear message and does not publish an empty backup. Old snapshots remain recoverable after changing selections.
- [ ] Import a nested folder with hidden/link/package files; confirm regular file count and retry/cancel behavior.
- [ ] Keep Originals leaves everything intact. Cancel the Trash confirmation leaves everything intact. Approve on disposable Files items and inspect provider Trash/Recently Deleted.
- [ ] Edit an original after import; Trash must refuse it. Test a provider without Trash support: no permanent deletion fallback.
- [ ] Include a failed import; only successful sources can be removed, and the folder remains. Lock during checks/removal and ensure no subsequent source is processed.
- [ ] Photos import offers the exact count, preserves edited/extra-resource assets, and requests iOS confirmation without a concurrency crash. Cancel and limited-access paths preserve originals.
- [ ] Calculator C, AC, delete, decimal, sign, operators, scientific mode, DEG/RAD, and hold-equals entry work in portrait/landscape, light/dark, and largest text sizes.


Backup picker follow-up: Test and Restore now share an import-as-copy chooser with protected, coordinated staging. If the file is gray, use **Browse a Folder Instead**, choose its folder, tap Open, then select the filename inside Arithvale. Selection checks archive contents rather than the extension. Cancel preserves the previous selection; full recovery still authenticates the key and every record. Actual LiveContainer behavior remains a device check.


## 0.5.1 recovery and viewer follow-up

- Confirm Help → About and Recovery both show **0.5.1 (7)**.
- Fresh-install restore: both file/folder buttons must be on the recovery form.
- File mode: select a local and an iCloud backup; cancel once, retry, and confirm
  the selected filename appears. Check LiveContainer's Fix File Picker setting.
- Folder mode: Open chooses the folder; then select the actual filename inside
  Arithvale. Test a renamed backup, empty folder, ordinary non-backup file, missing
  permission, and cloud placeholder. No restore should start from a folder alone.
- Restore an exported sample using its original key. Confirm item counts, original
  photo bytes, a full video, dates, and Live Photo pairing. Wrong-key failure must
  leave the destination empty and the external backup intact.
- Swipe quickly through 30 mixed items and back. Confirm counter/content alignment,
  correct first/last boundaries, canceled drags, rapid arrow taps, and no stale photo.
- Metadata is hidden initially. Swipe up at 1× zoom and test Info with VoiceOver.
- Pinch/double-tap zoom, pan the zoomed image, return to 1×, then swipe to the next.
- Play a video and swipe away: audio must stop. Test Live Photo motion after leaving
  and returning during loading. Large videos may still need preparation time.
- Open/dismiss details and export without losing the page. Lock/background mid-load;
  return must show the calculator and cached plaintext must be removed.
- Measure frame timing and memory with Instruments on a Mac/device when available;
  this build's automated tests do not substitute for performance measurements.


## 0.5.2 picker lifecycle regression

- Verify 0.5.2 (8) in calculator Help → About.
- On fresh-install recovery, open Choose Backup File and wait ten seconds before
  touching Files. Browse, cancel, reopen, then select a backup with its original key.
- Repeat with Choose Backup Folder; Open returns to the filename list in Arithvale.
- Repeat both paths in Test a Backup after setup, including multiple Cancel/retry cycles.
- Cancel a later selection and verify the previously selected backup remains selected.
- Rotate while Files is open and repeat after backgrounding/reopening the app.
  Backgrounding must still lock the private library.
- If Files closes immediately, record whether the recovery form or calculator is
  shown, any picker notice, the LiveContainer version and Fix File Picker setting.
  Do not include recovery keys, private filenames or media in diagnostic reports.
- These checks require a phone; core tests do not exercise UIKit presentation.
