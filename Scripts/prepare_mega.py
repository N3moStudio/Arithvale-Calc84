"""Prepare pinned public MEGA sources/dependencies for the iOS cross-build.

Downloaded archives are checksummed before extraction. Does not need account
credentials. The app key is entered on-device; no developer key is bundled.
"""
from pathlib import Path
import hashlib
import urllib.request
import zipfile

root = Path(__file__).resolve().parents[1]
cache = root.parent / "tmp" / "mega-research"
cache.mkdir(parents=True, exist_ok=True)
inputs = [
    ("sdk.zip", "https://github.com/meganz/sdk/archive/refs/tags/v10.20.0.zip",
     "be78799244b8f6371df18f0f0f1731f2312316ed11ba1e928c866a6adfdd6108"),
    ("libmega.zip", "https://s3.g.s4.mega.io/dmlaaezwz52y37atz56mfvmrvltfagrltbgpr/ios-xcframeworks/libmega_25_12_12.xcframework.zip",
     "f1e94204bf47c79f65733bc5e9b9606857448a1645c88a59d106c643fac38b92"),
]
for filename, url, expected in inputs:
    path = cache / filename
    if not path.exists():
        urllib.request.urlretrieve(url, path)
    with path.open("rb") as f:
        actual = hashlib.file_digest(f, "sha256").hexdigest()
    if actual != expected:
        raise SystemExit(f"Checksum mismatch: {filename}")
    with zipfile.ZipFile(path) as archive:
        prefix = "sdk-10.20.0/" if filename == "sdk.zip" else "libmega.xcframework/ios-arm64/"
        target = root / "Vendor" / ("MEGASDK" if filename == "sdk.zip" else "MEGADependencies")
        for entry in archive.infolist():
            if not entry.filename.startswith(prefix) or entry.is_dir():
                continue
            relative = Path(entry.filename[len(prefix):])
            # SwiftPM's macOS build driver can mistake CMake build descriptions
            # for compilable sources when recursively expanding this SDK.
            if relative.name == "CMakeLists.txt":
                continue
            if relative.is_absolute() or ".." in relative.parts:
                raise SystemExit("Unsafe archive member")
            output = target / relative
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(archive.read(entry))
print("Prepared MEGA SDK 10.20.0 and checksum-verified iOS arm64 dependencies.")
