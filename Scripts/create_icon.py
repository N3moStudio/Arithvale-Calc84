"""Export the user's approved PA1 artwork without changing its visual design."""
from pathlib import Path
import hashlib
from PIL import Image, ImageCms

root = Path(__file__).resolve().parents[1]
source = root / "Docs/Brand/Arithen-PA1-approved.png"
expected = "ad0068b3515a0c10297bbd8174d4b9f0f9f20f68aa232e2fd5887e8d9d0b5427"
if hashlib.sha256(source.read_bytes()).hexdigest() != expected:
    raise SystemExit("Approved PA1 source changed. Review the design approval before exporting.")
profile = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
with Image.open(source) as image:
    for size, output in [(1024, root / "AppIcon.png"),
                         (256, root / "Sources/Calc84/Resources/ArithenIcon.png")]:
        image.convert("RGB").resize((size, size), Image.Resampling.LANCZOS).save(output, icc_profile=profile)
print("Exported approved Arithen PA1 artwork with an embedded sRGB profile.")
