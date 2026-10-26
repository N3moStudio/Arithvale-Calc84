# Storage and recovery design · 0.9.0

## Scope and trust

Encrypt photo/video/file contents and library metadata at rest and in portable backups. The calculator is an appearance choice, not encryption or proof of concealment.

No Arithen account, application telemetry, developer server, or embedded cloud credentials. Optional Blomp and MEGA connections contact the user's provider directly. PhotoKit can fetch iCloud originals when importing; a selected Files provider can also handle snapshot transport. System backups can include encrypted app files, but are not a substitute for tested portable recovery.

## Optional cloud transport

CloudBackup.swift publishes immutable, versioned catalogs after referenced ciphertext objects have been uploaded and read back. Original names, dates and albums remain in the encrypted index; the public envelope includes IDs, lengths, SHA-256 hashes and snapshot time. New data keys are not generated for backup. No raw recovery key or PIN is uploaded; the wrapped-key header is necessary for recovery.

Cached verification receipts contain opaque IDs/hashes. Subsequent runs check presence and length before reusing a previously checked object. Recheck All Remote Files forces download/hash verification of the current eligible set. Restore authenticates the catalog with the recovery key before downloading, then authenticates every resource before the repository commits a new library. Local status is historical evidence, not continuous proof of durability. No remote delete operation is exposed. This is backup/restore, not a multi-writer merge protocol.

Blomp uses HTTPS-only authentication and an allowlist of documented storage hostnames, upgrades their legacy HTTP advertisements to HTTPS, refuses redirects and enforces normal certificates. HTTP response sizes are bounded. A failed certificate check cannot fall back to HTTP. MEGA uses the official SDK with HTTPS-only transfers, public-key pinning enabled, logging disabled and no SDK node-cache path. MEGA's account encryption is not reimplemented. Blomp passwords and MEGA session strings use nonsynchronizing WhenUnlockedThisDeviceOnly Keychain items; disconnect deletes the local item, not remote data.

Only public documentation/downloads and credential-free service checks were used. A documented Blomp storage host failed TLS hostname validation here. Actual account authentication, endpoint mapping, provider round-trips, quotas, network changes, SDK cancellation, and device lifecycle behavior still require phone/service testing. The test IPA is not a provider-verified release.

This alpha is not independently audited. It does not protect against a compromised OS, malicious modified app/LiveContainer host, runtime inspection, possession of recovery secrets, screenshots, or an already-unlocked vault. Guest-app isolation and Keychain access depend on the installer/host. No forensic erasure or undetectability guarantee.

## Keys and local access

New libraries use:
- A cryptographically random 32-byte data key.
- A separate random 32-byte recovery secret, displayed as 64 uppercase hexadecimal characters with hyphens.
- PBKDF2-HMAC-SHA256, 600,000 iterations, 32-byte salt, 32-byte derived wrapping key.
- The data key wrapped with AES-256-GCM using context Calc84/v2/<vault UUID>/key.
- Fresh AES-GCM nonces for the manifest and each encrypted chunk.

New recovery keys normalize hex case, whitespace, and hyphens. Legacy passwords remain byte-for-byte compatible, with no trimming. PBKDF2 parameters are fixed and validated before derivation. Native crypto uses CryptoKit/CommonCrypto; Linux tests use pinned Apple Swift Crypto.

The 6–12 digit calculator code is a **local access gate**, not the portable backup encryption key. A Keychain record stores the data key, vault ID, salted PBKDF2 code verifier, and retry state. It is nonsynchronizing, WhenUnlockedThisDeviceOnly. It does not migrate with a backup or a new signing identity. The record is available to this app when the phone is unlocked; it is not hardware-bound to knowledge of the short code.

Five failed code attempts introduce a delay starting at 30 seconds, capped at five minutes. Retry state is persisted, not tamper-proof against a compromised runtime or clock. Changing the code leaves the data key and recovery key unchanged. Knowing the recovery key permits enrolling a new code.

