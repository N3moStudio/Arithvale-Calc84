# Appearance and settings standard

## The intended look

Compact, readable native controls; intentional space between tasks; a roomier appearance card at the top. Related controls share a section. A simple label, slider or toggle does not each need its own rounded container.

This carries the owner's approved Elsepin design direction. It is not a screenshot-perfect skin for every possible app. Adopt each component where it serves the receiving app's task; preserve that app's brand and functionality.

## Overview to detail

```text
Settings                         native inline title
[Search, revealed by scrolling]  native drawer, never an overlay

[app art]  MAKE IT YOURS          the intentionally larger card
           Your space. Your way.
           Bloom · Solid                       >

Category relevant to THIS app
  icon  Setting                       value    >
  icon  Related setting                        >

Another category
  icon  Setting                                >

Tap a row → a focused native detail page → native Back / edge swipe
```

Use the host's existing categories where they work. Suggested starting categories are Look & feel, app-specific behavior, Your data, and Help & updates. Do not add empty categories, Elsepin's connection/movement settings, or features that the app does not have. Keep meaningful independent choices; this is organization, not a preset-only replacement.

In detail pages, put everyday controls first. Put genuinely optional advanced controls in one useful disclosure group. Avoid several disclosures just to shorten a screenshot. Do not bury essential errors, recovery, Stop, accessibility controls or permission actions.

## Typography, density and touch

- Rounded system font throughout adopted views. The compact policy reduces ordinary Dynamic Type by one category, with a floor at xSmall; accessibility1–5 pass through unchanged. Applying the kit modifier again inside the same subtree does not compact it again.
- Keep semantic text styles (`body`, `subheadline`, `headline`, `title2`) so text scales. No hard-coded tiny fonts, text truncation of settings names, `minimumScaleFactor` as a layout fix, or cap on accessibility sizes.
- Ordinary native rows: minimum 52pt list row; custom row content has a 44pt minimum hit area. Primary buttons: at least 48pt; longer labels may grow.
- Related rows have no artificial vertical gaps; sections use 24pt spacing. The overview leaves 16pt above scroll content so the native search/title region has space.
- Larger identity card: 70pt artwork, title2 headline, 16pt vertical padding; stack artwork/text vertically at accessibility sizes. Keep this contrast with smaller surrounding rows.
- Use leading/trailing alignment, native controls and flexible layout. Verify narrow widths, landscape, iPad windows, long translations and right-to-left content.

## Themes and surfaces

The eight supplied themes are Glacier, Afterhours, Porcelain, Ion, Ember, Bloom, Blueprint and Titanium. Each has a full canvas, surface, text, muted, accent and button-label palette. Ion's preferred appearance is dark; it is not a bright map with only a lime tint. Afterhours, Ember and Titanium also prefer dark; Bloom, Blueprint and Porcelain prefer light; Glacier follows the inherited system scheme.

For **new apps adopting this standard**, start at Bloom + Solid. Existing saved choices remain owned by the app: do not reset them just to match the template. Do not add font or density selectors to a new appearance page. Existing unrelated controls must remain unless removal is separately authorized.

Show themes as larger selectable tiles. Show only two surface choices in this order: **Solid**, **Liquid Glass**. No Theme Default choice. Glass is for custom floating controls and system navigation treatment; settings content remains opaque for readability. Solid does not promise to override iOS-owned alerts, keyboard or all system chrome.

Reduce Transparency or Increase Contrast forces an opaque custom floating background. Older systems use regular material when glass is selected. Theme changes must preserve drafts, selections, search, navigation and ongoing app work. Never use `.id(theme)` or a new root view to force a refresh.

Surface controls and themes are independent. Switching a theme must not reset the surface. Icons are a separate host capability: preserve its own icon collection, restrictions and signing behavior. No Elsepin logo is included.

## Navigation, editing and feedback

- Keep the app's current navigation owner. Do not put a second NavigationStack inside a pushed detail page. A standalone modal may own a stack.
- Use native Back and edge-pop. Do not hide Back and then add a broad drag gesture; that interferes with maps, sliders and scrolling.
- Search uses native `.searchable(... .navigationBarDrawer(displayMode: .automatic))` where appropriate. The host supplies destinations/keywords; do not display a decorative search box that searches nothing.
- Draft editors keep Cancel/Save and save only on confirmation. Immediate preferences keep their immediate semantics. Preserve unsaved-change prompts and destructive confirmations.
- Keep errors, permission feedback, disabled-state explanations and progress where needed. Remove repeated tutorials or decorative filler, not actionable information.
- No perpetual animation, polling, haptics loop or animation on every keystroke. The included button style only changes opacity on press. Retain any useful native interaction already present.

## Native reference and limits

The closest executable reference is [SettingsGallery.swift](Examples/SettingsGallery.swift), with Bloom, Ion, narrow-phone and maximum-accessibility previews. These are **preview definitions, not captured native screenshots**. Capture real screenshots in the receiving app before declaring a visual match. An HTML mockup is not evidence of SwiftUI layout.

Principles consulted: Apple's [Settings](https://developer.apple.com/design/human-interface-guidelines/settings) (task-specific settings stay near their task), [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [Typography](https://developer.apple.com/design/human-interface-guidelines/typography), and [Materials](https://developer.apple.com/design/human-interface-guidelines/materials). Compact sizing and the larger identity card are the owner's design choices, not a claim that Apple mandates this exact style.
