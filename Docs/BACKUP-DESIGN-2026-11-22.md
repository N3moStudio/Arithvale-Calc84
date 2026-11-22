# Backup replacement: research and implementation

Target: **0.13.0, build 25**. The user authorized replacing the old backup format on November 22. This replaces new portable exports and strengthens cloud catalogs; it does not erase or re-key the installed library. Existing readers remain inexpensive recovery tools, not a constraint on the new format.

## Decision

Use a new indexed `.arithenbackup` container with two authenticated recovery catalogs and independently checked encrypted resources. Keep established AES-256-GCM rather than inventing a cipher. Derive a separate catalog key for each snapshot with HKDF-SHA256. Normal restoration remains all-or-nothing. Explicit **Recover Intact Files** can rescue authenticated originals from a damaged container, reports omissions, and requires confirmation before importing. It cannot reconstruct missing bytes or a lost recovery secret.

## Primary-source comparison

| Source / alternative | Finding and application |
| --- | --- |
| [Apple CryptoKit](https://developer.apple.com/documentation/cryptokit) and [AES-GCM sealing](https://developer.apple.com/documentation/cryptokit/aes/gcm/seal(_:using:nonce:authenticating:)) | Use the platform's authenticated encryption and generated nonces. No homemade encryption algorithm, nonce counter or password cipher is introduced. |
| [NIST SP 800-38D](https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38D.pdf) | Authentication and nonce uniqueness matter. AEAD detects altered ciphertext; it cannot restore deleted data. Per-snapshot catalog subkeys isolate the new catalog-encryption domain. Existing resource encryption remains unchanged; cumulative lifetime key-use accounting is still a hardening opportunity, not a claimed solved problem. |
| [RFC 5869](https://www.rfc-editor.org/rfc/rfc5869) | HKDF provides a standard derivation mechanism and application context separation. The new catalog key is derived from the random vault key, with snapshot-specific salt and fixed protocol information. |
| [OWASP password storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html) | Argon2id is a useful choice for new human-password systems. Arithen generates a 256-bit recovery secret; replacing its existing PBKDF2 envelope with Argon2 solely for novelty would not fix missing backups. Weak legacy human passwords remain offline-guessable. |
| [NIST backup guidance](https://csrc.nist.gov/pubs/other/2020/04/24/protecting-data-from-ransomware-and-other-data-los/final) and [CISA/FBI guide](https://www.ic3.gov/CSA/2023/231019.pdf) | Recovery must be tested, and independent/offline copies protect against losing an account or all online copies. Successful upload is not proof of permanent recoverability. Keep recovery keys separately and periodically perform a real restore check. |
| [restic format](https://restic.readthedocs.io/en/stable/100_references.html) and [repository checks](https://restic.readthedocs.io/en/stable/045_working_with_repos.html) | Established backup systems use encrypted objects, snapshot metadata and content verification. Full data checks are distinct from inventory checks. Arithen retains object reuse and historical cloud snapshots; it does not claim restic compatibility or its maturity. |
| [libsodium secretstream](https://doc.libsodium.org/secret-key_cryptography/secretstream) | A credible authenticated streaming alternative, with sequence/truncation detection. It would add a native dependency without repairing a lost catalog. Arithen's existing authenticated chunks already bind position and total size; replacement here targets container recovery instead. |
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | A standard ZIP container can package encrypted files, but ZIP itself is not encryption. Merely changing to ZIP would not establish safer recovery. The new format uses a small documented parser and an independent Python implementation, with corruption tests. |

This is an engineering comparison and bounded source review, not an independent cryptographic certification. The references do not endorse this app.

## Wire format

All lengths are unsigned 64-bit big-endian. UUID strings used for cryptographic contexts are uppercase canonical UUIDs.

1. `ARITHB03` (8 bytes), envelope length, envelope JSON.
2. Encrypted resource bytes, contiguous in the authenticated catalog's record order.
3. An identical envelope JSON copy, envelope length, `ARITHEND` (8 bytes).

The envelope contains `version: 3`, `snapshotID`, Base64 `vaultHeader`, and Base64 `sealedCatalog`. The catalog plaintext contains the existing encrypted `index`, ordered `records` (`id`, encrypted `bytes`, ciphertext `sha256`), and `headerSHA256`, binding the exact vault header. Original names remain inside the encrypted index.

Catalog key: HKDF-SHA256 with the existing random vault key as input, UTF-8 snapshot UUID as salt, UTF-8 `Arithen/backup/v3/catalog` as info, and 32 output bytes. Catalog AEAD context: `Arithen/backup/v3/<snapshot UUID>`. CryptoKit's combined AES-GCM representation contains a random nonce, ciphertext and authentication tag. Existing resource AEAD is authenticated again before any library is published.

The envelope is capped at 12 MiB to cover nested Base64 encoding of a 4 MiB index and bounded inventory. Entire archives remain capped at 64 GiB, with 5,000 resources and the existing per-resource limits. There is no compression or ZIP extraction, and archive names never become filesystem paths.

## Recovery behavior

- Either catalog can authenticate independently. If both authenticate, their encoded bytes must agree. Conflicting authenticated catalogs are rejected.
- A usable spare catalog can restore the whole library when the other copy is damaged. The app recommends creating a fresh backup afterward.
- Ordinary restore rejects damaged or missing resources. It verifies both ciphertext digests and resource AEAD in isolated staging before publishing by rename into an empty location.
- Explicit salvage permits a truncated payload only after a catalog authenticates. It retains complete authenticated resources, skips damaged originals, excludes a Live Photo whose required motion resource is missing, and drops missing derived thumbnail references. Storage errors and cancellation still abort. The source backup is preserved.
- The import screen requires confirmation of the recovery counts before merging anything into the current library. Partial recovery retains the received backup copy.
- Cloud catalog v2 embeds the authenticated envelope. Recovery authenticates it and compares the outer inventory before downloading. The cloud still holds separate encrypted objects and versioned catalogs; unchanged objects are reused. It is not a single repeatedly overwritten archive.
- New automatic folder copies use `.arithenbackup`. Receipt-owned seven-copy retention remains; old journal entries keep their original filenames.
- The independent Python recovery tool reads old and new formats. `--salvage` is explicit, reports omissions and exits with a partial-recovery status. The app is not the sole recovery implementation.

## Limits and verification

Two catalogs in one file are redundancy against some local corruption, not two independent backups. Neither they nor AES can repair lost media bytes. A provider can delete files or revoke access; Arithen does not provide server-enforced object immutability. Prior receipts plus a size check do not detect every subsequent same-size remote corruption; **Recheck All Remote Files** performs a fresh read-back check. No guaranteed daily background execution is possible on iOS.

New regression coverage exercises either/both catalog damage, wrong keys, conflicting catalogs, truncation, appended bytes, isolated resource corruption, explicit partial recovery, Live Photo dependencies, source/output preservation, old-format recovery and independent Python interoperability. GitHub build/simulator results must be recorded after the exact candidate completes. Real FlareStore installation, iCloud/third-party providers and live MEGA/Blomp account recovery remain device/account validation, not claims established by fixtures.

## Completed verification and delivery

GitHub run [45008145545](https://github.com/N3moStudio/Arithvale-Calc84/actions/runs/45008145545) passed all three jobs at source **72fbf92c86ec0ae02d53d316601daf113013d3f3**:

- **176 core tests** and **27 independent Python recovery tests** passed on macOS. Swift-created new archives were recovered independently in Python; old-format fixtures still passed. The same 27 recovery tests also passed on Windows against Swift fixtures from the preceding fully passing `aafabee` revision (`.build/windows-recovery-0.13.0.log`); the final follow-up changes only decorative icon sizing and filename hints.
- **20 simulator tests** passed on iPhone 17 Pro / iOS 26.2, including the production app's recovery-confirmation/cancellation model, Files coordination, interrupted backup/lock, export cleanup, JPEG/MOV metadata and actual Photos saves after source removal.
- One end-to-end UI journey covered ordinary setup/authentication, evaluated-code hold protection, calculator, Albums route retention, settings, two real Files open/cancel paths, a seeded Photos import, lock/reopen and accessibility/theme screens. **15 planned screenshots** were visually reviewed.
- Native arm64 IPA compilation and package checks passed. Source and artifact provenance were verified before delivery. Screenshot review prompted an image-only Dynamic Type cap to prevent decorative settings icons crowding fully scaled accessibility labels; the final screenshots verify that spacing fix.
- Delivered only `C:\Users\naith\Desktop\ipa\My Projects (N3mo Studio)\Arithen-0.13.0.ipa`; older Arithen copies were replaced after verification and other apps preserved. No public release.

Evidence: `.build/delivery-0.13.0.json`, `.build/simulator-0.13.0-evidence.json`, `.build/core-0.13.0-evidence.json` and GitHub artifacts. Later documentation-only commits do not change tested implementation.

Native testing caught two old tests that corrupted the now-redundant footer and expected total failure. They now damage media payloads, retaining strict rejection/rollback assertions; separate tests prove spare-catalog recovery. Review also found that an open vault could export a damaged or stale disk index; export now authenticates and compares the committed index before output, with regression tests. The first 0.13.0 run failed and is retained as evidence, not counted as a pass.

Earlier simulator automation/permission failures are distinct from app acceptance. The final workflow runs the real Photos permission/import journey before native Photos tests, retains both result bundles and merges their results. Test-only code remains outside the IPA.

**Still unverified:** live MEGA/Blomp accounts, FlareStore-signed installation, real iCloud/third-party selection and persistent folder grants, physical-device media playback, large-library frame pacing and battery. Real Files open/cancel plus app-host staging is narrower evidence than completing a real-provider selection. Partial-recovery model tests do not substitute for every visual recovery-screen/device interaction. No real user media or credentials were used. Existing MEGA dependency deprecation warnings are retained.
