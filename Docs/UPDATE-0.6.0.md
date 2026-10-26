# Arithvale 0.6.0 · build 10

- Six remembered layouts, with **Clear Glass initially selected**: Photo Library,
  Nightroom, Albums First, Timeline, and Contact Sheet remain available.
- Familiar calculator geometry, combined delete/AC capsule, session history,
  scientific mode, and four accent colors.
- Four simple Settings destinations, plus visible version/build information.
- Received-backup card, + → From a Backup, full authentication and item preview,
  and an atomic addition into the existing encrypted library.
- Exact-original duplicate detection, Live Photo resources, dates, albums,
  favorites and per-provider exclusions preserved during backup addition.

Update the existing app/container. The bundle identifier and backup formats stay
compatible. This is a test prerelease; rendering, gestures and LiveContainer
interactions still need an iPhone check. The IPA contains no personal library.

Initial empty-install restore uses the source library’s key. **Adding** a backup
to a library uses the current library’s key for added items. These are different
operations; neither silently replaces the current library or changes its key.
