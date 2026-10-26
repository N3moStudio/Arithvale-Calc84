# Your cloud, your choices

Open **Settings → Backup & Recovery → MEGA & Blomp**. The two providers have
independent selections, automatic settings, and Never Upload lists.

| Mode | Included in the next backup |
| --- | --- |
| Manual selection (default) | Only items you chose, excluding blocked items |
| Automatic · all eligible | All active items, including new imports, excluding blocked items |
| Never Upload | Always excluded for that provider, in either mode |

In manual mode, tap **Choose Items**, select or drag across thumbnails, and tap
**Save**. Then tap **Back Up to…**. Choosing items alone does not start a manual
upload. Automatic mode queues a backup after changes while the app stays open and
unlocked. Connecting a service alone does not upload; automatic jobs also run on
the next unlock/change. Wi-Fi is the default; cellular is optional.

**Never Upload** uses the same selection grid. Checked items are blocked. Blocking
removes them from manual selection. Unblocking in automatic mode makes them
eligible again; in manual mode they must be selected again. Choices take effect
on Save. Controls are disabled during a transfer—pause it before changing them.

From the main gallery, Select → cloud button applies bulk choices. An individual
item’s cloud/backup status sheet has the same controls. Newly imported duplicate
copies have new identities; a block applies to the existing library item, not to
all future files with similar content or names.

## What leaves the phone

Only eligible originals and their own thumbnails/Live Photo companions go into a
provider’s snapshot. Its encrypted catalog excludes other items’ filenames,
metadata, and selection rules. Recently Deleted is excluded from new cloud
snapshots. The cloud service can observe object sizes, counts, and transfer times.

The app verifies new encrypted objects by downloading them again and publishes
the recovery catalog last. Completed objects can be reused after interruption.
**Recheck All Remote Files** checks the current eligible set again. The status
records the last completed selection; it is not continuous remote monitoring.

**Blocking or deleting locally never purges older cloud backups.** Old catalogs
and encrypted objects remain in your account, including completed objects from
an interrupted upload. To remove old copies, manage them in the provider directly;
deleting shared objects may break older snapshots. Files backups always remain
full snapshots and are independent of MEGA/Blomp exclusions.

## Connect an account

- **MEGA:** uses the official SDK 10.20.0. Supply your own developer app key from [MEGA](https://mega.nz/sdk), your sign-in, and a two-factor code if required. The app key is not a recovery key. The session stays in the device Keychain. Transfer allowances can delay upload verification or recovery.
- **Blomp:** uses its OpenStack Swift account/container interface and requires HTTPS with valid certificates. The password stays in Keychain for token renewal. A previous credential-free storage-endpoint check failed certificate validation; live account operation remains unverified. The app does not bypass TLS errors.

The IPA contains no shared credentials or developer recovery key. Connecting the
same provider to another account resets local upload receipts. Provider choices
belong to the encrypted library; disconnecting does not erase the choices or
remote backups. No storage quotas are pooled and there is no two-way phone sync.

## Recovery

**Test Cloud Recovery** downloads and authenticates a snapshot without replacing
your library. New-library setup requires an empty installation, the source
recovery key, and saving/confirming a new destination recovery key. A selected-items
snapshot supplies only its selected items. In 0.7.0 these are re-encrypted under
the new destination key; future exports require that new key. Existing libraries
are never rotated by updating. New cloud/Files setup starts manual/empty for
uploads and preserves source Never Upload blocks. Old archives retain their keys.

The included offline recovery tool also accepts `.c84cloud` catalogs after you
download the complete provider folder with both `objects/` and `snapshots/` intact.
See [the recovery commands](BUILDING.md#recover-without-the-app).
