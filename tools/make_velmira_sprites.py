#!/usr/bin/env python3
"""
tools/make_velmira_sprites.py

Generates Velmira's sprites & 100% hand-crafted Dark-Fantasy Pixel-Art Blood VFX:
  1. `assets/textures/player_shabnam.png` (`1792 x 1120` = 8 cols x 5 rows of `224x224`, 40 frames):
       - Clean character sprites ONLY (ZERO baked AI splash clouds, ZERO square cutoffs!)
       - Strictly uniform character body scale (`TARGET_BODY_H = 164 px` across all standing,
         walking, directional, and attack poses — Velmira NEVER shrinks!)
       - Upright regal side walk (`3..8`: upright-posture-corrected stride cycle `w0..w3..w1`
         with baked floor shadow stripped so she walks tall & vertical — ZERO forward-falling!)
       - `die` (`32..39`): clean 3-stage collapse (`die0..die2`) followed by a 100% hand-crafted
         organic swirling crimson blood-pool dissolve (`die3..die7`).
  2. `assets/textures/portrait_shabnam.png` (`960 x 192` = 5 standalone `192x192` circular-framed states)
  3. `assets/textures/velmira_fx.png` (`1024 x 128` = 8 frames of native `128x128` 100% HAND-CRAFTED
     Dark-Fantasy Pixel-Art Blood VFX — ZERO pixels copied from any reference image!):
       - `0..2`: 3-frame Animated Sweeping Liquid Crimson Crescent Slash
       - `3..4`: 2-frame Animated Swirling Double-Crescent Vampire Claw Finisher
       - `5..7`: 3-frame Animated Organic Ground Crimson Blood Geyser Eruption
  4. `assets/textures/crimson_bat.png` (`72 x 24` = 3 frames of `24x24` classic pixel-art Vampire Bats)
  5. `docs/images/velmira_preview.png` (visual verification sheet)
"""

from __future__ import annotations
from collections import deque
import math
from pathlib import Path
import sys

for extra in ("/tmp/pydeps",):
    if Path(extra).exists() and extra not in sys.path:
        sys.path.insert(0, extra)

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
REF_PATH = ROOT / "assets/sprites/vampire/velmira_reference.png"
OUT_HERO = ROOT / "assets/textures/player_shabnam.png"
OUT_PORTRAIT = ROOT / "assets/textures/portrait_shabnam.png"
OUT_FX = ROOT / "assets/textures/velmira_fx.png"
OUT_BAT = ROOT / "assets/textures/crimson_bat.png"
OUT_PREVIEW = ROOT / "docs/images/velmira_preview.png"

CELL = 224
COLS = 8
ROWS = 5
GROUND_Y = 200
TARGET_BODY_H = 164

# 6-tone Gothic Vampire Blood Pixel-Art Palette (100% hand-crafted VFX!)
C_OUTLINE = (22, 3, 8, 245)       # Crisp 1px dark-wine pixel outline
C_ABYSS   = (66, 5, 19, 255)      # Deepest claret shadow
C_CRIMSON = (136, 11, 36, 255)    # Arterial crimson body
C_SCARLET = (216, 22, 58, 255)    # Vivid vampire scarlet
C_RUBY    = (255, 68, 102, 255)   # Bright ruby highlight
C_CORE    = (255, 220, 230, 255)  # Razor hot pale-rose specular core


def _trim_rgba(im: Image.Image, min_a: int = 28) -> Image.Image:
    w, h = im.size
    px = im.load()
    minx, miny, maxx, maxy = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > min_a:
                if x < minx: minx = x
                if x > maxx: maxx = x
                if y < miny: miny = y
                if y > maxy: maxy = y
    if maxx < minx:
        return Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    return im.crop((minx, miny, maxx + 1, maxy + 1))


def clean_character_crop(
    ref: Image.Image,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    strip_detached_red: bool = False,
    strip_floor_shadow: bool = False,
    upright_deg: float = 0.0,
) -> Image.Image:
    """Crops a clean character pose, strips stray specks & floor shadow streaks, and optionally uprights lean."""
    im = ref.crop((x0, y0, x1, y1)).copy()
    w, h = im.size
    px = im.load()

    if strip_detached_red:
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a > 0 and r > 80 and g < 38 and b < 52 and (r - max(g, b)) > 52:
                    if x > int(w * 0.68) and y < int(h * 0.45):
                        px[x, y] = (0, 0, 0, 0)

    # Remove tiny disconnected specks (< 48 px)
    vis = [[False] * w for _ in range(h)]
    for sy in range(h):
        for sx in range(w):
            if not vis[sy][sx] and px[sx, sy][3] > 28:
                comp = []
                q = deque([(sx, sy)])
                vis[sy][sx] = True
                while q:
                    cx, cy = q.popleft()
                    comp.append((cx, cy))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            if dx == 0 and dy == 0:
                                continue
                            nx, ny = cx + dx, cy + dy
                            if 0 <= nx < w and 0 <= ny < h and not vis[ny][nx] and px[nx, ny][3] > 28:
                                vis[ny][nx] = True
                                q.append((nx, ny))
                if len(comp) < 48:
                    for cx, cy in comp:
                        px[cx, cy] = (0, 0, 0, 0)
            elif px[sx, sy][3] <= 28:
                px[sx, sy] = (0, 0, 0, 0)

    im = _trim_rgba(im, 28)

    if strip_floor_shadow:
        # Strip flat black shadow smear under boots (`y >= h - 5` where pure near-black shadow extends horizontally)
        sw, sh = im.size
        spx = im.load()
        for y in range(max(0, sh - 5), sh):
            for x in range(sw):
                r, g, b, a = spx[x, y]
                if a > 0 and r < 24 and g < 20 and b < 26:
                    # Keep boot sole pixels that have non-black boot leather right above them
                    above_colored = False
                    for ay in range(max(0, y - 5), y):
                        ar, ag, ab, aa = spx[x, ay]
                        if aa > 90 and (ar >= 26 or ag >= 22 or ab >= 28):
                            above_colored = True
                            break
                    if not above_colored:
                        spx[x, y] = (0, 0, 0, 0)
        im = _trim_rgba(im, 28)

    if abs(upright_deg) > 0.1:
        im = im.rotate(upright_deg, resample=Image.BICUBIC, expand=True)
        im = _trim_rgba(im, 36)

    return im


