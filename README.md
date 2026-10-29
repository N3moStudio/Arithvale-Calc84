<p align="center">
  <img src="AppIcon.png" alt="Arithen app icon" width="112">
</p>

<h1 align="center">Arithen</h1>
<p align="center"><strong>Familiar calculations. A private library.</strong></p>
<p align="center">0.11.0 testing · iOS 17+ · SwiftUI · MIT licensed</p>
<p align="center">
  <a href="SETUP.md">Get started</a> &nbsp;·&nbsp;
  <a href="Docs/UPDATE-0.11.0.md">What’s new</a> &nbsp;·&nbsp;
  <a href="CHANGELOG.md">Changelog</a> &nbsp;·&nbsp;
  <a href="Docs/CLOUD-BACKUP.md">Cloud choices</a> &nbsp;·&nbsp;
  <a href="Docs/BUILDING.md">Build from source</a>
</p>

Arithen is a working calculator with an encrypted library for photos, videos,
Live Photos, and files. It keeps the everyday calculator familiar and gives you
control over which memories leave your phone. Previously **Arithvale / Calc 84**, by **N3mo Studio**.

## Make it yours

- **Calculate naturally.** A familiar keypad with glass keys, purple accents, clear and backspace controls, and optional scientific functions.
- **Make the glass yours.** Choose separate glass tints and your own video backgrounds for the calculator and library. Movement stops in Low Power Mode and with Reduce Motion.
- **Keep your memories.** Choose Clear Glass, Photo Library, Nightroom, Albums First, Timeline, or Contact Sheet. Search, favorite, and drag across items to select them.
- **Choose your cloud copies.** Select items separately for MEGA and Blomp, or enable automatic backup for a provider. A provider’s Never Upload list takes priority.
- **Import, then decide.** Import Photos, files, or folders. Keep the originals, or explicitly approve moving verified originals to Photos Recently Deleted or the file provider’s Trash.
- **Recover independently.** Save encrypted backups to Files, test recovery, and recover on a computer using the included offline tool.

## The latest

**0.11.0** adds quick privacy controls and reduces unnecessary library work:

- **One-tap lock:** return to the calculator from the library header or media viewer.
- **Private backup reminders:** opt in under Settings → Backups. Reminders appear
  inside the unlocked library, open Backup Center, and can be snoozed until tomorrow.
- **Large imports:** publish grid updates in batches, reuse search indexes, cancel
  obsolete thumbnail work, and retry unsuccessful file imports from their review.
- **Power-aware work:** defer automatic backups in Low Power Mode or high heat,
  pause text indexing when inactive, and limit speculative photo preparation.
  Covering the library pauses its background without repeatedly re-encoding it.

Original deletion remains optional and rechecks committed encrypted copies before
Photos confirmation or supported-provider Trash. Backup formats and keys stay compatible.
Battery and scrolling improvements still require measurement on an iPhone.

[Read the 0.11.0 update notes →](Docs/UPDATE-0.11.0.md)

**0.10.0** makes the library easier to organize and recover:

- **Backup Center:** create, import and test from one place. See separate Files,
  MEGA and Blomp coverage; recovery checks belong to the exact tested snapshot.
- **Private Text Search:** opt in to reading words inside photos/screenshots on
  the phone. The local search index is encrypted and never uploaded.
- **Storage:** review large files and exact duplicates, see encrypted storage
  usage, and check working-space estimates before importing/restoring.
- **Albums & Tags:** put one photo in multiple albums without extra copies,
  add tags, pin albums and choose covers.
- **Background editor:** choose the loop section, crop position and Low Power
  Mode still frame independently for the calculator and library.

[Read the 0.10.0 update notes →](Docs/UPDATE-0.10.0.md)

The **0.9.0** design remains: Arithen’s approved purple Aperture A icon and glass on
calculator keys, library controls, filters, and the viewer’s Details handle.
Native Liquid Glass is available on iOS 26+; iOS 17–25 uses translucent material.
Reduce Transparency and increased contrast use opaque controls.

Open the calculator’s **top-right Settings → Glass Tint & Video Background**,
or the library’s **Settings → Appearance → Library Glass & Video Background**.
Choose Plum, Neutral, Blue, Mint, Rose, or Amber. Your own video can become a silent,
reduced-size loop of up to 30 seconds; the source stays unchanged. Library
backgrounds come from already-encrypted library videos. Settings for these two
areas stay separate, and backgrounds stop playing when covered or inactive.

