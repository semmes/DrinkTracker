#!/usr/bin/env python3
"""The drink glyphs and the tab-bar glyphs: custom SF Symbols built from the
owner's 24×24 source art.

Regenerate with:  python3 scripts/make-drink-symbols.py

Reads `docs/design/icons/icons/<name>.svg` (the design bundle's source art —
24-unit grid, 2-unit safe margin, every vessel on the same baseline at y 20)
and writes one `DrinkTracker/Assets.xcassets/tally.<name>.symbolset` per
glyph, each holding an SF Symbols template SVG plus its `Contents.json`.
The names are the bundle README's: `tally.beer`, `tally.wine`, `tally.spirit`,
`tally.cocktail`, `tally.other`, `tally.standard`, `tally.health`,
`tally.alcoholfree`.

A second set, the five tab-bar glyphs (ADR-0040 amendment), reads
`docs/design/bottom-nav/icons/<name>.svg` — the prototype's own bar, lifted
into single paths — and writes `tally.tab.<name>.symbolset`. Same template,
same winding rules; only the placement differs: a tab glyph is centred on the
capital-letter height and drawn at the bar's size rather than sitting on the
drink glyphs' shared baseline at cap height (see `TabPlacement`).

Deliberately dependency-free, like `make-app-icon.py`: it carries its own SVG
path parser rather than needing a library, so it runs anywhere Python does.

What it has to do beyond copying, and why:

- **A template, not a bare SVG.** Xcode's asset compiler only accepts symbol
  art laid out on Apple's template — a 3300×2200 sheet with a `Notes` group
  (carrying the template version), a `Guides` group (caplines, baselines,
  margins) and a `Symbols` group holding one `<g>` per weight-and-scale
  variant. The 24-unit box is scaled so that its art baseline (y 20) lands on
  the template's `Baseline-M` and its vessel tops (y ≈ 3) on `Capline-M`,
  which is exactly how Apple's own glyphs sit: aligned to the capital-letter
  height, not to the em box. One em is the whole 24-unit box, the size the
  design canvas renders them at ("body · 17pt (rows)").
- **No strokes, nonzero winding.** Symbol art must be filled paths. The
  source art draws its cut-outs (the mug's foam line, the glass's fill line,
  the cup's dots) with `fill-rule="evenodd"`, and the alcohol-free ring and
  check are stroked. Rather than rely on the compiler honouring either, every
  contour is re-oriented so that outer shapes wind one way and holes the
  other — correct under *both* fill rules — and the stroked check is
  outlined analytically (a capsule per segment, one round join).
- **All 27 variants, same geometry.** The art is a filled silhouette with no
  weight axis, so every weight gets the same path and the three scales get
  the Small/Large ratios SF Symbols use. Providing every variant means the
  compiler derives nothing.
"""

import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs" / "design" / "icons" / "icons"
TAB_SOURCE = ROOT / "docs" / "design" / "bottom-nav" / "icons"
CATALOG = ROOT / "DrinkTracker" / "Assets.xcassets"

GLYPHS = ["beer", "wine", "spirit", "cocktail", "other", "standard", "health", "alcoholfree"]
TAB_GLYPHS = ["today", "calendar", "trends", "history", "settings"]

# Template geometry (Apple's sheet; the caplines/baselines are the values the
# SF Symbols app writes into every exported template).
SHEET_W, SHEET_H = 3300, 2200
CAPLINE = {"S": 625.541, "M": 1126.28, "L": 1607.56}
BASELINE = {"S": 696.729, "M": 1197.42, "L": 1678.7}
WEIGHTS = ["Ultralight", "Thin", "Light", "Regular", "Medium", "Semibold", "Bold", "Heavy", "Black"]
COLUMN_X = [559.0, 856.0, 1153.0, 1450.0, 1747.0, 2044.0, 2341.0, 2638.0, 2935.0]
# Apple's documented scale factors relative to Medium.
SCALE_RATIO = {"S": 0.783, "M": 1.0, "L": 1.29}