def resize_to_height(im: Image.Image, target_h: int) -> Image.Image:
    s = target_h / float(max(im.height, 1))
    nw = max(1, int(round(im.width * s)))
    return im.resize((nw, target_h), Image.LANCZOS)


def compute_torso_x(im: Image.Image) -> float:
    w, h = im.size
    px = im.load()
    xs = []
    y0 = int(h * 0.14)
    y1 = max(y0 + 1, int(h * 0.68))
    for y in range(y0, y1):
        for x in range(w):
            if px[x, y][3] >= 110:
                xs.append(x)
    if not xs:
        return w * 0.5
    xs.sort()
    return float(xs[len(xs) // 2])


def compute_boot_bottom_y(im: Image.Image) -> int:
    w, h = im.size
    px = im.load()
    for y in range(h - 1, -1, -1):
        hits = 0
        for x in range(w):
            if px[x, y][3] >= 96:
                hits += 1
        if hits >= 2:
            return y
    return h - 1


def place_grounded(
    im: Image.Image,
    target_h: int = TARGET_BODY_H,
    dx: int = 0,
    dy: int = 0,
    center_x_box: bool = False,
) -> Image.Image:
    im_s = resize_to_height(im, target_h)
    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    cx = (im_s.width * 0.5) if center_x_box else compute_torso_x(im_s)
    boot_y = compute_boot_bottom_y(im_s)
    px_x = int(round(CELL * 0.5 - cx)) + dx
    px_y = (GROUND_Y - boot_y) + dy
    px_x = max(2, min(CELL - im_s.width - 2, px_x))
    px_y = max(2, min(CELL - im_s.height - 2, px_y))
    canvas.alpha_composite(im_s, (px_x, px_y))
    return canvas


def add_ruby_cast_glint(cell: Image.Image, hand_xy: tuple[int, int]) -> Image.Image:
    out = cell.copy()
    hx, hy = hand_xy
    d = ImageDraw.Draw(out)
    for x, y in [
        (hx + 4, hy), (hx - 4, hy), (hx, hy - 4), (hx, hy + 4),
        (hx + 2, hy - 2), (hx + 2, hy + 2), (hx - 2, hy - 2), (hx - 2, hy + 2),
    ]:
        d.rectangle([x, y, x + 1, y + 1], fill=C_RUBY)
    for x, y in [(hx, hy), (hx + 2, hy), (hx, hy - 2), (hx, hy + 2), (hx - 2, hy)]:
        d.rectangle([x, y, x + 1, y + 1], fill=C_CORE)
    return out


# ==============================================================================
# 100% HAND-CRAFTED NATIVE 128x128 ORGANIC PIXEL-ART BLOOD VFX ENGINE!
# ==============================================================================

def _new_grid(size: int = 128) -> list[list[int]]:
    return [[0] * size for _ in range(size)]


def _disc(grid: list[list[int]], cx: float, cy: float, r: float, val: int) -> None:
    if r <= 0.18:
        return
    n = len(grid)
    ir = int(math.ceil(r + 1))
    icx, icy = int(round(cx)), int(round(cy))
    r2 = r * r
    for y in range(max(1, icy - ir), min(n - 1, icy + ir + 1)):
        for x in range(max(1, icx - ir), min(n - 1, icx + ir + 1)):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r2:
                if val > grid[y][x]:
                    grid[y][x] = val


def _organic_crescent_blade(
    grid: list[list[int]],
    cx: float,
    cy: float,
    rx: float,
    ry: float,
    a0_deg: float,
    a1_deg: float,
    max_w: float,
    tilt_deg: float = 0.0,
    with_core: bool = True,
    steps: int = 220,
) -> None:
    """Sculpts a liquid dark-fantasy crescent blood wave with razor tips & inner specular gleam."""
    a0 = math.radians(a0_deg)
    a1 = math.radians(a1_deg)
    ct = math.cos(math.radians(tilt_deg))
    st = math.sin(math.radians(tilt_deg))
    for i in range(steps + 1):
        t = i / float(steps)
        ang = a0 + (a1 - a0) * t
        # Asymmetric liquid wave profile (fuller near leading belly, needle-sharp tips!)
        prof = math.sin(math.pi * (t ** 0.86)) * (0.88 + 0.14 * math.sin(t * math.pi * 5.0))
        w = max_w * max(0.0, prof)
        if w < 0.45:
            continue
        lx = math.cos(ang) * rx
        ly = math.sin(ang) * ry
        px = cx + lx * ct - ly * st
        py = cy + lx * st + ly * ct
        nx = math.cos(ang) * ct - math.sin(ang) * st
        ny = math.cos(ang) * st + math.sin(ang) * ct

        _disc(grid, px, py, w, 1)
        _disc(grid, px + nx * (w * 0.16), py + ny * (w * 0.16), w * 0.80, 2)
        if w >= 1.3:
            _disc(grid, px + nx * (w * 0.28), py + ny * (w * 0.28), w * 0.58, 3)
        if w >= 2.0:
            _disc(grid, px + nx * (w * 0.40), py + ny * (w * 0.40), w * 0.36, 4)
        if with_core and w >= 2.8 and 0.18 <= t <= 0.82:
            _disc(grid, px + nx * (w * 0.48), py + ny * (w * 0.48), max(0.85, w * 0.20), 5)


def _organic_s_plume(
    grid: list[list[int]],
    x0: float,
    y0: float,
    dir_deg: float,
    length: float,
    base_w: float,
    curl_deg: float = 28.0,
    s_wave: float = 16.0,
    with_core: bool = False,
) -> None:
    """Sculpts an S-curving liquid blood ribbon/plume that curls organically like real splashed blood!"""
    steps = max(24, int(length * 2.4))
    cx, cy = x0, y0
    ds = length / float(steps)
    for i in range(steps + 1):
        t = i / float(steps)
        ang = math.radians(dir_deg + curl_deg * (t ** 1.25) + s_wave * math.sin(t * math.pi * 2.0))
        cx += math.cos(ang) * ds
        cy += math.sin(ang) * ds
        w = base_w * ((1.0 - t) ** 1.08)
        if w < 0.42:
            break
        _disc(grid, cx, cy, w, 1)
        _disc(grid, cx, cy, w * 0.80, 2 if t > 0.72 else 3)
        if w >= 1.5:
            _disc(grid, cx, cy, w * 0.50, 4)
        if with_core and w >= 2.4 and t < 0.52:
            _disc(grid, cx, cy, w * 0.25, 5)


def _liquid_droplet(
    grid: list[list[int]],
    x: float,
    y: float,
    dir_deg: float,
    r: float = 2.4,
) -> None:
    """Draws a smooth teardrop blood droplet (NO blocky '+' crosses!)."""
    ang = math.radians(dir_deg)
    _disc(grid, x, y, r, 2)
    _disc(grid, x + math.cos(ang) * 0.35, y + math.sin(ang) * 0.35, r * 0.74, 3)
    if r >= 1.8:
        _disc(grid, x + math.cos(ang) * 0.65, y + math.sin(ang) * 0.65, r * 0.42, 4)
    for k in range(1, 7):
        f = k / 6.0
        tx = x - math.cos(ang) * (r * 2.1 * f)
        ty = y - math.sin(ang) * (r * 2.1 * f)
        tr = r * (1.0 - 0.82 * f)
        if tr >= 0.55:
            _disc(grid, tx, ty, tr, 2 if f > 0.5 else 3)


def _puddle_vortex(
    grid: list[list[int]],
    cx: float,
    cy: float,
    rx: float,
    ry: float,
    hollow_ring: bool = False,
) -> None:
    """Draws a glossy multi-toned dark-blood puddle with swirling scarlet highlights."""
    n = len(grid)
    for y in range(max(1, int(cy - ry - 3)), min(n - 1, int(cy + ry + 4))):
        for x in range(max(1, int(cx - rx - 3)), min(n - 1, int(cx + rx + 4))):
            dx = (x - cx) / max(rx, 0.5)
            dy = (y - cy) / max(ry, 0.5)
            d = math.hypot(dx, dy)
            if d > 1.0:
                continue
            if hollow_ring and d < 0.48:
                grid[y][x] = max(grid[y][x], 1)
                continue
            swirl = 0.08 * math.sin(math.atan2(dy, dx) * 3.0 + d * 6.0)
            de = d + swirl
            if de > 0.82:
                val = 1
            elif de > 0.56:
                val = 2
            elif de > 0.30:
                val = 3
            else:
                val = 4
            grid[y][x] = max(grid[y][x], val)


def _grid_to_image(grid: list[list[int]]) -> Image.Image:
    """Renders native pixel grid with a crisp 1px dark-claret outline."""
    n = len(grid)
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = im.load()
    pal = {1: C_ABYSS, 2: C_CRIMSON, 3: C_SCARLET, 4: C_RUBY, 5: C_CORE}
    for y in range(n):
        for x in range(n):
            v = grid[y][x]
            if v > 0:
                px[x, y] = pal[v]
            elif (
                (x > 0 and grid[y][x - 1] > 0)
                or (x + 1 < n and grid[y][x + 1] > 0)
                or (y > 0 and grid[y - 1][x] > 0)
                or (y + 1 < n and grid[y + 1][x] > 0)
            ):
                px[x, y] = C_OUTLINE
    return im


def build_handcrafted_velmira_fx() -> Image.Image:
    """Builds 8 native 128x128 organic Dark-Fantasy Pixel-Art Blood VFX frames (ZERO reference pixels!)."""
    strip = Image.new("RGBA", (128 * 8, 128), (0, 0, 0, 0))

    # --- FRAME 0: Crescent Blood-Slash Ignite (fast razor upper-to-front sweep) ---
    g0 = _new_grid(128)
    _organic_crescent_blade(g0, 34, 64, 54, 46, -92, 38, 6.2, with_core=True)
    _organic_crescent_blade(g0, 30, 64, 40, 35, -72, 20, 3.0, with_core=False)
    for ang, ln, bw, curl in [(-52, 20, 3.2, 26), (-18, 24, 3.6, 22), (14, 18, 2.8, 20)]:
        rad = math.radians(ang)
        _organic_s_plume(g0, 34 + math.cos(rad) * 53, 64 + math.sin(rad) * 45, ang + 20, ln, bw, curl, 12)
    for dx, dy, da, dr in [(92, 30, -24, 2.5), (104, 52, 8, 2.8), (98, 76, 28, 2.2)]:
        _liquid_droplet(g0, dx, dy, da, dr)
    strip.alpha_composite(_grid_to_image(g0), (0, 0))

    # --- FRAME 1: Peak Swirling Serrated Crimson Blood Crescent ---
    g1 = _new_grid(128)
    _organic_crescent_blade(g1, 30, 64, 60, 50, -98, 98, 8.2, with_core=True)
    _organic_crescent_blade(g1, 26, 64, 43, 37, -80, 80, 4.0, with_core=True)
    for ang, ln, bw, curl in [
        (-70, 18, 2.8, 24), (-44, 24, 3.8, 26), (-18, 28, 4.4, 22),
        (8, 29, 4.5, 20), (34, 25, 3.9, 24), (60, 20, 3.2, 26), (82, 14, 2.4, 22),
    ]:
        rad = math.radians(ang)
        _organic_s_plume(g1, 30 + math.cos(rad) * 59, 64 + math.sin(rad) * 49, ang + 20, ln, bw, curl, 14, with_core=(abs(ang) < 25))
    for dx, dy, da, dr in [
        (88, 16, -42, 2.4), (108, 34, -20, 2.9), (116, 60, 4, 3.2),
        (112, 86, 24, 2.9), (94, 106, 46, 2.5), (70, 114, 66, 2.0),
    ]:
        _liquid_droplet(g1, dx, dy, da, dr)
    strip.alpha_composite(_grid_to_image(g1), (128, 0))

    # --- FRAME 2: Liquid Ribbon Trail & Crimson Droplet Spray ---
    g2 = _new_grid(128)
    _organic_crescent_blade(g2, 38, 64, 63, 52, -82, 86, 4.2, with_core=False)
    _organic_crescent_blade(g2, 34, 64, 48, 40, -52, 58, 2.5, with_core=False)
    for ang, ln, bw in [(-36, 18, 2.8), (4, 22, 3.2), (42, 18, 2.8)]:
        rad = math.radians(ang)
        _organic_s_plume(g2, 38 + math.cos(rad) * 62, 64 + math.sin(rad) * 51, ang + 22, ln, bw, 22, 12)
    for dx, dy, da, dr in [
        (96, 20, -36, 2.3), (114, 40, -14, 2.8), (120, 66, 6, 3.0),
        (114, 90, 24, 2.7), (96, 110, 44, 2.3), (78, 34, -24, 2.0), (80, 92, 28, 2.0),
    ]:
        _liquid_droplet(g2, dx, dy, da, dr)
    strip.alpha_composite(_grid_to_image(g2), (128 * 2, 0))

    # --- FRAME 3: Swirling Double-Crescent Vampire Claw Finisher (Peak) ---
    g3 = _new_grid(128)
    _organic_crescent_blade(g3, 28, 64, 62, 46, -88, 88, 6.8, tilt_deg=-22.0, with_core=True)
    _organic_crescent_blade(g3, 28, 64, 62, 46, -88, 88, 6.8, tilt_deg=22.0, with_core=True)
    _organic_crescent_blade(g3, 22, 64, 48, 38, -64, 64, 4.4, tilt_deg=0.0, with_core=True)
    for ang, ln, bw, curl in [(-34, 26, 3.8, -18), (0, 30, 4.6, 8), (34, 26, 3.8, 18)]:
        rad = math.radians(ang)
        _organic_s_plume(g3, 28 + math.cos(rad) * 58, 64 + math.sin(rad) * 42, ang, ln, bw, curl, 14, with_core=True)
    for dx, dy, da, dr in [
        (106, 24, -28, 2.8), (118, 64, 0, 3.2), (106, 104, 28, 2.8),
        (76, 14, -48, 2.3), (76, 114, 48, 2.3),
    ]:
        _liquid_droplet(g3, dx, dy, da, dr)
    strip.alpha_composite(_grid_to_image(g3), (128 * 3, 0))

    # --- FRAME 4: Double-Crescent Liquid Splash Dispersion ---
    g4 = _new_grid(128)
    _organic_crescent_blade(g4, 26, 64, 58, 48, -88, 88, 4.6, with_core=True)
    for ang, ln, bw, curl in [
        (-56, 22, 3.2, -20), (-28, 25, 3.6, -12), (0, 27, 4.0, 10),
        (28, 25, 3.6, 12), (56, 22, 3.2, 20),
    ]:
        rad = math.radians(ang)
        _organic_s_plume(g4, 26 + math.cos(rad) * 57, 64 + math.sin(rad) * 47, ang, ln, bw, curl, 12)
    for dx, dy, da, dr in [
        (102, 18, -38, 2.5), (116, 42, -16, 2.8), (120, 64, 0, 3.0),
        (116, 86, 16, 2.8), (102, 110, 38, 2.5),
    ]:
        _liquid_droplet(g4, dx, dy, da, dr)
    strip.alpha_composite(_grid_to_image(g4), (128 * 4, 0))

    # --- FRAME 5: Ground Crimson Blood Seal & Initial Swirling Surge (4-stack Curse!) ---
    g5 = _new_grid(128)
    _puddle_vortex(g5, 64, 106, 40, 9, hollow_ring=False)
    _organic_s_plume(g5, 64, 106, -90, 56, 6.4, curl_deg=6, s_wave=10, with_core=True)
    _organic_s_plume(g5, 52, 106, -104, 36, 4.4, curl_deg=-22, s_wave=12, with_core=True)
    _organic_s_plume(g5, 76, 106, -76, 36, 4.4, curl_deg=22, s_wave=-12, with_core=True)
    for dx, dy, da, dr in [(42, 68, -112, 2.5), (86, 68, -68, 2.5), (64, 36, -90, 2.7)]:
        _liquid_droplet(g5, dx, dy, da, dr)
    strip.alpha_composite(_grid_to_image(g5), (128 * 5, 0))

    # --- FRAME 6: Towering Organic Gothic Blood Geyser Peak! ---
    g6 = _new_grid(128)
    _puddle_vortex(g6, 64, 106, 52, 11, hollow_ring=False)
    # 7 fluid S-curving arterial geyser plumes curling naturally outward!
    _organic_s_plume(g6, 64, 106, -90, 92, 8.2, curl_deg=4, s_wave=11, with_core=True)
    _organic_s_plume(g6, 55, 106, -99, 76, 6.0, curl_deg=-20, s_wave=14, with_core=True)
    _organic_s_plume(g6, 73, 106, -81, 76, 6.0, curl_deg=20, s_wave=-14, with_core=True)
    _organic_s_plume(g6, 44, 106, -112, 56, 4.8, curl_deg=-30, s_wave=12, with_core=False)
    _organic_s_plume(g6, 84, 106, -68, 56, 4.8, curl_deg=30, s_wave=-12, with_core=False)
    _organic_s_plume(g6, 32, 106, -128, 36, 3.8, curl_deg=-34, s_wave=10, with_core=False)
    _organic_s_plume(g6, 96, 106, -52, 36, 3.8, curl_deg=34, s_wave=-10, with_core=False)
    for dx, dy, da, dr in [
        (64, 10, -90, 2.8), (38, 22, -116, 2.7), (90, 22, -64, 2.7),
        (22, 46, -135, 2.5), (106, 46, -45, 2.5), (16, 74, -150, 2.1), (112, 74, -30, 2.1),
    ]:
        _liquid_droplet(g6, dx, dy, da, dr)
    strip.alpha_composite(_grid_to_image(g6), (128 * 6, 0))

    # --- FRAME 7: Subsiding Swirling Blood Pool & Falling Scarlet Rain ---
    g7 = _new_grid(128)
    _puddle_vortex(g7, 64, 108, 54, 10.5, hollow_ring=True)
    _organic_s_plume(g7, 64, 108, -90, 44, 4.8, curl_deg=8, s_wave=12)
    _organic_s_plume(g7, 48, 108, -110, 30, 3.6, curl_deg=-26, s_wave=10)
    _organic_s_plume(g7, 80, 108, -70, 30, 3.6, curl_deg=26, s_wave=-10)
    for dx, dy, da, dr in [
        (64, 30, 90, 2.7), (40, 38, 102, 2.5), (88, 38, 78, 2.5),
        (24, 60, 108, 2.4), (104, 60, 72, 2.4), (32, 84, 96, 2.1), (96, 84, 84, 2.1),
    ]:
        _liquid_droplet(g7, dx, dy, da, dr)
    strip.alpha_composite(_grid_to_image(g7), (128 * 7, 0))

    return strip


def build_handcrafted_death_dissolve_frames(fallen_im: Image.Image) -> list[Image.Image]:
    """Builds frames 35..39 (`die_3..die_7`) using a fine 112x112 -> 224x224 organic swirling
    crimson blood pool & S-curved wisps (ZERO straight forks, ZERO AI puddle crops!)."""
    fallen_s = resize_to_height(fallen_im, 74)
    out_frames: list[Image.Image] = []

    for step in range(5):
        p = (step + 1) / 5.0
        cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))

        pg = _new_grid(112)
        puddle_rx = 30.0 + 18.0 * math.sin(p * math.pi * 0.72)
        puddle_ry = 5.2 + 3.6 * math.sin(p * math.pi * 0.75)
        cy_grid = 100
        _puddle_vortex(pg, 56, cy_grid, puddle_rx, puddle_ry, hollow_ring=(step == 4))

        if step <= 3:
            wisp_scale = math.sin((step + 1) / 4.3 * math.pi)
            for sx, ang, ln, bw, curl in [
                (40, -100, 26.0 * wisp_scale, 3.6, -24),
                (56, -90, 34.0 * wisp_scale, 4.4, 14),
                (72, -80, 25.0 * wisp_scale, 3.6, 24),
                (28, -114, 17.0 * wisp_scale, 2.8, -30),
                (84, -66, 17.0 * wisp_scale, 2.8, 30),
            ]:
                if ln >= 5.0:
                    _organic_s_plume(pg, sx, cy_grid, ang, ln, bw, curl_deg=curl, s_wave=12)

            for dx, dy, da in [(36, 74 - step * 4, -105), (56, 64 - step * 4, -90), (76, 75 - step * 4, -75)]:
                if dy > 42:
                    _liquid_droplet(pg, dx, dy, da, 2.1)

        puddle_224 = _grid_to_image(pg).resize((CELL, CELL), Image.NEAREST)

        if step < 4:
            sink_px = int(round(p * 56.0))
            body_crop_h = max(1, fallen_s.height - sink_px)
            sub_body = fallen_s.crop((0, 0, fallen_s.width, body_crop_h)).copy()
            spx = sub_body.load()
            fade = 1.0 - p * 0.55
            crimson_mix = p * 0.65
            for y in range(sub_body.height):
                edge_fade = min(1.0, max(0.15, (sub_body.height - 1 - y) / 14.0))
                for x in range(sub_body.width):
                    r, g, b, a = spx[x, y]
                    if a > 0:
                        nr = int(r * (1.0 - crimson_mix) + 165 * crimson_mix)
                        ng = int(g * (1.0 - crimson_mix) + 12 * crimson_mix)
                        nb = int(b * (1.0 - crimson_mix) + 38 * crimson_mix)
                        na = int(a * fade * edge_fade)
                        spx[x, y] = (min(255, nr), max(0, ng), max(0, nb), na)
            bx = (CELL - sub_body.width) // 2
            by = GROUND_Y - sub_body.height + 2
            cell.alpha_composite(puddle_224, (0, 0))
            cell.alpha_composite(sub_body, (bx, by))
            front_wisps = puddle_224.crop((0, 0, CELL, GROUND_Y - 4))
            cell.alpha_composite(front_wisps, (0, 0))
        else:
            cell.alpha_composite(puddle_224, (0, 0))

        out_frames.append(cell)

    return out_frames