No key is written to UserDefaults. Key references are released on lock, but Swift runtime copies are not guaranteed to be zeroized. Recovery is impossible without an appropriate secret; there is no developer reset. A recovery key saved alongside the backup removes that separation.

Existing version 0.1 libraries retain their original v1 password-derived data key. Enrolling a local numeric code does not upgrade their password strength or reencrypt every existing resource. Starting a new library from their backup in 0.7.0 instead authenticates with the old password and re-encrypts into a fresh v2 destination.

## Private storage and transactions

### Optional video backgrounds

Calculator backgrounds are public decoration, visible before unlocking. Their
silent, bounded playback copies live in `Application Support/CalculatorWallpapers`,
use iOS complete file protection and are excluded from system backup. They are
not encrypted with the library key and are not included in library/cloud backups.
The picker explains this visibility before selection; original Photos assets are
not changed or deleted. Replacing/removing a background removes its playback copy.

Library backgrounds reference an existing encrypted library video by UUID. They
do not export it into calculator storage or change any cloud upload selection.
Authenticated originals and bounded playback copies are temporarily materialized
under `Calc84Temporary` with complete file protection. Leaving/locking clears the
playback copy; canceled preparation removes its working copies. Launch removes
interrupted temporary files. This is best-effort cleanup, not forensic erasure.
Background choices are local preferences, separate from portable backup contents.

### Encrypted library

Encrypted files and index live in Application Support/Calc84Library. UIFileSharingEnabled and opening-documents-in-place are disabled. Filenames on disk are random UUIDs, not media titles. Encrypted items use iOS complete file protection; Linux test files use owner-only permissions where available.

The manifest encrypts names, capture/import dates, media types, favorites, albums, deleted state, sizes, and links to thumbnails/Live Photo companions. Public headers expose vault ID, versions, KDF parameters, salt, and a wrapped key. File counts, encrypted sizes, and access patterns remain visible.

Imports authenticate the encrypted disk copy before committing the index. Multi-resource imports remain pending until the image, companion, and optional thumbnail are linked in one final index update. Failed imports roll back newly created records; reopening removes interrupted pending imports.

Photos import review offers optional source deletion, off by default for every batch. The pending review retains exact source asset identifiers and modification dates in memory only, tied to successfully committed vault item IDs. Fallback imports without a fetched Photos asset, incomplete resources, and Photos-only edits/alternate resources are excluded. Immediately before requesting deletion, the app re-reads/authenticates the committed encrypted index, verifies all relevant encrypted resources, confirms originals remain accessible and unchanged, and checks the unlock generation. PhotoKit performs the system-confirmed transaction on those exact assets only. Denial/failure leaves vault copies intact. Lock clears the pending review; an already-submitted Photos transaction remains controlled by iOS. Files sources and Photos Recently Deleted are never removed by this flow. Photos deletions can propagate through iCloud Photos.

Index writes are atomic. Permanent deletion commits removal from the index before deleting associated encrypted files. Cleanup failure may leave orphan ciphertext. Recently Deleted is soft deletion; no time-based purge is performed.

Create and restore use unique sibling staging directories and commit by rename into an empty destination. Existing libraries are never overwritten. Restore authenticates every stored resource before committing. Failed operations remove staging files; power loss can leave encrypted staging/orphan files, never a trusted completed restore.

A serial storage actor and UI generation checks prevent stale operations from reopening locked UI. An operation already in progress may complete its encrypted transaction before the queued lock executes.

## Portable format

All lengths/counts are unsigned 64-bit big-endian.

1. Eight-byte magic: C84B0002 (C84B0001 also accepted).
2. Length + public JSON header, at most 4 KiB.
3. Length + AES-GCM combined encrypted JSON manifest, at most 4 MiB.
4. Record count matching the authenticated manifest.
5. Per record: 36 ASCII UUID bytes, length, encrypted file bytes.
6. End of file; trailing data is rejected.

