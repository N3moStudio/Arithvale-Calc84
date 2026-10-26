# Arithvale 0.5.2 · picker presentation correction

Version 0.5.2, build 8. This targets a reported immediate close of the Files picker
in both fresh-install recovery and Test a Backup on 0.5.1. The user also reported
that enabling LiveContainer's Fix File Picker did not resolve it on 0.5.1.

## What changed

- The recovery form owns the picker state and presentation. The sheet is no longer
  attached to a Section that SwiftUI can rebuild independently.
- Removing a document controller now detaches its delegate and invalidates its
  callback. It no longer sends a synthetic Cancel result into presentation state.
- Each opening receives a new identifier. A late callback from an older picker
  cannot close or change a newer selection.
- Real selection and Cancel callbacks still complete once. Interactive dismissal
  is handled by the owning sheet. Selected-file copying starts after dismissal.
- An early close now leaves a readable notice on the recovery form. No recovery
  key or backup contents are included in that notice.

The backup format, encryption, library identity and automatic background lock are
unchanged. An old backup still needs its original recovery key.

## What to check on a phone

Confirm **0.5.2 (8)** under Calculator → … → Help → About. On a fresh installation,
open recovery and try both file and folder selection. Repeat in an existing
library's Test a Backup screen. Wait before selecting, scroll, open a subfolder,
Cancel, reopen, and select a backup. In folder mode, tap Open and then select the
filename in Arithvale. Confirm the selected file survives a later canceled attempt.

If it still closes, report whether it returns to the recovery form or calculator,
and the notice shown on the form. These identify different lifecycle paths.

The cleanup defect and unstable presentation ownership were identified in source.
This environment has no iPhone/LiveContainer session or iOS simulator: automated
core/recovery tests and a successful native compilation do not reproduce this UI
failure or establish that the reported device issue is resolved. The release's
BUILD-RESULT.json records the checks actually completed.

References:

- [Apple: document picker cancellation callback](https://developer.apple.com/documentation/uikit/uidocumentpickerdelegate/documentpickerwascancelled(_:))
- [Apple: SwiftUI controller teardown](https://developer.apple.com/documentation/swiftui/uiviewcontrollerrepresentable/dismantleuiviewcontroller(_:coordinator:))
- [LiveContainer: app-specific picker setting](https://github.com/LiveContainer/LiveContainer#fix-file-picker--local-notification)
