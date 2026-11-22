"""Offline Arithen backup verification/recovery. Never sends files or keys over a network."""
from __future__ import annotations
import argparse
import base64
import datetime as dt
import getpass
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import tempfile
import uuid
from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

CHUNK = 1024 * 1024
MAX_FILE = 4 * 1024**3
MAX_BACKUP = 64 * 1024**3
APPLE_EPOCH = 978307200
V3_MAGIC = b"ARITHB03"
V3_END = b"ARITHEND"
MAX_ENVELOPE = 12 * 1024**2

def exact(stream, length):
    value = stream.read(length)
    if len(value) != length:
        raise ValueError("Incomplete backup.")
    return value

def number(stream):
    return struct.unpack(">Q", exact(stream, 8))[0]

def block(stream, limit):
    length = number(stream)
    if length > limit:
        raise ValueError("Unsupported or oversized record.")
    return exact(stream, length)

def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate metadata field.")
        result[key] = value
    return result

def decode(data):
    return json.loads(data, object_pairs_hook=unique_object, parse_constant=lambda _: (_ for _ in ()).throw(ValueError("Invalid number.")))

def open_sealed(data, key, context):
    if len(data) < 28:
        raise ValueError("Incomplete encrypted record.")
    return AESGCM(key).decrypt(data[:12], data[12:], context.encode())

def normalize(secret):
    compact = re.sub(r"[\s-]", "", secret)
    return compact.upper() if re.fullmatch(r"[a-fA-F0-9]{64}", compact) else secret

def recovery_key(header, secret):
    if header.get("version") not in (1, 2) or header.get("rounds") != 600000:
        raise ValueError("Unsupported encryption version.")
    ident = str(uuid.UUID(header["id"])).upper()
    salt = base64.b64decode(header["salt"], validate=True)
    if len(salt) != 32 or len(secret.encode()) > 1024:
        raise ValueError("Invalid recovery parameters.")
    context = f'Calc84/v{header["version"]}/{ident}'
    password = normalize(secret) if header["version"] == 2 else secret
    key = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 600000, 32)
    if header["version"] == 2:
        wrapped = base64.b64decode(header["wrappedKey"], validate=True)
        if len(wrapped) != 60:
            raise ValueError("Invalid key envelope.")
        key = open_sealed(wrapped, key, context + "/key")
        if len(key) != 32:
            raise ValueError("Invalid data key.")
    return key, context

def safe_name(item):
    original = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", item["name"]).strip(". ")[:150] or "original.bin"
    # A UUID prefix prevents traversal, collisions and Windows reserved-device basenames.
    return f'{item["id"]}_{original}'

def recover(backup: Path, secret: str, output: Path | None = None, include_deleted=False, salvage=False):
    """Strict verification is the default. Salvage never bypasses authentication."""
    backup = Path(backup)
    if backup.stat().st_size > MAX_BACKUP:
        raise ValueError("Backup exceeds the supported 64 GB limit.")
    with backup.open("rb") as stream:
        magic = stream.read(8)
        stream.seek(max(0, backup.stat().st_size - 8))
        footer = stream.read(8)
    if magic == V3_MAGIC or footer == V3_END:
        return recover_v3(backup, secret, output, include_deleted, salvage)
    if salvage:
        raise ValueError("Salvage is available only for the redundant Arithen v3 format. Older backups require complete verification.")
    return recover_legacy(backup, secret, output, include_deleted)