# One em of the rendered symbol is the whole 24-unit source box, so a 100pt
# glyph is 100 template units tall: 24 source units → 100 template units.
#
# A stated decision, not an accident of the box (ADR-0036): this is the size
# the design canvas renders the set at ("body · 17pt (rows)" draws a 17px
# box), which puts each vessel at the capital-letter height of the text
# beside it. Apple's own filled glyphs are larger — `mug.fill`'s ink is about
# 118 units tall at this point size against the mug's 73 — so the set reads
# lighter than the SF Symbols it replaced. Raising this one constant scales
# every glyph together if the owner wants the SF size instead.
UNITS_PER_SOURCE_UNIT = 100.0 / 24.0
ART_BASELINE_Y = 20.0  # the bundle's shared baseline, in source units

# The tab glyphs are drawn to be as tall as the system's own tab-bar symbols,
# not to the drink glyphs' cap height: the prototype draws its bar with a
# 24-unit box per tab, and the gear in that box (20.2 units of ink) is the
# size `gearshape.fill` renders at in the bar. Measured against that render
# on an iPhone 17 Pro, the box lands on the SF size at this scale; one
# constant, like the one above, if the owner wants the bar lighter.
TAB_UNITS_PER_SOURCE_UNIT = 120.0 / 24.0

FLATTEN_STEPS = 24


# MARK: - Path parsing

class Seg:
    """One absolute path segment. `kind` is L, C, or A; `end` is where it lands."""

    def __init__(self, kind, start, end, c1=None, c2=None, arc=None):
        self.kind = kind
        self.start = start
        self.end = end
        self.c1 = c1
        self.c2 = c2
        self.arc = arc  # (rx, ry, rotation, large, sweep)


# Every letter is a token, so a command this parser does not implement (Q, T)
# reaches the `unsupported command` guard instead of being dropped and its
# arguments read as repeats of the previous command.
_TOKEN = re.compile(r"[A-Za-z]|-?\d*\.?\d+(?:e-?\d+)?")


def parse_path(d, close_all=True):
    """Parse an SVG path into a list of subpaths, each a list of absolute `Seg`s.

    Filled art is a set of closed contours, so by default a subpath that ends
    without `Z` is closed anyway. Stroked art is not — a polyline's open end
    is its cap — so a stroke's parser passes `close_all=False` and only `Z`
    closes."""
    tokens = _TOKEN.findall(d)
    i = 0
    cmd = None
    cur = (0.0, 0.0)
    start = (0.0, 0.0)
    last_c2 = None
    subpaths = []
    current = []

    def num():
        nonlocal i
        v = float(tokens[i])
        i += 1
        return v

    def close(force):
        nonlocal current, cur
        if current:
            # A tolerance, not equality: relative arcs return to their start
            # with an ulp of drift, and exact comparison emitted a zero-length
            # line before every Z.
            if force and math.dist(current[-1].end, start) > 1e-9:
                current.append(Seg("L", current[-1].end, start))
            subpaths.append(current)
        current = []
        cur = start

    while i < len(tokens):
        t = tokens[i]
        if re.match(r"[A-Za-z]", t):
            cmd = t
            i += 1
            if cmd in "Zz":
                close(True)
                continue
        rel = cmd.islower()
        c = cmd.upper()
        if c == "M":
            x, y = num(), num()
            if rel:
                x, y = cur[0] + x, cur[1] + y
            if current:
                close(close_all)
            cur = start = (x, y)
            last_c2 = None
            cmd = "l" if rel else "L"
        elif c == "L":
            x, y = num(), num()
            if rel:
                x, y = cur[0] + x, cur[1] + y
            current.append(Seg("L", cur, (x, y)))
            cur = (x, y)
            last_c2 = None
        elif c == "H":
            x = num()
            if rel:
                x += cur[0]
            current.append(Seg("L", cur, (x, cur[1])))
            cur = (x, cur[1])
            last_c2 = None
        elif c == "V":
            y = num()
            if rel:
                y += cur[1]
            current.append(Seg("L", cur, (cur[0], y)))
            cur = (cur[0], y)
            last_c2 = None
        elif c == "C":
            x1, y1, x2, y2, x, y = (num() for _ in range(6))
            if rel:
                x1, y1, x2, y2, x, y = (cur[0] + x1, cur[1] + y1, cur[0] + x2, cur[1] + y2, cur[0] + x, cur[1] + y)
            current.append(Seg("C", cur, (x, y), c1=(x1, y1), c2=(x2, y2)))
            cur = (x, y)
            last_c2 = (x2, y2)
        elif c == "S":
            x2, y2, x, y = (num() for _ in range(4))
            if rel:
                x2, y2, x, y = cur[0] + x2, cur[1] + y2, cur[0] + x, cur[1] + y
            c1 = (2 * cur[0] - last_c2[0], 2 * cur[1] - last_c2[1]) if last_c2 else cur
            current.append(Seg("C", cur, (x, y), c1=c1, c2=(x2, y2)))
            cur = (x, y)
            last_c2 = (x2, y2)
        elif c == "A":
            rx, ry, rot, large, sweep, x, y = (num() for _ in range(7))
            if rel:
                x, y = cur[0] + x, cur[1] + y
            current.append(Seg("A", cur, (x, y), arc=(rx, ry, rot, int(large), int(sweep))))
            cur = (x, y)
            last_c2 = None
        else:
            raise ValueError(f"unsupported command {cmd}")
    if current:
        close(close_all)
    return subpaths


