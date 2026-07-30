#!/usr/bin/env python3
from pathlib import Path

try:
    from PIL import Image
except ImportError as error:
    raise SystemExit("Pillow is required to rebuild NetHalo.icns") from error


project_dir = Path(__file__).resolve().parent.parent
source_path = project_dir / "Resources" / "AppIcon.png"
output_path = project_dir / "Resources" / "NetHalo.icns"

with Image.open(source_path) as source:
    source.convert("RGBA").save(output_path, format="ICNS")

print(output_path)
