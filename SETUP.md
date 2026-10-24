# Get started with Arithvale

## First use

1. Install the test IPA using your installer or existing LiveContainer setup.
2. Enter **160160**, then **hold = for about 0.6 seconds**.
3. Save the generated recovery key somewhere separate from this app. Confirm its last eight characters.
4. Choose a personal **6–12 digit calculator code**. Enter that code and hold = to return to the library.
5. Import a few disposable samples. Photos uses the Import button; Files offers **Import Files** and **Import Folder**.

The calculator Help screen contains only calculator help. If you forget the code,
enter 160160 and hold = to reach the locked recovery form. Your original recovery
key is still required; the starter code does not decrypt an existing library.

## Keep a backup outside the app

1. Open **Settings → Backups → Save Backup to Files**.
2. Save to your own iCloud Drive folder or another Files location outside the app/LiveContainer.
3. Open **Test a Backup**, select the actual `.c84backup` file, and enter its recovery key. If the picker closes, use the sharing route below.
4. Check the Files provider’s upload status separately. A successful local save is not proof of cloud upload.

The local encrypted library is private app data. It is not a normal Photos album
or a folder of playable pictures in Files. The `.c84backup` file is your portable,
encrypted copy. You need that file **and its recovery key** after deletion/reinstall.

## Choose cloud items

Open **Settings → Cloud Copies**, choose a provider, and
configure **Manual selection** or **Automatic · all eligible**. Add exclusions in
**Never Upload**. Sign in, then Back Up to the provider. See [the cloud guide](Docs/CLOUD-BACKUP.md).

You can also tap **Select**, drag across gallery items, and open the cloud button
to add, remove, block, or unblock that selection for a provider.

## Keep or remove originals

Every import review offers **Keep Originals**. Removal is optional for that batch;
it never becomes an automatic preference.

- **Photos:** the app rechecks the encrypted copies and the exact source assets, then requests iOS’s deletion confirmation. Changed, inaccessible, edited, or incomplete-resource originals are kept. iCloud Photos can sync removal to other devices. Check Photos → Recently Deleted.
- **Files and folders:** the review lists the successfully imported originals and their count. Confirm **Move to Trash** to recheck each source against its imported bytes and request the provider’s recoverable Trash operation. Changed or unsupported files stay in place. There is no permanent-delete fallback, and containing folders are never deleted.
- Failed imports are never included in removal. Folder import skips hidden files, symbolic links, and packages.

Provider Trash behavior and retention need testing with disposable files on your
device. Save and test an external backup before making the vault your only copy.

## Restore or update

Install updates into the same app/data container to retain the local library.
Restore an external backup into an **empty installation** using its original
recovery key. You can choose a new calculator code, but that does not rotate the
library’s encryption key. Newly imported items use the restored library key.

Restore does not merge with or replace an existing library. Old 0.1 backups use
their original password. Files backups retain per-provider choices; cloud recovery
starts with manual/empty cloud choices. Sign-ins and folder permissions must be
connected again. See [offline computer recovery](Docs/BUILDING.md#recover-without-the-app).


## Receive a backup without opening the picker (0.6.0)

1. Open Apple’s **Files** app yourself. Find the `.c84backup` and download it if it has a cloud icon.
2. Touch and hold the file → **Share → LiveContainer → Arithvale**. Choose the intended data container. Share one downloaded file, not a folder or collaboration link. A directly installed Arithvale can be selected instead of LiveContainer.
3. Arithvale still opens as a calculator. Enter your code and hold **=**; an empty installation uses **160160** and hold **=**.
4. On setup, tap **Use Received Backup**, enter its original recovery key and choose a new calculator code. Tap **Restore Library**. For an existing library, go to **Settings → Backups → Test a Backup → Use Received Backup** instead.
5. Receipt means the encrypted copy arrived; only a successful recovery test or restore authenticates it. **Remove Received Copy** removes this extra copy, not the original in Files or your library. One received backup is retained at a time.

This path never opens Arithvale’s document picker. LiveContainer documents its
share handoff, but that host-to-app transfer still needs testing on your phone.
If **No shared backup received yet** remains, the host has not delivered a file.
If LiveContainer is absent from Share → More, check that its share extension is
installed/enabled. Keep the original and key; do not delete them to troubleshoot.

The original **Choose Backup File** and **Choose Backup Folder** paths remain
available. Find the build in calculator Help → About or the Recovery footer:
**0.6.0 (9)** for this update.


## Add another backup after setup

Download the backup in Files, then Share → LiveContainer → Arithvale. Unlock the
library and tap **Backup received**, or **+ → From a Backup**. Use the original
key for that backup, tap **Preview Contents**, select items, then **Add Items**.
The current library is preserved. Added items use its current recovery key.
Exact duplicate originals (including Live Photo motion) are skipped. Source
Never Upload exclusions carry over; check Cloud Copies before uploading.

You can remove a waiting copy from the received card to make room for another.
Removing it here never removes the original file in Files. **Test a Backup** is
still available under Settings → Backups when you only want to check a copy.

## Choose a look

Settings → Appearance offers all six layouts. Clear Glass is the initial choice;
subsequent choices are remembered. Nightroom stays dark. The calculator has its
own appearance and Blue, Mint, Lilac, or Amber colors. Version/build appears at
the bottom of Settings; it is deliberately absent from the ordinary calculator.