# MARK: - Geometry

def arc_center(seg):
    """Centre-parameterised form of an SVG arc (per the SVG spec, F.6.5)."""
    (x1, y1), (x2, y2) = seg.start, seg.end
    rx, ry, rot, large, sweep = seg.arc
    phi = math.radians(rot)
    cp, sp = math.cos(phi), math.sin(phi)
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p = cp * dx + sp * dy
    y1p = -sp * dx + cp * dy
    rx, ry = abs(rx), abs(ry)
    lam = (x1p / rx) ** 2 + (y1p / ry) ** 2
    if lam > 1:
        rx *= math.sqrt(lam)
        ry *= math.sqrt(lam)
    num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    coef = math.sqrt(max(0.0, num / den)) if den else 0.0
    if large == sweep:
        coef = -coef
    cxp = coef * rx * y1p / ry
    cyp = -coef * ry * x1p / rx
    cx = cp * cxp - sp * cyp + (x1 + x2) / 2
    cy = sp * cxp + cp * cyp + (y1 + y2) / 2

    def ang(ux, uy, vx, vy):
        a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return a

    t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and dt > 0:
        dt -= 2 * math.pi
    if sweep and dt < 0:
        dt += 2 * math.pi
    return cx, cy, rx, ry, phi, t1, dt


def flatten(seg, steps=FLATTEN_STEPS):
    """Points along the segment, excluding its start."""
    if seg.kind == "L":
        return [seg.end]
    if seg.kind == "C":
        (x0, y0), (x1, y1), (x2, y2), (x3, y3) = seg.start, seg.c1, seg.c2, seg.end
        out = []
        for k in range(1, steps + 1):
            t = k / steps
            u = 1 - t
            out.append((
                u ** 3 * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t ** 3 * x3,
                u ** 3 * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t ** 3 * y3,
            ))
        return out
    cx, cy, rx, ry, phi, t1, dt = arc_center(seg)
    out = []
    for k in range(1, steps + 1):
        t = t1 + dt * k / steps
        x = cx + rx * math.cos(t) * math.cos(phi) - ry * math.sin(t) * math.sin(phi)
        y = cy + rx * math.cos(t) * math.sin(phi) + ry * math.sin(t) * math.cos(phi)
        out.append((x, y))
    out[-1] = seg.end
    return out


