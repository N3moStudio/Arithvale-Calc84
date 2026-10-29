# Changelog

## 0.10.0 · Library Tools

**October 28, 2026 · Build 14 · Test build · iOS 17+**

- Add a Backup Center with Create, Import and Test actions; separate Files/MEGA/
  Blomp coverage, working-space estimates and direct Files-share instructions.
- Bind recovery-test results to the exact archive digest or provider snapshot;
  older tests cannot certify newer backups.
- Add optional on-device text recognition for photos/screenshots, an encrypted
  local search index, pause/resume indexing, and search across names/albums/tags/text.
- Add encrypted storage usage, largest-item review and exact-duplicate scans.
  Removals require explicit selection; recoverable deletion remains the default.
- Add an import review before Photos/files/folders enter the vault. Report unknown
  provider sizes honestly and keep runtime free-space checks.
- Add multiple album memberships, tags, pinned albums, custom covers, compatible
  archive metadata and privacy-filtered provider snapshots without duplicating media.
- Add loop start/length, crop positioning, a chosen Low Power Mode still frame,
  silent previews and re-editing for personal video backgrounds in both areas.
- Preserve existing keys, bundle identity, archive encryption, cloud exclusions,
  Clear Glass default, purple branding and all six gallery layouts.
- Add migration, recovery, storage, search authentication, duplicate and wallpaper
  policy tests. Physical-device and live-provider checks remain pending.

[Detailed changes, usage, privacy and compatibility](Docs/UPDATE-0.10.0.md)

## 0.9.0 · Arithen — Glass & Personal Backgrounds

**October 26, 2026 · Build 13 · Test prerelease · iOS 17+**

Arithvale is now **Arithen**. This release brings the approved purple Aperture A
identity, glass controls throughout the calculator and library, and separate
personal video backgrounds for each area. Clear Glass remains the default;
all six gallery layouts remain available.

### New identity and glass controls

- Apply the Arithen name to the Home Screen, in-app identity, permission text,
  backup descriptions, current documentation, and release assets.
- Install the approved purple Aperture A app icon and matching in-app icon.
- Add native Liquid Glass to calculator keys, History, mode and Settings
  controls, library actions, filter chips, floating navigation, selection controls,
  and the viewer's Details handle on iOS 26+. Earlier iOS versions use translucent
  material. Reduce Transparency and increased contrast use opaque controls.
- Keep the familiar calculator keypad, shared backspace/AC capsule, scientific
  buttons, and session history. A top-right gear opens Calculator Settings.
- Offer separate Plum, Neutral, Blue, Mint, Rose, and Amber tints for the
  calculator and library. Purple is the default.

### Personal video backgrounds

- Choose a personal video from Photos for the calculator, or an already-imported
  encrypted library video for the private area. The selections are independent.
- Prepare a reduced-size 720p loop from up to the first 30 seconds, with no audio
  track. Original files stay unchanged. Sources above 256 MB are rejected with a
  trimming suggestion.
- Pause background playback in Low Power Mode, Reduce Motion, Reduce
  Transparency, increased contrast, or serious/critical thermal conditions.
- Stop playback while the surface is covered or inactive. Prevent decorative
  playback from keeping the screen awake or routing to an external display.
- Add background softness, replacement, removal, and static-background options.
  The initial Purple Glow background is still; video is opt-in.
- Keep private background sources encrypted. Protected temporary playback copies
  are cleared on leaving or locking. Missing/deleted sources use a still fallback.
- Keep calculator backgrounds separate from encrypted library storage. They are
  visible before unlock and excluded from system backup. Background selections
  are local preferences and are not part of portable library backups.

### Where to customize

- **Calculator:** top-right gear → Glass Tint & Video Background.
- **Library:** Settings → Appearance → Library Glass & Video Background.
  Import a video with Library → + → Photos & Videos before selecting it here.

### Compatibility and recovery

- Preserve bundle ID `studio.n3mo.calc84`, Keychain services, encrypted library
  paths, backup formats, cloud prefixes, and the received-backup inbox.
- Updating an existing library does not rotate its recovery key. Existing
  `.c84backup` archives retain their original keys.
- Choosing a library video as a background does not change its cloud selection
  or Never Upload exclusions. Removing the background does not delete the video.
- The optional Files picker is not claimed fixed for every LiveContainer host.
  Files → Share → LiveContainer → Arithen remains the alternative receipt route.

### Validation

- **92 Swift tests passed**, including playback-policy combinations, video ID
  validation, duration bounds, and background-softness bounds.
- **12 independent Python recovery tests passed.**
- Native iPhone arm64 release build and source-bound IPA inspection passed.
- App icon, name, version/build, expected settings, architecture, backup type,
  privacy manifest, and the copied IPA checksum were checked.
- iPhone/LiveContainer rendering, imports, gestures, power-mode transitions,
  battery use, VoiceOver, and real MEGA/Blomp account transfers remain device
  checks. The downloadable IPA is unsigned.

### Updating

Download `Arithen-0.9.0-test.ipa` and update the existing signed app or LiveContainer
entry/data container after saving a checked external backup and its recovery key.
Keep your existing calculator code. On an empty installation, enter `160160` and
hold `=` to begin setup, then save the new recovery key and choose your own code.

## 0.8.0 · Gallery Motion · Build 12

Included in 0.9.0; not previously published as a separate GitHub release.

- Add native thumbnail-to-viewer zoom on iOS 18+, including a return transition
  to the currently viewed photo; retain standard presentation on iOS 17.
- Separate settled-page state from requested navigation so canceled swipes and
  rapid Previous/Next taps keep the correct item and playback state.
- Keep metadata behind Info or the dedicated Details handle, away from photo
  panning, PDF scrolling, Live Photo interaction, and video scrubbing.
- Cache gallery filtering, grouping, and selection mappings; preserve the visible
  item's offset where possible when switching layouts.
- Add explicit backup preparation, authentication, and import progress labels.
- Respect Reduce Motion in transitions, layout changes, and navigation highlights.

[Detailed 0.8.0 notes](Docs/UPDATE-0.8.0.md)

## 0.7.0 · Fresh Keys for New Libraries · Build 11

Included in 0.9.0; not previously published as a separate GitHub release.

- Generate a fresh recovery secret, encryption key, salt, and library identity
  for every new destination, including setup from existing Files or cloud backups.
- Require acknowledgment and last-eight-character confirmation of the new key.
- Authenticate sources with their original keys, then re-encrypt into an isolated
  staged destination before committing a complete new library.
- Combine multiple backup sources, skip exact-content duplicates, and preserve
  dates, albums, favorites, deleted status, Live Photo associations, and cloud blocks.
- Preserve existing libraries and their keys during updates and later backup imports.
  Source archives remain unchanged; legacy formats remain readable.

[Detailed 0.7.0 notes](Docs/UPDATE-0.7.0.md)

## Earlier releases

See [GitHub Releases](https://github.com/N3moStudio/Calc-84/releases) for 0.6.0
and earlier assets and historical release notes.
