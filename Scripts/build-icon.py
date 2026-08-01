#!/usr/bin/env python3
import io
import struct
from pathlib import Path

try:
    from PIL import Image
except ImportError as error:
    raise SystemExit("Pillow is required to rebuild NetHalo.icns") from error


project_dir = Path(__file__).resolve().parent.parent
source_path = project_dir / "Resources" / "AppIcon.png"
output_path = project_dir / "Resources" / "NetHalo.icns"

with Image.open(source_path) as source:
    icon = source.convert("RGBA")
    if icon.width != icon.height or icon.width < 1024:
        raise SystemExit("AppIcon.png must be square and at least 1024 x 1024")

    # Pillow's built-in ICNS writer omits the non-Retina 16 px and 32 px
    # representations. Finder can usually fall back to a larger layer, but the
    # Login Items list in System Settings does not always do so and displays a
    # generic placeholder instead. Write the complete modern ICNS set.
    representations = (
        (b"icp4", 16),
        (b"icp5", 32),
        (b"icp6", 64),
        (b"ic07", 128),
        (b"ic08", 256),
        (b"ic09", 512),
        (b"ic10", 1024),
        (b"ic11", 32),
        (b"ic12", 64),
        (b"ic13", 256),
        (b"ic14", 512),
    )

    png_by_size = {}
    for size in {size for _, size in representations}:
        resized = icon.resize((size, size), Image.Resampling.LANCZOS)
        stream = io.BytesIO()
        resized.save(stream, format="PNG")
        png_by_size[size] = stream.getvalue()

    entries = [
        (kind, png_by_size[size])
        for kind, size in representations
    ]
    toc_length = 8 + 8 * len(entries)
    total_length = 8 + toc_length + sum(8 + len(data) for _, data in entries)

    with output_path.open("wb") as output:
        output.write(b"icns")
        output.write(struct.pack(">I", total_length))
        output.write(b"TOC ")
        output.write(struct.pack(">I", toc_length))
        for kind, data in entries:
            output.write(kind)
            output.write(struct.pack(">I", 8 + len(data)))
        for kind, data in entries:
            output.write(kind)
            output.write(struct.pack(">I", 8 + len(data)))
            output.write(data)

print(output_path)
