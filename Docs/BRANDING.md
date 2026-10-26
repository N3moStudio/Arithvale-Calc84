# Arithvale identity and compatibility

Arithvale is the visible product name. The calculator remains an everyday calculator; the private area remains Memories. No notification sender or notification copy exists in this version.

| Surface | Source |
| --- | --- |
| Name/version/build used by release verification | `Brand.json` |
| In-app name, calculator heading, version/support | `Sources/Calc84/AppBrand.swift` |
| Home Screen, system Photos prompts, backup type description | `Sources/Calc84/Info.plist` |
| IPA and product name | `Package.swift` |
| MEGA client identifier | `Sources/CalcMega/CalcMega.cpp` |
| Recovery utility and release packaging | `Scripts/recover.py`, `Scripts/package_release.py` |
| Public positioning | README, Docs/STORE-LISTING.md |

Do not replace internal strings just because they contain Calc84. Preserve `studio.n3mo.calc84`, Keychain services/accounts, `Calc84Library`, `Calc84Temporary`, preferences, encryption context `Calc84/v…`, archive magics `C84B0001/2` and `C84F0002`, `.c84backup`, `.c84cloud`, UTI `studio.n3mo.calc84.backup`, and cloud prefix `c84/v1/`. These are compatibility contracts. The target/module directory name Calc84 is internal.

An update must use the same signing identity and data container. A name change cannot migrate an unrelated installation automatically. Existing v1, v2 and cloud recovery checks remain in the test suite.