def recover_legacy(backup: Path, secret: str, output: Path | None = None, include_deleted=False):
    backup = Path(backup)
    if backup.suffix == ".c84cloud":
        # Download the entire library folder first, retaining snapshots/ and
        # objects/. This conversion is offline and writes ciphertext only.
        with tempfile.TemporaryDirectory(prefix="calc84-cloud-") as directory:
            archive = Path(directory) / "checked.c84backup"
            assemble_cloud(backup, secret, archive)
            return recover(archive, secret, output, include_deleted)
    if backup.stat().st_size > MAX_BACKUP:
        raise ValueError("Backup exceeds the supported 64 GB limit.")
    output = Path(output).absolute() if output is not None else None
    if output is not None and output.exists():
        raise ValueError("Choose a new output folder. Existing folders are never overwritten.")
    stage = None
    try:
        with backup.open("rb") as stream:
            if exact(stream, 8) not in (b"C84B0001", b"C84B0002"):
                raise ValueError("Not a supported Arithen or legacy backup.")
            header = decode(block(stream, 4096))
            key, context = recovery_key(header, secret)
            manifest = decode(open_sealed(block(stream, 4 * 1024**2), key, context + "/manifest"))
            entries = manifest.get("items")
            if manifest.get("version") not in (1, 2) or not isinstance(entries, list) or len(entries) > 5000:
                raise ValueError("Unsupported library metadata.")
            lookup = {}
            total_size = 0
            for item in entries:
                ident = str(uuid.UUID(item["id"])).upper()
                if ident != item["id"] or ident in lookup:
                    raise ValueError("Duplicate or noncanonical item identity.")
                size = item["byteCount"]
                version = item.get("storageVersion")
                if type(size) is not int or not 0 <= size <= (MAX_FILE if version == 2 else 128 * 1024**2) or version not in (None, 2):
                    raise ValueError("Invalid item size or storage version.")
                if not isinstance(item["name"], str) or len(item["name"]) > 180:
                    raise ValueError("Invalid filename metadata.")
                total_size += size
                if total_size >= MAX_BACKUP:
                    raise ValueError("Library exceeds its size limit.")
                lookup[ident] = item
            if number(stream) != len(entries):
                raise ValueError("Missing library entries.")
            selected = {item["id"] for item in entries if not item.get("isThumbnail") and not item.get("isCompanion") and not item.get("pendingImport")
                        and (include_deleted or item.get("deletedAt") is None)}
            for ident in list(selected):
                companion = lookup[ident].get("companionID")
                if companion:
                    if companion not in lookup or companion == ident:
                        raise ValueError("Missing Live Photo resource.")
                    selected.add(companion)
            if output is not None:
                output.parent.mkdir(parents=True, exist_ok=True)
                stage = Path(tempfile.mkdtemp(prefix=".calc84-recovery-", dir=output.parent))
                os.chmod(stage, 0o700)
            seen = set()
            recovered_metadata = []
            for _ in entries:
                ident = exact(stream, 36).decode("ascii")
                if ident not in lookup or ident in seen:
                    raise ValueError("Duplicate or unknown file record.")
                seen.add(ident)
                item = lookup[ident]
                size = item["byteCount"]
                record_size = number(stream)
                chunked = item.get("storageVersion") == 2
                count = max(1, (size + CHUNK - 1) // CHUNK)
                expected = 16 + size + count * 36 if chunked else size + 28
                if record_size != expected:
                    raise ValueError("File length does not match authenticated metadata.")
                target = stage / safe_name(item) if stage is not None and ident in selected else None
                handle = target.open("xb") if target is not None else None
                try:
                    if chunked:
                        if exact(stream, 8) != b"C84F0002" or number(stream) != size:
                            raise ValueError("Invalid encrypted file header.")
                        for index in range(count):
                            length = min(CHUNK, size - index * CHUNK)
                            sealed = block(stream, length + 28)
                            if len(sealed) != length + 28:
                                raise ValueError("Invalid encrypted chunk length.")
                            plain = open_sealed(sealed, key, f"{context}/{ident}/chunk/{index}/{size}")
                            if handle:
                                handle.write(plain)
                    else:
                        plain = open_sealed(exact(stream, record_size), key, f"{context}/{ident}")
                        if len(plain) != size:
                            raise ValueError("Incorrect recovered size.")
                        if handle:
                            handle.write(plain)
                    if handle:
                        handle.flush()
                        os.fsync(handle.fileno())
                finally:
                    if handle:
                        handle.close()
                if target is not None:
                    timestamp = item.get("captured", item["added"]) + APPLE_EPOCH
                    os.utime(target, (timestamp, timestamp))
                    metadata = dict(item)
                    metadata["exportedFilename"] = target.name
                    metadata["captureDateUTC"] = dt.datetime.fromtimestamp(timestamp, dt.timezone.utc).isoformat()
                    recovered_metadata.append(metadata)
            if stream.read(1):
                raise ValueError("Unexpected trailing data.")
            if stage is not None:
                (stage / "metadata.json").write_text(json.dumps(recovered_metadata, ensure_ascii=False, indent=2), encoding="utf-8")
                if output.exists():
                    raise ValueError("Output folder appeared during recovery; no files were overwritten.")
                stage.rename(output)
                stage = None
            return {"authenticatedRecords": len(entries), "recoverableResources": len(selected),
                    "output": str(output) if output is not None else None}
    finally:
        if stage is not None:
            shutil.rmtree(stage)

def _canonical_id(value):
    if not isinstance(value, str) or str(uuid.UUID(value)).upper() != value:
        raise ValueError("Noncanonical record identity.")
    return value


def _expected_resource_size(item):
    size = item["byteCount"]
    return 16 + size + max(1, (size + CHUNK - 1) // CHUNK) * 36 if item.get("storageVersion") == 2 else size + 28


def _v3_envelope(raw, secret):
    envelope = decode(raw)
    if not isinstance(envelope, dict) or envelope.get("version") != 3:
        raise ValueError("Unsupported portable backup version.")
    snapshot = _canonical_id(envelope["snapshotID"])
    header_data = base64.b64decode(envelope["vaultHeader"], validate=True)
    if not 0 < len(header_data) <= 4096:
        raise ValueError("Invalid vault header size.")
    header = decode(header_data)
    if not isinstance(header, dict):
        raise ValueError("Invalid vault header.")
    key, context = recovery_key(header, secret)
    # Domain separation gives every portable snapshot a separate catalog key;
    # existing independently authenticated resource keys and bytes stay unchanged.
    catalog_key = HKDF(algorithm=hashes.SHA256(), length=32, salt=snapshot.encode(),
                       info=b"Arithen/backup/v3/catalog").derive(key)
    sealed = base64.b64decode(envelope["sealedCatalog"], validate=True)
    if len(sealed) > MAX_ENVELOPE:
        raise ValueError("Oversized encrypted catalog.")
    catalog = decode(open_sealed(sealed, catalog_key, "Arithen/backup/v3/" + snapshot))
    if not isinstance(catalog, dict) or catalog.get("headerSHA256") != hashlib.sha256(header_data).hexdigest():
        raise ValueError("Vault header does not match the authenticated catalog.")
    index = base64.b64decode(catalog["index"], validate=True)
    if not 28 <= len(index) <= 4 * 1024**2:
        raise ValueError("Oversized library metadata.")
    records = catalog.get("records")
    if not isinstance(records, list) or len(records) > 5000:
        raise ValueError("Invalid recovery inventory.")
    seen, body_size = set(), 0
    for record in records:
        ident = _canonical_id(record["id"])
        length, digest = record["bytes"], record["sha256"]
        if ident in seen or type(length) is not int or not 28 <= length <= 16 + MAX_FILE + max(1, (MAX_FILE + CHUNK - 1) // CHUNK) * 36:
            raise ValueError("Duplicate or oversized encrypted resource.")
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("Invalid authenticated resource hash.")
        seen.add(ident)
        body_size += length
    if 32 + 2 * len(raw) + body_size > MAX_BACKUP:
        raise ValueError("Backup exceeds the supported size limit.")
    return {"raw": raw, "key": key, "context": context, "headerData": header_data,
            "index": index, "records": records, "bodySize": body_size}


def _v3_items(opened):
    manifest = decode(open_sealed(opened["index"], opened["key"], opened["context"] + "/manifest"))
    if not isinstance(manifest, dict):
        raise ValueError("Invalid library metadata.")
    entries, records = manifest.get("items"), opened["records"]
    if manifest.get("version") not in (1, 2) or not isinstance(entries, list) or len(entries) > 5000:
        raise ValueError("Unsupported library metadata.")
    if not isinstance(records, list) or len(records) != len(entries):
        raise ValueError("Invalid recovery inventory.")
    lookup, total_size = {}, 0
    for item in entries:
        ident = _canonical_id(item["id"])
        size, version = item["byteCount"], item.get("storageVersion")
        if ident in lookup or type(size) is not int or version not in (None, 2):
            raise ValueError("Duplicate or invalid library item.")
        if not 0 <= size <= (MAX_FILE if version == 2 else 128 * 1024**2):
            raise ValueError("Unsupported resource size.")
        if not isinstance(item["name"], str) or len(item["name"]) > 180:
            raise ValueError("Invalid filename metadata.")
        total_size += size
        if total_size >= MAX_BACKUP:
            raise ValueError("Library exceeds its size limit.")
        lookup[ident] = item
    for record in records:
        ident = record["id"]
        if ident not in lookup or record["bytes"] != _expected_resource_size(lookup[ident]):
            raise ValueError("Authenticated resource does not match library metadata.")
    return lookup


def _read_v3(stream, secret, salvage):
    stream.seek(0, os.SEEK_END)
    size = stream.tell()
    if size > MAX_BACKUP:
        raise ValueError("Backup exceeds the supported 64 GB limit.")
    candidates, cached = {}, {}
    # Each location is bounded and authenticated independently. Damaged front
    # length fields never dictate where we seek to find the redundant footer.
    for position in ("front", "footer"):
        try:
            if position == "front":
                stream.seek(0)
                if exact(stream, 8) != V3_MAGIC:
                    continue
                length = number(stream)
                start = 16
            else:
                if size < 16:
                    continue
                stream.seek(size - 16)
                length = number(stream)
                if exact(stream, 8) != V3_END:
                    continue
                start = size - 16 - length
            if not 0 < length <= MAX_ENVELOPE or start < 16 or start + length > size:
                continue
            stream.seek(start)
            raw = exact(stream, length)
            if raw not in cached:
                cached[raw] = _v3_envelope(raw, secret)
            candidates[position] = cached[raw]
        except (InvalidTag, ValueError, TypeError, KeyError, UnicodeError, OverflowError, struct.error):
            continue
    if not candidates:
        raise ValueError("Neither backup catalog authenticated. The recovery key is wrong or both metadata copies are damaged.")
    if len(candidates) == 2 and candidates["front"]["raw"] != candidates["footer"]["raw"]:
        raise ValueError("Ambiguous backup: the two authenticated catalogs disagree.")
    opened = next(iter(candidates.values()))
    body_start = 16 + len(opened["raw"])
    body_end = body_start + opened["bodySize"]
    expected_size = body_end + len(opened["raw"]) + 16
    if expected_size > MAX_BACKUP or size > expected_size:
        raise ValueError("Unexpected trailing data or oversized backup.")
    if "footer" in candidates and size != expected_size:
        raise ValueError("Footer position does not match the authenticated inventory.")
    if size < body_end and not salvage:
        raise ValueError("Incomplete encrypted resource body. Explicit salvage may recover intact resources.")
    # Compare both authenticated catalogs before decoding their manifests. A
    # validly sealed but unusable index must not conceal an ambiguous snapshot.
    opened["items"] = _v3_items(opened)
    opened.update(bodyStart=body_start, bodyEnd=body_end, fileSize=size,
                  metadataCopies=list(candidates), expectedSize=expected_size)
    return opened


class _ResourceReader:
    """A hash-limited view prevents a malformed chunk consuming its neighbor."""
    def __init__(self, stream, length):
        self.stream, self.remaining = stream, length
        self.digest = hashlib.sha256()

    def read(self, length):
        data = self.stream.read(min(length, self.remaining))
        self.remaining -= len(data)
        self.digest.update(data)
        return data


def _decrypt_resource(reader, item, key, context, handle):
    size, ident = item["byteCount"], item["id"]
    if item.get("storageVersion") == 2:
        if exact(reader, 8) != b"C84F0002" or number(reader) != size:
            raise ValueError("Invalid encrypted resource header.")
        for index in range(max(1, (size + CHUNK - 1) // CHUNK)):
            length = min(CHUNK, size - index * CHUNK)
            sealed = block(reader, length + 28)
            if len(sealed) != length + 28:
                raise ValueError("Invalid encrypted chunk length.")
            plain = open_sealed(sealed, key, f"{context}/{ident}/chunk/{index}/{size}")
            if handle:
                handle.write(plain)
    else:
        plain = open_sealed(exact(reader, size + 28), key, f"{context}/{ident}")
        if len(plain) != size:
            raise ValueError("Incorrect recovered size.")
        if handle:
            handle.write(plain)


def recover_v3(backup, secret, output=None, include_deleted=False, salvage=False):
    output = Path(output).absolute() if output is not None else None
    if output is not None and output.exists():
        raise ValueError("Choose a new output folder. Existing folders are never overwritten.")
    stage = None
    try:
        with Path(backup).open("rb") as stream:
            opened = _read_v3(stream, secret, salvage)
            lookup = opened["items"]
            selected = {ident for ident, item in lookup.items() if not item.get("isThumbnail")
                        and not item.get("isCompanion") and not item.get("pendingImport")
                        and (include_deleted or item.get("deletedAt") is None)}
            for ident in list(selected):
                companion = lookup[ident].get("companionID")
                if companion:
                    if companion not in lookup or companion == ident:
                        raise ValueError("Missing Live Photo resource metadata.")
                    selected.add(companion)
            if output is not None:
                output.parent.mkdir(parents=True, exist_ok=True)
                stage = Path(tempfile.mkdtemp(prefix=".arithen-recovery-", dir=output.parent))
                os.chmod(stage, 0o700)
            metadata, omissions, intact = [], [], set()
            offset = opened["bodyStart"]
            for record in opened["records"]:
                ident, length = record["id"], record["bytes"]
                item = lookup[ident]
                target = stage / safe_name(item) if stage is not None and ident in selected else None
                handle = target.open("xb") if target is not None else None
                try:
                    stream.seek(offset)
                    reader = _ResourceReader(stream, length)
                    _decrypt_resource(reader, item, opened["key"], opened["context"], handle)
                    if reader.remaining or reader.digest.hexdigest() != record["sha256"]:
                        raise ValueError("Encrypted resource does not match its authenticated hash.")
                    if handle:
                        handle.flush()
                        os.fsync(handle.fileno())
                    intact.add(ident)
                except (InvalidTag, ValueError) as error:
                    if not salvage:
                        raise ValueError(f"Resource {ident} is incomplete or damaged.") from error
                    omissions.append({"id": ident, "name": item["name"],
                                      "reason": "Incomplete or damaged encrypted resource; authentication failed."})
                finally:
                    if handle:
                        handle.close()
                    offset += length
                if ident not in intact:
                    if target is not None:
                        target.unlink()
                    continue
                if target is not None:
                    # Originals are byte-for-byte intact. Preserve Photos-adjusted
                    # dates/location in sidecar metadata as well as embedded data.
                    date = item.get("captured")
                    timestamp = (item["added"] if date is None else date) + APPLE_EPOCH
                    os.utime(target, (timestamp, timestamp))
                    entry = dict(item, exportedFilename=target.name,
                                 captureDateUTC=dt.datetime.fromtimestamp(timestamp, dt.timezone.utc).isoformat())
                    metadata.append(entry)
            result = {"formatVersion": 3, "status": "partial" if omissions else "complete",
                      "complete": not omissions, "salvageRequested": salvage,
                      "authenticatedRecords": len(intact), "expectedRecords": len(lookup),
                      "recoverableResources": len(selected & intact), "omittedRecords": omissions,
                      "metadataCopies": opened["metadataCopies"],
                      "output": str(output) if output is not None else None}
            if len(opened["metadataCopies"]) < 2:
                result["redundancyWarning"] = "Only one metadata copy authenticated; create a new verified backup after recovery."
            if stage is not None:
                (stage / "metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
                (stage / "recovery-report.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
                if output.exists():
                    raise ValueError("Output folder appeared during recovery; no files were overwritten.")
                stage.rename(output)
                stage = None
            return result
    finally:
        if stage is not None:
            shutil.rmtree(stage)


def assemble_cloud(catalog: Path, secret: str, destination: Path):
    if catalog.stat().st_size > 32 * 1024**2:
        raise ValueError("Oversized recovery catalog.")
    snapshot = decode(catalog.read_bytes())
    if snapshot.get("version") not in (1, 2):
        raise ValueError("Unsupported cloud backup version.")
    header_data = base64.b64decode(snapshot["header"], validate=True)
    index_data = base64.b64decode(snapshot["index"], validate=True)
    if len(header_data) > 4096 or len(index_data) > 4 * 1024**2:
        raise ValueError("Oversized encrypted catalog.")
    header = decode(header_data)
    if uuid.UUID(header["id"]) != uuid.UUID(snapshot["vaultID"]):
        raise ValueError("Library identity mismatch.")
    key, context = recovery_key(header, secret)
    manifest = decode(open_sealed(index_data, key, context + "/manifest"))
    records = snapshot["records"]
    items = manifest["items"]
    envelope = None
    if snapshot["version"] == 2:
        envelope = base64.b64decode(snapshot["archiveEnvelope"], validate=True)
        if not 0 < len(envelope) <= MAX_ENVELOPE:
            raise ValueError("Oversized portable recovery envelope.")
        opened = _v3_envelope(envelope, secret)
        _v3_items(opened)
        if opened["headerData"] != header_data or opened["index"] != index_data or opened["records"] != records:
            raise ValueError("Cloud inventory disagrees with its authenticated portable catalog.")
        if 32 + 2 * len(envelope) + opened["bodySize"] > MAX_BACKUP:
            raise ValueError("Cloud backup exceeds the supported limit.")
    if not isinstance(records, list) or len(records) > 5000 or len(records) != len(items):
        raise ValueError("Invalid recovery inventory.")
    lookup = {str(uuid.UUID(item["id"])).upper(): item for item in items}
    if len(lookup) != len(items):
        raise ValueError("Duplicate library records.")
    seen, total = set(), 0
    objects = catalog.parent.parent / "objects"
    with destination.open("xb") as stream:
        if envelope is not None:
            stream.write(V3_MAGIC)
            stream.write(struct.pack(">Q", len(envelope))); stream.write(envelope)
        else:
            stream.write(b"C84B0002")
            for data in (header_data, index_data):
                stream.write(struct.pack(">Q", len(data))); stream.write(data)
            stream.write(struct.pack(">Q", len(records)))
        for record in records:
            ident = str(uuid.UUID(record["id"])).upper()
            digest = record["sha256"]
            length = record["bytes"]
            if ident in seen or ident not in lookup or not re.fullmatch(r"[0-9a-f]{64}", digest):
                raise ValueError("Invalid cloud record.")
            seen.add(ident)
            item = lookup[ident]
            plain_size = item["byteCount"]
            if type(plain_size) is not int or not 0 <= plain_size <= MAX_FILE:
                raise ValueError("Invalid resource size.")
            # Stream v2: magic + size, then 8-byte block lengths and
            # authenticated chunks (including one authenticated empty chunk).
            expected = 16 + plain_size + 36 * max(1, (plain_size + CHUNK - 1) // CHUNK) if item.get("storageVersion") == 2 else plain_size + 28
            if type(length) is not int or length != expected:
                raise ValueError("Incorrect cloud resource length.")
            total += length
            if total > MAX_BACKUP:
                raise ValueError("Cloud backup exceeds the supported limit.")
            source = objects / f"{ident}-{digest}.enc"
            if source.is_symlink() or source.stat().st_size != length:
                raise ValueError("Missing or damaged cloud object.")
            if envelope is None:
                stream.write(ident.encode()); stream.write(struct.pack(">Q", length))
            check = hashlib.sha256()
            with source.open("rb") as encrypted:
                remaining = length
                while remaining:
                    data = exact(encrypted, min(CHUNK, remaining)); remaining -= len(data)
                    check.update(data); stream.write(data)
                if encrypted.read(1):
                    raise ValueError("Cloud object changed while being read.")
            if check.hexdigest() != digest:
                raise ValueError("Damaged cloud object.")
        if envelope is not None:
            stream.write(envelope); stream.write(struct.pack(">Q", len(envelope))); stream.write(V3_END)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("backup", type=Path, nargs="?")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--include-deleted", action="store_true")
    parser.add_argument("--salvage", action="store_true", help="v3 only: recover whole authenticated resources and report every damaged or missing record")
    args = parser.parse_args()
    if args.backup is None:
        args.backup = Path(input("Encrypted .c84backup or .c84cloud catalog file: ").strip().strip('"'))
        if not args.verify_only and args.output is None:
            args.output = Path(input("New folder for recovered originals: ").strip().strip('"'))
    if not args.verify_only and args.output is None:
        parser.error("Choose --output NEW_FOLDER or --verify-only.")
    secret = getpass.getpass("Recovery key (or original 0.1 password): ")
    try:
        result = recover(args.backup, secret, None if args.verify_only else args.output, args.include_deleted, args.salvage)
    except Exception as error:
        print("Recovery failed. Wrong secret, damaged backup, unsupported file, or storage error.")
        print(f"Details: {type(error).__name__}: {error}")
        return 1
    print(json.dumps(result, indent=2))
    if result["output"]:
        print("Recovered files are unencrypted. Protect the output folder.")
    if not result.get("complete", True):
        print("PARTIAL RECOVERY ONLY. Missing or damaged resources were omitted; see omittedRecords. Keep the original backup.")
        return 2
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
