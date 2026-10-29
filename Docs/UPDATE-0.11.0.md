# Arithen 0.11.0 · Privacy & Efficiency

Build 15 is an update to the existing library. Keep the same installation/container
to keep its data. Clear Glass and the purple theme remain the defaults.

## Quick privacy exit

Tap the lock in the library header or the photo/video viewer to lock the library
and return to the calculator. Existing app-switcher masking remains in place.
Locking cancels pending imports and transfers; already committed copies remain.

## Import, verify, then choose

The import review offers **Keep Originals** and an optional deletion action with
the exact eligible count. Encrypted copies are verified again before originals
can be removed. Missing or damaged Live Photo resources block deletion.

Photos supplies the system confirmation and Recently Deleted behavior. Files use
the provider's Trash only when supported; changed originals stay, and folders are
never deleted. Failed imports can be retried directly from either review. This
preserves the existing deletion protections rather than changing encryption.

## Simple backup reminders

Enable **Settings → Backups → Private Backup Reminders**. A reminder appears only
inside the unlocked library when it has changes and no recorded Files backup, or
the last recorded save is at least seven days old. Tap it to open Backup Center,
or tap its close button to snooze for 24 hours. No Lock Screen notifications are sent.

A recorded save is not proof that a cloud provider still has the file. Files and
provider coverage remain separate. Existing Create, Import and Test actions remain
available; this update adds no new setup or guided restore requirement.

## Large libraries and power use

- Imports update the grid at most four times a second, plus the final result;
  every successful file is still committed individually before being offered for deletion.
- Search changes reuse metadata documents and album lists. Thumbnail tasks cancel
  when their cells leave the screen instead of continuing avoidable decode work.
- Automatic backup waits for state changes rather than polling an open import
  review. Low Power Mode, inactivity and serious/critical heat defer new automatic
  work; manual backup remains available.
- Optional full-photo neighbor preparation stops under power/thermal limits.
  The current photo/video remains available. Text indexing pauses on inactivity
  or power limits and can be resumed from Private Text Search.
- A covering sheet pauses the library background while retaining its prepared
  loop. Entering with motion disabled prepares a still frame without exporting a
  video loop. Locking/inactivity still clears private background resources.
- Repeated imports do not rewrite already-dirty backup receipts for every item.

These changes remove concrete work, but no battery percentage, frame-rate gain or
physical-device acceptance is claimed. Follow [device checks](../DEVICE-CHECKS.md)
for Low Power Mode, transitions, restore compatibility and provider behavior.

## Compatibility and validation

The bundle identifier, recovery keys, backup format and provider exclusions are
unchanged. Existing archives still use their existing recovery keys.

The build pipeline runs core tests, independent recovery tests, an iOS arm64 build
and source-bound package checks. See the delivered build evidence for actual
results. An unsigned IPA needs the user's signing installer or LiveContainer;
automated checks do not establish real-device or live-provider behavior.
