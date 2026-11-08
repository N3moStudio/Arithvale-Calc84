# Get started with Arithen

## First use

1. Install the test IPA using your installer or existing LiveContainer setup.
2. Enter **160160**, then **hold = for half a second**. From 0.12.3, recognition starts entry while your finger is still down, and successful entry skips the opening slide animation.
3. Save the generated recovery key somewhere separate from this app. Confirm its last eight characters.
4. Choose a personal **6–12 digit calculator code**. Enter that code and hold = to return to the library.
5. Tap **+ → Photos & Videos**, or **Import from Files**. For Files, share the source to LiveContainer → Arithen first, unlock, then tap **Import**. Try disposable samples first.

The calculator Help screen contains only calculator help. If you forget the code,
enter 160160 and hold = to reach the locked recovery form. Your original recovery
key is still required; the starter code does not decrypt an existing library.

## Keep a backup outside the app

1. Open **Settings → Backups → Create Backup**.
2. Save to your own iCloud Drive folder or another Files location outside the app/LiveContainer.
3. Open **Test Backup**, select the actual `.c84backup` file, and enter its recovery key. If the picker closes, use the sharing route below.
4. Check the Files provider’s upload status separately. A successful local save is not proof of cloud upload.

The local encrypted library is private app data. It is not a normal Photos album
or a folder of playable pictures in Files. The `.c84backup` file is your portable,
encrypted copy. You need that file **and its recovery key** after deletion/reinstall.

## Choose cloud items

Open **Settings → Cloud Copies**, choose a provider, and
configure **Manual selection** or **Automatic · all eligible**. Add exclusions in
**Never Upload**. Sign in, then Back Up to the provider. See [the cloud guide](Docs/CLOUD-BACKUP.md).

Cloud selection and exclusions live in **Settings → Cloud Copies → provider**.
Long-press gallery items for Share, Add to Album, or Delete.

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
Start from external backups in an **empty installation**. Each source needs its
old recovery key. Version 0.7.0 creates a new destination key: save and confirm it
during setup, then use it for all future backups of that destination library.

Setup does not replace an existing library. Old 0.1 backups use their original
password to read the source. New libraries start with manual/empty cloud choices;
source Never Upload exclusions are retained. Sign-ins and folder permissions must be
connected again. See [offline computer recovery](Docs/BUILDING.md#recover-without-the-app).


## Receive a backup without opening the picker (0.7.0)

1. Open Apple’s **Files** app yourself. Find the `.c84backup` and download it if it has a cloud icon.
2. Touch and hold the file → **Share → LiveContainer → Arithen**. Choose the intended data container. Share one downloaded file, not a folder or collaboration link. A directly installed Arithen can be selected instead of LiveContainer.
3. Arithen still opens as a calculator. Enter your code and hold **=**; an empty installation uses **160160** and hold **=**.
4. On setup, tap **Use Received Backup**, enter its old key, and tap **Add Backup to Setup**. Save and confirm the **new** recovery key, choose a calculator code, and tap **Create Library from Backups**. For an existing library, use **+ → From a Backup** to add items or **Settings → Backups → Test a Backup** to check a copy without adding it.
5. Receipt means the encrypted copy arrived; only a successful recovery test or restore authenticates it. **Remove Received Copy** removes this extra copy, not the original in Files or your library. One received backup is retained at a time.

This path never opens Arithen’s document picker. LiveContainer documents its
share handoff, but that host-to-app transfer still needs testing on your phone.
If **No shared backup received yet** remains, the host has not delivered a file.
If LiveContainer is absent from Share → More, check that its share extension is
installed/enabled. Keep the original and key; do not delete them to troubleshoot.

The original **Choose Backup File** and **Choose Backup Folder** paths remain
available. Find the build in calculator Help → About or the Recovery footer:
**0.10.0 (14)** for this update.

Where file selection works, you may queue several backups with separate old keys
before creating the new library. In LiveContainer, finish setup before leaving to
share the next file, then add it through **+ → From a Backup**. Later additions
keep the current destination key. Raw Photos/files/folders are imported after
**Create Library**, which already creates and confirms a fresh key.

Updating an existing library never rotates its keys. Libraries restored in 0.6.0
or earlier still use their original key. **Settings → Privacy & Access → Recovery
Key** explains this; it cannot reveal or export a forgotten key. Keep the key
saved during setup. Old archives continue to require their own original key.


## Add another backup after setup

Download the backup in Files, then Share → LiveContainer → Arithen. Unlock the
library and tap **Backup received**, or **+ → From a Backup**. Use the original
key for that backup, then tap **Import** when its received copy is ready.
The current library is preserved. Added items use its current recovery key.
Exact duplicate originals (including Live Photo motion) are skipped. Source
Never Upload exclusions carry over; check Cloud Copies before uploading.

You can remove a waiting copy from the received card to make room for another.
Removing it here never removes the original file in Files. **Test a Backup** is
still available under Settings → Backups when you only want to check a copy.

## Choose a look

Settings → Appearance contains **Theme** and **Surfaces**. Bloom and Theme default are initial/reset choices. All eight themes default to Solid. Liquid Glass has an older-iOS material fallback and respects Reduce Transparency and increased contrast. One theme styles the whole app. Old video/background/layout preferences are ignored; their files are not erased.

## Organize and find things

- Hold a snap to select, then tap **Add to Album**. Cancel or deselect all to exit.
- **Albums → …:** pin an album or choose its cover.
- **Privacy & Access → Photo Indexing:** enabled by default; recognizes words locally after imports finish. Turning it off removes its encrypted index and remembers your choice. Low Power Mode, heat, inactivity, and busy operations defer work.
- **Backups → Storage:** large items, Recently Deleted, and exact duplicates. Nothing is automatically permanently deleted.
- **Backups:** create, import, test, check provider coverage, or find recovery-key help.
- **About:** app version, build, and privacy information.

These instructions describe the current source and 0.12.4 build 20 target. Use the matching build verification report for automated results; installation, layouts and live provider transfers require device checks.
