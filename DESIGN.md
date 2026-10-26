# Arithen · 0.9.0 design

Arithen uses the approved purple Aperture A icon. Purple is the initial glass
tint. Calculator keys, top controls, library filters/actions/navigation and the
viewer Details handle share `ArithenGlass`: native regular Liquid Glass on iOS
26+, translucent material on earlier systems, and opaque outlined controls for
Reduce Transparency or increased contrast. Nearby controls share a glass
container; photo content never becomes glass. All layouts now use the same
floating glass control language while preserving their content geometry.

Calculator and library appearance are separate. Users can select Plum, Neutral,
Blue, Mint, Rose or Amber, a still background, or their own video. The default
Purple Glow background is static. Videos loop silently for at most 30 seconds
using a 720p export, stop in Low Power Mode/Reduce Motion, and stop when covered,
inactive, or thermally limited. Library video sources stay encrypted at rest;
protected playback copies are discarded on leaving or locking. Calculator
backgrounds are intentionally visible before unlock and use separate storage.

The previous approved gallery geometry and motion behavior remain:

Implementation reference: the six interactive library previews and the calculator
preview approved October 23, 2026. The user explicitly selected **Clear Glass** as
the initial layout. Sample photographs, dates, counts, and the fake device shell
in those previews are not app content.

| Layout | Geometry | Navigation |
| --- | --- | --- |
| Clear Glass | 3 portrait columns, 0.85 aspect, 2 pt gaps | Floating glass pill |
| Photo Library | 3 square columns, 2 pt gaps | Floating glass bar |
| Nightroom | 2 portrait columns, 7 pt gaps, 12 pt inset/corners | Dark glass bar |
| Albums First | 2 columns of four-photo collage covers | Album overview first |
| Timeline | Month sections, large left photo and two stacked on the right | Floating glass bar |
| Contact Sheet | 4 square columns, 1 pt gaps, compact header | Bar with Add |

All six are persisted options in Appearance. The new galleryStyle preference
leaves the legacy libraryLayout preference untouched. New/unset galleryStyle
uses Clear Glass. Dynamic Type uses two columns for ordinary photo grids at
accessibility sizes; album covers stack into one column. Safe areas and adaptive
text replace the mockup’s fixed 360×720 device dimensions.

Native reusable collection cells, date scrolling, drag selection, contextual
menus and the existing adjacent-media pager remain. Only the control layer uses
glass, with native regular Liquid Glass on iOS 26+ and regular material on older
iOS. Reduce Transparency and increased contrast use an opaque outlined pill.
Photos and metadata never form translucent backgrounds for one another.

Motion uses native ownership: the collection grid presents a UIKit-hosted SwiftUI
viewer, with iOS 18 zoom matching the current item's UUID. iOS 17 retains a standard
full-screen presentation. The viewer's requested page is distinct from the page
whose transition completed; playback and return identity follow the completed page.
Details stays in a native medium/large sheet, opened from its button or dedicated
44-point handle. The image surface has no competing swipe-up recognizer.

Compatible grid changes preserve the first visible item's pixel offset. Layout
changes use a 0.15-second crossfade; the Clear Glass selection highlight uses a
0.22-second spring with 0.08 bounce. Reduce Motion omits both effects and uses a
non-zoom viewer transition. Privacy shielding/lock never waits for an animation.

The root header is Library / Select / + / Settings. Filters are All, Photos,
Videos and Favorites; Files and Recently Deleted live in Albums. Settings starts
with Backups, Cloud Copies, Privacy & Access, and Appearance. Lock and About
are secondary actions there. Private filenames stay behind the calculator code.

The calculator matches the supplied arrangement: shared delete/AC capsule, % and
÷; 7–9/×; 4–6/−; 1–3/+; sign/0/decimal/=. History is session-only, and mode and
angle controls use the top-right menu. Hold Equals retains its original entry
behavior. The default calculator is dark with blue operators; library appearance
is independent. Mint, Lilac and Amber are also available.

## Backup addition

Received encrypted copies are visible after unlock, with a stable + → From a
Backup route. Full archive authentication happens in an isolated encrypted
preview directory before item selection. The commit re-encrypts selected resources
with the current library key, using fresh nonces and new identifiers. Existing
assets are unchanged and one atomic index write publishes the new items. Failure
or cancellation before that commit removes staged files. A process crash can
leave unreferenced encrypted resources; it cannot publish a partial index.