The gallery/viewer improvements from **0.8.0** remain: native zoom transitions on
iOS 18+, settled-page tracking, a dedicated Details handle, cached gallery
sections, and scroll-position preservation when changing layouts. Physical-device
checks are still required for glass appearance, playback, battery use, and gestures.

The **0.7.0** recovery improvements remain: every new library gets a fresh recovery key, including setup from
existing Files or cloud backups. Use each source’s old key to read it, save and
confirm the new destination key, then create the library. Future backups use
that new key, even when they contain the same photos. Existing libraries and
old archives keep their keys; later imports do not rotate the destination key.

All six approved gallery designs remain available. **Clear Glass opens
first**; choose another under **Settings → Appearance** and it stays selected.
The calculator keeps circular keys, a shared backspace/AC capsule, and the familiar
number arrangement. Purple is the default glass tint.

Settings starts with **Backups**, **Cloud Copies**, **Privacy & Access**, and
**Appearance**, followed by **Storage** and **Private Text Search** under Library
tools. Version and build are visible there.

Shared backups appear on the unlocked library as **Backup received**. Tap it,
or **+ → From a Backup**, enter the original recovery key, preview the contents,
and choose items to add. Exact original-content duplicates are skipped; Live
Photo motion counts too. Added items are encrypted using the current library’s
key. Its existing items and identity stay in place. Source cloud exclusions are
carried over; source upload selections never opt items into a new provider.

Use **Files → Share → LiveContainer → Arithen** to receive a backup. The Files
picker remains an optional route; its reported host-specific issue is not claimed
fixed by this update. After a successful addition the received copy is cleared,
leaving the original backup in Files available to share again.

Your existing library identity and recovery key stay compatible. The IPA contains
the app, not anyone’s photos, recovery key, or cloud credentials.

[Read the update notes →](Docs/UPDATE-0.9.0.md)

## Get Arithen

Use a verified IPA from this repository’s test
[Releases](https://github.com/N3moStudio/Calc-84/releases). Sign and install it
with your chosen installer, or import it into your existing LiveContainer setup.
The supplied IPA is unsigned; compatibility depends on your iOS version and installer.

For first use, enter **160160** and **hold =**. Save the generated recovery key
separately, then choose your personal calculator code. Ordinary taps on = calculate.

Updating? Save and test an external backup first, then update the same app/data
container. Uninstalling or replacing that container can remove its local library.

[Follow the short setup guide →](SETUP.md)

## Know where your copies are

| Destination | What it contains |
| --- | --- |
| This phone | The encrypted local library in private app storage |
| Files backup | A full encrypted `.c84backup` snapshot, including Recently Deleted |
| MEGA / Blomp | Only that provider’s eligible items and their related resources |
| Photos / Share export | Ordinary, unencrypted copies you explicitly save or share |

**Never Upload stops future uploads of the selected library items.** It does not
erase old cloud backups or automatically recognize separate copies imported later.
Cloud backups are snapshots, not two-way sync. Automatic jobs run while open and
unlocked. Each cloud provider starts in manual mode with nothing selected.

[Cloud setup and limitations](Docs/CLOUD-BACKUP.md) · [Security and storage](SECURITY.md)

## Tested—and what still needs a phone

The release kit records automated Swift tests, independent Python recovery tests,
an iPhone arm64 build, and IPA inspection. The exact results and checksum are in
its build report. LiveContainer interactions, Photos permissions, provider Trash,
Keychain behavior, and real MEGA/Blomp round trips require device testing.

This remains a test build. There is no developer-held recovery key or password
reset. Keep an external backup and its original recovery key.

[Phone testing checklist](DEVICE-CHECKS.md) · [Source map](Docs/PROJECT-MAP.md)

## Open to everyone

Use it, change it, share it, or help make it better under the [MIT license](LICENSE).
Keep the applicable copyright and dependency notices. The software is provided as is.

Built with SwiftUI, CryptoKit, and the official MEGA SDK. Independent of Apple,
MEGA, and Blomp. This repository keeps its original URL and internal compatibility
identifiers so existing libraries and backups continue to work.