def build_classic_crimson_bats() -> Image.Image:
    strip = Image.new("RGBA", (72, 24), (0, 0, 0, 0))
    OUTLINE = (24, 6, 14, 255)
    BODY = (62, 12, 28, 255)
    WING_DARK = (118, 16, 42, 255)
    WING_LIT = (212, 32, 68, 255)
    EYE = (255, 72, 96, 255)

    for idx, mode in enumerate(("up", "mid", "down")):
        cell = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
        d = ImageDraw.Draw(cell)
        cx, cy = 12, 12
        if mode == "up":
            l_wing = [(cx - 2, cy), (cx - 6, cy - 6), (cx - 10, cy - 8), (cx - 9, cy - 2), (cx - 5, cy + 1)]
            r_wing = [(cx + 2, cy), (cx + 6, cy - 6), (cx + 10, cy - 8), (cx + 9, cy - 2), (cx + 5, cy + 1)]
        elif mode == "mid":
            l_wing = [(cx - 2, cy - 1), (cx - 7, cy - 3), (cx - 11, cy - 1), (cx - 8, cy + 3), (cx - 4, cy + 2)]
            r_wing = [(cx + 2, cy - 1), (cx + 7, cy - 3), (cx + 11, cy - 1), (cx + 8, cy + 3), (cx + 4, cy + 2)]
        else:
            l_wing = [(cx - 2, cy - 1), (cx - 7, cy + 1), (cx - 10, cy + 7), (cx - 6, cy + 5), (cx - 3, cy + 2)]
            r_wing = [(cx + 2, cy - 1), (cx + 7, cy + 1), (cx + 10, cy + 7), (cx + 6, cy + 5), (cx + 3, cy + 2)]

        d.polygon(l_wing, fill=WING_DARK, outline=OUTLINE)
        d.polygon(r_wing, fill=WING_DARK, outline=OUTLINE)
        d.line([l_wing[0], l_wing[1], l_wing[2]], fill=WING_LIT, width=1)
        d.line([r_wing[0], r_wing[1], r_wing[2]], fill=WING_LIT, width=1)
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=BODY, outline=OUTLINE)
        cell.putpixel((cx - 2, cy - 4), OUTLINE)
        cell.putpixel((cx + 2, cy - 4), OUTLINE)
        cell.putpixel((cx - 1, cy - 1), EYE)
        cell.putpixel((cx + 1, cy - 1), EYE)
        strip.alpha_composite(cell, (idx * 24, 0))
    return strip


