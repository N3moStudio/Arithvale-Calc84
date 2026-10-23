"""Independent Python recovery checks against fixtures produced by Swift tests."""
import json
import base64
import hashlib
import os
from pathlib import Path
import struct
import tempfile
import unittest
from recover import recover, block, number, exact

SECRET = "C24144AF-B3E94438-97C89127-E373D053-9F19F720-E47CA588-7C38BF10-14C2AF32"
FIXTURES = Path(os.environ["C84_FIXTURE_DIR"])


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
        records = json.loads((output / "metadata.json").read_text())
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
        records = json.loads((output / "metadata.json").read_text())
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
