#!/usr/bin/env python3
"""Crop proofs for Tallyist's App Store creative assets (README.md).

Draws each rendered asset with Apple's Art Safe Area dashed over it, beside
what survives a crop to that safe area, the worst case. For the universal
asset it adds two illustrative crops, 21:9 for the header and 3:2 for search
results, each centred on its safe area: Apple publishes no crops beyond the
templates' safe areas, and App Store Connect's Preview shows the real ones.

    python3 proofs.py           reads ./out, writes out/proofs-dark.jpg and out/proofs-light.jpg
    python3 proofs.py DIR       reads and writes DIR instead

Needs Python 3 and Pillow (`pip install pillow`). Run `node render.js` first.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(HERE, 'out')

# The "Art Safe Area" layer of each of Apple's templates, as in banner.html.
SAFE = {'header': (1097, 493, 1646, 661), 'search': (836, 765, 2168, 1030), 'universal': (1921, 660, 1402, 962)}
FILES = {'header': 'tallyist-header{}-3840x1646.png', 'search': 'tallyist-search-results{}-3840x2560.png',
         'universal': 'tallyist-universal{}-5244x2950.png'}
NAMES = {'header': 'Product page header · 3840 × 1646 (21:9)', 'search': 'Search results · 3840 × 2560 (3:2)',
         'universal': 'Universal · 5244 × 2950 (16:9, PNG only) · header and search results'}
BG, FG, MUTED, GREEN = (24, 24, 27), (240, 240, 245), (150, 150, 160), (64, 220, 120)
FULL_W, CROP_W, MARGIN, GUTTER = 1180, 640, 30, 60
LABEL, GAP = 30, 44   # a crop's label above it, and the space after it


def font(name, size):
    return ImageFont.truetype(os.path.join(HERE, 'fonts', name), size)


def centred_crop(image, safe, aspect):
    """The largest crop of the given aspect, centred on the safe area and kept inside the image."""
    w, h = image.size
    cw, ch = (w, round(w / aspect)) if w / h < aspect else (round(h * aspect), h)
    cx, cy = safe[0] + safe[2] / 2, safe[1] + safe[3] / 2
    x = min(max(round(cx - cw / 2), 0), w - cw)
    y = min(max(round(cy - ch / 2), 0), h - ch)
    return image.crop((x, y, x + cw, y + ch))


def dashed_box(draw, box, width=3, dash=14, gap=9):
    x0, y0, x1, y1 = box
    for (ax, ay), horizontal in (((x0, y0), True), ((x0, y1), True), ((x0, y0), False), ((x1, y0), False)):
        length, t = (x1 - x0) if horizontal else (y1 - y0), 0
        while t < length:
            e = min(t + dash, length)
            draw.line([(ax + t, ay), (ax + e, ay)] if horizontal else [(ax, ay + t), (ax, ay + e)], fill=GREEN, width=width)
            t += dash + gap


def resized(image, width):
    return image.resize((width, round(image.size[1] * width / image.size[0])), Image.LANCZOS)


def row(fmt, theme):
    image = Image.open(os.path.join(OUT, FILES[fmt].format('-light' if theme == 'light' else ''))).convert('RGB')
    x, y, w, h = SAFE[fmt]
    full = resized(image, FULL_W)
    scale = FULL_W / image.size[0]
    dashed_box(ImageDraw.Draw(full), (x * scale, y * scale, (x + w) * scale, (y + h) * scale))
    crops = [('Safe area only (worst case)', image.crop((x, y, x + w, y + h)))]
    if fmt == 'universal':
        crops.append(('Illustrative 21:9 crop, centred on the safe area (header use)', centred_crop(image, SAFE[fmt], 21 / 9)))
        crops.append(('Illustrative 3:2 crop, centred on the safe area (search use)', centred_crop(image, SAFE[fmt], 3 / 2)))
    crops = [(label, resized(c, CROP_W)) for label, c in crops]
    top = 80
    column = sum(LABEL + c.size[1] + GAP for _, c in crops) - GAP
    out = Image.new('RGB', (MARGIN + FULL_W + GUTTER + CROP_W + MARGIN, top + max(full.size[1], column) + MARGIN), BG)
    draw = ImageDraw.Draw(out)
    draw.text((MARGIN, 26), NAMES[fmt], font=font('InterDisplay-Bold.otf', 30), fill=FG)
    out.paste(full, (MARGIN, top))
    cx, cy = MARGIN + FULL_W + GUTTER, top
    for label, c in crops:
        draw.text((cx, cy - 2), label, font=font('Inter-Medium.otf', 20), fill=MUTED)
        out.paste(c, (cx, cy + LABEL))
        cy += LABEL + c.size[1] + GAP
    return out


def sheet(theme):
    rows = [row(fmt, theme) for fmt in ('header', 'search', 'universal')]
    width = rows[0].size[0]
    head = Image.new('RGB', (width, 150), BG)
    draw = ImageDraw.Draw(head)
    draw.text((MARGIN, 30), f'Tallyist · App Store creative assets · crop proofs ({theme})', font=font('InterDisplay-Bold.otf', 40), fill=FG)
    draw.text((MARGIN, 92), "Green dashes: the Art Safe Area from Apple's templates. The headline and the counter stay inside it "
              "in every asset; the universal's month runs below it by design.", font=font('Inter-Medium.otf', 21), fill=MUTED)
    out = Image.new('RGB', (width, head.size[1] + sum(r.size[1] for r in rows)), BG)
    out.paste(head, (0, 0))
    y = head.size[1]
    for r in rows:
        out.paste(r, (0, y))
        y += r.size[1]
    path = os.path.join(OUT, f'proofs-{theme}.jpg')
    out.save(path, quality=90)
    print(os.path.relpath(path), out.size)


for theme in ('dark', 'light'):
    sheet(theme)
