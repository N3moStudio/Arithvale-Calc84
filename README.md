# Calc 84 · 0.3.0 alpha

A scientific calculator with an encrypted photo, video, and file library. Native SwiftUI for iPhone. This is a test build, not a production security guarantee.

This update adds Cloud Backup settings, individual encrypted uploads, recovery tests, and per-item backup status. It also includes the Memories gallery and optional deletion of verified imported originals. Existing library encryption and recovery keys are unchanged. **Cloud account connections and iPhone behavior still need device testing.**

## First use

1. Install **Calc 84 0.3.0.ipa** through SideStore. The IPA is unsigned; your installer signs it. Test a direct installation first; test your existing LiveContainer setup separately if you intend to use it.
2. Enter **160160**, then **=**. There is no long-press entry.
3. Save the randomly generated **recovery key somewhere separate** and confirm its last eight characters.
4. Choose your own **6–12 digit calculator code**. The public starter cannot protect your library. From now on, type your chosen code and **=**.
5. Import disposable photos and a video. Choose **Keep Originals** or **Delete Imported Originals** after the encrypted copies are checked. Nothing is deleted automatically; Files imports keep their sources.
6. Open **Settings → Backup & Recovery → Save Backup to Files**. Choose your own iCloud Drive folder or another Files provider outside the app/LiveContainer. This path needs no remembered folder permission.
7. **Test a Backup** using that file and your recovery key. Also check that the provider actually uploads it. To reuse a destination, optionally **Connect Backup Folder**, then **Back Up to Connected Folder**. Choosing a folder does not itself save a backup.

Keep originals until the tests in [DEVICE-CHECKS.md](DEVICE-CHECKS.md) pass.

## Cloud Backup

Open **Settings → Cloud Backup**. Connect your own Blomp or MEGA account, then tap **Back Up Now**. Both destinations receive the same library; their quotas are not pooled. Automatic backup after changes is optional and off initially. Wi-Fi is the default. Keep the app unlocked while transferring; locking pauses the job.

- Each original, thumbnail, and Live Photo companion stays encrypted. Original filenames, dates, and albums stay inside the encrypted catalog. Service operators can still observe object sizes, counts, access, and backup times.
- New objects are uploaded separately and downloaded once to check their SHA-256. Previously verified objects are reused after a presence/size check. **Recheck All Remote Files** downloads them again. A local status cannot detect later remote deletion or corruption until another check.
- The catalog is published last. An interrupted job can reuse completed files. Deleting from the phone does not erase cloud backups; old catalogs and their objects remain and consume space.
- A photo's **Backup Status** is in its preview toolbar. It reports inclusion in the last completed backup, including the thumbnail and paired resources.
- On an empty install, enter 160160 and =, then **Restore from Cloud**. Connect the account, find a saved backup, and enter its original Calc 84 recovery key. Choose a new calculator code. Restoration does not merge with or overwrite an existing library.
- **Test Cloud Recovery** downloads and authenticates a backup in a temporary library. Allow up to three times the backup size in spare phone storage during recovery. Save to Photos uses the original capture date; Recently Added can still show today.

