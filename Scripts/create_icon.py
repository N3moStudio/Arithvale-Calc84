"""Render the project's original geometric calculator glyph; no external artwork."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
scale = 2
canvas = Image.new("RGB", (1024 * scale, 1024 * scale), "#e8edf5")
draw = ImageDraw.Draw(canvas)

def rounded(box, radius, fill):
    draw.rounded_rectangle(tuple(round(x * scale) for x in box), radius=radius * scale, fill=fill)

rounded((213, 136, 811, 914), 116, "#c4ccda")
rounded((213, 110, 811, 888), 116, "#253044")
rounded((267, 164, 757, 366), 52, "#dce6f4")
rounded((476, 234, 699, 251), 8, "#30477a")
rounded((569, 282, 699, 299), 8, "#30477a")
for x in (277, 444):
    for y in (422, 565, 708):
        rounded((x, y, x + 130, y + 112), 30, "#566277")
rounded((611, 422, 741, 534), 30, "#566277")
rounded((611, 565, 741, 820), 30, "#a1c2ff")
rounded((642, 659, 710, 676), 7, "#253044")
rounded((642, 707, 710, 724), 7, "#253044")
canvas.resize((1024, 1024), Image.Resampling.LANCZOS).save(root / "AppIcon.png")

def luminance(hex_color):
    channels = [int(hex_color[i:i+2], 16) / 255 for i in (1, 3, 5)]
    linear = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in channels]
    return sum(v * w for v, w in zip(linear, (.2126, .7152, .0722)))

for foreground, background in [("#2947a1", "#ffffff"), ("#a1c2ff", "#1f2630"), ("#1c1c1e", "#e0e8f2"), ("#ffffff", "#1f2630")]:
    a, b = sorted((luminance(foreground), luminance(background)))
    print(f"{foreground} on {background}: {(b + .05) / (a + .05):.2f}:1")
