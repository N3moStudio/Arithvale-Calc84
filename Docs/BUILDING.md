# Build Arithen


With Swift 6, xtool, and the iOS 27.1 Darwin SDK in WSL/Linux or macOS:

```sh
python Scripts/prepare_mega.py
python3 -m venv .build/recovery-venv
.build/recovery-venv/bin/python -m pip install -r Scripts/recovery-requirements.txt
python3 Scripts/verify_release.py --ipa --python "$PWD/.build/recovery-venv/bin/python"
```

The verifier runs tests and build sequentially because they share .build. It writes full logs and input hashes, then produces an ignored `Releases/Arithen-0.5.0-test-<hash>/` test kit. Any changed source invalidates the evidence. Output: xtool/Arithen.ipa. Bundle identifier: studio.n3mo.calc84. Linux tests use pinned Swift Crypto 4.3.1; iPhone uses CryptoKit/CommonCrypto.

`prepare_mega.py` downloads checksum-pinned MEGA source and iOS arm64 dependencies into ignored Vendor folders. They are not required for core-only tests. Native builds require them. No credentials are part of the build. The native MEGA dependency bundle is device-only; simulator builds need matching simulator libraries.

The app's iOS linker settings explicitly record SDK 27.1 while keeping the minimum OS at 17.0. This corrects this cross-build toolchain's fallback SDK metadata so native appearance follows the modern SDK. If changing SDKs, update the linker declaration and package check to match the SDK actually used.

For independent recovery tests: set C84_FIXTURE_DIR to a new persistent folder, run the Swift fixture test, then Scripts/test_recovery.py with the same environment setting.

See [SECURITY.md](SECURITY.md), [DESIGN.md](DESIGN.md), and [DEVICE-CHECKS.md](DEVICE-CHECKS.md).


## Recover without the app

Install Python 3.10+ and the dependency once:

```sh
python -m pip install -r Scripts/recovery-requirements.txt
python Scripts/recover.py "Library.c84backup" --verify-only
python Scripts/recover.py "Library.c84backup" --output "Recovered originals"
```

On Windows, **Recover Vault.cmd** prompts for the file, a new output folder, and the secret after Python/dependency installation. Recovery runs offline and supports old/new backups. It writes originals plus metadata.json. Add --include-deleted for Recently Deleted. Recovered output is unencrypted.

For cloud recovery without the app, download the entire `c84/v1/<library ID>` folder from the provider, keeping `objects/` and `snapshots/` together. Give `recover.py` a `.c84cloud` file inside `snapshots/` instead of a `.c84backup`. The same recovery key is required. The tool checks and assembles the encrypted records offline before extraction.

