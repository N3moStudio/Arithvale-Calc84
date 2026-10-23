# Calc 84 · phone test guide
Version 0.3.0 alpha · Build 3

## Cloud backup checks

Use disposable samples first. Do not delete your only library to test recovery.

1. Update over the old app using the same installer/signing identity. Check that the existing calculator code, photos, videos, and recovery key still work.
2. Open Settings → Cloud Backup. Sign in to your own service. MEGA also asks for a developer app key from https://mega.nz/sdk; this is not a recovery key. Blomp must pass HTTPS checks; stop and use another destination if it reports a certificate error.
3. Import one old-dated photo, one video, and a Live Photo if available. Back Up Now. Wait for the completed catalog, not just an individual upload. Open a photo → Backup Status; check the provider and saved time.
4. Check the cloud account in its own website/app. Files under c84/v1 should be opaque encrypted objects, with no ordinary media thumbnails or original filenames. Save the Calc 84 recovery key separately.
5. Add another sample. Back up again: it should upload only new resource objects plus a catalog. Recheck All Remote Files also downloads unchanged files and consumes bandwidth.
6. Interrupt a transfer with Pause, app backgrounding, and loss of Wi-Fi. Unlock and retry. No interrupted catalog should replace an older complete backup. Completed files should be reusable; the currently interrupted file can restart from the beginning.
7. Confirm Wi-Fi-only behavior; then explicitly test the cellular toggle. Verify MEGA transfer-limit errors leave a usable app and retry path.
8. Cloud Backup → service → Test Cloud Recovery. Choose a completed snapshot and its original recovery key. A wrong key must fail before media download. A correct test authenticates files without replacing the library. Allow up to 3× the backup size in free phone space for this alpha.
9. With a separate test installation/container, choose Restore from Cloud before creating a new library. Connect the same account, select the snapshot, enter its original Calc 84 key, and choose a new calculator code. Compare media, albums, favorites, original dates and Live Photo pairing.
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

- Install Calc 84 0.3.0.ipa directly with SideStore. No extension is included. Keep your normal signing/refresh process.
- Launch: calculator first, no photo permission request.
- Type 160160 and =. Save the recovery key outside the app, confirm its final eight characters, and choose a unique 6–12 digit code.
- Lock; your new code and = should reopen it. The public starter must no longer open the configured library.
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
- A Live Photo should say its paired video is retained; vault preview is still-only.
- Cancel pickers. Try a cloud-only photo with and without connectivity. A failed import must retain the source.
- Interrupt an import. Completed items may remain; an incomplete Live Photo must not appear as fully imported.
- After a successful Photos import, choose Keep Originals: sources and vault copies must both remain. Dismiss the review sheet for the same result.
- Import disposable samples again and choose Delete Imported Originals. Cancel iOS's confirmation first; sources must remain. Retry and confirm; only those originals should move to Photos → Recently Deleted, with vault copies still viewable.
- Import a mix with an unavailable cloud item: only completed imports may be offered for deletion. All failed/unprocessed originals must remain.
- Edited photos, alternate/RAW resources, missing asset identifiers, and limited-access fallback imports must be excluded from in-app deletion. Files imports must never offer this action.
- Change an original in Photos, revoke access, or remove/corrupt a disposable vault copy before deletion: the request must be refused. Background/lock during verification must not start a stale deletion request. Once an OS-confirmed Photos transaction has begun, iOS controls its completion.
- For a Live Photo, confirm both vault resources work before confirming deletion. Check iCloud Photos propagation on a disposable sample; Calc 84 must never empty Recently Deleted.
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

1. Choose your own iCloud Drive or other external folder, outside Calc 84/LiveContainer.
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
2. Empty installation: 160160 and = → Restore an Existing Backup.
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
- Calculator works offline. No Calc 84 account, analytics, or subscription is required. Cloud backups use your optional provider accounts.

## Send useful results

Include build number, iOS version, installer/host, exact steps, expected result, and actual result. Use disposable samples in screenshots. Never send your recovery key, private originals, or unredacted backups.

Mark each group passed/failed after your own run. Computer tests are separate from these real-device checks.