def polygon(subpath):
    pts = [subpath[0].start]
    for seg in subpath:
        pts.extend(flatten(seg))
    return pts


def signed_area(pts):
    a = 0.0
    for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]):
        a += x0 * y1 - x1 * y0
    return a / 2


def contains(poly, point):
    """Even-odd point-in-polygon."""
    x, y = point
    inside = False
    for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1]):
        if (y0 > y) != (y1 > y):
            xi = x0 + (y - y0) * (x1 - x0) / (y1 - y0)
            if x < xi:
                inside = not inside
    return inside


def centroid(pts):
    return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))


def interior_point(pts):
    """A point strictly inside the contour: the midpoint of its first edge,
    nudged off the edge to whichever side the contour itself contains. A
    vertex will not do — the mug's handle starts on the body's own edge, and
    a ray cast from a point that sits exactly on another contour's boundary
    answers by rounding luck."""
    (x0, y0), (x1, y1) = pts[0], pts[1]
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    nx, ny = -(y1 - y0), x1 - x0
    length = math.hypot(nx, ny) or 1.0
    eps = 1e-3
    for sign in (1, -1):
        candidate = (mx + sign * eps * nx / length, my + sign * eps * ny / length)
        if contains(pts, candidate):
            return candidate
    raise SystemExit("could not find a point inside a contour; the art may be degenerate")


def reversed_subpath(subpath):
    out = []
    for seg in reversed(subpath):
        if seg.kind == "L":
            out.append(Seg("L", seg.end, seg.start))
        elif seg.kind == "C":
            out.append(Seg("C", seg.end, seg.start, c1=seg.c2, c2=seg.c1))
        else:
            rx, ry, rot, large, sweep = seg.arc
            out.append(Seg("A", seg.end, seg.start, arc=(rx, ry, rot, large, 1 - sweep)))
    return out


def normalise_winding(subpaths):
    """Outer contours wind one way, holes the other, so the art reads the
    same under nonzero and even-odd. A contour is a hole when it sits inside
    an odd number of the others (the ring's inner circle; the check inside
    both circles is at depth two and stays solid)."""
    polys = [polygon(sp) for sp in subpaths]
    out = []
    for i, sp in enumerate(subpaths):
        probe = interior_point(polys[i])
        depth = sum(1 for j, other in enumerate(polys) if j != i and contains(other, probe))
        want_positive = depth % 2 == 0
        is_positive = signed_area(polys[i]) > 0
        out.append(sp if want_positive == is_positive else reversed_subpath(sp))
    return out


# MARK: - The stroked check, outlined

