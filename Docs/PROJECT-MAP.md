# Arithvale source map

| Area | Main files | Responsibility |
| --- | --- | --- |
| Calculator/access | CalculatorView, PrivateSpaceView, SetupSession, DeviceAccess | Calculation, explicit hold-to-unlock, recovery key setup, throttled device access |
| Library operations | VaultModel, VaultEngine, VaultRepository | Import transactions, cancellation, encrypted storage, backup/restore |
| Photo pipeline | MediaBridge, PhotoResourceWriter, PhotoImportReview | Original resources, cancellable protected streaming, verified optional deletion |
| Browsing | LibraryView, MemoryGrid, MediaBrowser, FilePreview, LivePhotoPreview | Grid/search/filter, accessible cells, current-item preview, paired motion |
| Export | FilePreview, PrivatePhotoCopy | Original sharing and optional metadata-free JPEG derivatives |
| Backup status | BackupStatus, BackupSummaryView, VaultSettingsView | Destination-aware summary and recovery-test identity |
| Cloud | CloudBackupModel, CloudDiscovery, CloudBackup, BlompStore, MegaStore, CalcMega | Cursor pages, resilient discovery, verified encrypted transfers |
| Release | Brand.json, verify_release.py, package_release.py | Fresh source-bound tests, build evidence, IPA/source kit |
| Compatibility | Docs/BRANDING.md, SECURITY.md, recover.py | Stable data identity and independent recovery |

Use `Scripts/verify_release.py --ipa --python <recovery-venv-python>` after `Scripts/prepare_mega.py`. The verifier runs the core tests, independent recovery tests and native build sequentially. It rejects source changes during the run. Device checks are a separate layer and are never inferred from a passing build.
