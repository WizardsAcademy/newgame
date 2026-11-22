#!/usr/bin/env python3
"""Shared reference-sheet extraction, de-matting, uniform grounding, and portrait kit.

Matches the battle-tested `make_velmira_sprites.py` pipeline (`224x224` cells,
`GROUND_Y = 200`, `TARGET_BODY_H = 164`, `192x192` x 5 circular HUD portraits):
  - Clean border flood-fill + enclosed hole keying + white-fringe de-matting
    for white-background sheets (`sylvara_reference.png`)
  - Clean border flood-fill + grid-line removal + enclosed black-gap keying
    for black-background sheets (`behemoth_reference.png`, `knight_reference.png`)
  - Fixed-body-scale placement (`place_grounded`) so overhead sword arcs or
    charged bow auras NEVER shrink the character body
  - Subtle locked-boots breathing generator (`make_calm_breath_variant`) so
    all directional idles feel alive yet calm and natural!
"""
from __future__ import annotations

from collections import deque
import math
import numpy as np
from PIL import Image, ImageDraw

CELL = 224
GROUND_Y = 200
TARGET_BODY_H = 164


def trim_rgba(im: Image.Image, min_a: int = 24) -> Image.Image:
    arr = np.array(im)
    ys, xs = np.where(arr[:, :, 3] > min_a)
    if len(xs) == 0:
        return Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    return im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def _remove_small_specks(rgba: np.ndarray, min_pixels: int = 36, alpha_thresh: int = 28) -> np.ndarray:
    h, w, _ = rgba.shape
    fg = rgba[:, :, 3] > alpha_thresh
    vis = np.zeros((h, w), dtype=bool)
    for sy in range(h):
        xs = np.where(fg[sy] & (~vis[sy]))[0]
        for sx in xs:
            if vis[sy, sx]:
                continue
            q = deque([(int(sx), int(sy))])
            vis[sy, sx] = True
            comp = []
            while q:
                cx, cy = q.popleft()
                comp.append((cx, cy))
                for nx, ny in (
                    (cx - 1, cy),
                    (cx + 1, cy),
                    (cx, cy - 1),
                    (cx, cy + 1),
                    (cx - 1, cy - 1),
                    (cx + 1, cy - 1),
                    (cx - 1, cy + 1),
                    (cx + 1, cy + 1),
                ):
                    if 0 <= nx < w and 0 <= ny < h and fg[ny, nx] and not vis[ny, nx]:
                        vis[ny, nx] = True
                        q.append((nx, ny))
            if len(comp) < min_pixels:
                for cx, cy in comp:
                    rgba[cy, cx] = (0, 0, 0, 0)
    rgba[rgba[:, :, 3] <= alpha_thresh] = (0, 0, 0, 0)
    return rgba


