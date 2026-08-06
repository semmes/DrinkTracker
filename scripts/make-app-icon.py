#!/usr/bin/env python3
"""The Tallyist app icon: the tally-of-five mark on the brand's deep blue field.

Regenerate with:  python3 scripts/make-app-icon.py

Deliberately dependency-free — it writes the PNG bytes itself rather than needing
Pillow, so it runs anywhere Python does. Rendering is analytic: every stroke is a
capsule (a segment with a radius), and per-pixel signed distance to the capsule
edge gives smooth anti-aliasing with no supersampling.

Design, all from the documented system (docs/design-system.md §1–2, ADR-0010):
- Field: vertical gradient between named ramp steps 600 → 700, centred on the
  icon's documented 650, with a slight corner vignette toward 700.
- Marks: four near-white verticals (the #fcfcfb surface tone; ≥9:1 on the field)
  with a soft drop shadow, and the slash in ramp step 250 — the same two-tone
  hierarchy as the onboarding hero, which tilts the same −4°.
- The glyph is the canonical tally of five: a counting mark, not a count being
  encouraged. Never a partial tally (see design-system.md, "The mark").
"""

import math
import struct
import zlib
from pathlib import Path

W = H = 1024

# Named ramp steps only — "another blue" has nowhere to hide (ADR-0010).
TOP = (0x18, 0x4F, 0x95)     # 600
BOTTOM = (0x0D, 0x36, 0x6B)  # 700
MARK = (252, 252, 251)       # #fcfcfb near-white surface tone
SLASH_TINT = (0x86, 0xB6, 0xEF)  # 250 — the hero's lighter-slash hierarchy
SHADOW = (5, 22, 46)

TILT_DEG = -4.0
CENTER = (512.0, 516.0)

BAR_R = 36.0
SLASH_R = 38.0
BARS = [((cx, 318.0), (cx, 708.0)) for cx in (320.0, 452.0, 584.0, 716.0)]
SLASH = ((286.0, 726.0), (752.0, 306.0))

SHADOW_OFFSET = 10.0
SHADOW_SPREAD = 26.0
SHADOW_ALPHA = 0.30
AA = 1.6  # anti-alias band, px
VIGNETTE = 0.16


def rotated(p):
    a = math.radians(TILT_DEG)
    ca, sa = math.cos(a), math.sin(a)
    x, y = p[0] - CENTER[0], p[1] - CENTER[1]
    return (CENTER[0] + x * ca - y * sa, CENTER[1] + x * sa + y * ca)


def seg_dist(px, py, a, b):
    (x0, y0), (x1, y1) = a, b
    dx, dy = x1 - x0, y1 - y0
    t = ((px - x0) * dx + (py - y0) * dy) / (dx * dx + dy * dy)
    t = 0.0 if t < 0.0 else 1.0 if t > 1.0 else t
    ex, ey = x0 + t * dx, y0 + t * dy
    return math.hypot(px - ex, py - ey)


def coverage(dist, radius):
    """0 outside, 1 inside, smooth across the AA band at the edge."""
    t = (radius + AA * 0.5 - dist) / AA
    return 0.0 if t <= 0.0 else 1.0 if t >= 1.0 else t


def bbox(shapes, radius, pad):
    xs = [c for a, b in shapes for c in (a[0], b[0])]
    ys = [c for a, b in shapes for c in (a[1], b[1])]
    m = radius + pad
    return (min(xs) - m, max(xs) + m, min(ys) - m, max(ys) + m)


def render():
    bars = [(rotated(a), rotated(b)) for a, b in BARS]
    slash = (rotated(SLASH[0]), rotated(SLASH[1]))
    shadow_shapes = [
        ((a[0], a[1] + SHADOW_OFFSET), (b[0], b[1] + SHADOW_OFFSET))
        for a, b in bars + [slash]
    ]
    gx0, gx1, gy0, gy1 = bbox(
        bars + [slash], max(BAR_R, SLASH_R), SHADOW_OFFSET + SHADOW_SPREAD + 2
    )

    half = W / 2.0
    max_corner = math.hypot(half, half)
    rows = []
    for y in range(H):
        fy = y / (H - 1)
        base = [TOP[i] + (BOTTOM[i] - TOP[i]) * fy for i in range(3)]
        row = bytearray([0])  # PNG filter byte: none
        for x in range(W):
            # Field: vertical gradient, darkened toward the corners.
            v = (math.hypot(x - half, y - half) / max_corner) ** 2 * VIGNETTE
            r, g, b = (base[i] * (1.0 - v) + BOTTOM[i] * v for i in range(3))

            if gx0 <= x <= gx1 and gy0 <= y <= gy1:
                # Soft shadow under every stroke.
                sh = 0.0
                for a2, b2 in shadow_shapes:
                    d = seg_dist(x, y, a2, b2)
                    radius = BAR_R if sh < 1.0 else BAR_R
                    t = (BAR_R + SHADOW_SPREAD - d) / SHADOW_SPREAD
                    if t > 0.0:
                        sh = max(sh, min(1.0, t))
                if sh > 0.0:
                    a = sh * SHADOW_ALPHA
                    r += (SHADOW[0] - r) * a
                    g += (SHADOW[1] - g) * a
                    b += (SHADOW[2] - b) * a

                # Verticals first, slash crossing over them last.
                cov = 0.0
                for a2, b2 in bars:
                    cov = max(cov, coverage(seg_dist(x, y, a2, b2), BAR_R))
                if cov > 0.0:
                    r += (MARK[0] - r) * cov
                    g += (MARK[1] - g) * cov
                    b += (MARK[2] - b) * cov
                s = coverage(seg_dist(x, y, *slash), SLASH_R)
                if s > 0.0:
                    r += (SLASH_TINT[0] - r) * s
                    g += (SLASH_TINT[1] - g) * s
                    b += (SLASH_TINT[2] - b) * s

            row += bytes((int(r + 0.5), int(g + 0.5), int(b + 0.5)))
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
