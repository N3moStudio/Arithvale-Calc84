# Arithen 0.10.0 · Library Tools

Build 14 adds five improvements while keeping the purple identity, Clear Glass
default, all six layouts, calculator behavior, and existing recovery keys.

## Backup Center

Open **Library Settings → Backups**. Create Backup, Import Backup and Test Backup
are the first three actions. Files, MEGA and Blomp have separate status rows.
Cloud rows distinguish chosen items from Never Upload and unselected items.
Changed libraries conservatively show eligible items needing a current backup.

A completed save/transfer and a successful recovery test are separate facts.
Recovery results match an exact Files SHA-256 or cloud snapshot ID, including the
provider. Testing an older snapshot does not certify a new one. Older receipts
without these identifiers need a new save/test before this stronger status can
be displayed. Recovery history retains the most recent 40 exact checks locally.

The Files share instructions are available directly in Backup Center. Shared
backups still appear on the library; adding another one keeps the destination
library and key. The optional document picker is not claimed fixed for every
LiveContainer host. Files cloud-upload completion must still be checked in Files.

## Private text search

Open **Library Settings → Private Text Search** and enable **Search Text in
Photos**. Apple Vision reads photo/screenshot text on the device, one image at a
time with bounded decoding. The saved index is authenticated and encrypted using
the library key with a separate encryption context. Names, albums and tags remain
searchable with this option off.

Indexing is opt-in, with a manual **Index New Photos** action after new imports.
It stops at lifecycle/cancellation boundaries and pauses before processing the
next photo when Low Power Mode, thermal limits or another library operation
requires it. Completed batches are retained; unreadable images can be retried.
Recognition can miss words. The first image of an animated asset is analyzed;
video frames, faces and semantic descriptions are not indexed.

Each photo's text is limited to 4 KiB. The encrypted sidecar has a 24 MiB bound,
is local to this installation, and is excluded from the portable archive and
provider snapshots. Restore rebuilds it only after opt-in. Turning the option
off removes its saved index. Locking clears the UI's searchable text. As with
other local deletion, this is not a forensic-erasure guarantee.

## Storage and import review

Open **Library Settings → Storage** for actual encrypted-library usage, totals
for photos/videos/files, Recently Deleted, the search index, and available phone
space. Largest Items includes each item's paired motion and thumbnail storage.

**Find Exact Duplicates** authenticates and hashes original resources. Live Photo
motion participates; derived thumbnail differences do not. It never selects or
deletes anything automatically. Preview copies, select the ones to remove, and
move them to Recently Deleted. Only separately confirmed permanent deletion frees
that space. Existing external/cloud backups remain unchanged.

Imports now have a review screen. Files/folder sizes are estimated before import;
Photos/providers that cannot supply sizes say so rather than inventing a number.
Restore/test/setup surfaces show working-space estimates. Runtime checks remain
in place because free space can change. Ordinary import still has its separate,
optional post-import original-removal review.

## Albums and tags

Select items and tap the album button for **Albums & Tags**. Add or remove several
album memberships and comma-separated tags. No media is duplicated. Limits are
24 memberships and 32 tags per item. Use an album's **…** button to pin it or
choose a cover from its contents. A missing/deleted cover falls back to a collage.

Optional manifest fields preserve old archives: the former single album becomes
the first membership. Albums, tags, pins and covers survive new backups and
restore/import; cross-library imports remap cover IDs. Exact duplicate imports
merge memberships/tags. Cloud snapshots contain only relevant album preferences
and never reference an excluded item's cover. Existing cloud opt-in/block rules
remain authoritative. Avoid downgrading: older app versions do not preserve fields
they do not understand.

## Background editor

Both appearance screens offer **Edit Loop, Crop & Still Frame**. Choose the start,
up-to-30-second duration, crop position, and still-frame time. Preview the silent
loop before saving. Low Power Mode and Reduce Motion show the chosen still frame.
Existing thermal, visibility, contrast and transparency safeguards remain.

Calculator wallpapers retain a protected local source copy for later editing,
plus the smaller silent loop. This area is public before unlock; its files are
excluded from system backup. Replacing/removing the background removes both
copies. An older 0.9 wallpaper can only edit the clip that version retained;
choose the original again to access a later part of it.

Library wallpapers continue using encrypted library videos. The editor's and
player's temporary plaintext copies are cleaned after completion/cancellation,
leaving, or lock. They are never copied into calculator wallpaper storage.
Background selections/edits remain local appearance preferences, outside portable
library backups. The 256 MB source limit remains.

## Validation

The release kit binds automated core and independent Python recovery checks,
native arm64 compilation, and IPA inspection to the exact tested source. See its
BUILD-RESULT.json for final counts and checksum. The added tests exercise legacy
decode, organization migration, key-preserving membership edits, cloud metadata
filtering, duplicate signatures, encrypted-index authentication/bounds, exact
recovery identity, storage arithmetic, and wallpaper range/crop calculations.

Physical iPhone/LiveContainer UI, OCR quality, crop/frame accuracy, power changes,
gesture behavior, cleanup timing, accessibility and live-provider round trips
remain device checks. The supplied test IPA is unsigned.
