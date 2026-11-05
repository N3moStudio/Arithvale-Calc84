# Automatic folder backups · 0.12.2

In Library Settings → Backups → Connected Folder, connect an external folder and enable **Automatic Daily Backup**. The existing `automaticFolderBackup` preference is retained; users who enabled the old after-changes option receive the new daily limit.

## Frequency and scope

- When there are changes, save at most once per 24 hours after a successful automatic save to this folder for this library. No changes means no automatic export.
- Work requires the unlocked, active library and existing power/thermal gates. A foreground timer waits for the due time; returning to the app or unlocking catches up. This is not a guaranteed iOS background schedule.
- Manual Create Backup and Back Up to Connected Folder remain immediate and outside retention. They can be kept independently.
- Existing legacy backups and files from another installation/library are not adopted or deleted. Reinstalling loses local ownership receipts, so old files remain protected.
- MEGA/Blomp snapshot/object storage is unchanged; automatic folder cleanup never deletes provider API objects.

## Safe rotation

Each new automatic file uses an opaque `Automatic-UUID.c84backup` name. A private journal under Application Support/AutomaticBackupHistory identifies exact files, hashes, and save times. The journal is scoped to the canonical folder URL and library UUID; filenames alone do not establish ownership.

The exporter authenticates the library resources using the existing recovery format. The new copy is read back and hash checked, and its receipt is atomically persisted before any cleanup. When there are more than seven tracked copies, every retained copy is read back and compared with its recorded digest. All obsolete candidates are preflighted too, and each is rechecked inside a coordinated delete. Symlinks, changed content, wrong-folder journals, duplicate receipts, and malformed history fail closed. Only a regular file with its exact recorded name and digest can be removed.

Failed writes do not advance the daily schedule. Cleanup errors retain the successful replacement and any remaining older files, with visible feedback. Missing obsolete files can be forgotten safely after the seven retained copies pass; a missing retained copy blocks cleanup. An interrupted journal update is recoverable on a later run. This permits extra copies when safety cannot be established, rather than promising a hard disk-space cap.

Rechecking seven full copies uses provider reads and may download cloud placeholders. This happens only when rotation is needed, at most after a daily automatic save. A successful Files read/write does not prove the provider finished uploading to the cloud. Sufficient space for a new full snapshot is required before older copies are considered for cleanup.

## Verification

Focused filesystem regression tests cover frequency/relaunch/clock changes, seven-copy retention, legacy/manual/other-library protection, damaged or missing retained files, replaced candidates, failed writes, invalid history, folder/library changes, symlinks, cancellation, delete failures/retry, interrupted journal updates, and encrypted restore after rotation.

Full source tests, independent recovery tests, native arm64 compilation, and IPA inspection are recorded in the workflow's `.build/verification/` report and release kit when complete. Logs remain the authority for pass/fail and counts. The existing GitHub Actions workflow is the fallback after a local WSL startup stall; the earlier local focused-test pass does not substitute for final build evidence.

Physical iPhone/LiveContainer and real provider tests remain required: connect a disposable external folder, save/relaunch, verify manual saves are preserved, test an interrupted automatic save, and recover a downloaded cloud copy into a separate empty container. Do not uninstall the real library to test recovery. Daily timing/provider coordination and cloud upload have not been proved by desktop tests.
