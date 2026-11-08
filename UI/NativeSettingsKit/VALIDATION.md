# Validation and integration checks

## Evidence for kit 0.1.0

Prepared on Windows on 7 November 2026. No local Swift/Xcode executable is available. No cloud build, IPA, release or change to Elsepin is part of this task.

The portable validator checks all eight light/dark palettes, normal-text contrast pairs, local documentation links, required files and accidental runtime/storage dependencies. A source review checks navigation/state ownership and accessibility sizing. These are **not native compile or visual acceptance evidence**. The four XCTest contract tests are provided for the next suitable Apple build environment; their results must not be claimed until run.

```powershell
python scripts/validate_bundle.py
```

The final portable result is recorded in [validation-result.txt](validation-result.txt). It measures solid token pairs, not arbitrary colors behind translucent surfaces, system control rendering, color-blind usability or the whole app. All seven Swift files also passed a Tree-sitter Swift grammar parse. That checks syntax only, not API availability, type correctness, linking or executable behavior. The optional [syntax checker](scripts/validate_swift_syntax.py) reproduces this check with `tree-sitter==0.26.0` and `tree-sitter-swift==0.7.4` installed in an isolated Python environment.

## Native validation when an Apple environment is available

Use the receiving app's supported build/test workflow first. This kit requires an iOS SDK; plain `swift test` on Windows/Linux is not a SwiftUI validation path. Do not create a paid build service or assume the user has a Mac.

On a Mac with Xcode, open the local Package.swift. Build the **NativeSettingsKitExamples** scheme for an iOS simulator to type-check both components and gallery. Run **NativeSettingsKit** tests on a specific installed iOS simulator. Available schemes can be checked with `xcodebuild -list`; destinations with `xcodebuild -showdestinations -scheme NativeSettingsKit`.

Equivalent commands from the package folder (replace the simulator ID with an actual available one):

```bash
mkdir -p .validation
set -euo pipefail
xcodebuild -scheme NativeSettingsKitExamples \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .validation/DerivedData CODE_SIGNING_ALLOWED=NO build \
  2>&1 | tee .validation/native-build.log
# Stop if this pipeline fails. pipefail preserves the compiler/build failure.

xcodebuild -scheme NativeSettingsKit \
  -destination 'platform=iOS Simulator,id=REPLACE_WITH_INSTALLED_SIMULATOR_ID' \
  -derivedDataPath .validation/DerivedData \
  -resultBundlePath .validation/NativeSettingsKit.xcresult test \
  2>&1 | tee .validation/native-tests.log
```

Use a fresh result-bundle path for repeat runs. If package-only test schemes are unavailable in the host setup, add the test file to its existing iOS test target and run that target instead. Do not count that as a pass until it executes. Keep full logs and original failure status; summarize meaningful errors/warnings. No packaging or signing is needed for these checks.

## Review the real receiving app

1. **Feature preservation:** verify every item in its completed feature map. Change a preference and reopen; Cancel a draft; exercise permission denial and error handling; run an existing old-backup fixture if settings persistence/backup touches this screen.
2. **Navigation/state:** open a child page and edge-swipe back; open/dismiss a sheet; change a theme while a draft exists. Search results/deep links must still reach the real setting. Theme changes cannot reset active app work.
3. **Visual:** Bloom/Solid, dark Ion, Liquid Glass, Reduce Transparency, Increase Contrast and largest accessibility size. Check a narrow phone, landscape/iPad, long strings and RTL. Inspect screenshots; do not infer layout from a successful build.
4. **Accessibility:** native Toggle announces value/action, navigation rows announce title/value, theme choice announces selected state, decorative artwork is hidden, text wraps, hit targets remain usable.
5. **Regression:** run the host's relevant tests and any checks its instructions require. This presentation kit makes no measured battery, provider, signing or physical-device claims.

Record actual evidence and remaining gaps in that app's handoff. Avoid building an IPA unless requested.
