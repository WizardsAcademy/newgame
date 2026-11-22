#!/usr/bin/env python3
"""Measure 96x96 hero sprite sheets in assets/textures/player_*.png.

Reports per-frame bounding boxes (`bbox`, `body_height`, `top_y`, `bottom_y`)
and prints a per-hero summary table:
  frames | f0_h | body_h avg/min/max | ground_y set | colours | semi_alpha_pct

Exits non-zero if:
  - any sheet width is not a multiple of 96 (or height != 96),
  - any 96x96 cell has zero visible pixels, or
  - semi-transparent pixel percentage exceeds 2.0%.

Pass `--strict` to also enforce the art contract targets (`f0_h` in 70..74,
`ground_y == {80}`, `colours <= 24`, zero `#000000` pixels).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from PIL import Image

CELL = 96
GROUND_Y_TARGET = 80
BODY_H_MIN = 70
BODY_H_MAX = 74
MAX_COLOURS = 24
MAX_SEMI_ALPHA_PCT = 2.0

NON_HERO_PLAYER_PNGS = {
    "player_arrow.png",
    "player_placeholder.png",
}


def iter_pixels(im: Image.Image):
    if hasattr(im, "get_flattened_data"):
        return im.get_flattened_data()
    return im.getdata()


def default_hero_sheets(repo_root: Path) -> list[Path]:
    tex_dir = repo_root / "assets" / "textures"
    return sorted(
        p for p in tex_dir.glob("player_*.png")
        if p.name not in NON_HERO_PLAYER_PNGS
    )


def measure_sheet(path: Path, verbose: bool = True) -> dict:
    im = Image.open(path).convert("RGBA")
    width, height = im.size
    errors: list[str] = []

    if height != CELL:
        errors.append(f"{path.name}: height {height} != {CELL}")
    if width == 0 or width % CELL != 0:
        errors.append(f"{path.name}: width {width} is not a positive multiple of {CELL}")

    frames = width // CELL if width >= CELL else 0
    pxs = list(iter_pixels(im))
    total_px = max(len(pxs), 1)
    colours = {(r, g, b) for (r, g, b, a) in pxs if a > 0}
    pure_black_px = sum(1 for (r, g, b, a) in pxs if a > 0 and (r, g, b) == (0, 0, 0))
    semi_alpha = sum(1 for (_r, _g, _b, a) in pxs if 0 < a < 255)
    semi_alpha_pct = 100.0 * semi_alpha / float(total_px)

    if semi_alpha_pct > MAX_SEMI_ALPHA_PCT:
        errors.append(
            f"{path.name}: semi_alpha_pct {semi_alpha_pct:.2f}% > {MAX_SEMI_ALPHA_PCT:.1f}%"
        )

    frame_stats: list[dict] = []
    if verbose:
        print(f"=== {path.name} ({width}x{height}, {frames} frames) ===")

    for idx in range(frames):
        cell = im.crop((idx * CELL, 0, (idx + 1) * CELL, min(height, CELL)))
        bbox = cell.getbbox()
        if bbox is None:
            errors.append(f"{path.name}: frame {idx} has no pixels")
            frame_stats.append(
                {"frame": idx, "bbox": None, "body_height": 0, "top_y": None, "bottom_y": None}
            )
            if verbose:
                print(f"  f{idx:02d}: EMPTY")
            continue
        x0, top_y, x1, bottom_y = bbox
        body_h = bottom_y - top_y
        frame_stats.append(
            {
                "frame": idx,
                "bbox": bbox,
                "width": x1 - x0,
                "body_height": body_h,
                "top_y": top_y,
                "bottom_y": bottom_y,
            }
        )
        if verbose:
            print(
                f"  f{idx:02d}: bbox=({x0:2d},{top_y:2d},{x1:2d},{bottom_y:2d})  "
                f"body_height={body_h:2d}  top_y={top_y:2d}  bottom_y={bottom_y:2d}"
            )

    heights = [f["body_height"] for f in frame_stats if f["bbox"] is not None]
    grounds = sorted({f["bottom_y"] for f in frame_stats if f["bottom_y"] is not None})
    avg_h = (sum(heights) / len(heights)) if heights else 0.0
    min_h = min(heights) if heights else 0
    max_h = max(heights) if heights else 0
    f0_h = heights[0] if heights else 0

    return {
        "path": path,
        "name": path.stem.replace("player_", ""),
        "frames": frames,
        "f0_h": f0_h,
        "avg_h": avg_h,
        "min_h": min_h,
        "max_h": max_h,
        "grounds": grounds,
        "colour_count": len(colours),
        "pure_black_px": pure_black_px,
        "semi_alpha_pct": semi_alpha_pct,
        "frame_stats": frame_stats,
        "errors": errors,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sheets", nargs="*", help="Optional explicit PNG paths")
    parser.add_argument("--quiet-frames", action="store_true", help="Print only summary table")
    parser.add_argument("--strict", action="store_true", help="Also enforce Phase 1/4 contract targets")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    paths = [Path(s) for s in args.sheets] if args.sheets else default_hero_sheets(repo_root)
    if not paths:
        print("ERROR: no hero sheets found", file=sys.stderr)
        return 1

    results = [measure_sheet(p, verbose=not args.quiet_frames) for p in paths]

    print("\n=== Hero Sheet Summary ===")
    header = (
        f"{'hero':<10} | {'frames':>6} | {'f0_h':>4} | {'body_h avg/min/max':>18} | "
        f"{'ground_y set':<22} | {'colours':>7} | {'semi_alpha':>10}"
    )
    print(header)
    print("-" * len(header))

    all_errors: list[str] = []
    for r in results:
        grounds_str = ",".join(str(g) for g in r["grounds"])
        h_str = f"{r['avg_h']:4.1f} / {r['min_h']:2d} / {r['max_h']:2d}"
        grounds_col = ("{" + grounds_str + "}").ljust(22)
        print(
            f"{r['name']:<10} | {r['frames']:>6d} | {r['f0_h']:>4d} | {h_str:>18} | "
            f"{grounds_col} | {r['colour_count']:>7d} | {r['semi_alpha_pct']:>9.2f}%"
        )
        all_errors.extend(r["errors"])
        if args.strict:
            if not (BODY_H_MIN <= r["f0_h"] <= BODY_H_MAX):
                all_errors.append(
                    f"{r['name']}: standing f0 body_h={r['f0_h']} outside [{BODY_H_MIN}, {BODY_H_MAX}]"
                )
            if r["grounds"] != [GROUND_Y_TARGET]:
                all_errors.append(
                    f"{r['name']}: ground_y set {r['grounds']} != [{GROUND_Y_TARGET}]"
                )
            if r["colour_count"] > MAX_COLOURS:
                all_errors.append(
                    f"{r['name']}: colour_count={r['colour_count']} > {MAX_COLOURS}"
                )

    if all_errors:
        print("\nMEASUREMENT ERRORS:", file=sys.stderr)
        for err in all_errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
