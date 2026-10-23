# Arithvale 0.5.1 · recovery and browsing

Version 0.5.1, build 7. This follow-up addresses a reported restore-picker failure
in LiveContainer and makes the running version visible before unlocking.

## Choose the backup directly

Both Restore and Test a Backup now show **Choose Backup File** and **Choose Backup
Folder** directly on their forms. There is no intermediate chooser page.

- **File:** tap the backup itself. The picker imports a local copy and accepts
  generic data, instead of requesting the broader item type that also includes folders.
- **Folder:** open the folder containing the backup, tap **Open**, then tap the
  backup filename in the list inside Arithvale. Opening the folder alone does not
  select a backup. Folder listing does not download every file or trust extensions.
- A selected file is copied, checked by contents, and then authenticated using the
  original recovery key. Canceling or picking an invalid file preserves the prior selection.
- If LiveContainer's picker does not respond, its official documentation recommends
  **Fix File Picker** in the individual app's LiveContainer settings. Relaunch afterward.

The version is visible in **calculator → … → Help → About**, on the recovery screen,
and in Test a Backup. Calculator Help still contains no private-library instructions.

## Photo and video viewer

| Before | After | What this changes |
| --- | --- | --- |
| `FilePreview(...).id(current.id)` recreated the preview for every item | Native `UIPageViewController` paging keeps adjacent pages available | Horizontal swipes have an interactive transition instead of replacing the whole screen |
| Filename and capture-date notes were always visible | Swipe upward at normal zoom, or tap the 44pt-or-larger Info control, to open a details sheet | The photo or video remains the main content |
| Each navigation decrypted and decoded the image again | Retain the current page and immediate neighbors; predecode eligible stills at up to 2048px | Back-and-forth browsing can reuse prepared previews |
| All navigation used arrow buttons | Native swipes plus accessible Previous/Next buttons; pinch and double-tap zoom | Touch browsing and accessibility both remain available |

Only small neighboring still images (up to 16 MiB each) are speculatively prepared.
Large originals, video files, and Live Photo motion load when opened. Original
export quality is unchanged. One current video player is active; leaving its page
stops playback. Preview resources are released when evicted, closed, or locked.

## Why the backup format remains compatible

iOS explicitly supports exporting documents to Files and importing local copies
from Files. Our backup is a binary document containing an encrypted catalog and
encrypted resource records. The restore engine authenticates them in staging and
commits only after successful validation. The picker issue occurs before this step.

The current format uses CryptoKit AES-256-GCM with authenticated, bounded chunks.
Replacing encryption would not make a grayed-out file selectable. This release
therefore improves file access and presentation without changing keys or archive
formats. Old `.c84backup` files remain supported, including when renamed; they
still require their original recovery key. Files itself does not decrypt the backup.

Apple Encrypted Archive is another possible encrypted container, but migrating to
it would introduce a second format and new compatibility work for the Windows
recovery tool without solving the host picker. No migration is made here.

## Evidence and remaining checks

The release build report records the actual automated results. Tests cover export,
renamed-file import, recovery with the original key, rejection of a wrong key,
malformed archives, and folder candidate listing. These tests do not execute the
iOS Files UI. Native compilation and inspection likewise do not prove LiveContainer
compatibility or smooth frame timing. Restore from Files, picker dismissal, rapid
swipes, video/Live Photo playback, zoom, details, and memory pressure must be checked
on a phone before describing this issue as resolved there.

References:

- [Apple: document import/export and access permissions](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/DocumentPickerProgrammingGuide/AccessingDocuments/AccessingDocuments.html)
- [Apple: modern import-as-copy initializer](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller/init(foropeningcontenttypes:ascopy:))
- [Apple: folder access](https://developer.apple.com/documentation/uikit/providing-access-to-directories)
- [Apple: AES-GCM](https://developer.apple.com/documentation/cryptokit/aes/gcm)
- [Apple: encrypted archive example](https://developer.apple.com/documentation/AppleArchive/encrypting-and-decrypting-a-string)
- [LiveContainer: Fix File Picker](https://github.com/LiveContainer/LiveContainer#fix-file-picker--local-notification)
