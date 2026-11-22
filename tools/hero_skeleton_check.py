#!/usr/bin/env python3
"""Verify every hero sheet against the skeleton contract (docs/HERO_SKELETON_SPEC.md).

The art generators (`tools/make_*_sprites.py`) are free to draw however they
like, but they MUST land inside these proportions. This script measures the
real pixels and fails loudly when a body is too wide, too tall, too leggy or
too generic — the exact drift that produced four near-identical "Roblox"
silhouettes.

Usage:
    python3 tools/hero_skeleton_check.py                # human table
    python3 tools/hero_skeleton_check.py --strict        # exit 1 on failure
    python3 tools/hero_skeleton_check.py --iou           # silhouette overlap
    python3 tools/hero_skeleton_check.py --json          # machine readable

Only standard library + Pillow are required.
"""

from __future__ import annotations

import argparse
import itertools
import json
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("Pillow is required:  pip install pillow")

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / "assets" / "textures"

CELL = 96
GROUND_Y = 80

# ---------------------------------------------------------------------------
# THE CONTRACT
#
# Every value is an absolute pixel count inside the 96x96 cell.
# `body_h`      standing body height, crown -> ground line.
# `head`        head share of body height (crown -> chin), as a fraction.
# `shoulder_w`  widest torso width, measured at the shoulder line.
# `hip_w`       torso width at the hip line (legs must be narrower).
# `leg_mass`    opaque pixels in the bottom 30% of the body (thin legs!).
# `stance_w`    horizontal span of the feet at the bottom row.
# ---------------------------------------------------------------------------
SPEC: dict[str, dict] = {
    # Thick, hunched pit champion: shortest-torso / widest-shouldered hero.
    "behemoth": {
        "sheet": "player_behemoth.png",
        "body_h": (66, 70),          # SHORT + MASSIVE
        "head_ratio": (0.28, 0.33),
        "shoulder_w": (44, 52),      # widest of all four
        "hip_w": (24, 32),
        "leg_mass": (380, 560),      # thickest legs, still legible
        "stance_w": (18, 30),
        "max_width": 60,
    },
    # The human baseline: everything else is described relative to him.
    "knight": {
        "sheet": "player_knight.png",
        "body_h": (74, 80),
        "head_ratio": (0.24, 0.29),
        "shoulder_w": (26, 34),      # normal human shoulders
        "hip_w": (16, 24),
        "leg_mass": (240, 360),
        "stance_w": (10, 20),
        "max_width": 44,
    },
    # Slightly taller, clearly thinner and lighter than the knight.
    "sylvara": {
        "sheet": "player_sylvara.png",
        "body_h": (78, 84),
        "head_ratio": (0.22, 0.27),
        "shoulder_w": (20, 28),
        "hip_w": (12, 18),
        "leg_mass": (150, 260),      # daintiest legs
        "stance_w": (8, 18),
        "max_width": 40,             # bow may overhang: measured on torso below
    },
    # SHORTEST hero; hand-drawn royal overcoat + ankle-length silver haircape.
    "noa": {
        "sheet": "player_noa.png",
        "body_h": (62, 68),
        "head_ratio": (0.30, 0.40),
        "shoulder_w": (18, 35),      # includes flowing silver haircape over shoulders
        "hip_w": (12, 27),           # flared gothic overcoat waist/skirt
        "leg_mass": (150, 555),      # floor-length crimson-lined coat + long hair
        "stance_w": (8, 16),
        "max_width": 52,             # hair mass may overhang
    },
}

# Hard global rules (from docs/ART_CONTRACT.md).
MAX_COLOURS = 24
MAX_SEMI_ALPHA_PCT = 2.0
# Silhouette identity: below this the roster reads as one character.
MAX_PAIRWISE_IOU = 0.55


# ---------------------------------------------------------------------------
# MEASUREMENT
# ---------------------------------------------------------------------------

