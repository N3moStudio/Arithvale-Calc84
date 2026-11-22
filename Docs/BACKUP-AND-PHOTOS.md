# Restoring memories and keeping their dates

Use **Save to Photos** inside Arithen to return an original to Apple's library. Arithen supplies the saved capture date, including Photos date adjustments available when it was imported. That metadata survives file backups, cloud recovery and importing into another encrypted vault. For older items without a saved date, it now reads the original file's EXIF/QuickTime metadata first. Files with no recoverable capture date cannot have a historical date reconstructed.

Photos creates a new asset when saving a copy. **Date Captured** ordering places it according to its original date; **Recently Added** ordering still treats it as newly saved. The original Photos asset identifier, Recently Added position and membership in Photos albums are not restored. See [Apple's sorting guide](https://support.apple.com/en-ie/guide/iphone/iph2e66e2f2c/ios).

Saved coordinates are retained. New Files imports can read embedded GPS. Missing stored GPS is not explicitly filled during Save to Photos because old manifests cannot distinguish missing metadata from a location the user removed. Original bytes can themselves contain GPS that Photos interprets. **Share Photo Copies without Metadata** intentionally removes metadata and is a different route from Save to Photos; other receiving apps control their own import behavior.

## A file backup and a cloud backup are different

| Backup | Stored form |
| --- | --- |
| Files / connected folder | One portable `.arithenbackup` snapshot containing two authenticated catalogs and encrypted resources, including Recently Deleted |
| MEGA / Blomp | Separate encrypted objects plus versioned recovery catalogs, limited to that provider's eligible items |

The new portable backup is an indexed `ARITHB03` archive, **not an ordinary ZIP**. It packages encrypted data for convenient copying; the extension is not its security mechanism. Resources use authenticated AES-GCM records, and each snapshot has a separate HKDF-derived catalog key. Either authenticated catalog can recover from damage to the other. Old `C84B0001` and `C84B0002` readers remain available.

Cloud uploads reuse previously verified unchanged objects. New objects are downloaded and checked before the final recovery catalog is published; restoring authenticates the encrypted contents with the recovery key. Previously verified objects can be reused after a size check, so a completed status is not continuous monitoring of remote storage. **Recheck All Remote Files** performs a fresh readback check. Phone deletions do not purge old cloud snapshots.

Cloud catalogs contain an encrypted private index and a visible inventory of opaque object identifiers, lengths and hashes. Providers can see transfer sizes/counts/times, but do not receive plaintext photos or the Arithen recovery key. Both the `objects/` and `snapshots/` folders are needed for cloud recovery; one catalog alone is not a complete copy.

## Reliability safeguards

- Keep an independent portable backup outside the app as well as a cloud copy; losing access to one destination should not remove the only recoverable copy.
- Keep the matching recovery key separately. Updating the app does not rotate an existing vault's key. Importing into a new vault uses that vault's key for future backups; older archives still need their original key.
- Use **Check a Backup** or **Test Cloud Recovery** to authenticate a saved copy without replacing the current library. A successful copied-file check and an authenticated recovery check are different evidence.
- Automatic connected-folder backups retain seven checked automatic copies, protect manual/pre-existing files and retain extra copies if pruning cannot be verified. They run while the app is open and unlocked; iOS does not guarantee a daily background run.

The user authorized a replacement portable format after the initial reliability pass. It adds catalog redundancy and explicitly confirmed intact-file recovery while retaining established encryption primitives. A damaged media resource still cannot be recreated from missing bytes. Read the [research, new format and validation limits](BACKUP-DESIGN-2026-11-22.md).
