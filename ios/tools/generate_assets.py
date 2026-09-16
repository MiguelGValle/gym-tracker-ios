"""Render the existing Android vector icon as iOS app icons (Pillow required)."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1] / "GymTracker" / "Assets.xcassets"
root.mkdir(parents=True, exist_ok=True)
(root / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}), encoding="utf-8")
icons = root / "AppIcon.appiconset"
icons.mkdir(exist_ok=True)
# Same rectangles and colors as app/src/main/res/drawable/ic_launcher_foreground.xml.
image = Image.new("RGB", (1024, 1024), "#0C0D0F")
draw = ImageDraw.Draw(image)
for x, y, width, height in [(26, 48, 8, 12), (74, 48, 8, 12), (37, 43, 34, 22), (18, 44, 6, 20), (84, 44, 6, 20)]:
    draw.rectangle(tuple(round(v * 1024 / 108) for v in (x, y, x + width, y + height)), fill="#FF6B00")
image.save(icons / "AppIcon.png")
metadata = {"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}}
(icons / "Contents.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
accent = root / "AccentColor.colorset"; accent.mkdir(exist_ok=True)
(accent / "Contents.json").write_text(json.dumps({"colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {"red": "1.000", "green": "0.420", "blue": "0.000", "alpha": "1.000"}}}], "info": {"author": "xcode", "version": 1}}, indent=2), encoding="utf-8")
print("Rendered existing Gym Tracker icon at 1024 px")
