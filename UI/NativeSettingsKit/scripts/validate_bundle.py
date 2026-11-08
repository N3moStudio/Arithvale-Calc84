"""Portable bundle checks, NOT a Swift compiler or native UI test. Python 3.9+."""
from pathlib import Path
import math
import re
import sys
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
errors = []


def check(condition, description):
    if not condition:
        errors.append(description)


def luminance(value):
    channels = [(value >> shift & 255) / 255 for shift in (16, 8, 0)]
    linear = [c / 12.92 if c <= 0.04045 else math.pow((c + 0.055) / 1.055, 2.4) for c in channels]
    return sum(c * w for c, w in zip(linear, (0.2126, 0.7152, 0.0722)))


source = ROOT / "Sources" / "NativeSettingsKit"
theme_text = (source / "NSKTheme.swift").read_text(encoding="utf-8")
palettes = re.findall(r"case \.(\w+):\s*light = \[([^]]+)\]\s*night = \[([^]]+)\]", theme_text)
expected = {"glacier", "afterhours", "porcelain", "ion", "ember", "bloom", "blueprint", "titanium"}
check({name for name, *_ in palettes} == expected, "Expected exactly the eight approved theme palettes")
pairs = [(5, 3), (5, 4), (6, 3), (6, 4), (2, 3), (2, 4), (0, 3), (0, 4), (1, 0)]
ratios = []
for name, light, dark in palettes:
    for mode, raw in (("light", light), ("dark", dark)):
        values = [int(value.strip(), 16) for value in raw.split(",")]
        check(len(values) == 7, f"{name}/{mode}: palette must have seven tokens")
        if len(values) != 7:
            continue
        for fg, bg in pairs:
            a, b = luminance(values[fg]), luminance(values[bg])
            ratio = (max(a, b) + 0.05) / (min(a, b) + 0.05)
            ratios.append(ratio)
            check(ratio >= 4.5, f"{name}/{mode}: text pair {fg}/{bg} contrast {ratio:.2f} < 4.5")

link_count = 0
for document in ROOT.glob("*.md"):
    text = document.read_text(encoding="utf-8")
    for target in re.findall(r"\]\(([^)]+)\)", text):
        if urlparse(target).scheme or target.startswith("#"):
            continue
        link_count += 1
        resolved = (document.parent / unquote(target.split("#")[0])).resolve()
        check(resolved.is_relative_to(ROOT) and resolved.exists(), f"Broken/nonportable local link in {document.name}: {target}")

for swift in source.glob("*.swift"):
    content = swift.read_text(encoding="utf-8")
    # Prevent accidental copying of Elsepin's runtime dependencies or data ownership.
    for pattern in (r"\b(?:UserDefaults|AppStorage|URLSession|FileManager|Keychain|SpoofSession|SessionPreferences|DeveloperLogStore)\b",
                    r"\.navigationBarBackButtonHidden\(true\)", r"\.id\(theme\)", r"Timer\.publish", r"\.onAppear\s*\{"):
        code = "\n".join(line.split("//")[0] for line in content.splitlines())
        check(not re.search(pattern, code), f"Unexpected ownership/navigation pattern in {swift.name}: {pattern}")
    check("\ufffd" not in content, f"Replacement character in {swift.name}")

required = ["Package.swift", "README.md", "AGENTS.md", "DESIGN.md", "ADOPTION.md", "PROMPT.md",
            "PROVENANCE.md", "FEATURE-MAP.md", "VALIDATION.md", "LICENSES/Elsepin-MIT.txt",
            "LICENSES/Elsepin-New-Additions.txt", "Examples/SettingsGallery.swift",
            "Tests/NativeSettingsKitTests/AppearanceContractTests.swift"]
for filename in required:
    check((ROOT / filename).is_file(), f"Missing {filename}")

if errors:
    print("FAILED portable bundle checks:")
    for error in errors:
        print("-", error)
    sys.exit(1)
print(f"PASS: {len(palettes)} themes, {len(ratios)} solid-color contrast pairs (minimum {min(ratios):.2f}:1), {link_count} local documentation links.")
print("PASS: bundle files and production source ownership/navigation guardrails.")
print("NOT RUN: native Swift compilation, XCTest execution, simulator/device visual, accessibility and gesture checks.")