def _cells(sheet: Path) -> list[Image.Image]:
    im = Image.open(sheet).convert("RGBA")
    if im.width % CELL:
        raise ValueError(f"{sheet.name}: width {im.width} is not a multiple of {CELL}")
    return [im.crop((i * CELL, 0, (i + 1) * CELL, CELL)) for i in range(im.width // CELL)]


def _standing_cell(cells: list[Image.Image]) -> Image.Image:
    """Return the idle/standing pose: tall, but with nothing extended sideways.

    Attack frames are tall too, but a swung sword or a drawn bow makes the
    bounding box much wider. So: keep the frames that are within 8% of the
    maximum body height, then pick the NARROWEST of those.
    """
    measured: list[tuple[int, int, Image.Image]] = []
    for c in cells:
        bb = c.getbbox()
        if not bb:
            continue
        measured.append((bb[3] - bb[1], bb[2] - bb[0], c))
    if not measured:
        raise ValueError("sheet has no opaque pixels")
    tallest = max(m[0] for m in measured)
    tall = [m for m in measured if m[0] >= tallest * 0.92]
    return min(tall, key=lambda m: m[1])[2]


def _row_spans(cell: Image.Image) -> dict[int, tuple[int, int]]:
    px = cell.load()
    spans: dict[int, tuple[int, int]] = {}
    for y in range(CELL):
        xs = [x for x in range(CELL) if px[x, y][3] > 0]
        if xs:
            spans[y] = (min(xs), max(xs))
    return spans


def _measure(name: str, sheet: Path) -> dict:
    cells = _cells(sheet)
    cell = _standing_cell(cells)
    bb = cell.getbbox()
    top, bottom = bb[1], bb[3]
    body_h = bottom - top
    spans = _row_spans(cell)

    # --- Head -------------------------------------------------------------
    # The crown is a point, so start from the CROWN ROW (first row whose width
    # is a real cross-section, i.e. >= 20% of the widest head row) instead of
    # from the outermost pixel. Then walk down until the silhouette pinches
    # (the chin) and widens again into the shoulders.
    widths = {y: (spans[y][1] - spans[y][0] + 1) for y in spans}
    rows = [y for y in sorted(widths) if y < top + int(body_h * 0.55)]
    head_ratio = 0.0
    chin_y = top
    if rows:
        head_w = max(widths[y] for y in rows[: max(2, len(rows) // 2)])
        crown_y = next(y for y in rows if widths[y] >= max(2, head_w * 0.30))
        peak_y = max(rows[: max(2, len(rows) // 2)], key=lambda y: widths[y])
        chin_y = peak_y
        for y in rows:
            if y <= peak_y:
                continue
            chin_y = y
            # Torso has begun once we are clearly wider than the head.
            if widths[y] >= head_w * 1.10:
                break
        head_ratio = (chin_y - crown_y) / max(body_h, 1)

    shoulder_w = max(widths.values()) if widths else 0

    hip_y = top + int(body_h * 0.62)
    hip_w = (spans[hip_y][1] - spans[hip_y][0] + 1) if hip_y in spans else 0

    leg_top = top + int(body_h * 0.70)
    leg_mass = sum(spans[y][1] - spans[y][0] + 1 for y in range(leg_top, bottom) if y in spans)

    bottom_y = max(spans)
    stance_w = spans[bottom_y][1] - spans[bottom_y][0] + 1

    colours = {p[:3] for p in cell.get_flattened_data() if p[3] > 0}
    all_px = [p for c in cells for p in c.get_flattened_data()]
    opaque = [p for p in all_px if p[3] > 0]
    semi = [p for p in opaque if p[3] < 255]
    semi_pct = 100.0 * len(semi) / max(len(opaque), 1)

    return {
        "hero": name,
        "frames": len(cells),
        "body_h": body_h,
        "head_ratio": round(head_ratio, 3),
        "shoulder_w": shoulder_w,
        "hip_w": hip_w,
        "leg_mass": leg_mass,
        "stance_w": stance_w,
        "max_width": bb[2] - bb[0],
        "ground_y": bottom,
        "colours": len(colours),
        "semi_alpha_pct": round(semi_pct, 2),
        "mask": _mask(cell),
    }


def _mask(cell: Image.Image) -> list[list[bool]]:
    px = cell.load()
    return [[px[x, y][3] > 0 for x in range(CELL)] for y in range(CELL)]


def _iou(a: list[list[bool]], b: list[list[bool]]) -> float:
    inter = sum(1 for y in range(CELL) for x in range(CELL) if a[y][x] and b[y][x])
    union = sum(1 for y in range(CELL) for x in range(CELL) if a[y][x] or b[y][x])
    return inter / union if union else 0.0


# ---------------------------------------------------------------------------
# REPORTING
# ---------------------------------------------------------------------------

def _fmt_range(rng: tuple[float, float], value: float, pct: bool = False) -> str:
    lo, hi = rng
    ok = lo <= value <= hi
    shown = f"{value * 100:.0f}%" if pct else f"{value:g}"
    return f"{shown:>8} {'ok' if ok else 'FAIL':<4} [{lo * 100:.0f}–{hi * 100:.0f}%]" if pct \
        else f"{shown:>8} {'ok' if ok else 'FAIL':<4} [{lo:g}–{hi:g}]"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true", help="exit 1 on any violation")
    ap.add_argument("--json", action="store_true", help="machine readable output")
    ap.add_argument("--iou", action="store_true", help="print silhouette overlap table")
    ap.add_argument("--textures", default=str(TEX))
    args = ap.parse_args()

    tex = Path(args.textures)
    results: dict[str, dict] = {}
    failures: list[str] = []

    for name, spec in SPEC.items():
        sheet = tex / spec["sheet"]
        if not sheet.exists():
            failures.append(f"{name}: missing {sheet}")
            continue
        try:
            m = _measure(name, sheet)
        except ValueError as exc:
            failures.append(f"{name}: {exc}")
            continue
        results[name] = m

        for key in ("body_h", "shoulder_w", "hip_w", "leg_mass", "stance_w"):
            lo, hi = spec[key]
            if not lo <= m[key] <= hi:
                failures.append(f"{name}.{key} = {m[key]} outside [{lo}, {hi}]")
        # `max_width` is a single hard ceiling, not a range.
        if m["max_width"] > spec["max_width"]:
            failures.append(f"{name}.max_width = {m['max_width']} > {spec['max_width']}")
        lo, hi = spec["head_ratio"]
        if not lo <= m["head_ratio"] <= hi:
            failures.append(f"{name}.head_ratio = {m['head_ratio']:.2f} outside [{lo}, {hi}]")
        if m["colours"] > MAX_COLOURS:
            failures.append(f"{name}.colours = {m['colours']} > {MAX_COLOURS}")
        if m["semi_alpha_pct"] > MAX_SEMI_ALPHA_PCT:
            failures.append(f"{name}.semi_alpha_pct = {m['semi_alpha_pct']}% > {MAX_SEMI_ALPHA_PCT}%")

    iou: dict[str, float] = {}
    names = list(results)
    for a, b in itertools.combinations(names, 2):
        v = _iou(results[a]["mask"], results[b]["mask"])
        iou[f"{a}/{b}"] = round(v, 3)
        if v > MAX_PAIRWISE_IOU:
            failures.append(f"silhouette {a} vs {b} IoU {v:.2f} > {MAX_PAIRWISE_IOU}")

    if args.json:
        for m in results.values():
            m.pop("mask", None)
        print(json.dumps({"heroes": results, "iou": iou, "failures": failures}, indent=2))
        return 0 if not failures else 1

    print("\n=== Hero skeleton contract ===\n")
    for name, m in results.items():
        spec = SPEC[name]
        print(f"{name.upper()}  ({m['frames']} frames, ground_y={m['ground_y']}, "
              f"{m['colours']} colours, {m['semi_alpha_pct']}% semi-alpha)")
        print(f"  body height  {_fmt_range(spec['body_h'], m['body_h'])}")
        print(f"  head ratio   {_fmt_range(spec['head_ratio'], m['head_ratio'], True)}")
        print(f"  shoulders    {_fmt_range(spec['shoulder_w'], m['shoulder_w'])}")
        print(f"  hips         {_fmt_range(spec['hip_w'], m['hip_w'])}")
        print(f"  leg mass     {_fmt_range(spec['leg_mass'], m['leg_mass'])}")
        print(f"  stance width {_fmt_range(spec['stance_w'], m['stance_w'])}")
        print(f"  max width    {m['max_width']:>8} {'ok' if m['max_width'] <= spec['max_width'] else 'FAIL':<4} [<= {spec['max_width']}]")
        print()

    if args.iou or failures:
        print("=== Silhouette overlap (IoU, lower = more distinct) ===")
        for pair, v in sorted(iou.items(), key=lambda kv: -kv[1]):
            flag = "ok" if v <= MAX_PAIRWISE_IOU else "TOO SIMILAR"
            print(f"  {pair:<22} {v:.2f}  {flag}")
        print()

    if failures:
        print(f"=== {len(failures)} violation(s) ===")
        for f in failures:
            print("  -", f)
        print()
        if args.strict:
            return 1
    else:
        print("=== ALL CONTRACT CHECKS PASSED ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
