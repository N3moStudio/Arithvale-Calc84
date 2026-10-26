# Arithen 0.9.0 · glass and personal backgrounds

This update applies the approved **PA1 Aperture A** logo and the **Arithen** name.
The purple identity carries through the app, permission text, backup descriptions,
release packaging and current public documentation. Bundle ID, Keychain services,
library paths, backup formats and the existing received-backup inbox are preserved.

## Calculator

The top-right gear opens Calculator Settings. Choose **Glass Tint & Video Background**
to set Plum, Neutral, Blue, Mint, Rose or Amber glass independently of the library.
The keypad keeps its familiar arrangement. Keys, History, mode and Settings controls
use native Liquid Glass on iOS 26+, with a material fallback on iOS 17–25.

Choose **Your Video** from Photos. The app makes a silent, reduced-resolution loop
from the first 30 seconds; the original is unchanged. Sources above 256 MB are
rejected with a trimming suggestion. The calculator background is visible before
unlocking, so this picker never offers private-library media.

## Private library

Open **Settings → Appearance → Library Glass & Video Background**.
Choose a video already imported into the encrypted library. Import a new one with
**Library → + → Photos & Videos** first. The selected video's existing cloud
choices still apply; choosing it as a background never changes those choices.

The original remains encrypted. Playback uses a protected, temporary reduced-size
copy while this area is visible and unlocked. Playback copies are removed on
lock, leaving the screen, or background/inactive transitions. Missing/deleted
videos fall back to a still background. Removing a background selection does not
delete the library item.

Header actions, filter chips, selection controls and navigation use glass.
The media viewer's native toolbars and Details handle support the same visual
direction. Photos and videos themselves remain unobscured. Clear Glass stays
the default and all six layouts remain available.

## Motion and readability

- Low Power Mode immediately pauses background playback.
- Reduce Motion, Reduce Transparency and increased contrast pause background motion.
- Serious/critical thermal conditions also pause playback.
- Covered screens and inactive scenes do not play a wallpaper.
- Video sound is muted, external playback is disabled, and backgrounds cannot keep the screen awake.
- A softness slider maintains a scrim over video; accessible glass fallbacks use opaque surfaces.
- Purple Glow is a static default. Video is opt-in.

Calculator videos live in protected app storage excluded from device backup;
they are appearance assets, not encrypted-library content. Library wallpaper
selection is device-local and references an encrypted library item; the choice
itself is not restored by a library backup. The underlying media follows normal
backup policy.

## Validation boundaries

Automated tests cover playback gating across all power/visibility/accessibility
combinations, invalid video identities, duration limits and scrim limits.
Final source-bound verification passed: **92 Swift tests**, **12 independent
Python recovery tests**, native iPhone arm64 release build, and IPA inspection.
The release's `BUILD-RESULT.json` records the exact source hashes and IPA checksum.

Static icon checks cover PNG dimensions, profile and opacity. The approved artwork
is integrated through this project's existing PNG/xtool route. Icon Composer was
not available on this Windows host; no layered .icon file or Composer validation
is claimed.

Physical iPhone/LiveContainer appearance, video imports, immediate Low Power Mode
response, gestures, thermal behavior and battery usage remain device checks.
A successful build does not establish those outcomes.

Native material references:
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [Glass tint and interaction](https://developer.apple.com/documentation/swiftui/glass)