def outline_polyline(points, half_width):
    """A round-capped, round-joined stroke of a two-segment polyline as one
    closed contour: the outer offset with an arc at the join, a cap at each
    end, and the inner offset meeting at its own corner."""
    (p0, p1, p2) = points
    r = half_width

    def unit(a, b):
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy)
        return dx / n, dy / n

    d1, d2 = unit(p0, p1), unit(p1, p2)
    n1, n2 = (-d1[1], d1[0]), (-d2[1], d2[0])
    # The convex side of the bend takes the arc; the concave side's offsets
    # cross at one inner corner. The concave side is the one the interior
    # bisector points into, so the normals are flipped to face away from it —
    # a numeric test rather than a sign convention, which is where the first
    # version of this went wrong.
    bisector = (d2[0] - d1[0], d2[1] - d1[1])
    if n1[0] * bisector[0] + n1[1] * bisector[1] > 0:
        n1, n2 = (-n1[0], -n1[1]), (-n2[0], -n2[1])
    dot = n1[0] * n2[0] + n1[1] * n2[1]
    inner = (p1[0] - (n1[0] + n2[0]) * r / (1 + dot), p1[1] - (n1[1] + n2[1]) * r / (1 + dot))

    def add(p, n, s=1):
        return (p[0] + s * n[0] * r, p[1] + s * n[1] * r)

    def arc(start, end, large, centre, away_from):
        """The arc of radius r from start to end whose centre is `centre`
        (the join) or, for a semicircular cap where both candidate centres
        coincide, the one that bulges away from `away_from`."""
        best = None
        for sweep in (0, 1):
            seg = Seg("A", start, end, arc=(r, r, 0, large, sweep))
            mid = flatten(seg)[FLATTEN_STEPS // 2]
            cx, cy = arc_center(seg)[:2]
            centre_error = math.hypot(cx - centre[0], cy - centre[1])
            bulge = math.hypot(mid[0] - away_from[0], mid[1] - away_from[1])
            score = (round(centre_error, 6), -bulge)
            if best is None or score < best[0]:
                best = (score, seg)
        return best[1]

    a = add(p0, n1)
    b = add(p1, n1)
    c = add(p1, n2)
    d = add(p2, n2)
    e = add(p2, n2, -1)
    f = add(p0, n1, -1)
    segs = [
        Seg("L", a, b),
        arc(b, c, large=0, centre=p1, away_from=p1),
        Seg("L", c, d),
        arc(d, e, large=1, centre=p2, away_from=p1),
        Seg("L", e, inner),
        Seg("L", inner, f),
        arc(f, a, large=1, centre=p0, away_from=p1),
    ]
    return segs


def circle(cx, cy, r, sweep):
    p0 = (cx - r, cy)
    p1 = (cx + r, cy)
    return [Seg("A", p0, p1, arc=(r, r, 0, 0, sweep)), Seg("A", p1, p0, arc=(r, r, 0, 0, sweep))]


def stroked_contours(d, stroke_width):
    """Filled outlines of a stroked path, read from the art rather than
    transcribed from it, so a redrawn stroke reaches the catalog through the
    same CI gate as a redrawn fill.

    Supports exactly the shapes the set uses — a closed circle (the ring
    becomes two circles, half a stroke either side of it) and an open
    two-segment polyline (the check, outlined with round caps and one round
    join) — and refuses anything else rather than approximate it."""
    half = stroke_width / 2
    contours = []
    for subpath in parse_path(d, close_all=False):
        points = [subpath[0].start] + [seg.end for seg in subpath]
        is_closed = math.dist(points[0], points[-1]) < 1e-9
        if is_closed and all(seg.kind == "A" for seg in subpath):
            # Exact, from the arc's own centre parameterisation — a mean over
            # flattened points drifts by a few thousandths, enough to change
            # the file the CI gate compares.
            cx, cy, rx, ry = arc_center(subpath[0])[:4]
            if abs(rx - ry) > 1e-9:
                raise SystemExit("a stroked ellipse is not supported; the ring must be a circle")
            contours.append(circle(cx, cy, rx + half, sweep=1))
            contours.append(circle(cx, cy, rx - half, sweep=1))
        elif not is_closed and len(subpath) == 2 and all(seg.kind == "L" for seg in subpath):
            contours.append(outline_polyline(points, half_width=half))
        else:
            raise SystemExit("stroked art may be a circle or a two-segment polyline; outline anything else by hand")
    return contours


# MARK: - Emission

def fmt(v):
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def emit(subpaths, transform):
    """Absolute path data for the contours under an affine `transform`."""
    parts = []
    for sp in subpaths:
        x, y = transform(sp[0].start)
        parts.append(f"M{fmt(x)} {fmt(y)}")
        for seg in sp:
            ex, ey = transform(seg.end)
            if seg.kind == "L":
                parts.append(f"L{fmt(ex)} {fmt(ey)}")
            elif seg.kind == "C":
                c1 = transform(seg.c1)
                c2 = transform(seg.c2)
                parts.append(f"C{fmt(c1[0])} {fmt(c1[1])} {fmt(c2[0])} {fmt(c2[1])} {fmt(ex)} {fmt(ey)}")
            else:
                rx, ry, rot, large, sweep = seg.arc
                k = transform.scale
                parts.append(f"A{fmt(rx * k)} {fmt(ry * k)} {fmt(rot)} {large} {sweep} {fmt(ex)} {fmt(ey)}")
        parts.append("Z")
    return " ".join(parts)


class Placement:
    """Maps source units onto the sheet for one scale and one weight column:
    the drink glyphs, their shared baseline on the template's baseline."""

    def __init__(self, scale_key, column_x):
        self.scale = UNITS_PER_SOURCE_UNIT * SCALE_RATIO[scale_key]
        self.x0 = column_x - 12.0 * self.scale
        self.y0 = BASELINE[scale_key] - ART_BASELINE_Y * self.scale

    def __call__(self, p):
        return (self.x0 + p[0] * self.scale, self.y0 + p[1] * self.scale)


class TabPlacement:
    """The tab glyphs: the 24-unit box centred on the capital-letter height,
    which is where Apple's guidance puts a symbol's optical centre, at the
    bar's size."""

    def __init__(self, scale_key, column_x):
        self.scale = TAB_UNITS_PER_SOURCE_UNIT * SCALE_RATIO[scale_key]
        self.x0 = column_x - 12.0 * self.scale
        middle = (CAPLINE[scale_key] + BASELINE[scale_key]) / 2
        self.y0 = middle - 12.0 * self.scale

    def __call__(self, p):
        return (self.x0 + p[0] * self.scale, self.y0 + p[1] * self.scale)


def h_reference(scale_key):
    """A capital H between the capline and baseline, as the template draws
    for reference. Decorative: the compiler reads the guide lines, not this."""
    top, bottom = CAPLINE[scale_key], BASELINE[scale_key]
    h = bottom - top
    x = 263.0
    stem = h * 0.16
    w = h * 0.78
    bar_y0 = top + h * 0.44
    bar_y1 = bar_y0 + h * 0.13
    return (
        f"M{fmt(x)} {fmt(top)} L{fmt(x + stem)} {fmt(top)} L{fmt(x + stem)} {fmt(bar_y0)} "
        f"L{fmt(x + w - stem)} {fmt(bar_y0)} L{fmt(x + w - stem)} {fmt(top)} L{fmt(x + w)} {fmt(top)} "
        f"L{fmt(x + w)} {fmt(bottom)} L{fmt(x + w - stem)} {fmt(bottom)} L{fmt(x + w - stem)} {fmt(bar_y1)} "
        f"L{fmt(x + stem)} {fmt(bar_y1)} L{fmt(x + stem)} {fmt(bottom)} L{fmt(x)} {fmt(bottom)} Z"
    )


def template(name, subpaths, placement=Placement):
    text_style = "stroke:none;fill:black;font-family:sans-serif;font-size:13;"
    notes = [
        f'  <rect height="{SHEET_H}" opacity="0" width="{SHEET_W}" x="0" y="0"/>',
        f'  <text style="{text_style}" transform="matrix(1 0 0 1 263 292)">Weight/Scale Variations</text>',
    ]
    for weight, x in zip(WEIGHTS, COLUMN_X):
        notes.append(
            f'  <text style="{text_style}text-anchor:middle;" transform="matrix(1 0 0 1 {x} 322)">{weight}</text>'
        )
    notes += [
        f'  <text style="{text_style}" transform="matrix(1 0 0 1 263 1953)">Design Variations</text>',
        f'  <text style="{text_style}" transform="matrix(1 0 0 1 263 1971)">Symbols are supported in up to nine weights and three scales.</text>',
        f'  <text style="{text_style}" transform="matrix(1 0 0 1 263 1989)">For optimal layout with text and other symbols, vertically align</text>',
        f'  <text style="{text_style}" transform="matrix(1 0 0 1 263 2007)">symbols with the center of the capital letter height.</text>',
        f'  <text id="template-version" style="{text_style}text-anchor:end;" transform="matrix(1 0 0 1 3036 258)">Template v.3.0</text>',
        f'  <text id="descriptive-name" style="{text_style}text-anchor:end;" transform="matrix(1 0 0 1 3036 1953)">{name}</text>',
        f'  <text style="{text_style}" transform="matrix(1 0 0 1 263 2050)">Generated from scripts/make-drink-symbols.py</text>',
    ]

    guides = ['  <g id="H-reference" style="fill:#27AAE1;stroke:none;">']
    for key in ("S", "M", "L"):
        guides.append(f'   <path d="{h_reference(key)}"/>')
    guides.append("  </g>")
    for key in ("S", "M", "L"):
        guides.append(
            f'  <line id="Capline-{key}" stroke="#27AAE1" stroke-width="0.5" x1="263" x2="3036" y1="{CAPLINE[key]}" y2="{CAPLINE[key]}"/>'
        )
        guides.append(
            f'  <line id="Baseline-{key}" stroke="#27AAE1" stroke-width="0.5" x1="263" x2="3036" y1="{BASELINE[key]}" y2="{BASELINE[key]}"/>'
        )
    # The margins are the glyph's advance width, and they sit at its ink, not
    # at the 24-unit box: Apple's filled glyphs carry no side bearing, and a
    # box-edge margin put up to 58 units of empty space beside the narrower
    # vessels, which `Label` read as part of the icon and spaced the title
    # away from.
    regular = placement("M", COLUMN_X[3])
    xs = [point[0] for subpath in subpaths for point in polygon(subpath)]
    left, right = regular((min(xs), 0.0))[0], regular((max(xs), 0.0))[0]
    guide_top, guide_bottom = CAPLINE["M"] - 100, BASELINE["M"] + 60
    guides.append(
        f'  <line id="left-margin" stroke="#00AEEF" stroke-width="0.5" x1="{fmt(left)}" x2="{fmt(left)}" y1="{fmt(guide_top)}" y2="{fmt(guide_bottom)}"/>'
    )
    guides.append(
        f'  <line id="right-margin" stroke="#00AEEF" stroke-width="0.5" x1="{fmt(right)}" x2="{fmt(right)}" y1="{fmt(guide_top)}" y2="{fmt(guide_bottom)}"/>'
    )

    symbols = []
    for key in ("L", "M", "S"):
        for weight, x in zip(WEIGHTS, COLUMN_X):
            place = placement(key, x)
            symbols.append(f'  <g id="{weight}-{key}">')
            symbols.append(f'   <path d="{emit(subpaths, place)}"/>')
            symbols.append("  </g>")

    return "\n".join([
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!--Generator: scripts/make-drink-symbols.py-->',
        '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">',
        f'<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 {SHEET_W} {SHEET_H}">',
        f' <!--glyph: "{name}", point size: 100.000000, template writer version: "8"-->',
        ' <g id="Notes">',
        *notes,
        " </g>",
        ' <g id="Guides">',
        *guides,
        " </g>",
        ' <g id="Symbols">',
        *symbols,
        " </g>",
        "</svg>",
        "",
    ])


def source_contours(name, source=SOURCE):
    """The glyph's contours, read from the bundle's SVG. Filled art is parsed
    as it is; stroked art (the alcohol-free ring and check) is outlined from
    its own geometry and stroke width."""
    svg = (source / f"{name}.svg").read_text(encoding="utf-8")
    svg = re.sub(r"<metadata>.*?</metadata>", "", svg, flags=re.S)
    elements = re.findall(r"<path\b[^>]*>", svg)
    if len(elements) != 1:
        raise SystemExit(f"{name}.svg: expected one <path>, found {len(elements)}")
    element = elements[0]
    d = re.search(r'\sd="([^"]+)"', element).group(1)
    stroke = re.search(r'\sstroke="([^"]+)"', element)
    if stroke and stroke.group(1) != "none":
        width = re.search(r'\sstroke-width="([^"]+)"', element)
        if not width:
            raise SystemExit(f"{name}.svg is stroked without a stroke-width")
        return stroked_contours(d, float(width.group(1)))
    return parse_path(d)


def write_symbolset(name, source=SOURCE, prefix="tally.", placement=Placement):
    contours = normalise_winding(source_contours(name, source))
    symbol = f"{prefix}{name}"
    folder = CATALOG / f"{symbol}.symbolset"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"{symbol}.svg").write_text(template(symbol, contours, placement), encoding="utf-8")
    # Xcode's own `"key" : value` spacing, so a re-save from the asset editor
    # leaves the tree clean for the CI gate that diffs it.
    (folder / "Contents.json").write_text(json.dumps({
        "info": {"author": "xcode", "version": 1},
        "symbols": [{"filename": f"{symbol}.svg", "idiom": "universal"}],
    }, indent=2, separators=(",", " : ")) + "\n", encoding="utf-8")
    return symbol, contours