def _apply_circular_medallion_backdrop(face_im: Image.Image) -> Image.Image:
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
                r = int(34 * (1.0 - t) + 14 * t)
                g = int(12 * (1.0 - t) + 7 * t)
                b = int(26 * (1.0 - t) + 15 * t)
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


def build_portrait_strip(ref: Image.Image) -> Image.Image:
    P = 192
    base_raw = ref.crop((24, 14, 296, 286)).resize((P, P), Image.LANCZOS)
    strip = Image.new("RGBA", (P * 5, P), (0, 0, 0, 0))

    def is_iris(x: int, y: int, r: int, g: int, b: int) -> bool:
        in_left = (88 <= x <= 120 and 95 <= y <= 114)
        in_right = (130 <= x <= 154 and 100 <= y <= 120)
        return (in_left or in_right) and r > 105 and g < 78 and r > g + 42

    strip.alpha_composite(_apply_circular_medallion_backdrop(base_raw), (0, 0))

    b1 = base_raw.crop((2, 3, P - 2, P - 1)).resize((P, P), Image.LANCZOS)
    strip.alpha_composite(_apply_circular_medallion_backdrop(b1), (P, 0))

    f2 = base_raw.copy()
    px2 = f2.load()
    for y in range(93, 122):
        for x in range(86, 156):
            r, g, b, a = px2[x, y]
            if a > 180 and is_iris(x, y, r, g, b):
                px2[x, y] = (232, 204, 212, a)
    d2 = ImageDraw.Draw(f2)
    d2.line([(92, 107), (105, 109), (117, 108)], fill=(48, 20, 34, 245), width=2)
    d2.line([(134, 112), (142, 114), (150, 113)], fill=(48, 20, 34, 245), width=2)
    strip.alpha_composite(_apply_circular_medallion_backdrop(f2), (P * 2, 0))

    f3 = base_raw.copy()
    px3 = f3.load()
    for y in range(P):
        for x in range(P):
            r, g, b, a = px3[x, y]
            if a < 20:
                continue
            if is_iris(x, y, r, g, b):
                px3[x, y] = (min(255, int(r * 1.35 + 38)), max(0, int(g * 0.40)), max(0, int(b * 0.48)), a)
            else:
                dist = math.hypot((x - P * 0.54) / (P * 0.5), (y - P * 0.50) / (P * 0.5))
                vign = min(0.42, max(0.0, (dist - 0.34) * 0.60))
                nr = int(r * (1.0 - vign * 0.30) + 150 * vign * 0.30)
                ng = int(g * (1.0 - vign * 0.62))
                nb = int(b * (1.0 - vign * 0.48) + 42 * vign * 0.20)
                px3[x, y] = (min(255, nr), max(0, ng), max(0, nb), a)
    strip.alpha_composite(_apply_circular_medallion_backdrop(f3), (P * 3, 0))

    f4_rot = f2.rotate(-4.0, resample=Image.BICUBIC, expand=False)
    px4 = f4_rot.load()
    for y in range(P):
        for x in range(P):
            r, g, b, a = px4[x, y]
            if a < 20:
                continue
            px4[x, y] = (min(255, int(r * 1.12 + 24)), int(g * 0.84), int(b * 0.88), a)
    strip.alpha_composite(_apply_circular_medallion_backdrop(f4_rot), (P * 4, 0))

    return strip