**MEGA:** uses the official SDK 10.20.0. This personal test build asks for a developer application key from [MEGA's SDK page](https://mega.nz/sdk), plus your normal account sign-in and optional two-factor code. The app key is not either recovery key. No borrowed developer key is included. The session is stored in the phone's Keychain. MEGA transfer limits can delay a large backup or restore.

**Blomp:** uses its documented OpenStack Swift authentication and your existing email-named container. Only HTTPS with normal certificate validation is accepted. On October 17, 2026, a credential-free check of the documented storage hostname failed certificate validation from this environment. The app refuses an insecure connection; this integration must not be described as operational until an account round-trip succeeds. Blomp's password is held in the phone's Keychain for token renewal.

No account was created or accessed during development. The cloud engine is tested using a disposable local service fixture; live-provider login, quotas, interrupted real transfers, and phone restore remain unverified. Keep an independent encrypted backup in Files too.

## Included

- Arithmetic, parentheses, powers, percentages, trigonometry, logarithms, degree/radian modes. Not a TI-84 emulator.
- Numeric calculator entry, change-code settings, and a separate random recovery key.
- **Memories grid:** tall, four-column tiles, continuous native scrolling, pinned month headings, and a month/year handle that follows the actual visible photos. Drag the handle to scrub through the library. Two or three columns are also available.
- **Photos Layout:** year/month/day grouping. Settings control layout, grid size, date source, and order.
- Photos, videos, albums, favorites, name/album search, multi-select, and Recently Deleted. Nothing is automatically purged.
- Original media bytes, stored capture dates, and supported Live Photo image/video pairs.
- Optional deletion of just-imported Photos originals, with system confirmation. Failed, inaccessible, or edited/extra-resource imports are excluded. Copies are checked again before requesting deletion.
- Image zoom, video playback, PDFs, Save to Photos, original-file export, and the Share/AirDrop sheet.
- Encrypted snapshots, optional backup after changes while open, recovery testing, and a separate offline computer recovery tool.
- A flat, readable gallery with search, selection, and a fixed action bar. Native cell reuse, bounded thumbnail caching, light/dark mode, large-text density adjustment, and an accessible date handle.
- App-switcher cover while inactive; return to the calculator and lock when backgrounded.

## Reinstalling, moving phones, or changing installers

The local library is inside the app. **Uninstalling can delete it.** A normal update with the same application identity is intended to retain it; back up before updating or changing signing accounts.

Recovery needs **an external .c84backup file or a complete cloud backup, plus its recovery key**, not the original phone or Keychain. For a Files backup on an empty installation: 160160 and = → Restore an Existing Backup → choose file → enter secret → choose a new calculator code. Re-select the external backup folder afterward; its access permission does not automatically move. For a cloud backup, use Restore from Cloud and reconnect the service instead.

Forgot the code on the same phone? **Help → Restore or Recover Library** requires your recovery secret. Restore never replaces an existing library. Version 0.1 libraries/backups still use their original long password as that secret.

If switching Apple Accounts, transfer the encrypted backup using a computer, external drive, Files, or AirDrop. Keep the secret separately. Backups are encrypted, but their existence and sizes are discoverable.

## Dates and sharing

Photo-library imports use the asset's stored creation date where permission allows. Files imports read supported embedded dates. Missing dates fall back to import date; absent time zones can be ambiguous.

**Save to Photos** sets the saved capture date. Photos may still show the copy in Recently Added. **Files/AirDrop** retain original bytes and embedded metadata, but receiving apps may sort by receipt time.

Imports preserve original resources, not a rendered copy of every Photos crop/filter/edit. Photos-only adjusted dates, favorites, and albums are not necessarily embedded in the original file. Live Photos preview as stills in the vault; Save to Photos recreates the pair. Files/Share export both resources, which the recipient may not pair automatically.

Exports are unencrypted and may include GPS information.

**Deleting imported originals:** Photos deletion can sync to other devices through iCloud Photos. Originals may remain in Photos → Recently Deleted; Calc 84 does not empty it. This choice is for the current import only and does not become an automatic setting. Keep a tested external backup before relying on the vault as your only copy.

## Alpha limits

- iOS 17+ build target. Computer tests and native compilation are checked; installation, Keychain, permissions, Photos, UI rendering, and lifecycle privacy still need phone testing.
- 4 GiB per file; under 64 GiB per library/backup; 5,000 encrypted records, including thumbnails and Live Photo companions. Visible-item capacity is therefore lower.
- New files use bounded 1 MiB encrypted chunks; legacy files remain limited to 128 MiB.
- Files backups are **full snapshots**. Cloud backups reuse unchanged encrypted objects. Automatic backup is off by default, runs only while open, and can consume time, battery, and storage. Old snapshots remain until you delete them.
- No automatic removal of originals, live multi-phone sync, biometric unlock, screenshot prevention, or undetectability guarantee.
- The OS, installer, and any LiveContainer host remain trusted dependencies. Temporary plaintext is used for imports/previews/exports and cleaned on completion or next launch after a crash.
- There is no developer-held recovery key or password reset. Keep two backup copies when files matter.

## Recover without the app

Install Python 3.10+ and the dependency once:

```sh
python -m pip install -r Scripts/recovery-requirements.txt
python Scripts/recover.py "Library.c84backup" --verify-only
python Scripts/recover.py "Library.c84backup" --output "Recovered originals"
```

On Windows, **Recover Vault.cmd** prompts for the file, a new output folder, and the secret after Python/dependency installation. Recovery runs offline and supports old/new backups. It writes originals plus metadata.json. Add --include-deleted for Recently Deleted. Recovered output is unencrypted.

For cloud recovery without the app, download the entire `c84/v1/<library ID>` folder from the provider, keeping `objects/` and `snapshots/` together. Give `recover.py` a `.c84cloud` file inside `snapshots/` instead of a `.c84backup`. The same recovery key is required. The tool checks and assembles the encrypted records offline before extraction.

## Build

With Swift 6, xtool, and the iOS 27.1 Darwin SDK in WSL/Linux or macOS:

```sh
python Scripts/prepare_mega.py
CALC84_CORE_ONLY=1 swift test -j 4
xtool dev build --configuration release --ipa
```

Run sequentially: both use .build. Output: xtool/Calc84.ipa. Bundle identifier: studio.n3mo.calc84. Linux tests use pinned Swift Crypto 4.3.1; iPhone uses CryptoKit/CommonCrypto.

`prepare_mega.py` downloads checksum-pinned MEGA source and iOS arm64 dependencies into ignored Vendor folders. They are not required for core-only tests. Native builds require them. No credentials are part of the build. The native MEGA dependency bundle is device-only; simulator builds need matching simulator libraries.

The app's iOS linker settings explicitly record SDK 27.1 while keeping the minimum OS at 17.0. This corrects this cross-build toolchain's fallback SDK metadata so native appearance follows the modern SDK. If changing SDKs, update the linker declaration and package check to match the SDK actually used.

For independent recovery tests: set C84_FIXTURE_DIR to a new persistent folder, run the Swift fixture test, then Scripts/test_recovery.py with the same environment setting.

See [SECURITY.md](SECURITY.md), [DESIGN.md](DESIGN.md), and [DEVICE-CHECKS.md](DEVICE-CHECKS.md).
