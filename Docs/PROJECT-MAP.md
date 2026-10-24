# Arithvale source map

| Area | Main files | Responsibility |
| --- | --- | --- |
| Calculator/access | CalculatorView, PrivateSpaceView, SetupSession, DeviceAccess | Calculation, explicit hold-to-unlock, recovery key setup, throttled device access |
| Library operations | VaultModel, VaultEngine, VaultRepository | Import transactions, cancellation, encrypted storage, backup/restore |
| Photo pipeline | MediaBridge, PhotoResourceWriter, PhotoImportReview | Original resources, cancellable protected streaming, verified optional deletion |
| Browsing | LibraryView, MemoryGrid, MediaBrowser, MediaPreviewStore, FilePreview, LivePhotoPreview | Grid/search/filter, native paging, bounded prepared previews, zoom, paired motion |
| Selection | GridDragSelection, LibrarySelectionSweep | Horizontal sweep, reversible ranges, edge scrolling and tap/VoiceOver fallback |
| Files picker | BackupChooserView, BackupFolder, BackupFileProbe, RecoveryViews, PrivateSpaceView | Direct file/folder selection, scoped candidate list, verified local copies and clear invalid-selection feedback |
| Export | FilePreview, PrivatePhotoCopy | Original sharing and optional metadata-free JPEG derivatives |
| Backup status | BackupStatus, BackupSummaryView, VaultSettingsView | Destination-aware summary and recovery-test identity |
| Cloud | CloudBackupModel, CloudDiscovery, CloudBackup, BlompStore, MegaStore, CalcMega | Cursor pages, resilient discovery, verified encrypted transfers |
| Release | Brand.json, verify_release.py, package_release.py | Fresh source-bound tests, build evidence, IPA/source kit |
| Compatibility | Docs/BRANDING.md, SECURITY.md, recover.py | Stable data identity and independent recovery |

Use `Scripts/verify_release.py --ipa --python <recovery-venv-python>` after `Scripts/prepare_mega.py`. The verifier runs the core tests, independent recovery tests and native build sequentially. It rejects source changes during the run. Device checks are a separate layer and are never inferred from a passing build.


## 0.5.0 additions

| Files | Responsibility |
| --- | --- |
| `Sources/CalcCore/CloudSelection.swift` | Provider identities and encrypted, default-deny selection policies |
| `Sources/CalcCore/VaultRepository.swift` | Persist policies; project provider-only encrypted catalogs |
| `Sources/Calc84/CloudSelectionView.swift` | Provider mode, selection/block grids, and gallery bulk actions |
| `Sources/CalcCore/ImportFileList.swift` | Bounded folder enumeration without following links |
| `Sources/Calc84/FileImportReview.swift` | Scoped original access, coordinated snapshots, verified recoverable Trash, confirmation review |
| `Tests/CalcCoreTests/CloudPolicyTests.swift` | Selection privacy, partial recovery, compatibility regression coverage |
| `Tests/CalcCoreTests/ImportFileListTests.swift` | Folder bounds and calculator clear-entry coverage |

Start with README.md and SETUP.md; provider behavior lives in Docs/CLOUD-BACKUP.md,
and reproducible build/recovery steps live in Docs/BUILDING.md.

## 0.5.1 additions

| Files | Responsibility |
| --- | --- |
| `Sources/Calc84/MediaPreviewStore.swift` | Current/neighbor cache, background decoding, bounded prefetch, cancellation and plaintext cleanup |
| `Sources/Calc84/MediaBrowser.swift` | Native horizontal pager, current video player, swipe-up details and accessibility controls |
| `Sources/Calc84/BackupChooserView.swift` | Inline recovery file/folder buttons and filename selection after opening a folder |
| `Sources/CalcCore/BackupFileProbe.swift` | Non-downloading folder candidates and content-based backup validation |
| `Tests/CalcCoreTests/BackupFileProbeTests.swift` | Folder enumeration and renamed-backup restore regression checks |

See Docs/UPDATE-0.5.1.md for the iOS/LiveContainer evidence and outstanding phone checks.


## 0.5.2 picker ownership

`BackupInputModel` (BackupChooserView.swift) owns request identity, selections,
folder listing and preparation. `AccessView` and `RecoveryTestView` each retain
one model and attach `backupPicker` to their Form. `BackupInputSection` renders
controls only. `BackupDocumentPicker` cleanup invalidates callbacks without
changing presentation state; only delegate events complete a selection.

## 0.5.3 shared-file receipt

`Calc84App.onOpenURL` forwards local file handoffs to the app-owned
`SharedBackupModel` in `SharedBackupView.swift`. Its serial storage actor holds
security scope and coordinates reads into `CalcCore/BackupInbox.swift`.
The inbox publishes one protected encrypted copy atomically, survives relaunch,
and never authenticates/decrypts without an explicit restore/test and secret.
The calculator receives no private filename/status UI. Setup and RecoveryViews
offer receipt instructions and Use Received Backup. BackupInboxTests covers
core persistence, input rejection, interruption, source safety and authentication.


## 0.6.0 visual and backup map

| Change | Primary files |
| --- | --- |
| Six layout names, initial choice, dimensions | `Sources/CalcCore/LibraryPresentation.swift` (`GalleryStyle`) |
| Header, filters, bottom navigation, received card, add routes | `Sources/Calc84/LibraryView.swift` |
| Native reusable grid and timeline mosaics | `Sources/Calc84/MemoryGrid.swift` |
| Album collages | `Sources/Calc84/AlbumLibraryView.swift` |
| Layout, appearance and calculator color preferences; glass fallback | `Sources/Calc84/Appearance.swift` |
| Calculator geometry and session history | `Sources/Calc84/CalculatorView.swift` |
| Four settings destinations | `Sources/Calc84/VaultSettingsView.swift` |
| Authenticated preview and item selection | `Sources/Calc84/BackupImportView.swift` |
| Atomic archive addition and duplicate/cloud policies | `Sources/CalcCore/VaultRepository.swift` |
| Chunked re-encryption without plaintext files | `Sources/CalcCore/VaultStream.swift` |
| Merge regression tests | `Tests/CalcCoreTests/BackupImportTests.swift` |

`galleryStyle` defaults to Clear Glass and remembers later choices. Old
`libraryLayout` is retained but no longer drives the new gallery. Changing a
visual style does not touch media, encryption identifiers, or cloud preferences.
