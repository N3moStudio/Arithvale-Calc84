# Arithen project guidance

For appearance/settings work, read `UI/NativeSettingsKit/DESIGN.md` and `ADOPTION.md`, then `Docs/SETTINGS-FEATURE-MAP.md` and `Docs/SETTINGS-ADOPTION.md`. The kit is a retained reference package, not a second runtime design system. Adapt presentation through Arithen's existing palette, AppearanceRoot, and real model bindings.

Preserve settings, saved keys/defaults, backup compatibility, permissions, access restrictions, cancellation and confirmations. Update the feature map before moving controls. Use compact rounded text once, task-based groups, the larger branded appearance card, and native navigation. The November 8 user decision makes Liquid Glass standard, removes its surface picker, and retires Titanium to Bloom; keep legacy values decodable and accessibility fallbacks intact.

Use installed Apple skills selectively. Do not reset branding or approved settings from old exploratory mockups. Keep native compilation, simulator/device layout and portable source checks distinct. Delegate sparingly and never send source or keys to an external AI service without authorization.

Build/deliver an IPA or publish only when requested. Keep build evidence in the workspace; for an explicitly requested IPA delivery use the user's current delivery folder and provide only the latest IPA for this project.
