# Arithen identity and compatibility

Arithen is the visible product name on the Home Screen, inside the app, and in current public documentation. The private area is called Library. No notification sender or notification copy exists in this version.

| Surface | Source |
| --- | --- |
| Name/version/build used by release verification | `Brand.json` |
| In-app name, calculator heading, version/support | `Sources/Calc84/AppBrand.swift` |
| Home Screen, system Photos prompts, backup type description | `Sources/Calc84/Info.plist` |
| IPA and product name | `Package.swift` |
| Approved purple Aperture A artwork | `Docs/Brand/Arithen-PA1-approved.png`, `Docs/Brand/design-approval.yaml` |
| App icon and in-app identity | `AppIcon.png`, `ArithenIdentity.swift`, `Resources/ArithenIcon.png` |
| Glass colors and separate surface preferences | `ArithenGlass.swift`, `CalcCore/AppearancePolicy.swift` |
| MEGA client identifier | `Sources/CalcMega/CalcMega.cpp` |
| Recovery utility and release packaging | `Scripts/recover.py`, `Scripts/package_release.py` |
| Public positioning | README, Docs/STORE-LISTING.md |

Do not replace internal strings just because they contain Calc84. Preserve `studio.n3mo.calc84`, Keychain services/accounts, `Calc84Library`, `Calc84Temporary`, preferences, encryption context `Calc84/v…`, archive magics `C84B0001/2` and `C84F0002`, `.c84backup`, `.c84cloud`, UTI `studio.n3mo.calc84.backup`, and cloud prefix `c84/v1/`. These are compatibility contracts. The target/module directory name Calc84 is internal.

An update must use the same signing identity and data container. A name change cannot migrate an unrelated installation automatically. Existing v1, v2 and cloud recovery checks remain in the test suite.

Keep `ArithvaleIncomingBackup` as the on-disk inbox location so a received backup
survives this rename. Historical release notes keep the name used in that release.
`Scripts/create_icon.py` exports the approved artwork without redrawing it. This
Windows build uses the existing flat PNG route; a layered Icon Composer asset
has not been produced or validated.
