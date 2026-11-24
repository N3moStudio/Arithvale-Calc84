"""Independent Python recovery checks against fixtures produced by Swift tests."""
import json
import base64
import hashlib
import io
import os
from pathlib import Path
import struct
import tempfile
import unittest
from unittest import mock
from contextlib import redirect_stdout
from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from recover import recover, block, number, exact, main

SECRET = "C24144AF-B3E94438-97C89127-E373D053-9F19F720-E47CA588-7C38BF10-14C2AF32"
FIXTURES = Path(os.environ["C84_FIXTURE_DIR"])


class UnicodeFilenameRecoveryTests(unittest.TestCase):
    def test_legacy_and_portable_recovery_accept_unicode_and_budget_output_names(self):
        names = ["e\u0301" * 100 + ".txt", "\u5199" * 100 + ".jpg"]
        originals = [b"document", b"photo"]
        vault_id = "00000000-0000-4000-8000-000000000001"
        salt = bytes(32)
        header = json.dumps({"version": 1, "id": vault_id, "rounds": 600000,
                             "salt": base64.b64encode(salt).decode()}).encode()
        key = hashlib.pbkdf2_hmac("sha256", SECRET.encode(), salt, 600000, 32)
        context = f"Calc84/v1/{vault_id}"

        def seal(key, plaintext, context):
            nonce = os.urandom(12)
            return nonce + AESGCM(key).encrypt(nonce, plaintext, context.encode())

        def sized(data):
            return struct.pack(">Q", len(data)) + data

        items, records, resources = [], [], []
        for index, (name, original) in enumerate(zip(names, originals), start=2):
            ident = f"00000000-0000-4000-8000-{index:012d}"
            encrypted = seal(key, original, f"{context}/{ident}")
            items.append({"id": ident, "name": name, "byteCount": len(original), "added": 700000000})
            records.append({"id": ident, "bytes": len(encrypted), "sha256": hashlib.sha256(encrypted).hexdigest()})
            resources.append(encrypted)
        index = seal(key, json.dumps({"version": 1, "items": items}).encode(), context + "/manifest")
        legacy = b"C84B0002" + sized(header) + sized(index) + struct.pack(">Q", len(records))
        legacy += b"".join(record["id"].encode() + sized(data) for record, data in zip(records, resources))

        catalog = json.dumps({"index": base64.b64encode(index).decode(), "records": records,
                              "headerSHA256": hashlib.sha256(header).hexdigest()}).encode()
        catalog_key = HKDF(algorithm=hashes.SHA256(), length=32, salt=vault_id.encode(),
                           info=b"Arithen/backup/v3/catalog").derive(key)
        sealed = seal(catalog_key, catalog, f"Arithen/backup/v3/{vault_id}")
        envelope = json.dumps({"version": 3, "snapshotID": vault_id, "vaultHeader": base64.b64encode(header).decode(),
                               "sealedCatalog": base64.b64encode(sealed).decode()}).encode()
        portable = b"ARITHB03" + sized(envelope) + b"".join(resources) + envelope + struct.pack(">Q", len(envelope)) + b"ARITHEND"

        for label, archive in (("legacy", legacy), ("portable", portable)):
            with self.subTest(format=label), tempfile.TemporaryDirectory() as directory:
                folder = Path(directory)
                source = folder / "backup"
                source.write_bytes(archive)
                self.assertEqual(recover(source, SECRET)["authenticatedRecords"], len(items))
                output = folder / "recovered"
                self.assertEqual(recover(source, SECRET, output)["recoverableResources"], len(items))
                entries = json.loads((output / "metadata.json").read_text(encoding="utf-8"))
                self.assertEqual([item["name"] for item in entries], names)
                for entry, original in zip(entries, originals):
                    exported = output / entry["exportedFilename"]
                    self.assertEqual(exported.suffix, Path(entry["name"]).suffix)
                    self.assertLessEqual(len(exported.name.encode("utf-8")), 255)
                    self.assertEqual(exported.read_bytes(), original)


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_originals_dates_and_safe_filenames(self):
        output = self.base / "recovered"
        result = recover(FIXTURES / "v2.c84backup", SECRET.lower(), output)
        self.assertEqual(result["authenticatedRecords"], 3)
        records = json.loads((output / "metadata.json").read_text(encoding="utf-8"))
        self.assertEqual(len(records), 3)
        for entry in records:
            file = output / entry["exportedFilename"]
            self.assertEqual(file.parent.resolve(), output.resolve())
            data = file.read_bytes()
            if entry["name"].endswith("AUX.jpg"):
                self.assertEqual(data, b"portable original bytes")
                self.assertAlmostEqual(file.stat().st_mtime, 1680000000, delta=1)
                self.assertEqual(entry["captureDateUTC"], "2023-03-28T10:40:00+00:00")
            elif entry["name"] == "video.mov":
                self.assertEqual(data, bytes([0xA7]) * (1024 * 1024 + 7))
            else:
                self.assertEqual(entry["name"], "empty.bin")
                self.assertEqual(data, b"")

    def test_legacy_backup(self):
        output = self.base / "legacy"
        result = recover(FIXTURES / "v1.c84backup", "original long password", output)
        self.assertEqual(result["authenticatedRecords"], 1)
        self.assertEqual(next(output.glob("*_legacy.txt")).read_bytes(), b"legacy original bytes")

    def test_multiple_albums_and_tags_survive_independent_recovery(self):
        for archive, secret in (("v2.c84backup", SECRET), ("fresh.c84backup", "F" * 64)):
            output = self.base / archive
            recover(FIXTURES / archive, secret, output)
            records = json.loads((output / "metadata.json").read_text(encoding="utf-8"))
            photo = next(item for item in records if item["name"].endswith("AUX.jpg"))
            self.assertEqual(photo["album"], "Travel")
            self.assertEqual(photo["albums"], ["Travel", "Receipts"])
            self.assertEqual(photo["tags"], ["ticket", "été"])
            self.assertEqual((output / photo["exportedFilename"]).read_bytes(), b"portable original bytes")

    def test_fresh_library_export_uses_destination_key(self):
        # Fixed public fixture key, never real user key material.
        result = recover(FIXTURES / "fresh.c84backup", "F" * 64, self.base / "fresh")
        self.assertEqual(result["authenticatedRecords"], 3)
        records = json.loads((self.base / "fresh" / "metadata.json").read_text(encoding="utf-8"))
        originals = {entry["name"]: (self.base / "fresh" / entry["exportedFilename"]).read_bytes() for entry in records}
        self.assertTrue(originals["../../AUX.jpg"] == b"portable original bytes")
        self.assertTrue(originals["video.mov"] == bytes([0xA7]) * (1024 * 1024 + 7))
        self.assertTrue(originals["empty.bin"] == b"")
        with self.assertRaises(InvalidTag):
            recover(FIXTURES / "fresh.c84backup", SECRET, self.base / "must-not-exist")
        self.assertFalse((self.base / "must-not-exist").exists())

    def test_verify_only_leaves_no_plaintext(self):
        result = recover(FIXTURES / "v2.c84backup", SECRET)
        self.assertIsNone(result["output"])
        self.assertEqual(list(self.base.iterdir()), [])

    def cloud_fixture(self):
        folder = self.base / "cloud"
        (folder / "snapshots").mkdir(parents=True)
        (folder / "objects").mkdir()
        with (FIXTURES / "v2.c84backup").open("rb") as stream:
            exact(stream, 8)
            header = block(stream, 4096); index = block(stream, 4 * 1024**2)
            records = []
            for _ in range(number(stream)):
                ident = exact(stream, 36).decode()
                data = exact(stream, number(stream))
                digest = hashlib.sha256(data).hexdigest()
                (folder / "objects" / f"{ident}-{digest}.enc").write_bytes(data)
                records.append({"id": ident, "bytes": len(data), "sha256": digest})
        catalog = folder / "snapshots" / "test.c84cloud"
        catalog.write_text(json.dumps({"version": 1, "vaultID": json.loads(header)["id"],
            "header": base64.b64encode(header).decode(), "index": base64.b64encode(index).decode(), "records": records}))
        return catalog

    def test_cloud_folder_restores_dates_and_original_bytes(self):
        catalog = self.cloud_fixture()
        output = self.base / "recovered"
        result = recover(catalog, SECRET, output)
        self.assertEqual(result["authenticatedRecords"], 3)
        records = json.loads((output / "metadata.json").read_text(encoding="utf-8"))
        photo = next(item for item in records if item["name"].endswith("AUX.jpg"))
        self.assertEqual((output / photo["exportedFilename"]).read_bytes(), b"portable original bytes")
        self.assertEqual(photo["captureDateUTC"], "2023-03-28T10:40:00+00:00")

    def test_cloud_damage_and_wrong_key_leave_no_output(self):
        catalog = self.cloud_fixture()
        with self.assertRaises(Exception):
            recover(catalog, "wrong recovery secret", self.base / "output")
        target = next((catalog.parent.parent / "objects").iterdir())
        data = bytearray(target.read_bytes()); data[-1] ^= 1; target.write_bytes(data)
        with self.assertRaises(Exception):
            recover(catalog, SECRET, self.base / "output")
        self.assertFalse((self.base / "output").exists())

    def assert_rejected(self, data, secret=SECRET):
        source = self.base / "bad.c84backup"
        source.write_bytes(data)
        with self.assertRaises(Exception):
            recover(source, secret, self.base / "output")
        self.assertFalse((self.base / "output").exists())
        self.assertEqual(sorted(p.name for p in self.base.iterdir()), ["bad.c84backup"])

    def test_wrong_secret(self):
        self.assert_rejected((FIXTURES / "v2.c84backup").read_bytes(), "incorrect recovery key")

    def test_modified_ciphertext_cleans_partial_output(self):
        data = bytearray((FIXTURES / "v2.c84backup").read_bytes())
        data[-1] ^= 1
        self.assert_rejected(data)

    def test_truncated_backup_cleans_partial_output(self):
        self.assert_rejected((FIXTURES / "v2.c84backup").read_bytes()[:-8])

    def test_trailing_bytes_are_rejected(self):
        self.assert_rejected((FIXTURES / "v2.c84backup").read_bytes() + b"extra")

    def test_oversize_header_is_rejected_without_allocating_it(self):
        self.assert_rejected(b"C84B0002" + struct.pack(">Q", 2**63))

    def test_existing_folder_is_untouched(self):
        output = self.base / "existing"
        output.mkdir()
        keep = output / "keep.txt"
        keep.write_bytes(b"existing data")
        with self.assertRaises(ValueError):
            recover(FIXTURES / "v2.c84backup", SECRET, output)
        self.assertEqual(keep.read_bytes(), b"existing data")
        self.assertEqual(len(list(output.iterdir())), 1)


class RedundantRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.data = (FIXTURES / "v3.c84backup").read_bytes()
        self.envelope_size = struct.unpack(">Q", self.data[8:16])[0]
        self.raw = self.data[16:16 + self.envelope_size]
        self.body_start = 16 + self.envelope_size
        self.footer_start = len(self.data) - 16 - self.envelope_size
        self.envelope = json.loads(self.raw)
        # Independent test-only derivation for authenticated malformed fixtures.
        # The real valid fixture itself is always written by Swift, not Python.
        header = json.loads(base64.b64decode(self.envelope["vaultHeader"]))
        compact = SECRET.replace("-", "")
        wrapping = hashlib.pbkdf2_hmac("sha256", compact.encode(), base64.b64decode(header["salt"]), 600000, 32)
        sealed = base64.b64decode(header["wrappedKey"])
        self.key = AESGCM(wrapping).decrypt(sealed[:12], sealed[12:], f'Calc84/v2/{header["id"]}/key'.encode())
        self.catalog_key = HKDF(algorithm=hashes.SHA256(), length=32, salt=self.envelope["snapshotID"].encode(),
                                info=b"Arithen/backup/v3/catalog").derive(self.key)
        self.aad = ("Arithen/backup/v3/" + self.envelope["snapshotID"]).encode()
        sealed = base64.b64decode(self.envelope["sealedCatalog"])
        self.catalog = json.loads(AESGCM(self.catalog_key).decrypt(sealed[:12], sealed[12:], self.aad))

    def tearDown(self):
        self.temp.cleanup()

    def write(self, data, name="source.c84backup"):
        source = self.base / name
        source.write_bytes(data)
        return source

    def assert_rejected(self, data, salvage=False, secret=SECRET):
        source = self.write(data)
        output = self.base / "must-not-exist"
        with self.assertRaises(Exception):
            recover(source, secret, output, salvage=salvage)
        self.assertFalse(output.exists())
        self.assertFalse(any(path.name.startswith(".arithen-recovery-") for path in self.base.iterdir()))

    def rewritten(self, catalog=None, envelope=None, body=None):
        envelope = dict(self.envelope if envelope is None else envelope)
        if catalog is not None:
            nonce = os.urandom(12)
            sealed = nonce + AESGCM(self.catalog_key).encrypt(nonce, json.dumps(catalog).encode(), self.aad)
            envelope["sealedCatalog"] = base64.b64encode(sealed).decode()
        raw = json.dumps(envelope).encode()
        body = self.data[self.body_start:self.footer_start] if body is None else body
        return b"ARITHB03" + struct.pack(">Q", len(raw)) + raw + body + raw + struct.pack(">Q", len(raw)) + b"ARITHEND"

    def test_swift_v3_originals_dates_locations_and_empty_resource(self):
        output = self.base / "recovered"
        result = recover(FIXTURES / "v3.c84backup", SECRET.lower(), output)
        self.assertTrue(result["complete"])
        self.assertEqual(result["authenticatedRecords"], 3)
        self.assertEqual(result["metadataCopies"], ["front", "footer"])
        metadata = json.loads((output / "metadata.json").read_text(encoding="utf-8"))
        photo = next(item for item in metadata if item["name"].endswith("AUX.jpg"))
        self.assertEqual((output / photo["exportedFilename"]).read_bytes(), b"portable original bytes")
        self.assertEqual(photo["captureDateUTC"], "2023-03-28T10:40:00.125000+00:00")
        self.assertEqual((photo["latitude"], photo["longitude"]), (-33.75, -118.25))
        self.assertEqual(photo["albums"], ["Travel", "Receipts"])
        self.assertEqual(photo["tags"], ["ticket", "été"])
        self.assertAlmostEqual((output / photo["exportedFilename"]).stat().st_mtime, 1680000000.125, delta=0.01)
        video = next(item for item in metadata if item["name"] == "video.mov")
        self.assertEqual((output / video["exportedFilename"]).read_bytes(), bytes([0xA7]) * (1024 * 1024 + 7))
        empty = next(item for item in metadata if item["name"] == "empty.bin")
        self.assertEqual((output / empty["exportedFilename"]).read_bytes(), b"")
        self.assertTrue(json.loads((output / "recovery-report.json").read_text())["complete"])

    def test_footer_recovers_damaged_front_envelope_magic_and_length(self):
        for label, data in (("envelope", bytearray(self.data)), ("magic", bytearray(self.data)),
                            ("length", bytearray(self.data)), ("nonobject-json", bytearray(self.data))):
            with self.subTest(label=label):
                if label == "envelope":
                    data[16] ^= 1
                elif label == "magic":
                    data[0] ^= 1
                elif label == "length":
                    data[8:16] = struct.pack(">Q", 2**63)
                else:
                    data[16:self.body_start] = b"[]" + b" " * (self.envelope_size - 2)
                result = recover(self.write(data), SECRET)
                self.assertTrue(result["complete"])
                self.assertEqual(result["metadataCopies"], ["footer"])
                self.assertIn("redundancyWarning", result)

    def test_front_recovers_damaged_or_missing_footer(self):
        damaged = bytearray(self.data)
        damaged[self.footer_start] ^= 1
        for data in (damaged, self.data[:-8], self.data[:self.footer_start]):
            with self.subTest(size=len(data)):
                result = recover(self.write(data), SECRET)
                self.assertTrue(result["complete"])
                self.assertEqual(result["metadataCopies"], ["front"])

    def test_wrong_key_and_both_damaged_copies_never_salvage(self):
        for salvage in (False, True):
            self.assert_rejected(self.data, salvage=salvage, secret="wrong key")
            damaged = bytearray(self.data)
            damaged[16] ^= 1
            damaged[self.footer_start] ^= 1
            self.assert_rejected(damaged, salvage=salvage)

    def test_damaged_resource_strict_rejection_and_explicit_partial_salvage(self):
        damaged = bytearray(self.data)
        damaged[self.body_start + self.catalog["records"][0]["bytes"] - 1] ^= 1
        self.assert_rejected(damaged)
        output = self.base / "partial"
        result = recover(self.write(damaged), SECRET, output, salvage=True)
        self.assertFalse(result["complete"])
        self.assertEqual(result["status"], "partial")
        self.assertEqual(result["authenticatedRecords"], 2)
        self.assertEqual(result["expectedRecords"], 3)
        self.assertEqual([record["id"] for record in result["omittedRecords"]], [self.catalog["records"][0]["id"]])
        metadata = json.loads((output / "metadata.json").read_text(encoding="utf-8"))
        self.assertEqual(len(metadata), 2)
        self.assertNotIn(self.catalog["records"][0]["id"], {item["id"] for item in metadata})
        self.assertEqual(json.loads((output / "recovery-report.json").read_text())["status"], "partial")

    def test_truncated_body_salvages_only_whole_authenticated_resources(self):
        last = self.catalog["records"][-1]
        data = self.data[:self.footer_start - last["bytes"] + last["bytes"] // 2]
        self.assert_rejected(data)
        output = self.base / "partial"
        result = recover(self.write(data), SECRET, output, salvage=True)
        self.assertFalse(result["complete"])
        self.assertEqual(result["authenticatedRecords"], 2)
        self.assertEqual(result["omittedRecords"][0]["id"], last["id"])
        self.assertFalse(any(path.name.startswith(last["id"]) for path in output.iterdir()))

    def test_disagreeing_authenticated_catalogs_and_extra_bytes_are_rejected(self):
        second = (FIXTURES / "v3-other.c84backup").read_bytes()
        size = struct.unpack(">Q", second[-16:-8])[0]
        ambiguous = self.data[:self.footer_start] + second[-size - 16:]
        for salvage in (False, True):
            self.assert_rejected(ambiguous, salvage=salvage)
            self.assert_rejected(self.data + b"extra", salvage=salvage)
        altered = json.loads(json.dumps(self.catalog))
        altered["index"] = base64.b64encode(bytes(28)).decode()
        damaged_index = self.rewritten(catalog=altered)
        size = struct.unpack(">Q", damaged_index[-16:-8])[0]
        # Authentication of both catalogs must be compared before attempting to
        # decode either index, even when one catalog contains an unusable index.
        self.assert_rejected(damaged_index[:-size - 16] + self.data[self.footer_start:], salvage=True)

    def test_header_binding_rejects_even_valid_rewrapped_header_json(self):
        envelope = dict(self.envelope)
        header = json.loads(base64.b64decode(envelope["vaultHeader"]))
        header["unrecognizedField"] = "Header bytes must be bound even if decoding ignores this field."
        envelope["vaultHeader"] = base64.b64encode(json.dumps(header).encode()).decode()
        self.assert_rejected(self.rewritten(envelope=envelope), salvage=True)

    def test_catalog_hash_and_resource_aead_are_independently_required(self):
        catalog = json.loads(json.dumps(self.catalog))
        digest = catalog["records"][0]["sha256"]
        catalog["records"][0]["sha256"] = ("0" if digest[0] != "0" else "1") + digest[1:]
        result = recover(self.write(self.rewritten(catalog=catalog)), SECRET, salvage=True)
        self.assertFalse(result["complete"])
        self.assertEqual(result["authenticatedRecords"], 2)
        # A matching outer digest still cannot authenticate corrupted ciphertext.
        body = bytearray(self.data[self.body_start:self.footer_start])
        length = self.catalog["records"][0]["bytes"]
        body[length - 1] ^= 1
        catalog["records"][0]["sha256"] = hashlib.sha256(body[:length]).hexdigest()
        result = recover(self.write(self.rewritten(catalog=catalog, body=body)), SECRET, salvage=True)
        self.assertFalse(result["complete"])
        self.assertEqual(result["authenticatedRecords"], 2)

    def test_duplicate_inventory_and_oversized_lengths_are_rejected(self):
        catalog = json.loads(json.dumps(self.catalog))
        catalog["records"][1] = dict(catalog["records"][0])
        self.assert_rejected(self.rewritten(catalog=catalog), salvage=True)
        catalog = json.loads(json.dumps(self.catalog))
        catalog["records"][0]["bytes"] = 2**63
        self.assert_rejected(self.rewritten(catalog=catalog), salvage=True)

    def test_salvage_does_not_overwrite_existing_folder_or_accept_legacy(self):
        output = self.base / "existing"
        output.mkdir()
        keep = output / "keep.txt"
        keep.write_bytes(b"existing data")
        with self.assertRaises(ValueError):
            recover(FIXTURES / "v3.c84backup", SECRET, output, salvage=True)
        self.assertEqual(keep.read_bytes(), b"existing data")
        with self.assertRaises(ValueError):
            recover(FIXTURES / "v2.c84backup", SECRET, self.base / "legacy", salvage=True)
        self.assertFalse((self.base / "legacy").exists())

    def cloud_fixture(self):
        folder = self.base / "cloud-v2"
        (folder / "snapshots").mkdir(parents=True)
        (folder / "objects").mkdir()
        offset = self.body_start
        for record in self.catalog["records"]:
            data = self.data[offset:offset + record["bytes"]]
            offset += record["bytes"]
            (folder / "objects" / f'{record["id"]}-{record["sha256"]}.enc').write_bytes(data)
        header = json.loads(base64.b64decode(self.envelope["vaultHeader"]))
        catalog = folder / "snapshots" / "portable.c84cloud"
        catalog.write_text(json.dumps({"version": 2, "vaultID": header["id"],
            "header": self.envelope["vaultHeader"], "index": self.catalog["index"],
            "records": self.catalog["records"], "archiveEnvelope": base64.b64encode(self.raw).decode()}))
        return catalog

    def test_v2_cloud_snapshot_reassembles_redundant_archive_and_preserves_metadata(self):
        output = self.base / "recovered"
        result = recover(self.cloud_fixture(), SECRET, output)
        self.assertEqual(result["formatVersion"], 3)
        self.assertEqual(result["authenticatedRecords"], 3)
        self.assertEqual(result["metadataCopies"], ["front", "footer"])
        self.assertTrue(result["complete"])
        metadata = json.loads((output / "metadata.json").read_text(encoding="utf-8"))
        photo = next(item for item in metadata if item["name"].endswith("AUX.jpg"))
        self.assertEqual((output / photo["exportedFilename"]).read_bytes(), b"portable original bytes")
        self.assertEqual(photo["captureDateUTC"], "2023-03-28T10:40:00.125000+00:00")
        self.assertEqual((photo["latitude"], photo["longitude"]), (-33.75, -118.25))

    def test_v2_cloud_outer_inventory_tampering_and_missing_objects_leave_no_output(self):
        catalog = self.cloud_fixture()
        snapshot = json.loads(catalog.read_text())
        changed = json.loads(json.dumps(snapshot))
        changed["records"][0]["sha256"] = "0" * 64
        catalog.write_text(json.dumps(changed))
        with self.assertRaises(ValueError):
            recover(catalog, SECRET, self.base / "output")
        self.assertFalse((self.base / "output").exists())
        catalog.write_text(json.dumps(snapshot))
        next((catalog.parent.parent / "objects").iterdir()).unlink()
        with self.assertRaises(Exception):
            recover(catalog, SECRET, self.base / "output")
        self.assertFalse((self.base / "output").exists())

    def test_salvage_command_reports_partial_recovery_and_nonzero_exit(self):
        damaged = bytearray(self.data)
        damaged[self.body_start + self.catalog["records"][0]["bytes"] - 1] ^= 1
        source = self.write(damaged)
        output = self.base / "partial"
        console = io.StringIO()
        with mock.patch("sys.argv", ["recover.py", str(source), "--output", str(output), "--salvage"]), \
             mock.patch("recover.getpass.getpass", return_value=SECRET), redirect_stdout(console):
            self.assertEqual(main(), 2)
        self.assertIn("PARTIAL RECOVERY ONLY", console.getvalue())
        self.assertIn('"complete": false', console.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
