# Arithvale 0.8.0 test - build 12

## What changed

- Native thumbnail-to-viewer zoom on iOS 18 and later, including a return source
  resolved from the currently viewed photo rather than the originally opened one.
  UIKit owns interactive transition lifecycle. iOS 17 keeps standard presentation.
- Settled-page state separate from requested navigation: cancelled swipes retain
  the visible item, and rapid Previous/Next taps preserve the latest request.
- Details is hidden until opened using Info or the dedicated Details handle.
  Its native medium/large sheet remains. Photo, PDF and video surfaces no longer
  share an app-wide upward Details gesture.
- Cached library filtering/grouping and cached selection mappings reduce work
  during drag selection. Only content/query changes rebuild the library sections.
- Grid layout changes retain the visible item's pixel offset where possible and
  use a short crossfade. Clear Glass has one moving navigation highlight.
- Backup preparation, authentication and import use explicit progress labels.
  Success still comes only from successful completion of the actual operation.

Clear Glass remains the default. All six layouts and the familiar calculator
remain available. This update includes the 0.7.0 fresh-key onboarding changes;
updating an existing library does not rotate its keys or modify old archives.

## Motion contract

- Horizontal viewer gestures belong to native paging. Zoomed images retain pan
  and pinch ownership; interactive viewer dismissal is disallowed while zoomed.
- Downward eligible zoom dismissal uses UIKit's transition and cancellation.
  Buttons remain available; there is no custom percent-driven transition engine.
- Page identity/playback changes after the pager completes. Cancellation restores
  the actual page, without discarding a newer explicit button request.
- Details has its own 44-point touch region, outside media controls.
- Native dismissal completion clears prepared originals and transient media.
  Lock clears immediately and hides the viewer before nonanimated dismissal.
- The grid retains bounded thumbnails for return transitions while the viewer is
  open. Inactivity, teardown and the existing privacy shield keep private images
  out of app-switcher snapshots. Memory pressure drops the thumbnail cache.
- Reduce Motion uses a non-zoom viewer transition, no custom grid crossfade and
  no animated navigation highlight. A live setting change updates native policy.

## Verification boundary

The release verification runner records Swift tests, independent Python recovery
tests, the native arm64 build, source hashes and IPA inspection in BUILD-RESULT.json.
Read the report in the matching release kit for the actual outcome.

No iPhone, simulator, Instruments trace or live cloud account was available for
this change. Frame pacing, gesture feel, native zoom interruption, VoiceOver focus,
large text, RTL and LiveContainer behavior require the manual matrix in
DEVICE-CHECKS.md. No 60/120 fps performance claim is made.

## Install and rollback

Update the existing LiveContainer entry/data container or the same signed app.
Keep an independently checked backup and its recovery key. Do not uninstall the
existing library to update. This release does not migrate the storage format;
the previous 0.7.0 package and source kit remain available locally for rollback.
