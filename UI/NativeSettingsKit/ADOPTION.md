# Integrate safely into another app

## Before touching the app

1. Read its actual repository instructions, build configuration, settings source and data model. Locate existing theme/navigation components before introducing another system. This kit is native SwiftUI, not a web/Windows UI replacement.
2. Record the starting commit and dirty files. Keep unrelated work. Make a reversible, presentation-focused change on the receiving app's normal work branch; do not create a second clone just for the kit.
3. Copy [FEATURE-MAP.md](FEATURE-MAP.md) into the receiving app's docs and inventory **every existing setting/action**, including conditional and permission-dependent ones. Record storage keys and old/new locations. Mark values/actions unavailable for testing honestly.
4. Identify which existing components can simply adopt these colors/spacing. Prefer adapting an existing design system over keeping two competing ones. Reuse only the parts needed; do not remove features, dependencies or supported OS versions as incidental cleanup.

## Install and connect

Use either the local package or source-copy method in [README.md](README.md). Include required notices. Apply the style once around the existing settings navigation/presentation root. Do not wrap an existing settings NavigationStack in another stack. `NSKList` and `NSKAppearanceSettings` do not own navigation.

Use the current host bindings and command handlers:

```swift
NSKSection("Notifications") {
    Toggle("Allow alerts", isOn: existingNotificationsBinding)
    // Keep the host's permission status, errors, and settings link here too.
}
```

An appearance adapter can map **reads** from the host's existing model into `NSKTheme`/`NSKSurface`, and **explicit user writes** through its existing setters. Never initialize persistence in a view's body/onAppear or save a fallback on read. Supply both bindings to `NSKAppearanceSettings`; do not put permanent settings in the gallery's `@State` demo.

For existing apps with more themes, custom colors or different controls, retain those choices in a host appearance screen using the kit's components. The supplied eight-choice picker is optional; do not silently drop the host's extra cases. App-level theme installation beyond settings is a separate deliberate step; the environment modifier does not recolor UIKit views, maps, widgets or extensions automatically.

## Compatibility contract

- **Storage:** do not rename preference keys, IDs, database columns, Keychain groups, App Groups or bundle identifiers for visual polish.
- **Backups:** keep old decode/encode rules and old fields. The kit's optional `legacyValue` helpers know historical `abyss → bloom` and `theme → solid`; they do not perform a migration and return nil for unknown values. The host must retain its own unknown-value policy. Do not replace its Codable schema with kit enums.
- **Defaults:** kit starting values apply to new, explicitly adopted presentation. Existing stored values win. Do not reset user data to make a preview match.
- **State:** a route, recording, calculation, upload, purchase or edit keeps its original lifetime. Do not move that model into a short-lived settings row or recreate it on a theme change.
- **Permissions/actions:** keep real authorization requests, access gates, error paths, background policies, retries, cancellation and confirmation rules. Do not infer success from a visual toggle.
- **Navigation:** retain deep links, tab selection, dismissal semantics and restoration. If the host uses value-based routing, keep it. A cosmetic change does not authorize replacing its router.
- **Accessibility/localization:** keep semantic controls, readable hit targets, full accessibility Dynamic Type, VoiceOver state/value/labels and native RTL layout. Component String arguments accept host-localized strings. The sample picker/gallery's English labels are templates; localize them for a multilingual host before shipment.
- **Branding:** supply that app's icon and name. This kit contains no signing, alternate-icon switching, cloud helpers, pricing, website or Elsepin executable code.

## Small integration sequence

1. Adopt one non-destructive category with its original bindings. Test setting changes, reopening and persistence.
2. Apply the overview/grouping pattern. Every feature-map row must have a destination; test search/deep links to moved settings.
3. Add the appearance card and theme/surface adapter if requested. Keep state stable while changing themes and opening/closing editors.
4. Run the receiving app's appropriate regression tests, including old backup fixtures where affected. Run the kit's validation instructions. Do not disable failing tests to get a green result.
5. Inspect screenshots on a small phone, dark Ion, Bloom, accessibility5 and iPad/narrow window. Exercise Back/edge swipe, Cancel/Save and interrupted actions. Follow [VALIDATION.md](VALIDATION.md); report untested checks.
6. Record actual evidence and changed files in that app's handoff. Keep building IPAs, publishing and source pushes within the user's explicit scope.

## Keep future chats consistent

After copying the kit into `UI/NativeSettingsKit`, add this focused pointer to the **receiving app's** AGENTS.md (adjust the path if needed):

```markdown
For appearance/settings work, read UI/NativeSettingsKit/DESIGN.md and ADOPTION.md.
Preserve existing settings, storage, backups, permissions and feature behavior;
update the feature map before moving controls. Use compact rounded presentation,
task-based groups, the larger appearance card and native navigation. Native
compilation and screenshot/device checks are separate from portable validation.
Delegate only bounded supporting work when it saves effort; the lead verifies it.
```

A new chat only needs this pointer and the app's current handoff. It does not need the original long Elsepin conversation. Do not rewrite global instructions or installed skill manuals.

## Undo

Revert the app's integration commit and remove only its package/source references. Restore original view files; preserve the unchanged model/store. If an authorized migration was added separately, its rollback needs its own plan—the kit does not supply or authorize one.
