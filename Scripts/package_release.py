"""Verify the tested native IPA and produce a small, reproducible test kit."""
from pathlib import Path
import hashlib
import json
import plistlib
import re
import shutil
import struct
import zipfile

root = Path(__file__).resolve().parents[1]
output = root.parent / "outputs" / "Calc84-0.3.0-test-kit"
output.mkdir(parents=True, exist_ok=True)
ipa = root / "xtool" / "Calc84.ipa"
tests = (root / ".build" / "cloud-tests.log").read_text(encoding="utf-8-sig")
recovery = (root / ".build" / "cloud-recovery-tests-fixed.log").read_text(encoding="utf-8-sig")
build = (root / ".build" / "cloud-ios-build.log").read_text(encoding="utf-8-sig")
assert "Test Suite 'All tests' passed" in tests and "Executed 38 tests, with 0 failures" in tests
assert re.search(r"Ran 11 tests", recovery) and "\nOK" in recovery and "FAILED" not in recovery
assert "Build complete!" in build and "Calc84.ipa" in build and "error:" not in build
inputs = [p for p in (root / "Sources").rglob("*") if p.is_file()]
inputs += [root / x for x in ("Package.swift", "Package.resolved", "xtool.yml", "AppIcon.png")]
assert all(p.stat().st_mtime <= ipa.stat().st_mtime for p in inputs), "Native inputs are newer than IPA"
with zipfile.ZipFile(ipa) as archive:
    assert archive.testzip() is None
    info = plistlib.loads(archive.read("Payload/Calc84.app/Info.plist"))
    assert info["CFBundleIdentifier"] == "studio.n3mo.calc84"
    assert info["CFBundleDisplayName"] == "Calc 84"
    assert info["CFBundleShortVersionString"] == "0.3.0" and info["CFBundleVersion"] == "3"
    assert not info.get("NSAppTransportSecurity"), "No insecure transport exceptions"
    assert info["UIFileSharingEnabled"] is False
    assert info["LSSupportsOpeningDocumentsInPlace"] is False
    assert info["NSPhotoLibraryUsageDescription"] and info["NSPhotoLibraryAddUsageDescription"]
    assert not info.get("UIBackgroundModes")
    assert info["UTExportedTypeDeclarations"][0]["UTTypeIdentifier"] == "studio.n3mo.calc84.backup"
    binary = archive.read("Payload/Calc84.app/" + info["CFBundleExecutable"])
    assert binary[:4] == bytes.fromhex("cffaedfe")
    assert int.from_bytes(binary[4:8], "little") == 0x0100000C
    commands = struct.unpack_from("<I", binary, 16)[0]
    position, min_version, sdk = 32, None, None
    for _ in range(commands):
        command, size = struct.unpack_from("<II", binary, position)
        assert size >= 8
        if command == 0x32:
            platform, min_version, sdk = struct.unpack_from("<III", binary, position + 8)
            assert platform == 2, "Expected iOS device platform"
        position += size
    assert min_version == (17 << 16), min_version
    assert sdk == ((27 << 16) | (1 << 8)), "Expected the actual iOS 27.1 SDK, not the deployment target"
    assert not any(x.endswith(".mobileprovision") for x in archive.namelist())
    assert any("Icon" in x and x.endswith(".png") for x in archive.namelist())

artifact = output / "Calc 84 0.3.0.ipa"
shutil.copy2(ipa, artifact)
source = output / "Calc84-0.3.0-source.zip"
with zipfile.ZipFile(source, "w", zipfile.ZIP_DEFLATED) as archive:
    for directory in ("Sources", "Tests", "Scripts"):
        for path in sorted((root / directory).rglob("*")):
            if path.is_file() and "__pycache__" not in path.parts:
                archive.write(path, Path("Calc84") / path.relative_to(root))
    for filename in ("Package.swift", "Package.resolved", "xtool.yml", ".gitignore", "README.md",
                     "SECURITY.md", "DESIGN.md", "DEVICE-CHECKS.md", "AppIcon.png", "Recover Vault.cmd"):
        archive.write(root / filename, Path("Calc84") / filename)
with zipfile.ZipFile(source) as archive:
    assert archive.testzip() is None
    for entry in archive.infolist():
        relative = Path(entry.filename).relative_to("Calc84")
        assert archive.read(entry) == (root / relative).read_bytes(), relative

shutil.copy2(root / "DEVICE-CHECKS.md", output / "TEST-ON-YOUR-IPHONE.md")
(output / "START-HERE.txt").write_text(
    "Calc 84 0.3.0 alpha (build 3) - cloud integration test build\n\n"
    "1. Back up your current library, then update with Calc 84 0.3.0.ipa using the same SideStore setup.\n"
    "2. Existing library: use your current calculator code. Fresh install: enter 160160 and =, save the recovery key separately, then choose your code.\n"
    "3. Import disposable sample photos/videos first. Originals remain where they are.\n"
    "4. Settings > Cloud Backup: connect your account. MEGA needs your developer app key; never enter a recovery key in that field.\n"
    "5. Back Up Now, then Test Cloud Recovery with the original Calc 84 recovery key. Keep an independent Files backup too.\n"
    "6. Follow TEST-ON-YOUR-IPHONE.md before trusting it with important files.\n\n"
    "Native build passed; 38 Swift tests and 11 independent recovery tests passed.\n"
    "Actual account login, uploads/downloads, iPhone installation, Photos, and lifecycle behavior remain unverified.\n"
    "Blomp's documented storage host failed TLS hostname validation here; the app will not bypass certificate checks.\n"
    "Do not uninstall an existing library or remove your only originals to test this.\n\n"
    "Source ZIP includes the app, build files, tests, documentation, and offline recovery tool. Run Scripts/prepare_mega.py to fetch pinned native dependencies.\n"
    "No remote accounts or deployments were changed.\n",
    encoding="utf-8")
evidence = output / "Verification"
evidence.mkdir(exist_ok=True)
for name in ("cloud-tests.log", "cloud-recovery-tests-fixed.log", "cloud-ios-build.log"):
    shutil.copy2(root / ".build" / name, evidence / name)
version_string = lambda packed: f"{packed >> 16}.{(packed >> 8) & 255}.{packed & 255}"
files = [p for p in sorted(output.rglob("*")) if p.is_file() and p.name != "BUILD-RESULT.json"]
result = {
    "app": "Calc 84", "version": "0.3.0", "build": "3", "releaseStage": "alpha",
    "signedForInstallation": False, "architecture": "arm64", "minimumIOS": version_string(min_version),
    "sdk": version_string(sdk), "coreTests": {"passed": 38, "failed": 0},
    "independentRecoveryTests": {"passed": 11, "failed": 0}, "deviceTested": False, "liveCloudAccountsTested": False,
    "files": {p.relative_to(output).as_posix(): {
        "bytes": p.stat().st_size, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()
    } for p in files}
}
(output / "BUILD-RESULT.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result, indent=2))
