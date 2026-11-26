#!/usr/bin/env python3
"""Sylvara forge-frame pipeline: key -> crop -> scale -> palette-lock -> place -> QA.

Every generated take goes through ALL stages; QA failures are printed and the
frame is not written to frames/ unless every check passes (or is an approved
per-frame exception, e.g. the airborne vault pose).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
CELL = 64
PAL = json.loads((HERE / "palette.json").read_text())
PALETTE: list[tuple[int, int, int]] = [
    tuple(int(c.lstrip("#")[i:i+2], 16) for i in (0, 2, 4))
    for ramp in PAL["ramps"].values() for c in ramp
]

# Per-frame spec (game sheet order). ground = expected bbox bottom (exclusive).
# body = allowed body-height range. cx = target bbox-x centre in the 64-cell.
SPECS: dict[str, dict] = {
    "f00_idle": {
        "body": [
            46,
            50
        ],
        "ground": 54,
        "cx": 36,
        "air": False
    },
    "f01_walk_a": {
        "body": [
            45,
            49
        ],
        "ground": 54,
        "cx": 36,
        "air": False
    },
    "f02_walk_b": {
        "body": [
            45,
            49
        ],
        "ground": 54,
        "cx": 36,
        "air": False
    },
    "f03_windup": {
        "body": [
            49,
            53
        ],
        "ground": 54,
        "cx": 27,
        "air": False
    },
    "f04_sweep": {
        "body": [
            43,
            47
        ],
        "ground": 54,
        "cx": 32,
        "air": False
    },
    "f05_spin": {
        "body": [
            43,
            47
        ],
        "ground": 54,
        "cx": 32,
        "air": False
    },
    "f06_guard": {
        "body": [
            46,
            50
        ],
        "ground": 54,
        "cx": 31,
        "air": False
    },
    "f07_charge": {
        "body": [
            46,
            50
        ],
        "ground": 54,
        "cx": 36,
        "air": False
    },
    "f08_hurt": {
        "body": [
            46,
            50
        ],
        "ground": 54,
        "cx": 36,
        "air": False
    },
    "f09_blink": {
        "body": [
            45,
            49
        ],
        "ground": 54,
        "cx": 36,
        "air": False
    },
    "f10_idle_down": {
        "body": [
            46,
            50
        ],
        "ground": 54,
        "cx": 31,
        "air": False
    },
    "f11_walk_down_a": {
        "body": [
            45,
            49
        ],
        "ground": 54,
        "cx": 31,
        "air": False
    },
    "f12_walk_down_b": {
        "body": [
            45,
            49
        ],
        "ground": 54,
        "cx": 31,
        "air": False
    },
    "f13_idle_up": {
        "body": [
            46,
            50
        ],
        "ground": 54,
        "cx": 35,
        "air": False
    },
    "f14_walk_up_a": {
        "body": [
            45,
            49
        ],
        "ground": 54,
        "cx": 35,
        "air": False
    },
    "f15_walk_up_b": {
        "body": [
            45,
            49
        ],
        "ground": 54,
        "cx": 35,
        "air": False
    }
}


def magenta_ness(arr: np.ndarray) -> np.ndarray:
    r = arr[..., 0].astype(np.int16)
    g = arr[..., 1].astype(np.int16)
    b = arr[..., 2].astype(np.int16)
    return np.minimum(r, b) - g


def flood_background(key: np.ndarray) -> np.ndarray:
    """Connected-to-border component mask of key pixels (True = background)."""
    h, w = key.shape
    bg = np.zeros_like(key, dtype=bool)
    stack = []
    for x in range(w):
        for y in (0, h - 1):
            if key[y, x] and not bg[y, x]:
                bg[y, x] = True
                stack.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if key[y, x] and not bg[y, x]:
                bg[y, x] = True
                stack.append((y, x))
    while stack:
        y, x = stack.pop()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and key[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True
                stack.append((ny, nx))
    return bg


def key_magenta(im: Image.Image) -> Image.Image:
    """Binary-alpha magenta key with border flood fill + fringe despill."""
    arr = np.asarray(im.convert("RGB")).astype(np.uint8)
    m = magenta_ness(arr)
    strong = m > 100
    candidate = m > 35
    bg = flood_background(candidate) | strong
    alpha = np.where(bg, 0, 255).astype(np.uint8)

    # despill: non-bg pixels with residual magenta get g pulled toward min(r,b)
    fg = alpha == 255
    spill = fg & (m > 30)
    if spill.any():
        r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
        arr[..., 1] = np.where(spill, (np.minimum(r, b) * 0.4 + g * 0.6).astype(np.uint8), g)

    # fringe softening: fg pixels touching bg and weakly magenta -> shift away
    out = np.dstack([arr, alpha]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def crop_figure(im: Image.Image) -> Image.Image | None:
    bbox = im.getbbox()
    return im.crop(bbox) if bbox else None


def scale_to_body(fig: Image.Image, target_h: int) -> Image.Image:
    w, h = fig.size
    k = target_h / float(h)
    return fig.resize((max(1, int(round(w * k))), target_h), Image.NEAREST)


def palette_lock(im: Image.Image) -> Image.Image:
    arr = np.asarray(im.convert("RGBA")).astype(np.float32)
    rgb = arr[..., :3]
    alpha = arr[..., 3]
    mask = alpha > 0
    if not mask.any():
        return im
    pal = np.asarray(PALETTE, dtype=np.float32)
    # weighted OkLab-ish distance: weight chroma channels to protect hue
    px = rgb[mask]
    w = np.array([0.90, 1.35, 0.90])
    d = ((px[:, None, :] - pal[None, :, :]) * w) ** 2
    idx = np.argmin(d.sum(axis=2), axis=1)
    flat = rgb[mask].astype(np.int32)
    # snap only if reasonably close; far outliers keep original (QA will flag)
    best = pal[idx]
    dist = np.sqrt(((px - best) ** 2).sum(axis=1))
    snap = dist < 90
    mixed = flat.copy()
    mixed[snap] = best[snap].astype(np.int32)
    rgb[mask] = mixed
    out = np.dstack([rgb.astype(np.uint8), alpha.astype(np.uint8)])
    return Image.fromarray(out, "RGBA")


def place_in_cell(fig: Image.Image, spec: dict) -> Image.Image:
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    w, h = fig.size
    cx = spec["cx"]
    x0 = int(round(cx - w / 2))
    x0 = max(0, min(CELL - w, x0))
    y0 = spec["ground"] - h
    cell.alpha_composite(fig, (x0, y0))
    return cell


def qa_frame(cell: Image.Image, name: str) -> tuple[list[str], dict]:
    errs: list[str] = []
    spec = SPECS[name]
    arr = np.asarray(cell.convert("RGBA"))
    alpha = arr[..., 3]
    semi = int(((alpha > 0) & (alpha < 255)).sum())
    if semi:
        errs.append(f"semi-alpha pixels: {semi}")
    opaque = alpha == 255
    n_op = int(opaque.sum())
    if n_op < 120:
        errs.append(f"too few opaque pixels: {n_op}")
    ys, xs = np.nonzero(opaque)
    if len(ys) == 0:
        errs.append("empty frame")
        return errs, {}
    top, bottom, left, right = int(ys.min()), int(ys.max()), int(xs.min()), int(xs.max())
    body_h = bottom - top + 1
    bbox_bottom_excl = bottom + 1
    if bbox_bottom_excl != spec["ground"]:
        errs.append(f"bottom_y {bbox_bottom_excl} != {spec['ground']}")
    lo, hi = spec["body"]
    if not (lo <= body_h <= hi):
        errs.append(f"body_height {body_h} outside [{lo},{hi}]")
    if right + 1 >= CELL:
        print(f"       (warn) sprite reaches right cell edge (bow forward) x1={right + 1}")
    if left == 0:
        errs.append("touches left cell edge")
    if top < 2:
        errs.append(f"touches top edge: top_y={top}")
    if (right - left + 1) > 62:
        errs.append(f"figure too wide: {right - left + 1}px")
    colours = {tuple(int(v) for v in arr[y, x, :3]) for y, x in zip(ys, xs)}
    bad = colours - set(PALETTE)
    if bad:
        errs.append(f"{len(bad)} off-palette colours, e.g. {sorted(bad, key=lambda c: -sum(c))[:3]}")
    if (0, 0, 0) in colours:
        errs.append("contains #000000")
    m = magenta_ness(arr[..., :3].astype(np.int16))
    mag = int((opaque & (m > 40)).sum())
    if mag:
        errs.append(f"magenta spill pixels: {mag}")
    stats = {"body_h": body_h, "bottom_y": bbox_bottom_excl, "top_y": top,
             "x0": left, "x1": right + 1, "colours": len(colours), "opaque": n_op}
    return errs, stats


def build(raw_path: Path, out_path: Path, target_h: int, spec_name: str) -> bool:
    im = Image.open(raw_path)
    keyed = key_magenta(im)
    fig = crop_figure(keyed)
    if fig is None:
        print(f"  [FAIL] {raw_path.name}: nothing left after keying")
        return False
    scaled = scale_to_body(fig, target_h)
    locked = palette_lock(scaled)
    cell = place_in_cell(locked, SPECS[spec_name])
    errs, stats = qa_frame(cell, spec_name)
    tag = "PASS" if not errs else "FAIL"
    print(f"  [{tag}] {spec_name}: body_h={stats.get('body_h')} bottom={stats.get('bottom_y')} "
          f"cols={stats.get('colours')} opaque={stats.get('opaque')} x=({stats.get('x0')},{stats.get('x1')})")
    for e in errs:
        print(f"       ! {e}")
    if not errs:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        cell.save(out_path)
        return True
    cell.save(out_path.with_suffix(".fail.png"))
    return False


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("raw", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--name", required=True)
    ap.add_argument("--body", type=int, required=True)
    a = ap.parse_args()
    ok = build(a.raw, a.out, a.body, a.name)
    sys.exit(0 if ok else 1)
