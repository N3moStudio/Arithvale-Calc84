# Provenance and source notices

Prepared at the owner's request for reuse in their apps, 7 November 2026. No Elsepin file was edited and no app runtime, credentials, backups or icon assets are included.

Reference snapshot: Elsepin commit `4f6c3e17b5b3162f1a70a84ab24402d2994b5fd6` (build 74 source plus handoff documents).

- The palette data in `NSKTheme.swift` is adapted from `Shared/ShiftAppearance.swift`.
- Compact typography and the two-surface design reflect `AppearancePresentation.swift` and `AppearancePolicy.swift`, used under the owner's authorization for this kit.
- Settings hierarchy, the larger identity label and simple detail groups reflect `ShiftDesign.swift`, `SettingsView.swift` and the approved build-74 design direction. Components are separated from app-specific state rather than copied with that runtime.
- Retain the original [MIT notice](LICENSES/Elsepin-MIT.txt) for inherited applicable material and the original [new-additions scope notice](LICENSES/Elsepin-New-Additions.txt). These files are preserved verbatim. This bundle does not relicense third-party work, erase attribution, or grant broader rights over restricted original additions. No new blanket distribution license is asserted here.

The guide supplements the installed Axiom SwiftUI/Apple design guidance. It does not copy their manuals or change their rules. Apple's primary API references used during authoring include [glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)), [list section spacing](https://developer.apple.com/documentation/swiftui/view/listsectionspacing(_:)) and [minimum list row height](https://developer.apple.com/documentation/swiftui/environmentvalues/defaultminlistrowheight).
