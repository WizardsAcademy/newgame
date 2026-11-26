#!/usr/bin/env python3
"""Structural despeckle for the reskinned hero frames.

ROOT CAUSE BEING FIXED
  The AI-generated masters shade with 1-texel dither (single texels alternating
  between two tonal steps of the same material). The pipeline quantized colours
  (palette lock) but preserved the dither pattern spatially; NEAREST scaling
  kept it 1:1. Result: noisy, "low-quality" look on smooth masses (long hair),
  while fur-covered Behemoth reads as intentional texture.

FIX (targeted, detail-preserving)
  1. Connected-component analysis (4-conn) of same-colour texels per frame.
  2. Components of size <= 2 that are surrounded (>=3 of their 4-conn
     boundary positions) by ONE colour of the SAME PALETTE RAMP are absorbed
     into that colour — this flattens shading dither into clean bands.
  3. Components of size <= 2 fully encircled (all 4 boundary positions opaque
     and one unanimous colour) are absorbed too — kills trapped speckle.
  Deliberate small details survive: they are clusters of a DIFFERENT ramp
  (eye glints, rivets, flowers, buckles) or components >= 3 texels.

Only recolours happen — never moves — so placement geometry (ground row,
body height) is untouched, and the palette can only shrink. The per-frame
QA gate is re-run afterwards by the caller.
"""
from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

RAMP_SIZE = 4  # 6 ramps x 4 steps in palette.json order


def ramp_of(palette_index: int) -> int:
    return palette_index // RAMP_SIZE


def colour_ramp_map(palette: list[tuple[int, int, int]]) -> dict[tuple[int, int, int], int]:
    return {c: ramp_of(i) for i, c in enumerate(palette)}


def despeckle_cell(arr: np.ndarray, cramp: dict, iterations: int = 2) -> np.ndarray:
    """arr: HxWx4 uint8 RGBA cell (alpha binary). Returns recoloured copy.

    Rules for small (size<=2) same-colour components:
      - absorb into dominant boundary colour when it is the SAME palette ramp
        (tonal dither) with >=2 dominant neighbours;
      - absorb cross-ramp when the (component -> dominant) pair is SYSTEMATIC
        in this frame (>=5 occurrences) — i.e. mottle, not a one-off detail;
      - size-1 comps in fully mixed transition zones adopt the majority
        same-ramp neighbour colour (>=2 of 4).
    Components >=3 texels are never touched (features); one-off cross-ramp
    pairs are never touched (eye glints, rivets, buckles).
    """
    out = arr.copy()
    for _ in range(iterations):
        alpha = out[..., 3] == 255
        rgb = out[..., :3]
        h, w = alpha.shape
        colour_at = {(y, x): tuple(rgb[y, x]) for y, x in zip(*np.nonzero(alpha))}
        comps = components(colour_at, h, w)
        # frame-level systematic pair prior (size<=2 comps, dominant >= 2)
        pair_count: dict = {}
        for comp, c, outside in comps:
            if len(comp) > 2 or not outside:
                continue
            dom = dominant_of(outside)
            if dom is None:
                continue
            pair_count[(c, dom)] = pair_count.get((c, dom), 0) + 1
        changed = False
        for comp, c, outside in comps:
            if len(comp) > 2 or not outside:
                continue
            cnt: dict = {}
            for cc in outside:
                cnt[cc] = cnt.get(cc, 0) + 1
            dom, n = max(cnt.items(), key=lambda kv: kv[1])
            same_ramp = cramp.get(c) is not None and cramp.get(dom) is not None and cramp[c] == cramp[dom]
            systematic = pair_count.get((c, dom), 0) >= 5
            adopt = None
            if (same_ramp or systematic) and n >= 2:
                adopt = dom
            elif len(comp) == 1 and n == 1 and cramp.get(c) is not None:
                same_ramp_nbrs = [cc for cc in outside
                                  if cramp.get(cc) is not None and cramp[cc] == cramp[c]]
                if len(same_ramp_nbrs) >= 2:
                    sc = {}
                    for cc in same_ramp_nbrs:
                        sc[cc] = sc.get(cc, 0) + 1
                    adopt = max(sc.items(), key=lambda kv: kv[1])[0]
            if adopt is not None and adopt != c:
                for p in comp:
                    rgb[p] = adopt
                changed = True
        if not changed:
            break
    return out


def dominant_of(outside: list) -> tuple | None:
    if not outside:
        return None
    cnt: dict = {}
    for cc in outside:
        cnt[cc] = cnt.get(cc, 0) + 1
    return max(cnt.items(), key=lambda kv: kv[1])[0]


def components(colour_at: dict, h: int, w: int) -> list:
    """[(comp, colour, outside_colours)] for all 4-conn same-colour components."""
    seen: set = set()
    result = []
    for start in list(colour_at):
        if start in seen:
            continue
        c = colour_at[start]
        comp = []
        q = deque([start])
        seen.add(start)
        while q:
            y, x = q.popleft()
            comp.append((y, x))
            for ny, nx in ((y+1, x), (y-1, x), (y, x+1), (y, x-1)):
                if (ny, nx) in colour_at and (ny, nx) not in seen and colour_at[(ny, nx)] == c:
                    seen.add((ny, nx))
                    q.append((ny, nx))
        inner = set(comp)
        outside = []
        for y, x in comp:
            for ny, nx in ((y+1, x), (y-1, x), (y, x+1), (y, x-1)):
                if (ny, nx) not in inner and 0 <= ny < h and 0 <= nx < w and (ny, nx) in colour_at:
                    outside.append(colour_at[(ny, nx)])
        result.append((comp, c, outside))
    return result


def load_palette(palette_json: Path) -> list[tuple[int, int, int]]:
    import json
    data = json.loads(palette_json.read_text())
    pal = []
    for ramp in data["ramps"].values():
        for hx in ramp:
            pal.append(tuple(int(hx.lstrip("#")[i:i+2], 16) for i in (0, 2, 4)))
    return pal


def process(path: Path, cramp: dict, out_path: Path | None = None) -> float:
    arr = np.asarray(Image.open(path).convert("RGBA")).copy()
    before_runs = runs_metric(arr)
    arr = despeckle_cell(arr, cramp)
    after_runs = runs_metric(arr)
    Image.fromarray(arr, "RGBA").save(out_path or path)
    return (before_runs, after_runs)


def runs_metric(arr: np.ndarray) -> float:
    """Percentage of 1-texel horizontal runs (noise indicator)."""
    op = arr[..., 3] == 255
    total = 0
    ones = 0
    for y in range(arr.shape[0]):
        x = 0
        row = arr[y]
        while x < arr.shape[1]:
            if not op[y, x]:
                x += 1
                continue
            c = tuple(row[x][:3])
            x0 = x
            while x < arr.shape[1] and op[y, x] and tuple(row[x][:3]) == c:
                x += 1
            run = x - x0
            total += 1
            if run == 1:
                ones += 1
    return 100.0 * ones / max(total, 1)


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+", type=Path)
    ap.add_argument("--palette", type=Path, required=True)
    args = ap.parse_args()
    cramp = colour_ramp_map(load_palette(args.palette))
    for f in args.files:
        b, a = process(f, cramp)
        print(f"  {f.name:26s} 1px-runs {b:5.1f}% -> {a:5.1f}%")