def main() -> None:
    assert REF_PATH.exists(), f"Missing reference sheet: {REF_PATH}"
    ref = Image.open(REF_PATH).convert("RGBA")

    r2_idle       = clean_character_crop(ref, 343, 212, 482, 383)
    r1_side_a     = clean_character_crop(ref, 652, 14, 792, 196)
    r1_side_blink = clean_character_crop(ref, 1099, 15, 1239, 196)

    # Upright-posture-corrected regal side walk (`+6..+9.5 deg` CCW + floor shadow stripped -> 100% upright!)
    r2_w0 = clean_character_crop(ref, 491, 214, 635, 383, strip_floor_shadow=True, upright_deg=6.0)
    r2_w1 = clean_character_crop(ref, 645, 216, 798, 384, strip_floor_shadow=True, upright_deg=8.8)
    r2_w2 = clean_character_crop(ref, 815, 216, 958, 384, strip_floor_shadow=True, upright_deg=8.8)
    r2_w3 = clean_character_crop(ref, 968, 216, 1120, 384, strip_floor_shadow=True, upright_deg=9.5)

    r1_front_0    = clean_character_crop(ref, 345, 9, 483, 196)
    r1_front_step = clean_character_crop(ref, 497, 13, 639, 196)
    r1_front_step_mirror = r1_front_step.transpose(Image.FLIP_LEFT_RIGHT)
    r3_front_b    = clean_character_crop(ref, 6, 394, 131, 558)

    r1_back_a = clean_character_crop(ref, 954, 14, 1094, 196)
    r1_back_b = clean_character_crop(ref, 1250, 10, 1402, 196)
    r3_up_0   = clean_character_crop(ref, 140, 397, 270, 560)
    r3_up_1   = clean_character_crop(ref, 277, 397, 411, 560)
    r3_up_2   = clean_character_crop(ref, 421, 398, 539, 560)
    r4_up_3   = clean_character_crop(ref, 290, 590, 410, 741)

    atk_chamber = clean_character_crop(ref, 545, 403, 660, 559, strip_detached_red=True)
    atk_coil    = clean_character_crop(ref, 546, 588, 700, 738, strip_detached_red=True)
    atk_thrust  = clean_character_crop(ref, 1169, 396, 1308, 565, strip_detached_red=True)

    hurt_0 = clean_character_crop(ref, 138, 769, 245, 892)
    hurt_1 = clean_character_crop(ref, 251, 767, 360, 892)

    die_0 = clean_character_crop(ref, 369, 791, 518, 888)
    die_1 = clean_character_crop(ref, 677, 794, 832, 885)
    die_2 = clean_character_crop(ref, 1013, 816, 1177, 883)
    dissolve_frames = build_handcrafted_death_dissolve_frames(die_2)

    frames: list[Image.Image] = [
        place_grounded(r2_idle, TARGET_BODY_H),
        place_grounded(r1_side_a, TARGET_BODY_H),
        place_grounded(r1_side_blink, TARGET_BODY_H),

        place_grounded(r2_w0, TARGET_BODY_H),
        place_grounded(r2_w1, TARGET_BODY_H),
        place_grounded(r2_w2, TARGET_BODY_H),
        place_grounded(r2_w3, TARGET_BODY_H),
        place_grounded(r2_w2, TARGET_BODY_H),
        place_grounded(r2_w1, TARGET_BODY_H),

        place_grounded(r1_front_0, TARGET_BODY_H, center_x_box=True),
        place_grounded(r3_front_b, TARGET_BODY_H, center_x_box=True),

        place_grounded(r1_front_step, TARGET_BODY_H, center_x_box=True),
        place_grounded(r1_front_0, TARGET_BODY_H, center_x_box=True),
        place_grounded(r1_front_step_mirror, TARGET_BODY_H, center_x_box=True),
        place_grounded(r3_front_b, TARGET_BODY_H, center_x_box=True),

        place_grounded(r1_back_a, TARGET_BODY_H, center_x_box=True),
        place_grounded(r1_back_b, TARGET_BODY_H, center_x_box=True),

        place_grounded(r3_up_0, TARGET_BODY_H, center_x_box=True),
        place_grounded(r3_up_1, TARGET_BODY_H, center_x_box=True),
        place_grounded(r3_up_2, TARGET_BODY_H, center_x_box=True),
        place_grounded(r4_up_3, TARGET_BODY_H, center_x_box=True),

        place_grounded(atk_chamber, 160, dx=-2),
        place_grounded(atk_coil, 158, dx=-3),
        add_ruby_cast_glint(place_grounded(atk_thrust, TARGET_BODY_H, dx=4), (176, 118)),
        add_ruby_cast_glint(place_grounded(atk_thrust, TARGET_BODY_H, dx=6), (180, 118)),
        place_grounded(r2_w0, TARGET_BODY_H, dx=1),

        place_grounded(atk_coil, 158, dx=-4),
        place_grounded(atk_chamber, 160, dx=0),
        add_ruby_cast_glint(place_grounded(atk_thrust, TARGET_BODY_H, dx=6), (180, 118)),
        place_grounded(r1_side_a, TARGET_BODY_H, dx=2),

        place_grounded(hurt_0, 146, dx=-2),
        place_grounded(hurt_1, 146, dx=-4),

        place_grounded(die_0, 108, center_x_box=True),
        place_grounded(die_1, 100, center_x_box=True),
        place_grounded(die_2, 74, center_x_box=True),
        *dissolve_frames,
    ]
    assert len(frames) == 40, f"Expected 40 frames, got {len(frames)}"

    sheet = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for idx, frm in enumerate(frames):
        col = idx % COLS
        row = idx // COLS
        sheet.alpha_composite(frm, (col * CELL, row * CELL))
    OUT_HERO.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT_HERO)

    portrait_strip = build_portrait_strip(ref)
    portrait_strip.save(OUT_PORTRAIT)

    fx_strip = build_handcrafted_velmira_fx()
    fx_strip.save(OUT_FX)

    bat_strip = build_classic_crimson_bats()
    bat_strip.save(OUT_BAT)

    prev_w, prev_h = 1520, 1020
    prev = Image.new("RGBA", (prev_w, prev_h), (26, 22, 32, 255))
    pd = ImageDraw.Draw(prev)

    for i in range(5):
        pf = portrait_strip.crop((i * 192, 0, (i + 1) * 192, 192)).resize((104, 104), Image.LANCZOS)
        px = 18 + i * 116
        py = 16
        prev.alpha_composite(pf, (px, py))
        pd.ellipse((px - 2, py - 2, px + 106, py + 106), outline=(225, 184, 88, 255), width=2)

    for i in range(8):
        ff = fx_strip.crop((i * 128, 0, (i + 1) * 128, 128)).resize((86, 86), Image.NEAREST)
        fx_x = 615 + i * 92
        prev.alpha_composite(ff, (fx_x, 22))
        pd.text((fx_x + 22, 112), f"fx{i}", fill=(245, 160, 180, 255))
    prev.alpha_composite(bat_strip.resize((162, 54), Image.NEAREST), (1352, 38))

    labels = [
        "0:idle0", "1:idle1", "2:idle2", "3:walk0", "4:walk1", "5:walk2", "6:walk3", "7:walk4",
        "8:walk5", "9:down_i0", "10:down_i1", "11:down_w0", "12:down_w1", "13:down_w2", "14:down_w3", "15:up_i0",
        "16:up_i1", "17:up_w0", "18:up_w1", "19:up_w2", "20:up_w3", "21:atk1_0", "22:atk1_1", "23:atk1_2",
        "24:atk1_3", "25:atk1_4", "26:atk2_0", "27:atk2_1", "28:atk2_2", "29:atk2_3", "30:hurt0", "31:hurt1",
        "32:die0", "33:die1", "34:die2", "35:die3", "36:die4", "37:die5", "38:die6", "39:die7",
    ]
    for idx, frm in enumerate(frames):
        col = idx % 10
        row = idx // 10
        x = 18 + col * 148
        y = 148 + row * 214
        thumb = frm.resize((136, 136), Image.LANCZOS)
        gy = y + int(round(GROUND_Y * (136.0 / CELL)))
        ty = y + int(round((GROUND_Y - TARGET_BODY_H) * (136.0 / CELL)))
        pd.line([(x + 12, gy), (x + 124, gy)], fill=(90, 210, 130, 120), width=1)
        if idx < 30:
            pd.line([(x + 12, ty), (x + 124, ty)], fill=(210, 140, 90, 80), width=1)
        prev.alpha_composite(thumb, (x, y))
        pd.text((x + 28, y + 146), labels[idx], fill=(224, 216, 232, 255))

    OUT_PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    prev.save(OUT_PREVIEW)
    print(f"Wrote {OUT_HERO} ({sheet.size})")
    print(f"Wrote {OUT_PORTRAIT} ({portrait_strip.size})")
    print(f"Wrote {OUT_FX} ({fx_strip.size})")
    print(f"Wrote {OUT_BAT} ({bat_strip.size})")
    print(f"Wrote {OUT_PREVIEW} ({prev.size})")


if __name__ == "__main__":
    main()
