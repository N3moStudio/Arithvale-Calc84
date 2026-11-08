# Native Settings Kit

Version 0.1.0 · 7 November 2026 · reusable SwiftUI source + adoption guide

The approved Elsepin appearance, separated into small presentation components for other iPhone/iPad apps. It includes **Glacier, Afterhours, Porcelain, Ion, Ember, Bloom, Blueprint and Titanium**, compact rounded typography, solid settings surfaces, optional floating Liquid Glass, a larger appearance card, native settings navigation examples and plain detail-editor groups.

**Start here:** read [DESIGN.md](DESIGN.md) for the look, then [ADOPTION.md](ADOPTION.md) before editing a receiving app. Give another chat [PROMPT.md](PROMPT.md) along with this whole folder or ZIP. [VALIDATION.md](VALIDATION.md) states what has actually been checked.

## What this is

- An independent local Swift package, or four Swift files that can be copied into an app that does not use packages.
- A shared visual vocabulary for settings **and other screens**: theme colors, typography, button styling, editor grouping and floating surfaces. Feature-specific layouts still need deliberate adaptation.
- New-app starting choices: **Bloom + Solid**, rounded text and one-step compact ordinary text. System accessibility text sizes remain untouched.
- An appearance page with eight theme tiles and **Solid first / Liquid Glass second**. No Abyss, Theme Default, font selector or text-size selector in this page.
- Native `List`, `Section`, `NavigationLink`, `Toggle`, `TextField` and toolbar patterns. No custom replacement navigation system.

## What remains with the receiving app

Every feature, permission, subscription/gate, saved preference, backup field, error, confirmation, account, app icon and service. This kit stores nothing, requests no permissions, contacts no server, starts no tasks or timers, and installs no global UIKit appearance changes. Existing apps keep their current persisted settings/default semantics until a deliberate migration is authorized. The guide does not grant permission to remove controls.

## Add it locally

Requires an iOS 17+ SwiftUI app. No third-party dependencies. Xcode 15+ can compile the base components; the guarded Liquid Glass branch requires the iOS 26 SDK/Xcode 26+ (Swift 6.2+). Earlier SDKs/OS versions use regular material for a selected glass surface. Read [ADOPTION.md](ADOPTION.md) before changing an older app's deployment target—do not raise it just to install this kit.

1. Copy this folder into the receiving repository, for example `UI/NativeSettingsKit`. Keep its documents and notices.
2. In Xcode, add that local package and link **NativeSettingsKit** to the app target. For XcodeGen or another generator, update its source-of-truth project configuration.
3. Alternatively copy **all four files** under [Sources/NativeSettingsKit](Sources/NativeSettingsKit) into the app target, retain notices, and omit `import NativeSettingsKit` from usage code. Use one installation method only.
4. Apply `nativeSettingsAppearance(theme:surface:)` once at the settings navigation/presentation root. It scopes colors/type to that subtree. The host retains its window-level light/dark policy.
5. Wrap existing destination views/controls; connect their original models. Start with one small category and verify behavior before continuing.

Example composition (inside the host's existing navigation container):

```swift
NSKList {
    NSKSection("Your data") {
        NavigationLink {
            ExistingBackupSettingsView() // the real app's unchanged behavior
        } label: {
            NSKRow("Backup", symbol: "externaldrive")
        }
    }
}
.navigationTitle("Settings")
```

The complete [SettingsGallery](Examples/SettingsGallery.swift) has searchable categories, appearance selection, an immediate toggle, and a Cancel/Save draft editor. Its values are **in memory only**. Never ship demo actions as real features.

## Where to find things

| File / symbol | Responsibility |
|---|---|
| [NSKTheme.swift](Sources/NativeSettingsKit/NSKTheme.swift) | Eight light/dark palettes, theme display preference, optional legacy-name read adapters |
| [NSKAppearance.swift](Sources/NativeSettingsKit/NSKAppearance.swift) | Scoped environment, compact rounded text, accessibility-aware floating surface |
| [NSKComponents.swift](Sources/NativeSettingsKit/NSKComponents.swift) | `NSKList`, `NSKSection`, `NSKRow`, `NSKIdentityLabel`, `NSKEditorGroup`, `NSKPrimaryButtonStyle` |
| [NSKAppearanceSettings.swift](Sources/NativeSettingsKit/NSKAppearanceSettings.swift) | Theme tiles and two surface choices, using host-provided bindings |
| [FEATURE-MAP.md](FEATURE-MAP.md) | Inventory template to prevent settings/behavior from disappearing during adoption |
| [AGENTS.md](AGENTS.md) | Focused instructions for chats editing or adopting this kit |

## Check / undo

Run `python scripts/validate_bundle.py` for portable content/contrast checks. Native instructions and remaining device checks are in [VALIDATION.md](VALIDATION.md). Local validation is not an iOS compilation or screenshot result.

To undo adoption, revert the receiving app's presentation-only commit, remove its package reference/copied files, and restore the original views. No kit-owned persisted state needs deletion. **Elsepin itself was not changed. No IPA or release is created by this kit.**

Attribution and retained source terms: [PROVENANCE.md](PROVENANCE.md).
