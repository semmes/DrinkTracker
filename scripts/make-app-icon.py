#!/usr/bin/env python3
"""Placeholder app icon for Tallyist: five tally marks on the ramp's dark blue.

Regenerate with:  python3 scripts/make-app-icon.py

Deliberately dependency-free — it writes the PNG bytes itself rather than needing
Pillow, so it runs anywhere Python does. The palette comes from the documented
sequential blue ramp (see IntensityPalette.swift): background is step 650, marks
are the app's near-white surface tone. A tally is the literal namesake, and four
strokes plus the slash is the canonical way to draw one — it is a counting mark,
not a count being encouraged (the icon shows *a tally*, not a target).

Placeholder quality on purpose. When a real icon exists, replace AppIcon.png and
delete this script.
"""

import math
import struct
import zlib
from pathlib import Path

W = H = 1024
BG = (16, 66, 129)      # #104281 — sequential blue, step 650
FG = (252, 252, 251)    # #fcfcfb — near-white, matches the light surface

# Four vertical strokes (as capsules: a segment with a radius), then the slash.
BAR_R = 40
BARS = [((cx, 340.0), (cx, 684.0)) for cx in (256.0, 416.0, 576.0, 736.0)]
SLASH = ((176.0, 732.0), (848.0, 292.0))
SLASH_R = 42


def seg_dist2(px, py, a, b):
    """Squared distance from point to segment — squared to skip 1M sqrt calls."""
    (x0, y0), (x1, y1) = a, b
    dx, dy = x1 - x0, y1 - y0
    t = ((px - x0) * dx + (py - y0) * dy) / (dx * dx + dy * dy)
    t = 0.0 if t < 0.0 else 1.0 if t > 1.0 else t
    ex, ey = x0 + t * dx, y0 + t * dy
    return (px - ex) ** 2 + (py - ey) ** 2


def render():
    bar_r2 = BAR_R * BAR_R
    slash_r2 = SLASH_R * SLASH_R
    # Slash bounding box, padded, so most pixels skip the segment math entirely.
    sx0 = min(SLASH[0][0], SLASH[1][0]) - SLASH_R - 1
    sx1 = max(SLASH[0][0], SLASH[1][0]) + SLASH_R + 1
    sy0 = min(SLASH[0][1], SLASH[1][1]) - SLASH_R - 1
    sy1 = max(SLASH[0][1], SLASH[1][1]) + SLASH_R + 1

    bg, fg = bytes(BG), bytes(FG)
    rows = []
    for y in range(H):
        row = bytearray([0])  # PNG filter byte: none
        for x in range(W):
            hit = False
            for a, b in BARS:
                # Cheap reject first: outside the capsule's bounding box.
                if abs(x - a[0]) <= BAR_R and a[1] - BAR_R <= y <= b[1] + BAR_R:
                    if seg_dist2(x, y, a, b) <= bar_r2:
                        hit = True
                        break
            if not hit and sx0 <= x <= sx1 and sy0 <= y <= sy1:
                hit = seg_dist2(x, y, *SLASH) <= slash_r2
            row += fg if hit else bg
        rows.append(bytes(row))
    return b"".join(rows)


def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))


def main():
    raw = render()
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    out = Path(__file__).resolve().parent.parent / (
        "DrinkTracker/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    )
    out.write_bytes(png)
    print(f"wrote {out} ({len(png):,} bytes)")


if __name__ == "__main__":
    main()