def extract_from_white_bg(
    ref: Image.Image,
    box: tuple[int, int, int, int],
    clear_enclosed_holes: bool = True,
    min_speck: int = 36,
) -> Image.Image:
    """Extract character cleanly from a white-background sheet with zero white halo."""
    crop = ref.crop(box).convert("RGBA")
    rgba = np.array(crop, dtype=np.uint8)
    h, w, _ = rgba.shape
    rgb = rgba[:, :, :3].astype(np.int16)
    mn = rgb.min(axis=2)
    mx = rgb.max(axis=2)
    chroma = mx - mn

    # 1. Flood-fill white background from all 4 borders
    passable = (mn >= 228) & (chroma <= 24)
    bg = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        for y in (0, h - 1):
            if passable[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if passable[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((x, y))
    while q:
        cx, cy = q.popleft()
        for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
            if 0 <= nx < w and 0 <= ny < h and passable[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True
                q.append((nx, ny))

    # 2. Clear enclosed pure paper-white background pockets (e.g. bowstring D-gap, between boots)
    #    ONLY when the pocket is pure neutral white (`mn >= 247, chroma <= 6`) AND its boundary
    #    is predominantly dark outline pixels (`mx < 135`) — so ivory clothes/thighs stay 100% intact!
    if clear_enclosed_holes:
        pure_white = (mn >= 246) & (chroma <= 7) & (~bg)
        vis = np.zeros((h, w), dtype=bool)
        for sy in range(h):
            xs = np.where(pure_white[sy] & (~vis[sy]))[0]
            for sx in xs:
                if vis[sy, sx]:
                    continue
                hq = deque([(int(sx), int(sy))])
                vis[sy, sx] = True
                comp = []
                border_dark = 0
                border_total = 0
                while hq:
                    cx, cy = hq.popleft()
                    comp.append((cx, cy))
                    for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                        if 0 <= nx < w and 0 <= ny < h:
                            if pure_white[ny, nx]:
                                if not vis[ny, nx]:
                                    vis[ny, nx] = True
                                    hq.append((nx, ny))
                            elif not bg[ny, nx]:
                                # Step 1px further past anti-aliased fringe to check outline darkness
                                nnx = min(w - 1, max(0, nx + (nx - cx)))
                                nny = min(h - 1, max(0, ny + (ny - cy)))
                                border_total += 1
                                if mx[ny, nx] < 145 or mx[nny, nnx] < 130:
                                    border_dark += 1
                if len(comp) >= 6 and border_total > 0 and (border_dark / border_total) >= 0.72:
                    for cx, cy in comp:
                        bg[cy, cx] = True

    rgba[bg] = (0, 0, 0, 0)

    # 3. De-matte 2px outer anti-aliased white fringe touching `bg` so ZERO white halo remains!
    for _pass in range(2):
        padded = np.pad(bg, 1, mode="constant", constant_values=True)
        adj_bg = (
            padded[:-2, 1:-1]
            | padded[2:, 1:-1]
            | padded[1:-1, :-2]
            | padded[1:-1, 2:]
        ) & (~bg)
        ys, xs = np.where(adj_bg)
        newly_cleared = []
        for y, x in zip(ys, xs):
            r, g, b, a = int(rgba[y, x, 0]), int(rgba[y, x, 1]), int(rgba[y, x, 2]), int(rgba[y, x, 3])
            if a == 0:
                continue
            lum = (r + g + b) / 3.0
            ch = max(r, g, b) - min(r, g, b)
            if lum > 225 and ch <= 22:
                rgba[y, x] = (0, 0, 0, 0)
                newly_cleared.append((y, x))
            elif lum > 135 and ch <= 38:
                # Un-blend white (#255) against dark outline (#28)
                alpha_f = max(0.0, min(1.0, (250.0 - lum) / 145.0))
                new_a = int(round(a * alpha_f))
                if new_a < 24:
                    rgba[y, x] = (0, 0, 0, 0)
                    newly_cleared.append((y, x))
                else:
                    inv = 1.0 - alpha_f
                    nr = max(0, min(255, int(round((r - 255.0 * inv) / max(alpha_f, 0.15)))))
                    ng = max(0, min(255, int(round((g - 255.0 * inv) / max(alpha_f, 0.15)))))
                    nb = max(0, min(255, int(round((b - 255.0 * inv) / max(alpha_f, 0.15)))))
                    rgba[y, x] = (nr, ng, nb, new_a)
        for y, x in newly_cleared:
            bg[y, x] = True

    rgba = _remove_small_specks(rgba, min_pixels=min_speck)
    return trim_rgba(Image.fromarray(rgba, mode="RGBA"))


def extract_from_black_bg(
    ref: Image.Image,
    box: tuple[int, int, int, int],
    bg_thresh: int = 13,
    hole_thresh: int = 5,
    min_speck: int = 32,
) -> Image.Image:
    """Extract character cleanly from a black-background sheet while keeping interior dark outlines."""
    crop = ref.crop(box).convert("RGBA")
    rgba = np.array(crop, dtype=np.uint8)
    h, w, _ = rgba.shape
    rgb = rgba[:, :, :3].astype(np.int16)
    mx = rgb.max(axis=2)
    ch = mx - rgb.min(axis=2)

    # Strip thin grey separator grid lines near edges (neutral grey `ch <= 5`, `mx <= 58`)
    edge_band = np.zeros((h, w), dtype=bool)
    edge_band[:4, :] = True
    edge_band[-4:, :] = True
    edge_band[:, :4] = True
    edge_band[:, -4:] = True
    grid_px = edge_band & (ch <= 5) & (mx <= 60)
    rgba[grid_px] = (0, 0, 0, 0)
    mx[grid_px] = 0

    # 1. Border flood-fill through pure/near-black background
    passable = mx <= bg_thresh
    bg = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        for y in (0, h - 1):
            if passable[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if passable[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((x, y))
    while q:
        cx, cy = q.popleft()
        for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
            if 0 <= nx < w and 0 <= ny < h and passable[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True
                q.append((nx, ny))

    # 2. Clear enclosed pure-black background pockets (`mx <= hole_thresh`, area >= 14 px,
    #    e.g. between boots, between cape & leg, or between sword & body)
    if hole_thresh >= 0:
        pure_blk = (mx <= hole_thresh) & (~bg)
        vis = np.zeros((h, w), dtype=bool)
        for sy in range(h):
            xs = np.where(pure_blk[sy] & (~vis[sy]))[0]
            for sx in xs:
                if vis[sy, sx]:
                    continue
                hq = deque([(int(sx), int(sy))])
                vis[sy, sx] = True
                comp = []
                while hq:
                    cx, cy = hq.popleft()
                    comp.append((cx, cy))
                    for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                        if 0 <= nx < w and 0 <= ny < h and pure_blk[ny, nx] and not vis[ny, nx]:
                            vis[ny, nx] = True
                            hq.append((nx, ny))
                # Only clear genuine open gaps (not thin 1-2px interior outline strokes!)
                if len(comp) >= 18:
                    ys_c = [p[1] for p in comp]
                    xs_c = [p[0] for p in comp]
                    span_w = max(xs_c) - min(xs_c) + 1
                    span_h = max(ys_c) - min(ys_c) + 1
                    if span_w >= 4 and span_h >= 4:
                        for cx, cy in comp:
                            bg[cy, cx] = True

    rgba[bg] = (0, 0, 0, 0)

    # 3. Soft 1px outer anti-alias feather where `mx <= 24` touches `bg`
    padded = np.pad(bg, 1, mode="constant", constant_values=True)
    adj_bg = (
        padded[:-2, 1:-1] | padded[2:, 1:-1] | padded[1:-1, :-2] | padded[1:-1, 2:]
    ) & (~bg)
    ys, xs = np.where(adj_bg & (mx <= 24))
    for y, x in zip(ys, xs):
        rgba[y, x, 3] = int(round(255.0 * max(0.0, (int(mx[y, x]) - bg_thresh) / 14.0)))

    rgba = _remove_small_specks(rgba, min_pixels=min_speck)
    return trim_rgba(Image.fromarray(rgba, mode="RGBA"))


def compute_torso_x(im: Image.Image, y_frac0: float = 0.16, y_frac1: float = 0.68) -> float:
    arr = np.array(im)
    h, w, _ = arr.shape
    y0 = int(h * y_frac0)
    y1 = max(y0 + 1, int(h * y_frac1))
    ys, xs = np.where(arr[y0:y1, :, 3] >= 110)
    if len(xs) == 0:
        return w * 0.5
    return float(np.median(xs))


def compute_boot_bottom_y(im: Image.Image) -> int:
    arr = np.array(im)
    h, w, _ = arr.shape
    for y in range(h - 1, -1, -1):
        if int((arr[y, :, 3] >= 96).sum()) >= 2:
            return y
    return h - 1


def place_grounded(
    im: Image.Image,
    target_h: int | None = TARGET_BODY_H,
    fixed_scale: float | None = None,
    dx: int = 0,
    dy: int = 0,
    center_x_box: bool = False,
    ground_y: int = GROUND_Y,
) -> Image.Image:
    """Scale character uniformly and plant boots on `ground_y` inside a `224x224` cell."""
    if fixed_scale is not None:
        s = fixed_scale
    else:
        th = target_h if target_h is not None else TARGET_BODY_H
        s = th / float(max(im.height, 1))
    nw = max(1, int(round(im.width * s)))
    nh = max(1, int(round(im.height * s)))
    im_s = im.resize((nw, nh), Image.Resampling.LANCZOS)

    # Fit inside 220px width if an extreme dash streak or spear extends super wide
    if im_s.width > CELL - 4:
        fit_s = (CELL - 4) / float(im_s.width)
        # Crop left trailing speed-streaks rather than shrinking the character body!
        excess = im_s.width - (CELL - 4)
        im_s = im_s.crop((excess, 0, im_s.width, im_s.height))

    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    cx = (im_s.width * 0.5) if center_x_box else compute_torso_x(im_s)
    boot_y = compute_boot_bottom_y(im_s)
    px_x = int(round(CELL * 0.5 - cx)) + dx
    px_y = (ground_y - boot_y) + dy
    px_x = max(2, min(CELL - im_s.width - 2, px_x))
    px_y = max(2, min(CELL - im_s.height - 2, px_y))
    canvas.alpha_composite(im_s, (px_x, px_y))
    return canvas


def make_calm_breath_variant(
    cell_im: Image.Image,
    chest_lift_px: float = 1.4,
    cape_sway_px: float = 0.8,
) -> Image.Image:
    """Create a subtle, calm breathing idle frame from an already-grounded 224x224 cell.

    Boots (`y >= 152`) remain 100.0% pixel-locked to `GROUND_Y = 200` (ZERO foot jitter!),
    while the chest/shoulders gently inhale by ~1.4px and cloak/hair/pelt sways ~0.8px!
    """
    src = np.array(cell_im, dtype=np.float32)
    h, w, _ = src.shape
    out = np.zeros_like(src)

    # Bilinear backward sampling with smooth vertical/horizontal displacement field
    yy, xx = np.meshgrid(np.arange(h, dtype=np.float32), np.arange(w, dtype=np.float32), indexing="ij")
    # Smooth bell curve centered on upper torso (y ≈ 96), strictly 0 for y >= 152 (legs & boots!)
    t_torso = np.clip((152.0 - yy) / 116.0, 0.0, 1.0)
    lift_weight = np.sin(t_torso * math.pi * 0.85) * (yy < 152.0)
    sy = yy + chest_lift_px * lift_weight

    # Gentle horizontal fabric/cape/hair whisper on mid-lower back (`y` in `85..175`, `x < 112`)
    sway_band = np.clip(1.0 - np.abs(yy - 130.0) / 48.0, 0.0, 1.0) * np.clip((116.0 - xx) / 48.0, 0.0, 1.0)
    sx = xx - cape_sway_px * sway_band

    x0 = np.clip(np.floor(sx).astype(np.int32), 0, w - 1)
    x1 = np.clip(x0 + 1, 0, w - 1)
    y0 = np.clip(np.floor(sy).astype(np.int32), 0, h - 1)
    y1 = np.clip(y0 + 1, 0, h - 1)
    wx = (sx - x0)[..., None]
    wy = (sy - y0)[..., None]

    c00 = src[y0, x0]
    c10 = src[y0, x1]
    c01 = src[y1, x0]
    c11 = src[y1, x1]
    out = (c00 * (1 - wx) + c10 * wx) * (1 - wy) + (c01 * (1 - wx) + c11 * wx) * wy
    return Image.fromarray(np.clip(np.round(out), 0, 255).astype(np.uint8), mode="RGBA")


def apply_medallion_backdrop(
    face_im: Image.Image,
    inner_rgb: tuple[int, int, int],
    outer_rgb: tuple[int, int, int],
) -> Image.Image:
    """Frame a 192x192 portrait bust inside the exact circular medallion style as Velmira."""
    P = face_im.width
    out = Image.new("RGBA", (P, P), (0, 0, 0, 0))
    bg = Image.new("RGBA", (P, P), (0, 0, 0, 0))
    bg_px = bg.load()
    c = (P - 1) * 0.5
    max_r = P * 0.485
    for y in range(P):
        for x in range(P):
            dist = math.hypot(x - c, y - c)
            if dist <= max_r:
                t = dist / max_r
                r = int(inner_rgb[0] * (1.0 - t) + outer_rgb[0] * t)
                g = int(inner_rgb[1] * (1.0 - t) + outer_rgb[1] * t)
                b = int(inner_rgb[2] * (1.0 - t) + outer_rgb[2] * t)
                edge_a = 255 if dist <= max_r - 2.0 else int(255 * max(0.0, (max_r - dist) / 2.0))
                bg_px[x, y] = (r, g, b, edge_a)

    out.alpha_composite(bg, (0, 0))
    out.alpha_composite(face_im, (0, 0))

    opx = out.load()
    for y in range(P):
        for x in range(P):
            dist = math.hypot(x - c, y - c)
            if dist > max_r:
                opx[x, y] = (0, 0, 0, 0)
            elif dist > max_r - 2.0:
                r, g, b, a = opx[x, y]
                ma = int(a * max(0.0, (max_r - dist) / 2.0))
                opx[x, y] = (r, g, b, ma)
    return out