Duplicates compare original content and media type/size, including Live Photo
motion; derived thumbnails and filename differences do not produce extra copies.
Dates, favorites, albums and paired-resource relationships are preserved. Source
cloud blocks follow the item; source selections never grant upload permission.
Current provider modes still apply. Sources in Files are never deleted by import.

## Verification limits

Automated tests and native compilation do not establish final iPhone rendering,
glass behavior, frame timing, VoiceOver, or LiveContainer handoff. Compare the
installed build against the approved previews using DEVICE-CHECKS.md.

## Earlier implementation notes (historical)

# Arithvale · 0.5.0 design notes

The vault now follows the supplied Memories / My Eyes Only screenshots: photographs occupy the screen, with a compact header and direct controls. This replaces the earlier iOS glass/gallery treatment. The calculator remains a separate surface with a familiar four-column keypad, rounded keys, right-side operators, current-entry clear, and separate scientific/backspace controls. The blue palette is retained.

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

After importing from Photos, an Import Complete sheet offers Keep Originals (the primary action) and optional Delete Imported Originals. It names the eligible count, reports partial failures, and explains Recently Deleted and iCloud propagation. Dismissal keeps originals. Deletion is never remembered as an automatic preference; Files imports offer a separate counted Trash confirmation after coordinated snapshots and source-content checks; unsupported providers and changed originals are kept, and folders are never removed. The vault rechecks copies before presenting the system's deletion confirmation. This source update still needs on-device permission, cancellation, Live Photo, and lifecycle checks.

Save Backup to Files is the primary action. It prepares an encrypted snapshot and opens the system save picker, without requiring a remembered directory bookmark. Cancellation does not set a success state. A saved copy is read back and compared with the prepared snapshot. If the provider does not allow verification, the UI asks for Test a Backup and leaves the current library marked as needing backup.

Connecting a folder is optional. It opens Files without forcing a potentially stale starting URL. Folder selection is held with scoped access until the picker dismisses, then validated off the main thread with a coordinated write/read/remove probe. A failed choice preserves the previous connection. Automatic backups remain optional and require a connected folder.

Only a completed, checked save updates the last-backup timestamp and filename. Selecting a folder never does. The app's library format, recovery key, and existing backups remain compatible. Cloud upload and uninstall recovery require phone testing and an external copy.

## Cloud backup

Settings → Backup & Recovery has a MEGA & Blomp entry with overall status, separate service connections, a progress indicator, and Pause. Each provider defaults to manual/empty selection. Automatic-all is optional per provider; Never Upload overrides both modes. Cellular transfers are optional and off initially. Provider screens offer Back Up, Recheck All Remote Files, and Test Cloud Recovery. Item previews show each provider's last completed backup inclusion without adding badges to every gallery tile.

On an empty installation, Restore from Cloud reconnects a service, lists completed catalogs, and requests the source recovery key plus acknowledgment/confirmation of a new destination recovery key and a new local calculator code. Source archives keep their old key; future destination exports use the new one. Setup never replaces an existing library. The UI explains that transfers need an open, unlocked app and that backups are separate copies rather than live multi-phone synchronization.

MEGA uses direct SDK sign-in, with an application key field for this personal test build. Blomp requires a valid HTTPS storage endpoint; its documented host failed certificate checks during development. Neither provider has been tested with a real account.

## Verification limits

Fresh automated results are recorded by Scripts/verify_release.py and shipped in BUILD-RESULT.json. Device rendering, Photos confirmation, gestures, provider permissions, app lifecycle and LiveContainer behavior require the phone checks; compilation is not a device pass.

## 0.4.0 interaction changes

The everyday calculator uses five rows, with extra functions behind the calculator mode button. Hold Equals after a directly entered code to request access; taps calculate only. Setup owns its recovery key through child navigation. Import progress/retry/cancel precede automatic backups, which are coalesced after changes. The gallery opens a current-item full-screen browser with Previous, Next and Favorite; native Live Photo playback retains a still fallback. Video labels follow Dynamic Type and include media type/duration/favorite in VoiceOver. Settings includes About, storage capacity and recovery-test identity. Private JPEG export is an explicit derivative choice.


## 0.5.0 recovery chooser

Test and Restore share a chooser that imports an encrypted copy into protected temporary storage. Browse a Folder Instead presents filenames inside Arithvale, bypassing the native file-type filter. Selection validates archive magic instead of trusting an extension; recovery still authenticates every encrypted record. Cancel preserves the previous selection. UI behavior in LiveContainer remains a device check.