Header v1 derives the data key directly from the original password. Header v2 unwraps the random data key. Manifest v1 and v2 are accepted for compatibility. AES-GCM combined representation is nonce (12 bytes), ciphertext, and tag (16 bytes).

Contexts use Calc84/v<header version>/<vault UUID>/manifest for the index, and Calc84/v<header version>/<vault UUID>/<item UUID> for a legacy file. UUIDs use Swift's uppercase canonical representation.

New storageVersion=2 resources:
- C84F0002, then original byte count.
- max(1, ceil(size / 1 MiB)) chunks.
- Each chunk: length + AES-GCM combined bytes, including an authenticated zero-length chunk for empty files.
- Context: Calc84/v<header version>/<vault UUID>/<item UUID>/chunk/<zero-based index>/<total original bytes>.
- The position and total length in authentication prevent successful chunk reordering/truncation/substitution.

Maximum 4 GiB per new file, below 64 GiB per library/backup, 5,000 records including companions/thumbnails. Legacy resources have a 128 MiB bound. The encrypted format adds 16 bytes per file plus 36 bytes per chunk beyond plaintext. Total backup headroom is reserved on import.

Restore verifies versions, bounded parameters, unique IDs, exact record membership/count, lengths, authentication, and EOF. Archive-supplied original names are not used as storage paths.

Export authenticates every local resource. Folder export uses coordinated copy and SHA-256 readback; it does not confirm remote upload. Each snapshot is independent and older snapshots survive subsequent deletions.

## Plaintext and exports

Imports temporarily materialize original PhotoKit/Files data. Previews and explicit original exports use protected temporary files under Caches/Calc84Temporary. Cleanup occurs on completion/view disposal and at next launch after interruption. Operating-system/provider/recipient caches are outside the app's control. Complete file protection is not the vault's own encryption while a temporary original is materialized on an unlocked phone.

Exporting/Save to Photos intentionally produces ordinary media that may include GPS and identifying metadata. Photos permission is requested in context. Deleting imported originals is optional and requires verified committed vault copies, matching source assets, an explicit choice, and the system's deletion confirmation. Recently Deleted is not emptied.

The app-switcher cover and background lock need actual device/host tests. The app cannot stop users taking screenshots or recipients keeping shared copies.

## Independent recovery

Scripts/recover.py requires Python 3.10+ and cryptography, with a pinned requirements file. It does no network I/O. It supports v1 and v2, authenticates all resources, rejects existing output folders, and stages extraction before publishing a complete output.

Recovery writes original bytes under UUID-prefixed sanitized names plus metadata.json, retaining capture dates as file modification dates where supported. A photo app may need the sidecar for metadata absent from original bytes. Recently Deleted is excluded unless --include-deleted is selected. Thumbnail files are authenticated but not exported. Live Photo companions are exported with their primary asset.

Keep this tool/source with backup copies. Keep the recovery secret separately. Recovering to a computer intentionally creates plaintext.

## Validation

Automated checks cover encryption/reopen, independent KDF output, legacy interoperability, wrong secrets, corrupt/truncated/trailing/swapped records, oversized lengths, non-overwrite behavior, capture-date organization, incomplete import cleanup, chunk boundary/empty files, and a 130 MiB streaming sample. Additional paired-resource tests cover group recovery/deletion and rollback on a missing companion.

Python recovery tests consume fixtures produced by Swift, verify original bytes/dates and safe paths, exercise both versions, and reject wrong secrets/damaged output without publishing partial results.

Native compilation and package inspection do not verify phone installation, Keychain access, Photos resource APIs, visual layout, or lifecycle privacy. Follow DEVICE-CHECKS.md before storing sole copies. No independent penetration test is claimed.


## 0.5.0 selection and original-removal boundaries

