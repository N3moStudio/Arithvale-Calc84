# Arithvale 0.4.1 / build 5

- Select mode supports a one-finger horizontal sweep, continuing across rows and date sections. Starting on a selected item deselects. Reversing restores the initial selection outside the current range. Holding at the top/bottom scrolls; vertical swipes still scroll normally. Individual taps, Select All and VoiceOver remain available.
- Backup testing and restore use a native file picker that allows unknown file types, so LiveContainer does not need to register the guest app's custom type. Tap the .c84backup file itself. Folder/incorrect-extension choices get an explanation; archive authentication still happens during test/restore. File access remains retained through the operation.
- Public calculator Help now contains only calculator instructions. Its VoiceOver action is named Hold Equals. Hidden 160160 + hold Equals opens setup/recovery, including after a forgotten code; an existing library still requires its recovery key before access can be recovered. The personal code continues to unlock normally.
- Encryption, bundle identity, Keychain records, original files and backup formats are unchanged.

Restoring an older backup retains its original recovery key. New files added to that restored library use the same library key. A newly created library receives a new recovery key; changing a calculator code does not rotate encryption keys. This update does not merge libraries or re-encrypt old backups under a new key.

Physical phone/LiveContainer verification remains required. Automated selection logic and the full build are checked separately. See the test kit's BUILD-RESULT.json for the exact tests and source/IPA hashes.

API references: [gesture failure ordering](https://developer.apple.com/documentation/uikit/uigesturerecognizer/require(tofail:)), [document picker](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller/init(foropeningcontenttypes:ascopy:)), [generic file-system type](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/item).


## Verified result

48 Swift core tests and 11 independent Python recovery tests passed with zero failures. The iOS arm64 release build and IPA inspection passed. Package metadata identifies version 0.4.1, build 5. Phone/LiveContainer gesture and picker checks remain pending.

Test kit: Releases/Arithvale-0.4.1-test-808b7de8/. IPA SHA-256: 808b7de8ff625983a70229742357b62183009d4648ce3318a1095d364a60301c.
