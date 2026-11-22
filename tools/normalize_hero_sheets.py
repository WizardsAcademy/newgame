#!/usr/bin/env python3
"""Normalize hero sprite sheets in assets/textures/player_*.png (Phase 1).

For each hero sheet:
  1. Measures frame 0 (the standing idle pose) to get `standing_h`.
  2. Computes a uniform hero scale factor `k = 72.0 / standing_h`.
  3. Scales each 96x96 cell uniformly with `Image.NEAREST` (never squashing X
     independently from Y). If an oversized attack arc would exceed the 96px
     cell width or the 80px headroom above `GROUND_Y = 80`, scales that cell
     down uniformly as one unit so nothing is ever cropped or distorted.
  4. Re-grounds every frame so its bottom pixel row sits at `GROUND_Y = 80`
     (`bbox[3] == 80`), eliminating vertical jitter (including Sylvara f06).
  5. Writes the normalized sheet back in place and prints a before/after table.
"""

from __future__ import annotations

from pathlib import Path
from PIL import Image

from measure_hero_sheets import CELL, default_hero_sheets, measure_sheet

TARGET_BODY_H = 72
GROUND_Y = 80


def normalize_cell(cell: Image.Image, k_hero: float) -> Image.Image:
    bbox = cell.getbbox()
    if bbox is None:
        return Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))

    x0, y0, x1, y1 = bbox
    crop = cell.crop(bbox)
    w = x1 - x0
    h = y1 - y0

    # Uniform scale factor: never distort X vs Y, and never crop top or sides.
    k = min(k_hero, float(CELL) / float(w), float(GROUND_Y) / float(h))
    new_w = max(1, min(CELL, int(round(w * k))))
    new_h = max(1, min(GROUND_Y, int(round(h * k))))
    # Enforce exact aspect-locked uniform scale if rounding pushed one axis over.
    scaled = crop.resize((new_w, new_h), Image.NEAREST)

    # Preserve horizontal offset relative to cell center (x = 48), clamped to [0, 96].
    old_cx = 0.5 * (x0 + x1)
    new_cx = (CELL * 0.5) + (old_cx - (CELL * 0.5)) * k
    dst_x = int(round(new_cx - new_w * 0.5))
    dst_x = max(0, min(CELL - new_w, dst_x))
    dst_y = GROUND_Y - new_h

    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    out.alpha_composite(scaled, (dst_x, dst_y))

    # Re-verify exact bottom_y == GROUND_Y in case resize trimmed an ultra-thin row.
    out_bb = out.getbbox()
    if out_bb is not None and out_bb[3] != GROUND_Y:
        shift_y = GROUND_Y - out_bb[3]
        shifted = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        sub = out.crop(out_bb)
        ny = max(0, out_bb[1] + shift_y)
        shifted.alpha_composite(sub, (out_bb[0], ny))
        out = shifted

    return out


def normalize_sheet(path: Path) -> tuple[dict, dict]:
    before = measure_sheet(path, verbose=False)
    im = Image.open(path).convert("RGBA")
    frames = im.width // CELL

    f0_h = before["f0_h"]
    k_hero = float(TARGET_BODY_H) / float(max(f0_h, 1))

    out_sheet = Image.new("RGBA", (im.width, CELL), (0, 0, 0, 0))
    for idx in range(frames):
        cell = im.crop((idx * CELL, 0, (idx + 1) * CELL, CELL))
        norm = normalize_cell(cell, k_hero)
        out_sheet.alpha_composite(norm, (idx * CELL, 0))

    out_sheet.save(path)
    after = measure_sheet(path, verbose=False)
    return before, after


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    paths = default_hero_sheets(repo_root)

    rows = [normalize_sheet(p) for p in paths]

    print("=== Hero Sheet Normalization (Before -> After) ===")
    hdr = (
        f"{'hero':<10} | {'f0_h':<11} | {'avg_h':<13} | "
        f"{'ground_y before -> after':<34} | {'frames':>6}"
    )
    print(hdr)
    print("-" * len(hdr))
    for b, a in rows:
        gb = "{" + ",".join(str(g) for g in b["grounds"]) + "}"
        ga = "{" + ",".join(str(g) for g in a["grounds"]) + "}"
        print(
            f"{a['name']:<10} | {b['f0_h']:>2d} -> {a['f0_h']:>2d}    | "
            f"{b['avg_h']:>4.1f} -> {a['avg_h']:>4.1f} | "
            f"{(gb + ' -> ' + ga):<34} | {a['frames']:>6d}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