Provider policies live inside the encrypted local manifest. Absent policies are
manual/empty. Each provider plan reads the committed policy and creates a fresh
encrypted subset index; it never uploads the full index alongside a partial set
of objects. Blocks override manual selections and automatic mode. Excluded
primary items, their metadata, thumbnails, and Live Photo resources are omitted.
Malformed shared references fail closed. Files snapshots still contain the full
manifest and policies; cloud restore starts with manual/empty policies.

Blocks govern future uploads of those item identities. They do not purge old
snapshots or completed objects from interrupted transfers, and do not identify
duplicates imported later. Backups retain the key of their exporting library.
Existing libraries are not automatically rotated. The new-onboarding behavior
in 0.7.0 below supersedes source-key preservation for new destinations only.

Files imports use coordinated, protected snapshots. The in-memory import review
retains source scopes and content digests only until dismissal/lock. Optional
Trash authenticates committed vault resources, coordinates each original, checks
that its current digest matches the imported bytes, then requests recoverable
FileManager Trash. It never substitutes permanent removal for unsupported Trash.
Only successfully imported regular files are eligible; parent folders stay intact.
Provider Trash and Photos Recently Deleted can synchronize across devices.

Backup selection imports a verified encrypted copy under app-owned temporary
storage. A content probe recognizes both supported backup magics regardless of
extension; it is not a substitute for recovery-key authentication. Folder listing
offers a way around a host application's missing file-type registration. Native
provider coordination, security scopes, permission prompts and LiveContainer
runtime behavior still require phone tests.


## Adding an archive to an existing library (0.6.0)

The archive is first fully authenticated in a separate encrypted preview. The
user selects visible, non-deleted items. Selected originals, thumbnails and Live
Photo companions are re-encrypted with fresh nonces and new UUIDs under the
current library key. This does not rotate the current key or alter the source.
Chunked resources are re-encrypted without writing a plaintext intermediate file.
Legacy resources retain their existing bounded-memory compatibility path.

One atomic manifest write publishes the addition after all new ciphertext is
verified and moved into place. Cancellation/failure before that commit leaves the
old manifest intact; staged resources are removed. A process crash can leave
unreferenced ciphertext, not a partially published library. Such orphans can use
storage until removed in a future maintenance pass.

Duplicate detection hashes authenticated original content plus media type/size;
Live Photo motion is included, derived thumbnails and names are not. No public
content hashes are uploaded by this operation. Dates, favorites, albums, and
resource associations are retained. Source Never Upload restrictions are applied
to the corresponding destination items, including exact duplicates. Source
upload selections never opt items in; existing destination provider modes apply.

The isolated encrypted preview is deleted when leaving the flow, and temporary
review caches are cleaned on next launch after interruption. In 0.6.0 and earlier,
initial empty-app restore retained the source key. Those existing libraries are
unchanged by an update.

## Fresh-key onboarding (0.7.0)

New setup creates a random recovery secret and requires saved acknowledgment plus
confirmation of its last eight characters. Files and cloud setup share the same
setup-owned secret across navigation. It is not persisted as a viewable secret.
The source key is used only to authenticate/read that source. New library IDs,
data keys, salts, resource IDs and GCM nonces are generated; all copied media and
metadata are sealed under the destination key. Source keys cannot open new
exports. Current archive formats and the offline recovery reader are unchanged.

For one or multiple archives, each source is fully restored into isolated
encrypted staging, then merged into a new staged destination. A single rename
publishes the destination only after all sources succeed. Errors/cancellation
before commit remove staging and leave the destination absent. Source archives
are never modified. A crash can leave encrypted staging data until cleanup; it
cannot publish a partly built destination. There are no plaintext intermediate
files for chunked re-encryption; legacy inputs keep the bounded-memory path.

Setup preserves Recently Deleted status and separates active/deleted duplicates.
Source cloud blocks carry over, but cloud modes/selections default to manual and
empty. An empty source still gets fresh destination keys. Adding later backups,
raw media imports, changing the calculator code, recovering access to an existing
library and installing updates do not rotate the destination key.
