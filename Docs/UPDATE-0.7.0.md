# Arithvale 0.7.0 · build 11

Every new destination library now gets a fresh recovery secret, data-encryption
key, salt and library identity, including when setup starts from an old backup.
The new key is displayed during setup, with an explicit saved acknowledgment and
last-eight-character confirmation. It stays stable while navigating setup and
cloud recovery. It is not stored as a viewable secret after setup.

## Start from a backup

Share a downloaded backup from Files → LiveContainer → Arithvale. On setup,
choose Use Received Backup, enter its old key, then Add Backup to Setup. Save and
confirm the new recovery key, choose a calculator code, and tap Create Library
from Backups. Where the system picker works, additional backups can be queued
with separate source keys before creating the library. In LiveContainer, finish
setup before leaving to share another file, then use + → From a Backup.

Cloud setup has the same new-key acknowledgment. The old key authenticates the
source; the newly saved key protects future exports. Cloud test-only recovery
continues to verify without creating or changing a library.

There is no raw-photo import before library creation. Create Library already
generates fresh keys; every subsequently imported photo/file/folder uses that
destination key. Importing another batch does not generate another key.

## Transactions and compatibility

Source archives remain unchanged. Setup authenticates each archive in isolated
encrypted storage and re-encrypts content into a new staged destination, then
publishes the whole library with a single same-volume rename. Any ordinary
failure or cancellation before that commit leaves no destination library.
An interrupted process may leave encrypted staging data; it is not a completed
library. Chunked resources are re-encrypted without plaintext intermediate files;
legacy resources use the existing bounded-memory path.

Multiple sources merge exact-content duplicates while keeping active and deleted
copies distinct. Dates, favorites, albums, Recently Deleted status and Live Photo
associations are preserved. Never Upload exclusions carry over; source upload
selections and automatic modes do not opt the new library into cloud uploads.

Updates do not rotate existing libraries. Existing access recovery and later
Add from Backup keep the destination key. Old archives retain their old key;
versions C84B0001 and C84B0002 remain readable. Version 0.6.0 and earlier setup
restored the source identity/key; those already-created libraries remain intact.
No cipher or archive format is replaced in this update.

## Verification

Generated disposable fixtures exercise independent keys/ciphertext, multiple
source keys, old-key rejection for new exports, original-archive preservation,
legacy compatibility, invalid-source rollback, cancellation, empty backups,
metadata and Live Photos, cloud blocks, and existing-library non-rotation.
BUILD-RESULT.json records actual test/build results. iPhone setup, saved-key
confirmation, LiveContainer handoff and real cloud accounts still require device
checks; compilation is not a device acceptance test.