def preview(results, path):
    """A contact sheet of the normalised art at 96px, for a human eye."""
    cell = 120
    cols = 4
    rows = math.ceil(len(results) / cols)
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{cell * cols}" height="{cell * rows + 20}" viewBox="0 0 {cell * cols} {cell * rows + 20}">',
        '<rect width="100%" height="100%" fill="white"/>',
    ]
    for i, (symbol, contours) in enumerate(results):
        ox, oy = (i % cols) * cell + 12, (i // cols) * cell + 12
        k = 4.0

        class T:
            scale = k

            def __call__(self, p):
                return (ox + p[0] * k, oy + p[1] * k)

        parts.append(f'<path d="{emit(contours, T())}" fill="#256abf"/>')
        parts.append(f'<text x="{ox + 48}" y="{oy + 112}" font-family="sans-serif" font-size="10" text-anchor="middle">{symbol}</text>')
    parts.append("</svg>")
    path.write_text("\n".join(parts), encoding="utf-8")


def check_swift_names():
    """The package's `DrinkType.Symbol` and `GLYPHS` are two hand-written lists
    of the same eight names, and `AppTab.symbolName` and `TAB_GLYPHS` are two
    of the same five. A typo in any of them compiles and renders nothing, so
    they are compared here, and CI runs this script."""
    swift = (ROOT / "DrinkTrackerCore" / "Sources" / "DrinkTrackerCore" / "DrinkType.swift").read_text(encoding="utf-8")
    declared = set(re.findall(r'public static let \w+ = "tally\.(\w+)"', swift))
    expected = set(GLYPHS)
    if declared != expected:
        raise SystemExit(
            f"DrinkType.Symbol names {sorted(declared)} but the generator writes {sorted(expected)}"
        )
    tabs = (ROOT / "DrinkTracker" / "Features" / "Navigation" / "AppTabs.swift").read_text(encoding="utf-8")
    declared_tabs = set(re.findall(r'"tally\.tab\.(\w+)"', tabs))
    expected_tabs = set(TAB_GLYPHS)
    if declared_tabs != expected_tabs:
        raise SystemExit(
            f"AppTab.symbolName names {sorted(declared_tabs)} but the generator writes {sorted(expected_tabs)}"
        )
    on_disk = {p.name.removeprefix("tally.").removesuffix(".symbolset") for p in CATALOG.glob("tally.*.symbolset")}
    expected_all = expected | {f"tab.{name}" for name in expected_tabs}
    if on_disk != expected_all:
        raise SystemExit(f"the catalog holds {sorted(on_disk)} but the generator writes {sorted(expected_all)}")


if __name__ == "__main__":
    import sys

    results = [write_symbolset(name) for name in GLYPHS]
    results += [
        write_symbolset(name, source=TAB_SOURCE, prefix="tally.tab.", placement=TabPlacement)
        for name in TAB_GLYPHS
    ]
    check_swift_names()
    for symbol, contours in results:
        areas = [round(signed_area(polygon(sp)), 2) for sp in contours]
        print(f"{symbol}: {len(contours)} contours, signed areas {areas}")
    if len(sys.argv) > 1:
        preview(results, Path(sys.argv[1]))
        print(f"preview written to {sys.argv[1]}")
