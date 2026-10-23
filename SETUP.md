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

1. Open **Settings → Backup & Recovery → Save Backup to Files**.
2. Save to your own iCloud Drive folder or another Files location outside the app/LiveContainer.
3. Open **Test a Backup**, select the actual `.c84backup` file, and enter its recovery key. Do not select the containing folder.
4. Check the Files provider’s upload status separately. A successful local save is not proof of cloud upload.

The local encrypted library is private app data. It is not a normal Photos album
or a folder of playable pictures in Files. The `.c84backup` file is your portable,
encrypted copy. You need that file **and its recovery key** after deletion/reinstall.

## Choose cloud items

Open **Settings → Backup & Recovery → MEGA & Blomp**, choose a provider, and
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


Backup picker (0.5.1): choose **Choose Backup File** and tap the file, or
**Choose Backup Folder**, open its folder, tap Open, then tap the filename in
Arithvale's list. The selected name must appear before restoration. If LiveContainer
does not respond to Open, enable its per-app **Fix File Picker** setting and relaunch.
Find the running build in calculator Help → About or at the bottom of Recovery.
