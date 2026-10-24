# Arithvale 0.5.3 · receive a backup from Files

Version 0.5.3, build 9. Test release; phone validation remains pending.

## What changed

The reported LiveContainer file picker still closes before delivering a selection,
including with Fix File Picker enabled. Version 0.5.2 did not resolve that report.
This update adds a separate **Files → Share → LiveContainer → Arithvale** route.
It does not open Arithvale’s document picker or rely on its delegate callbacks.

The app registers its existing backup document type and receives file URLs using
SwiftUI’s onOpenURL. A serial background worker coordinates file-provider access,
validates the archive header/size, verifies a copied file’s hash, and publishes
only a complete encrypted copy in private Application Support. It retains one
copy across relaunches, with complete file protection and OS-backup exclusion.
Interrupted staging folders are removed on the next load.

Nothing opens or decrypts automatically. The calculator remains visible until
normal code entry. Setup and Test a Backup show **Use Received Backup** and the
filename. The original recovery key is still required; receipt alone does not
authenticate a backup. Removing the received copy never deletes the original.

## Encryption and compatibility

No new cipher, archive format, key rotation, or migration is introduced. Existing
C84B0001 and C84B0002 backups keep their original secrets. CryptoKit AES-GCM and
the existing authenticated restore engine remain in use. Restoring an older
library retains its library key; choosing a new calculator code does not rotate it.
Restore into an empty library only; Test a Backup keeps an existing library in place.

## Verification and limits

Six new core regression tests cover durable receipt/restoration, duplicate
handoffs, source preservation, invalid inputs, tamper authentication, cancellation,
interrupted staging, and path/metadata safety. The release report records fresh
Swift tests, independent Python recovery tests, native iOS compilation and IPA
metadata inspection. These checks cannot establish that LiveContainer delivered
a URL on a particular phone. Follow [the phone checks](../DEVICE-CHECKS.md).

The host’s share extension must be installed/enabled. This app does not add its
own share extension and does not expose the private library through Files.
Keep the original backup outside Arithvale/LiveContainer: its received copy is
app data and is not a replacement for your external backup.

## Primary references

- [LiveContainer: Open In App support](https://github.com/LiveContainer/LiveContainer#open-in-app-support)
- [LiveContainer shared-file preparation](https://github.com/LiveContainer/LiveContainer/blob/main/ShareExtension/ShareExtensionViewModel.swift)
- [LiveContainer warm/cold URL forwarding](https://github.com/LiveContainer/LiveContainer/blob/main/TweakLoader/UIKit%2BGuestHooks.m)
- [Apple: onOpenURL](https://developer.apple.com/documentation/swiftui/view/onopenurl(perform:))
- [Apple: document type declarations](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html#//apple_ref/doc/uid/TP40009249-SW1)
