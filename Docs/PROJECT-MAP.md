# Arithvale source map

| Area | Main files | Responsibility |
| --- | --- | --- |
| Calculator/access | CalculatorView, PrivateSpaceView, SetupSession, DeviceAccess | Calculation, explicit hold-to-unlock, recovery key setup, throttled device access |
| Library operations | VaultModel, VaultEngine, VaultRepository | Import transactions, cancellation, encrypted storage, backup/restore |
| Photo pipeline | MediaBridge, PhotoResourceWriter, PhotoImportReview | Original resources, cancellable protected streaming, verified optional deletion |
| Browsing | LibraryView, MemoryGrid, MediaBrowser, FilePreview, LivePhotoPreview | Grid/search/filter, accessible cells, current-item preview, paired motion |
| Selection | GridDragSelection, LibrarySelectionSweep | Horizontal sweep, reversible ranges, edge scrolling and tap/VoiceOver fallback |
| Files picker | BackupFolder, RecoveryViews, PrivateSpaceView | Host-compatible backup picking, scoped file access and clear invalid-selection feedback |
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
