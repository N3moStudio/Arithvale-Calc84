# Arithvale · 0.4.0 design notes

The vault now follows the supplied Memories / My Eyes Only screenshots: photographs occupy the screen, with a compact header and direct controls. This replaces the earlier iOS glass/gallery treatment. The calculator remains a separate surface; its requested Apple Calculator redesign has not been implemented in this revision.

## Gallery

- Flat background, compact Memories heading, lock/back chevron, Search, Select.
- Underlined All / Photos / Videos / Favorites tabs; Albums includes Recently Deleted.
- Four columns of tall tiles by default, approximately 1:1.65. One-point dividers, square edges, no decorative cards or large hero heading.
- New month headers separate the continuous grid. Headers stay visible while their section scrolls.
- A right-edge drag handle uses actual content height. Its month/year badge is derived from visible cells, not an equal division of months. It appears while scrolling and fades afterward.
- Video durations appear at the lower left. Selection/favorite marks overlay the image.
- Import, Files, and Settings are in a fixed, opaque bottom row. Selection replaces these with bulk actions. No glass overlay.
- Photos grid remains an optional square-tile view with years/months/days grouping.

## Scrolling and access

UICollectionView reuses native cells; thumbnails are loaded only as needed and cached with a 32 MiB budget. Reused/disappearing cells cancel work, and leaving the gallery clears visible decrypted images and its cache. Legacy image fallback is limited to 8 MiB. Large originals use their encrypted thumbnails.

Large text uses two gallery columns. The scroll handle has a 44-point-wide interaction area and VoiceOver increment/decrement actions. Native scrolling remains interruptible; dragging the date handle updates immediately without an animation gate. Reduce Motion disables the badge fade.

The layout uses the user's screenshot direction. Accessibility principles from the previously consulted Apple Look and Apple Motion skills remain applicable; this is not an attempt to imitate Apple's Photos interface.

## Backup flow

After importing from Photos, an Import Complete sheet offers Keep Originals (the primary action) and optional Delete Imported Originals. It names the eligible count, reports partial failures, and explains Recently Deleted and iCloud propagation. Dismissal keeps originals. Deletion is never remembered as an automatic preference; Files imports do not offer it. The vault rechecks copies before presenting the system's deletion confirmation. This source update still needs on-device permission, cancellation, Live Photo, and lifecycle checks.

Save Backup to Files is the primary action. It prepares an encrypted snapshot and opens the system save picker, without requiring a remembered directory bookmark. Cancellation does not set a success state. A saved copy is read back and compared with the prepared snapshot. If the provider does not allow verification, the UI asks for Test a Backup and leaves the current library marked as needing backup.

Connecting a folder is optional. It opens Files without forcing a potentially stale starting URL. Folder selection is held with scoped access until the picker dismisses, then validated off the main thread with a coordinated write/read/remove probe. A failed choice preserves the previous connection. Automatic backups remain optional and require a connected folder.

Only a completed, checked save updates the last-backup timestamp and filename. Selecting a folder never does. The app's library format, recovery key, and existing backups remain compatible. Cloud upload and uninstall recovery require phone testing and an external copy.

## Cloud backup

Settings → Backup & Recovery has a MEGA & Blomp entry with overall status, separate service connections, a progress indicator, and Pause. Backup after changes and cellular transfers are optional and off initially. Provider screens offer Back Up, Recheck All Remote Files, and Test Cloud Recovery. Item previews show each provider's last completed backup inclusion without adding badges to every gallery tile.

On an empty installation, Restore from Cloud reconnects a service, lists completed catalogs, and requests the original recovery key plus a new local calculator code. Recovery never replaces an existing library. The UI explains that transfers need an open, unlocked app and that backups are separate copies rather than live multi-phone synchronization.

MEGA uses direct SDK sign-in, with an application key field for this personal test build. Blomp requires a valid HTTPS storage endpoint; its documented host failed certificate checks during development. Neither provider has been tested with a real account.

## Verification limits

Fresh automated results are recorded by Scripts/verify_release.py and shipped in BUILD-RESULT.json. Device rendering, Photos confirmation, gestures, provider permissions, app lifecycle and LiveContainer behavior require the phone checks; compilation is not a device pass.

## 0.4.0 interaction changes

The everyday calculator uses five rows, with extra functions behind 2nd. Hold Equals after a directly entered code to request access; taps calculate only. Setup owns its recovery key through child navigation. Import progress/retry/cancel precede automatic backups, which are coalesced after changes. The gallery opens a current-item full-screen browser with Previous, Next and Favorite; native Live Photo playback retains a still fallback. Video labels follow Dynamic Type and include media type/duration/favorite in VoiceOver. Settings includes About, storage capacity and recovery-test identity. Private JPEG export is an explicit derivative choice.
