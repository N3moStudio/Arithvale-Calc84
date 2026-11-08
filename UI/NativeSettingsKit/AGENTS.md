# Native Settings Kit: adoption rules

- Read [DESIGN.md](DESIGN.md) for approved presentation, [ADOPTION.md](ADOPTION.md) before integration, and [VALIDATION.md](VALIDATION.md) before claiming readiness. Consult [PROVENANCE.md](PROVENANCE.md) when copying source/notices.
- This directory is independent. Do not modify Elsepin or another app merely because its source was used as a reference. No IPA, publication, hosting change or account change is authorized by these files.
- Keep production code in `Sources/NativeSettingsKit/`; example-only state belongs in `Examples/`. Do not import demo settings into a production target.
- Host models own values/actions. Preserve storage keys, backup schemas, access restrictions, async cancellation and permission flows. Complete the receiving app's [feature map](FEATURE-MAP.md) before moving controls.
- Appearance must not recreate feature views/navigation or reset active edits. Avoid `.id(theme)`, global appearance proxies, gesture overrides, hidden native Back controls and custom replacements for system toggles/text input.
- Keep compact rounded presentation, accessibility scaling, the larger identity card and task-based grouping. Use spacing/dividers inside editors, not a separate card around each small control.
- Use the host's installed native engineering/design skills when relevant. This kit supplements them; it does not replace skill manuals or repository rules.
- Keep delegation sparse: one bounded supporting task only when it saves more work than dispatch/review cost. Lead agent owns integration and verification. Never send credentials or proprietary source to an external model without the user's authorization.
- Run the portable check after edits. Native compilation, simulator appearance/accessibility, actual gestures, signing and battery are separate evidence. Never silently treat source checks as native validation.
