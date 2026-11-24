# Get started with Arithen

## Open your library

On a fresh installation, enter **160160** and hold **= for half a second**. Save the generated recovery key somewhere separate from the app, confirm its last eight characters, and choose your own 6–12 digit calculator code.

For normal access, type your own code and hold **=**. A short press evaluates the number; holding an already evaluated result cannot unlock the library. Retype the code. The starter code opens setup/recovery only and never decrypts an existing library.

Install updates into the same app identity/data container. A normal update keeps the library and its keys. If access is lost, recovery requires the matching recovery key. Erase and Start Over is a separately confirmed destructive action; it does not recover forgotten keys or old photos.

## Add photos, videos and files

Use **+ → Photos & Videos** or **Import from Files**. Choose files directly where supported, or download them in Files and share to Arithen. With LiveContainer, share to **LiveContainer → Arithen**, then unlock the intended library.

After successful import, keeping originals is always an option. Removal is offered only after verification:

- Photos uses the system deletion confirmation. Changed, inaccessible or incomplete originals stay. iCloud Photos can synchronize removal across devices.
- Files uses the provider's recoverable Trash operation after confirmation. Unsupported or changed originals stay; there is no permanent-delete fallback. Containing folders are not deleted.
- Failed imports are never included in removal. Folder import skips hidden files, symbolic links and packages.

## Save and check a backup

1. Open **Settings → Backups → Create Backup**.
2. Save the `.arithenbackup` outside Arithen/LiveContainer, such as your own Files folder.
3. Open **Check a Backup**, select that saved file and enter its recovery key. This checks restoration without importing into your library.
4. Wait for your Files provider to finish uploading. A successful local save is not proof of a completed cloud upload.

The new format stores encrypted resources with two authenticated recovery catalogs. It is not an ordinary ZIP. The file and its recovery key are both needed after deleting the app; neither can replace the other. Older `.c84backup` readers remain supported. See [backup design and validation](Docs/BACKUP-DESIGN-2026-11-22.md).

**Connected Folder → Automatic Daily Backup** can save changed libraries while the app is open and unlocked. It keeps seven tracked, checked automatic copies and protects manual/pre-existing copies. It is not a guaranteed background schedule; iOS decides when suspended apps can run. Private backup reminders are on by default and stay inside the unlocked library.

## Import another backup

Open **Settings → Backups → Import Backup** or **+ → From a Backup**. Choose the file directly, or share the downloaded file from Files to Arithen (through LiveContainer when applicable). Unlock, select the received backup, enter that backup's key and tap **Import**.

The current library is preserved. Added items are encrypted under its current key; exact duplicate originals are skipped. Source Never Upload exclusions carry over. Newly created libraries, including setup from backups, receive a new key which must be saved separately. Every older archive still needs the key that belongs to it.

If a new-format backup is damaged, **Recover Intact Files** checks for whole authenticated originals. Re-enter the source key and review the counts before choosing **Import Intact Items**. This is explicitly partial recovery; missing or damaged media cannot be recreated. The source backup stays unchanged. If an intact spare catalog restores the whole library, create a fresh backup afterward.

Removing a received copy only removes the app's extra copy. It does not delete the original in Files. If Files closes or cannot grant access, use sharing; a shared/copied folder cannot establish a persistent backup-folder connection.

## Cloud copies

Open **Settings → Cloud Copies**, choose MEGA or Blomp, and configure manual selection or automatic eligible items. **Never Upload** excludes selected items for that provider. Sign in and start backup. See [the cloud guide](Docs/CLOUD-BACKUP.md).

Cloud storage holds separate encrypted objects and versioned catalogs, not one continually overwritten portable file. Keep both objects and catalogs. New uploads are checked before the catalog is published. Previously verified objects can be reused after a size check; **Recheck All Remote Files** checks their bytes again. **Test Cloud Recovery** verifies that a snapshot can restore. An independent portable copy protects against losing access to the cloud account.

## Return an original to Photos

Use **Save to Photos**. Arithen supplies the stored capture date; older items can use embedded EXIF/QuickTime dates. Photos' **Date Captured** ordering uses that date, while **Recently Added** still shows a newly saved asset. Original Photos album membership and asset identity are not recreated. Files with no recoverable date cannot have a historical date reconstructed. [Details](Docs/BACKUP-AND-PHOTOS.md).

## Find settings and organize

- Hold a snap to select. Share, Add to Album or Delete; Cancel or deselect all to exit.
- Albums keeps its own navigation, including Recently Deleted. Reselect Albums to return to its home.
- Settings → Appearance offers seven themes. Liquid Glass is standard, with accessibility and older-iOS fallbacks; legacy appearance values remain decodable.
- Settings → Storage shows local storage, largest items and exact duplicates. Nothing is automatically permanently deleted.
- Privacy & Access contains Change Calculator Code and Photo Indexing. Indexing runs locally after import; busy state, Low Power Mode, heat and inactivity defer work.
- Backups contains Create, Import, Check, Connected Folder, Backup Status and private reminders. Backup Help includes recovery-key guidance.
- About shows the current version/build. The current test candidate is **0.13.1 (26)**; the last verified delivery is **0.13.0 (25)**.

Native compilation and simulator evidence are recorded in the research report. FlareStore signing, actual cloud accounts and real Files-provider permissions still need validation on the intended installation.
