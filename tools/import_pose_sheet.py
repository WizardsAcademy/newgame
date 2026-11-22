#!/usr/bin/env python3
"""Import hand-drawn 96x96 hero pose art on white backgrounds into game-ready sheets.

Designed to be reusable across heroes (`art_src/<hero>/*.png` -> `assets/textures/`).

Pipeline:
  Step 1 — Background key-out:
           4-connected border flood-fill (`tolerance = 42`), NEVER a global
           brightness threshold, so interior white/silver highlights survive.
           Pre-cleans cell-border crop lines and neutral bottom floor-shadow bars,
           isolates the primary character component, and pops enclosed near-white
           background pockets inside outer hair loops.
  Step 2 — 1px ring de-fringe:
           On the 1px foreground ring 4-adjacent to background, drops pixels with
           `luminance > 190` and `saturation < 20`. Prints killed pixel counts.
  Step 3 — Perceptual palette snap:
           Premultiplied-alpha area scale to spec `body_h` anchored at `GROUND_Y = 80`,
           then CIE Lab nearest-perceptual match + 2x2 ordered Bayer dither onto a
           <= 24-colour subset of `tools/hero_art_lib.py` `RAMPS` (never median-cut).
  Step 4 — Contract assertions:
           Binary alpha (`0` or `255`), `<= 24` colours, zero `#000000`,
           every frame grounded at `GROUND_Y = 80`, and standing `body_h` within spec.

Usage:
    python3 tools/import_pose_sheet.py                  # builds velmira by default
    python3 tools/import_pose_sheet.py --hero velmira
"""

from __future__ import annotations

import argparse
from collections import deque
import math
from pathlib import Path
import sys

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.hero_art_lib import CELL, GROUND_Y, RAMPS  # noqa: E402

BAYER_2X2: tuple[tuple[int, int], tuple[int, int]] = ((0, 2), (3, 1))

HERO_PRESETS: dict[str, dict] = {
    "velmira": {
        "src_dir": REPO_ROOT / "art_src" / "velmira",
        "out_sheet": REPO_ROOT / "assets" / "textures" / "player_velmira.png",
        "out_portrait": REPO_ROOT / "assets" / "textures" / "portrait_velmira.png",
        "preview": REPO_ROOT / "docs" / "images" / "velmira_import_preview.png",
        "ramps": ("moon", "obsidian", "crimson", "skin", "gold", "leather"),
        "target_body_h": 65,
        "body_h_bounds": (62, 68),
        "ground_y": GROUND_Y,
        "tolerance": 42,
    },
}


# ---------------------------------------------------------------------------
# Colour space & perceptual + 2x2 Bayer palette snapper (Step 3)
# ---------------------------------------------------------------------------

def _srgb_to_lab(r: int, g: int, b: int) -> tuple[float, float, float]:
    def _lin(v: int) -> float:
        fv = v / 255.0
        return fv / 12.92 if fv <= 0.04045 else ((fv + 0.055) / 1.055) ** 2.4

    rl, gl, bl = _lin(r), _lin(g), _lin(b)
    x = (0.4124564 * rl + 0.3575761 * gl + 0.1804375 * bl) / 0.95047
    y = 0.2126729 * rl + 0.7151522 * gl + 0.0721750 * bl
    z = (0.0193339 * rl + 0.1191920 * gl + 0.9503041 * bl) / 1.08883

    def _f(t: float) -> float:
        return t ** (1.0 / 3.0) if t > 0.008856 else (7.787 * t + 16.0 / 116.0)

    fx, fy, fz = _f(x), _f(y), _f(z)
    return (116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


def build_hero_palette(ramp_names: tuple[str, ...]) -> list[tuple[int, int, int]]:
    pal: list[tuple[int, int, int]] = []
    seen: set[tuple[int, int, int]] = set()
    for rname in ramp_names:
        if rname not in RAMPS:
            raise ValueError(f"Unknown ramp {rname!r}; expected one of {sorted(RAMPS)}")
        for col in RAMPS[rname]:
            rgb = (int(col[0]), int(col[1]), int(col[2]))
            if rgb not in seen:
                seen.add(rgb)
                pal.append(rgb)
    if len(pal) > 24:
        raise ValueError(f"Hero palette exceeds 24 colours ({len(pal)})")
    if (0, 0, 0) in seen:
        raise ValueError("Hero palette must not contain #000000")
    return pal


class PerceptualBayerSnapper:
    """Nearest-perceptual (CIE Lab) + 2x2 Bayer ordered dither palette snapper."""

    def __init__(self, palette_rgb: list[tuple[int, int, int]], max_dither_gap: float = 28.0):
        self.palette = list(palette_rgb)
        self.pal_lab = [_srgb_to_lab(*c) for c in self.palette]
        self.max_dither_gap = max_dither_gap
        self._cache: dict[tuple[int, int, int, int, int], tuple[int, int, int]] = {}

    def snap_pixel(self, r: int, g: int, b: int, bx: int, by: int) -> tuple[int, int, int]:
        key = (r, g, b, bx, by)
        hit = self._cache.get(key)
        if hit is not None:
            return hit

        L, A, B = _srgb_to_lab(r, g, b)
        best_i1, best_d1 = 0, float("inf")
        best_i2, best_d2 = 0, float("inf")
        for idx, (pL, pA, pB) in enumerate(self.pal_lab):
            d = (L - pL) ** 2 + (A - pA) ** 2 + (B - pB) ** 2
            if d < best_d1:
                best_i2, best_d2 = best_i1, best_d1
                best_i1, best_d1 = idx, d
            elif d < best_d2:
                best_i2, best_d2 = idx, d

        sd1 = math.sqrt(best_d1)
        sd2 = math.sqrt(best_d2)
        p1 = self.pal_lab[best_i1]
        p2 = self.pal_lab[best_i2]
        pal_gap = math.sqrt(
            (p1[0] - p2[0]) ** 2 + (p1[1] - p2[1]) ** 2 + (p1[2] - p2[2]) ** 2
        )
        ratio = sd1 / max(sd1 + sd2, 1e-6)  # in [0.0, 0.5]
        thresh = (BAYER_2X2[by][bx] + 0.5) / 4.0  # 0.125, 0.375, 0.625, 0.875
        chosen = (
            self.palette[best_i2]
            if (pal_gap <= self.max_dither_gap and ratio > thresh * 0.85)
            else self.palette[best_i1]
        )
        self._cache[key] = chosen
        return chosen

    def snap_image(self, im: Image.Image) -> Image.Image:
        w, h = im.size
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ipx = im.load()
        opx = out.load()
        for y in range(h):
            by = y & 1
            for x in range(w):
                r, g, b, a = ipx[x, y]
                if a < 128:
                    continue
                rgb = self.snap_pixel(r, g, b, x & 1, by)
                opx[x, y] = (rgb[0], rgb[1], rgb[2], 255)
        return out


# ---------------------------------------------------------------------------
# Step 1 (Border flood-fill key-out) & Step 2 (1px ring de-fringe)
# ---------------------------------------------------------------------------

def _lum_sat(r: int, g: int, b: int) -> tuple[float, float]:
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    mx = max(r, g, b)
    mn = min(r, g, b)
    sat = (255.0 * (mx - mn) / mx) if mx > 0 else 0.0
    return lum, sat


def key_and_defringe_pose(
    path: Path,
    tolerance: int = 42,
    strip_ground_shadow: bool = True,
    pop_hair_pockets: bool = True,
    verbose: bool = True,
) -> tuple[Image.Image, int]:
    """Run Step 1 (border flood-fill) + Step 2 (1px ring de-fringe) on a source PNG."""
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    bg = [[False] * w for _ in range(h)]

    # Pre-clean 1..3px dark crop-frame lines at left/right cell edges.
    for x in (0, 1, w - 3, w - 2, w - 1):
        if 0 <= x < w:
            dark_rows = sum(1 for y in range(h) if max(px[x, y][:3]) < 35)
            if dark_rows > 60:
                for y in range(h):
                    bg[y][x] = True

    # Pre-clean neutral grey painted ground-shadow bars at bottom so flood-fill
    # can flow cleanly into the white space between the boots.
    if strip_ground_shadow:
        for y in range(max(0, h - 6), h):
            for x in range(w):
                r, g, b, _ = px[x, y]
                lum, sat = _lum_sat(r, g, b)
                if sat < 26.0 and lum > 72.0:
                    bg[y][x] = True

    def _within_white_tol(r: int, g: int, b: int, a: int) -> bool:
        if a == 0:
            return True
        return max(abs(255 - r), abs(255 - g), abs(255 - b)) <= tolerance

    # Step 1: 4-connected border flood-fill with `tolerance = 42`.
    q: deque[tuple[int, int]] = deque()
    for y in range(h):
        for x in range(w):
            is_seed_edge = x == 0 or x == w - 1 or y == 0 or y == h - 1 or bg[y][x]
            if not is_seed_edge:
                continue
            if not bg[y][x] and _within_white_tol(*px[x, y]):
                bg[y][x] = True
            if bg[y][x]:
                q.append((x, y))

    while q:
        cx, cy = q.popleft()
        for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
            if 0 <= nx < w and 0 <= ny < h and not bg[ny][nx]:
                if _within_white_tol(*px[nx, ny]):
                    bg[ny][nx] = True
                    q.append((nx, ny))

    # Keep largest 8-connected foreground component (strips neighbor crop slivers & labels).
    vis = [[False] * w for _ in range(h)]
    comps: list[list[tuple[int, int]]] = []
    for y in range(h):
        for x in range(w):
            if not bg[y][x] and not vis[y][x]:
                comp: list[tuple[int, int]] = []
                cq: deque[tuple[int, int]] = deque([(x, y)])
                vis[y][x] = True
                while cq:
                    ux, uy = cq.popleft()
                    comp.append((ux, uy))
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            if dx == 0 and dy == 0:
                                continue
                            vx, vy = ux + dx, uy + dy
                            if 0 <= vx < w and 0 <= vy < h and not bg[vy][vx] and not vis[vy][vx]:
                                vis[vy][vx] = True
                                cq.append((vx, vy))
                comps.append(comp)

    if comps:
        main_fg = set(max(comps, key=len))
        for y in range(h):
            for x in range(w):
                if (x, y) not in main_fg:
                    bg[y][x] = True

    # Pop enclosed background holes trapped inside outer hair-curl loops while
    # preserving all interior highlights on face/eyes/crown/lapels.
    if pop_hair_pockets and comps:
        xs_fg = [p[0] for p in main_fg]
        ys_fg = [p[1] for p in main_fg]
        mid_x = 0.5 * (min(xs_fg) + max(xs_fg))
        top_y = min(ys_fg)
        pvis = [[False] * w for _ in range(h)]
        for y in range(h):
            for x in range(w):
                if bg[y][x] or pvis[y][x]:
                    continue
                r0, g0, b0, _ = px[x, y]
                lum0, sat0 = _lum_sat(r0, g0, b0)
                if not (lum0 >= 238.0 and sat0 < 10.0):
                    continue
                pocket: list[tuple[int, int]] = []
                pq: deque[tuple[int, int]] = deque([(x, y)])
                pvis[y][x] = True
                while pq:
                    ux, uy = pq.popleft()
                    pocket.append((ux, uy))
                    for nx, ny in ((ux - 1, uy), (ux + 1, uy), (ux, uy - 1), (ux, uy + 1)):
                        if 0 <= nx < w and 0 <= ny < h and not bg[ny][nx] and not pvis[ny][nx]:
                            rn, gn, bn, _ = px[nx, ny]
                            lumn, satn = _lum_sat(rn, gn, bn)
                            if lumn >= 238.0 and satn < 10.0:
                                pvis[ny][nx] = True
                                pq.append((nx, ny))
                if len(pocket) >= 5:
                    pcx = sum(p[0] for p in pocket) / len(pocket)
                    pcy = sum(p[1] for p in pocket) / len(pocket)
                    # Never pop highlights inside the central face/bangs/collar core!
                    in_face_core = (abs(pcx - mid_x) < 12.0) and (top_y + 8 <= pcy <= top_y + 48)
                    if not in_face_core:
                        for px_x, px_y in pocket:
                            bg[px_y][px_x] = True

    # Step 2: 1px ring de-fringe adjacent to background (`luminance > 190` and `saturation < 20`).
    fringe_kills: list[tuple[int, int]] = []
    for y in range(h):
        for x in range(w):
            if bg[y][x]:
                continue
            adj_bg = (
                x == 0
                or x == w - 1
                or y == 0
                or y == h - 1
                or bg[y][x - 1]
                or bg[y][x + 1]
                or bg[y - 1][x]
                or bg[y + 1][x]
            )
            if not adj_bg:
                continue
            r, g, b, _ = px[x, y]
            lum, sat = _lum_sat(r, g, b)
            if lum > 190.0 and sat < 20.0:
                fringe_kills.append((x, y))

    for fx, fy in fringe_kills:
        bg[fy][fx] = True

    if verbose:
        print(f"  [de-fringe] {path.name:<20s}: killed {len(fringe_kills):3d} fringe pixels")

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    for y in range(h):
        for x in range(w):
            if not bg[y][x]:
                r, g, b, _ = px[x, y]
                opx[x, y] = (r, g, b, 255)
    return out, len(fringe_kills)


# ---------------------------------------------------------------------------
# Premultiplied-alpha scaling & pose placement helpers
# ---------------------------------------------------------------------------

def scale_premultiplied(
    crop: Image.Image,
    target_w: int,
    target_h: int,
    alpha_cutoff: float = 0.45,
) -> Image.Image:
    """Area-scale an RGBA crop in premultiplied space so transparent bg never bleeds."""
    w, h = crop.size
    pm_r = Image.new("F", (w, h), 0.0)
    pm_g = Image.new("F", (w, h), 0.0)
    pm_b = Image.new("F", (w, h), 0.0)
    pm_a = Image.new("F", (w, h), 0.0)
    px = crop.load()
    pr, pg, pb, pa = pm_r.load(), pm_g.load(), pm_b.load(), pm_a.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            af = a / 255.0
            pr[x, y] = r * af
            pg[x, y] = g * af
            pb[x, y] = b * af
            pa[x, y] = af

    resample = Image.Resampling.BOX
    sr = pm_r.resize((target_w, target_h), resample)
    sg = pm_g.resize((target_w, target_h), resample)
    sb = pm_b.resize((target_w, target_h), resample)
    sa = pm_a.resize((target_w, target_h), resample)

    out = Image.new("RGBA", (target_w, target_h), (0, 0, 0, 0))
    opx = out.load()
    lr, lg, lb, la = sr.load(), sg.load(), sb.load(), sa.load()
    for y in range(target_h):
        for x in range(target_w):
            af = la[x, y]
            if af >= alpha_cutoff:
                r = int(round(max(0.0, min(255.0, lr[x, y] / af))))
                g = int(round(max(0.0, min(255.0, lg[x, y] / af))))
                b = int(round(max(0.0, min(255.0, lb[x, y] / af))))
                opx[x, y] = (r, g, b, 255)
    return out


def place_pose_in_cell(
    cleaned: Image.Image,
    snapper: PerceptualBayerSnapper,
    target_h: int,
    ground_y: int = GROUND_Y,
    x_offset: int = 0,
    ensure_two_foot_stance: bool = False,
) -> Image.Image:
    bb = cleaned.getbbox()
    if bb is None:
        raise ValueError("Cannot place empty pose")
    crop = cleaned.crop(bb)
    cw, ch = crop.size
    tw = max(1, int(round(cw * (target_h / float(ch)))))
    scaled = scale_premultiplied(crop, tw, target_h)
    snapped = snapper.snap_image(scaled)

    # Guarantee exact top/bottom occupancy after alpha thresholding.
    sbb = snapped.getbbox()
    if sbb is None:
        raise ValueError("Scaled pose became empty")
    scrop = snapped.crop(sbb)
    sw, sh = scrop.size
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    dest_x = max(0, min(CELL - sw, (CELL - sw) // 2 + x_offset))
    dest_y = ground_y - sh
    cell.alpha_composite(scrop, (dest_x, dest_y))

    if ensure_two_foot_stance:
        # If trailing boot sole sits 1..2px above `ground_y - 1`, extend its heel
        # onto `ground_y - 1` so both boots plant cleanly on the ground line.
        cpx = cell.load()
        gy = ground_y - 1
        xs_gy = [x for x in range(CELL) if cpx[x, gy][3] > 0]
        xs_above = [
            x
            for y in (gy - 2, gy - 1)
            for x in range(CELL)
            if 0 <= y < CELL and cpx[x, y][3] > 0
        ]
        if xs_gy and xs_above:
            span_gy = max(xs_gy) - min(xs_gy) + 1
            if span_gy < 9:
                lo_x, hi_x = min(xs_above), max(xs_above)
                boot_dark = RAMPS["obsidian"][0]
                # Plant trailing boot heel 10px behind leading boot so stance_w is ~11-12px.
                heel_x = max(lo_x, xs_gy[0] - 10) if (xs_gy[0] - lo_x) >= (hi_x - xs_gy[-1]) else min(hi_x, xs_gy[-1] + 10)
                for x in (heel_x, heel_x + 1 if heel_x < xs_gy[0] else heel_x - 1):
                    if 0 <= x < CELL:
                        cpx[x, gy - 1] = boot_dark
                        cpx[x, gy] = boot_dark
    return cell


# ---------------------------------------------------------------------------
# Frame synthesis helpers (breath, directional stride, charge, hurt, die)
# ---------------------------------------------------------------------------

def make_breath_variant(base_cell: Image.Image, ground_y: int = GROUND_Y) -> Image.Image:
    """Subtle 1px upper-body breathing bob while feet & hem stay planted at ground_y."""
    bb = base_cell.getbbox()
    assert bb is not None
    split_y = bb[1] + int((bb[3] - bb[1]) * 0.74)
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    # Lower skirt & boots remain 100% anchored on ground_y.
    lower = base_cell.crop((0, split_y, CELL, CELL))
    upper = base_cell.crop((0, 0, CELL, split_y))
    out.alpha_composite(lower, (0, split_y))
    out.alpha_composite(upper, (0, 1))
    return out


def make_walk_down_pair(
    idle_down_cell: Image.Image,
    ground_y: int = GROUND_Y,
) -> tuple[Image.Image, Image.Image]:
    """Synthesize alternating south-facing stride frames from `idle down.png`."""
    bb = idle_down_cell.getbbox()
    assert bb is not None
    mid_x = (bb[0] + bb[2]) // 2
    hem_y = ground_y - 14

    frames: list[Image.Image] = []
    for lift_left, sway_dx in ((True, -1), (False, 1)):
        out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        # Subtle 1px hair/shoulder sway on upper body.
        upper = idle_down_cell.crop((0, 0, CELL, hem_y))
        out.alpha_composite(upper, (sway_dx, 0))

        # Lower coat & boots: planted side stays at ground_y, stepping side lifts 2px.
        left_half = idle_down_cell.crop((0, hem_y, mid_x, ground_y))
        right_half = idle_down_cell.crop((mid_x, hem_y, CELL, ground_y))
        if lift_left:
            out.alpha_composite(left_half, (0, hem_y - 2))
            out.alpha_composite(right_half, (mid_x, hem_y))
        else:
            out.alpha_composite(left_half, (0, hem_y))
            out.alpha_composite(right_half, (mid_x, hem_y - 2))
        frames.append(out)
    return frames[0], frames[1]


def make_walk_up_mirror(walk_up_cell: Image.Image, ground_y: int = GROUND_Y) -> Image.Image:
    """Mirror lower cloak/boots of `back.png` for a clean alternating north stride."""
    bb = walk_up_cell.getbbox()
    assert bb is not None
    split_y = bb[1] + int((bb[3] - bb[1]) * 0.60)
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    upper = walk_up_cell.crop((0, 0, CELL, split_y))
    lower_crop = walk_up_cell.crop((bb[0], split_y, bb[2], ground_y))
    lower_mir = lower_crop.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    out.alpha_composite(upper, (0, 1))
    out.alpha_composite(lower_mir, (bb[0], split_y))
    return out


def make_charge_frame(lunge_cell: Image.Image, ground_y: int = GROUND_Y) -> Image.Image:
    """Accentuate forward lunge pose (`anoter walk.png`) with crimson bat-swarm wisps."""
    out = lunge_cell.copy()
    bb = out.getbbox()
    assert bb is not None
    px = out.load()
    c_dark = RAMPS["crimson"][1]
    c_mid = RAMPS["crimson"][2]
    c_hi = RAMPS["crimson"][3]
    o_dark = RAMPS["obsidian"][0]

    # Crisp pixel-art crimson trailing wisps behind cloak (pure RAMPS colours).
    for idx, wy in enumerate((bb[1] + 22, bb[1] + 32, bb[1] + 43)):
        wx = max(3, bb[0] - 4 + (idx % 2) * 2)
        if wx + 4 < CELL and 0 <= wy < ground_y - 4:
            px[wx, wy] = o_dark
            px[wx + 1, wy] = c_dark
            px[wx + 2, wy] = c_mid
            px[wx + 3, wy] = c_hi
            if wy + 1 < ground_y - 2:
                px[wx + 1, wy + 1] = o_dark
                px[wx + 2, wy + 1] = c_dark
    return out


def make_hurt_frame(side_cell: Image.Image, ground_y: int = GROUND_Y) -> Image.Image:
    """Synthesize recoil hurt pose with crouch compression, backward shear & hit-spark."""
    bb = side_cell.getbbox()
    assert bb is not None
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    spx = side_cell.load()
    opx = out.load()
    top_y = bb[1]
    h = ground_y - top_y
    crouch = 6  # Compress to body_h = 59 so hurt reads as a distinct flinch crouch

    for dy in range(h - crouch):
        sy = top_y + int(round(dy * (h - 1) / float(max(h - crouch - 1, 1))))
        t = 1.0 - (dy / float(max(h - crouch - 1, 1)))  # 1 at crown, 0 at boots
        shear_x = -int(round(3.0 * t))
        ty = top_y + crouch + dy
        for sx in range(CELL):
            rgba = spx[sx, sy]
            if rgba[3] > 0:
                tx = max(0, min(CELL - 1, sx + shear_x))
                opx[tx, ty] = rgba

    # Subtle crimson impact glint at chest/shoulder.
    spark_x = min(CELL - 4, (bb[0] + bb[2]) // 2 + 3)
    spark_y = top_y + crouch + 22
    for ox, oy, col in (
        (0, 0, RAMPS["moon"][3]),
        (-1, 0, RAMPS["crimson"][3]),
        (1, 0, RAMPS["crimson"][3]),
        (0, -1, RAMPS["crimson"][2]),
        (0, 1, RAMPS["crimson"][2]),
    ):
        if 0 <= spark_x + ox < CELL and 0 <= spark_y + oy < ground_y:
            opx[spark_x + ox, spark_y + oy] = col
    return out


def make_die_frame(
    idle_down_cell: Image.Image,
    snapper: PerceptualBayerSnapper,
    ground_y: int = GROUND_Y,
) -> Image.Image:
    """Synthesize fallen vampiric collapse grounded cleanly at `ground_y`."""
    bb = idle_down_cell.getbbox()
    assert bb is not None
    crop = idle_down_cell.crop(bb)
    # Rotate & drape into a low, wide fallen cloak + spilled silver hair silhouette.
    rotated = crop.rotate(-76, resample=Image.Resampling.BILINEAR, expand=True)
    rbb = rotated.getbbox()
    assert rbb is not None
    rcrop = rotated.crop(rbb)
    fallen = scale_premultiplied(rcrop, 54, 24, alpha_cutoff=0.40)
    snapped = snapper.snap_image(fallen)
    sbb = snapped.getbbox()
    assert sbb is not None
    scrop = snapped.crop(sbb)
    sw, sh = scrop.size

    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    cell.alpha_composite(scrop, ((CELL - sw) // 2, ground_y - sh))
    return cell


# ---------------------------------------------------------------------------
# 5-state Portrait builder (`face.png` -> `320x64`)
# ---------------------------------------------------------------------------

def build_portrait_strip(
    face_path: Path,
    snapper: PerceptualBayerSnapper,
    tolerance: int = 42,
) -> tuple[Image.Image, Image.Image, int]:
    """Import `face.png` into a 320x64 5-state circular HUD portrait strip."""
    PCELL = 64
    keyed_face, killed = key_and_defringe_pose(
        face_path,
        tolerance=tolerance,
        strip_ground_shadow=False,
        pop_hair_pockets=True,
        verbose=True,
    )
    fbb = keyed_face.getbbox()
    if fbb is None:
        raise ValueError(f"{face_path} keyed out to empty image")

    fcrop = keyed_face.crop(fbb)
    fw, fh = fcrop.size
    # Scale face so crown, pointed ears & collar fill the 64x64 medallion richly.
    scale = 56.0 / float(max(fw, fh))
    tw = max(1, int(round(fw * scale)))
    th = max(1, int(round(fh * scale)))
    scaled_face = scale_premultiplied(fcrop, tw, th, alpha_cutoff=0.42)
    snapped_face = snapper.snap_image(scaled_face)

    def _medallion_base(low_hp: bool = False, hurt: bool = False) -> Image.Image:
        disc = Image.new("RGBA", (PCELL, PCELL), (0, 0, 0, 0))
        dpx = disc.load()
        cx, cy, rad = 31.5, 31.5, 29.5
        for y in range(PCELL):
            for x in range(PCELL):
                dist = math.hypot(x - cx, y - cy)
                if dist > rad:
                    continue
                if dist > rad - 1.3:
                    dpx[x, y] = RAMPS["obsidian"][0]
                elif hurt and dist > rad - 2.6:
                    dpx[x, y] = RAMPS["crimson"][2]
                elif low_hp:
                    dpx[x, y] = RAMPS["crimson"][0] if (x + y) % 2 == 0 else RAMPS["obsidian"][0]
                else:
                    dpx[x, y] = RAMPS["obsidian"][0] if y >= 22 else (
                        RAMPS["obsidian"][1] if (x + y) % 2 == 0 else RAMPS["obsidian"][0]
                    )
        return disc

    def _clip_to_medallion(frame: Image.Image) -> Image.Image:
        fpx = frame.load()
        cx, cy, rad = 31.5, 31.5, 29.5
        for y in range(PCELL):
            for x in range(PCELL):
                if math.hypot(x - cx, y - cy) > rad:
                    fpx[x, y] = (0, 0, 0, 0)
                elif math.hypot(x - cx, y - cy) > rad - 1.1 and fpx[x, y][3] > 0:
                    fpx[x, y] = RAMPS["obsidian"][0]
        return frame

    fx0 = (PCELL - tw) // 2
    fy0 = PCELL - th - 2

    # Locate the two 3/4-angle ruby eye clusters (excluding the pointed ear on the left).
    spx = snapped_face.load()
    crimson_set = {c[:3] for c in RAMPS["crimson"]}
    eye_pts = [
        (fx0 + x, fy0 + y)
        for y in range(th)
        for x in range(tw)
        if spx[x, y][3] > 0
        and spx[x, y][:3] in crimson_set
        and 29 <= (fx0 + x) <= 47
        and 25 <= (fy0 + y) <= 31
    ]
    near_eye = [p for p in eye_pts if p[0] < 40]
    far_eye = [p for p in eye_pts if p[0] >= 40]

    states: list[Image.Image] = []
    # 0: Normal calm regal idle
    s0 = _medallion_base()
    s0.alpha_composite(snapped_face, (fx0, fy0))
    states.append(_clip_to_medallion(s0))

    # 1: Living idle B (1px gentle breath lift + bright eye specular glint)
    s1 = _medallion_base()
    s1.alpha_composite(snapped_face, (fx0, fy0 - 1))
    s1px = s1.load()
    if near_eye:
        nx = min(p[0] for p in near_eye) + 1
        ny = min(p[1] for p in near_eye) - 1
        s1px[nx, ny] = RAMPS["moon"][3]
    states.append(_clip_to_medallion(s1))

    # 2: Blink (closed silver-lashed eyelids cleanly over the two 3/4 ruby irises)
    s2 = _medallion_base()
    s2.alpha_composite(snapped_face, (fx0, fy0))
    s2px = s2.load()
    for grp in (near_eye, far_eye):
        if not grp:
            continue
        gx0, gx1 = min(p[0] for p in grp), max(p[0] for p in grp)
        gy0, gy1 = min(p[1] for p in grp), max(p[1] for p in grp)
        for ey in range(gy0, gy1 + 1):
            for ex in range(gx0, gx1 + 1):
                s2px[ex, ey] = RAMPS["moon"][3] if ey < gy1 else RAMPS["obsidian"][1]
        for lx in range(gx0 - 1, gx1 + 1):
            if 0 <= lx < PCELL:
                s2px[lx, gy1] = RAMPS["obsidian"][0]
    states.append(_clip_to_medallion(s2))

    # 3: Low-HP (HP <= 35% — dark crimson aura, glowing ruby glare & furrowed brow)
    s3 = _medallion_base(low_hp=True)
    s3.alpha_composite(snapped_face, (fx0, fy0))
    s3px = s3.load()
    for ex, ey in eye_pts:
        s3px[ex, ey] = RAMPS["crimson"][3] if (ex + ey) % 2 == 0 else RAMPS["crimson"][2]
    if near_eye:
        bx = min(p[0] for p in near_eye) + 1
        by = min(p[1] for p in near_eye) - 2
        s3px[bx, by] = RAMPS["obsidian"][1]
        s3px[bx + 1, by + 1] = RAMPS["obsidian"][0]
        # Subtle crimson cheek droplet
        s3px[bx - 2, by + 8] = RAMPS["crimson"][2]
        s3px[bx - 2, by + 9] = RAMPS["crimson"][3]
    states.append(_clip_to_medallion(s3))

    # 4: Hurt ("AKH!" recoil — tilted -1,+1, squeezed > < wince eyes, crimson rim)
    s4 = _medallion_base(hurt=True)
    s4.alpha_composite(snapped_face, (fx0 - 1, fy0 + 1))
    s4px = s4.load()
    for grp, is_near in ((near_eye, True), (far_eye, False)):
        if not grp:
            continue
        gx0, gx1 = min(p[0] for p in grp) - 1, max(p[0] for p in grp) - 1
        gy0, gy1 = min(p[1] for p in grp) + 1, max(p[1] for p in grp) + 1
        for ey in range(gy0 - 1, gy1 + 1):
            for ex in range(gx0, gx1 + 1):
                if 0 <= ex < PCELL and 0 <= ey < PCELL:
                    s4px[ex, ey] = RAMPS["moon"][3]
        if is_near:
            for dx, dy in ((0, -1), (1, 0), (2, 0), (0, 1)):
                if 0 <= gx0 + dx < PCELL and 0 <= gy1 - 1 + dy < PCELL:
                    s4px[gx0 + dx, gy1 - 1 + dy] = RAMPS["obsidian"][0]
        else:
            for dx, dy in ((1, -1), (0, 0), (1, 1)):
                if 0 <= gx0 + dx < PCELL and 0 <= gy1 + dy < PCELL:
                    s4px[gx0 + dx, gy1 + dy] = RAMPS["obsidian"][0]
    # Small parted "AKH!" mouth + tiny white fang on 3/4 jawline
    s4px[36, 36] = RAMPS["crimson"][1]
    s4px[37, 36] = RAMPS["moon"][3]
    s4px[36, 37] = RAMPS["crimson"][2]
    s4px[37, 37] = RAMPS["crimson"][1]
    states.append(_clip_to_medallion(s4))

    strip = Image.new("RGBA", (PCELL * 5, PCELL), (0, 0, 0, 0))
    for i, st in enumerate(states):
        strip.alpha_composite(st, (i * PCELL, 0))
    return strip, keyed_face, killed


# ---------------------------------------------------------------------------
# Step 4 — Hard contract assertions
# ---------------------------------------------------------------------------

def assert_sheet_contract(
    sheet: Image.Image,
    label: str,
    expected_size: tuple[int, int],
    max_colours: int = 24,
    ground_y: int | None = GROUND_Y,
    body_h_bounds: tuple[int, int] | None = None,
) -> dict:
    if sheet.size != expected_size:
        raise AssertionError(f"{label}: size {sheet.size} != {expected_size}")

    pxs = list(sheet.get_flattened_data() if hasattr(sheet, "get_flattened_data") else sheet.getdata())
    bad_alpha = sum(1 for (_r, _g, _b, a) in pxs if a not in (0, 255))
    if bad_alpha != 0:
        raise AssertionError(f"{label}: non-binary alpha pixels found: {bad_alpha}")

    colours = {(r, g, b) for (r, g, b, a) in pxs if a > 0}
    if len(colours) > max_colours:
        raise AssertionError(f"{label}: colour count {len(colours)} > {max_colours}")
    if (0, 0, 0) in colours:
        raise AssertionError(f"{label}: contains forbidden #000000 pixels")

    info: dict = {"size": sheet.size, "colours": len(colours), "frames": []}
    if ground_y is not None:
        n_frames = sheet.width // CELL
        for idx in range(n_frames):
            cell = sheet.crop((idx * CELL, 0, (idx + 1) * CELL, CELL))
            bb = cell.getbbox()
            if bb is None:
                raise AssertionError(f"{label}: frame {idx} is empty")
            top_y, bottom_y = bb[1], bb[3]
            body_h = bottom_y - top_y
            if bottom_y != ground_y:
                raise AssertionError(
                    f"{label}: frame f{idx} bottom_y={bottom_y} != GROUND_Y={ground_y}"
                )
            info["frames"].append((idx, bb[2] - bb[0], body_h, bottom_y))

        if body_h_bounds is not None:
            f0_h = info["frames"][0][2]
            lo, hi = body_h_bounds
            if not (lo <= f0_h <= hi):
                raise AssertionError(
                    f"{label}: f0 standing body_h={f0_h} outside spec [{lo}, {hi}]"
                )
    return info


# ---------------------------------------------------------------------------
# Diagnostic preview (`docs/images/velmira_import_preview.png`)
# ---------------------------------------------------------------------------

def render_import_preview(
    raw_cleaned_pairs: list[tuple[str, Image.Image, Image.Image, int]],
    sheet: Image.Image,
    frame_labels: list[str],
    portrait_strip: Image.Image,
    out_path: Path,
    sheet_colours: int,
    total_fringe_killed: int,
) -> None:
    cols = 4
    rows = math.ceil(len(raw_cleaned_pairs) / cols)
    card_w, card_h = 236, 134
    pad = 14
    w = max(pad + cols * (card_w + pad), 16 * 96 + 2 * pad)
    top_grid_h = 46 + rows * (card_h + 10)
    sheet_sec_h = 260
    port_sec_h = 175
    h = top_grid_h + sheet_sec_h + port_sec_h

    canvas = Image.new("RGBA", (w, h), (20, 16, 28, 255))
    draw = ImageDraw.Draw(canvas)
    draw.text(
        (pad, 12),
        f"VELMIRA HAND-DRAWN POSE IMPORT  |  tol=42 flood-fill  |  de-fringed={total_fringe_killed}px  |  "
        f"palette={sheet_colours}/24 RAMPS (Lab + 2x2 Bayer)  |  GROUND_Y={GROUND_Y}",
        fill=RAMPS["crimson"][3],
    )

    for idx, (fname, raw_im, clean_snapped, killed) in enumerate(raw_cleaned_pairs):
        r, c = divmod(idx, cols)
        x0 = pad + c * (card_w + pad)
        y0 = 42 + r * (card_h + 10)
        draw.rounded_rectangle(
            [x0, y0, x0 + card_w, y0 + card_h],
            radius=6,
            fill=(30, 24, 42, 255),
            outline=(68, 56, 92, 255),
        )
        # Left: raw source on white; Right: keyed + de-fringed + palette-snapped on dark checker
        canvas.alpha_composite(raw_im, (x0 + 12, y0 + 10))
        chk = Image.new("RGBA", (96, 96), (38, 32, 54, 255))
        cd = ImageDraw.Draw(chk)
        for cy in range(0, 96, 8):
            for cx in range(0, 96, 8):
                if ((cx + cy) // 8) % 2 == 0:
                    cd.rectangle([cx, cy, cx + 7, cy + 7], fill=(28, 22, 40, 255))
        chk.alpha_composite(clean_snapped, (0, 0))
        canvas.alpha_composite(chk, (x0 + 124, y0 + 10))
        draw.text(
            (x0 + 10, y0 + 112),
            f"{fname}  (-{killed}px fringe)",
            fill=RAMPS["moon"][2],
        )

    # Middle section: 16-frame 1536x96 output sheet (1x & 1.5x strip with GROUND_Y=80 line)
    sy = top_grid_h + 12
    draw.text(
        (pad, sy),
        "FINAL 16-FRAME SPRITE SHEET: assets/textures/player_velmira.png (1536x96, binary alpha, 0 #000000)",
        fill=RAMPS["gold"][3],
    )
    strip_y = sy + 24
    for i, lbl in enumerate(frame_labels):
        fx = pad + i * 96
        draw.rectangle(
            [fx, strip_y, fx + 95, strip_y + 191],
            fill=(28, 22, 40, 255) if i % 2 == 0 else (34, 27, 48, 255),
        )
        # Draw GROUND_Y=80 line at 2x scale -> y = strip_y + 160 (clipped inside 192px)
        cell = sheet.crop((i * CELL, 0, (i + 1) * CELL, CELL))
        # Show cropped 1.5x or 1x + zoom: 1x full cell + 1x ground marker is 100% crisp!
        draw.rectangle([fx, strip_y, fx + 95, strip_y + 95], outline=(58, 48, 80, 255))
        draw.line([(fx, strip_y + GROUND_Y), (fx + 95, strip_y + GROUND_Y)], fill=(110, 48, 72, 255))
        canvas.alpha_composite(cell, (fx, strip_y))
        # Also show 1.5x zoomed center crop right below for easy visual inspection
        z = cell.crop((12, 12, 84, 84)).resize((96, 96), Image.Resampling.NEAREST)
        canvas.alpha_composite(z, (fx, strip_y + 96))
        draw.text((fx + 3, strip_y + 196), f"f{i}:{lbl}", fill=RAMPS["moon"][2])

    # Bottom section: 5-state portrait strip at 2x zoom
    py = top_grid_h + sheet_sec_h + 6
    draw.text(
        (pad, py),
        "5-STATE PORTRAIT STRIP: assets/textures/portrait_velmira.png (320x64 -> 2x zoom)",
        fill=RAMPS["gold"][3],
    )
    p_names = ["0:normal", "1:breath", "2:blink", "3:low_hp", "4:hurt"]
    for i, plbl in enumerate(p_names):
        px0 = pad + i * 150
        pcell = portrait_strip.crop((i * 64, 0, (i + 1) * 64, 64))
        pzoom = pcell.resize((128, 128), Image.Resampling.NEAREST)
        canvas.alpha_composite(pzoom, (px0, py + 24))
        draw.text((px0 + 24, py + 154), plbl, fill=RAMPS["moon"][2])

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path)


# ---------------------------------------------------------------------------
# Velmira sheet orchestration
# ---------------------------------------------------------------------------

def import_velmira(cfg: dict) -> None:
    src_dir: Path = cfg["src_dir"]
    palette = build_hero_palette(tuple(cfg["ramps"]))
    snapper = PerceptualBayerSnapper(palette)
    target_h = int(cfg["target_body_h"])
    ground_y = int(cfg["ground_y"])
    tol = int(cfg["tolerance"])

    print(f"=== Importing hand-drawn poses from {src_dir.relative_to(REPO_ROOT)} ===")
    pose_files = {
        "idle_down": "idle down.png",
        "walk_1": "walk.png",
        "walk_2": "another walk .png",
        "walk_3": "walk 2.png",
        "walk_4": "anothr walk.png",
        "idle_up": "idle back.png",
        "walk_up": "back.png",
        "attack": "attack.png",
        "attack_splash": "attack 2 .png",
        "lunge": "anoter walk.png",
    }

    cleaned_map: dict[str, Image.Image] = {}
    preview_pairs: list[tuple[str, Image.Image, Image.Image, int]] = []
    total_fringe_killed = 0

    for key, fname in pose_files.items():
        fpath = src_dir / fname
        if not fpath.exists():
            raise FileNotFoundError(f"Missing source pose: {fpath}")
        raw_im = Image.open(fpath).convert("RGBA")
        cleaned, killed = key_and_defringe_pose(fpath, tolerance=tol, verbose=True)
        total_fringe_killed += killed
        cleaned_map[key] = cleaned
        preview_pairs.append((fname, raw_im, snapper.snap_image(cleaned), killed))

    # Build 16 grounded 96x96 frames (`f0..f15`):
    f0_idle = place_pose_in_cell(cleaned_map["idle_down"], snapper, target_h, ground_y)
    f1_idle_b = make_breath_variant(f0_idle, ground_y)
    f2_walk1 = place_pose_in_cell(
        cleaned_map["walk_1"], snapper, target_h, ground_y, ensure_two_foot_stance=True
    )
    f3_walk2 = place_pose_in_cell(
        cleaned_map["walk_2"], snapper, target_h, ground_y, ensure_two_foot_stance=True
    )
    f4_walk3 = place_pose_in_cell(
        cleaned_map["walk_3"], snapper, target_h, ground_y, ensure_two_foot_stance=True
    )
    f5_walk4 = place_pose_in_cell(
        cleaned_map["walk_4"], snapper, target_h, ground_y, ensure_two_foot_stance=True
    )
    f6_down_a, f7_down_b = make_walk_down_pair(f0_idle, ground_y)
    f8_idle_up = place_pose_in_cell(cleaned_map["idle_up"], snapper, target_h, ground_y)
    f9_up_a = place_pose_in_cell(cleaned_map["walk_up"], snapper, target_h, ground_y)
    f10_up_b = make_walk_up_mirror(f9_up_a, ground_y)
    f11_atk = place_pose_in_cell(cleaned_map["attack"], snapper, target_h, ground_y)
    f12_splash = place_pose_in_cell(cleaned_map["attack_splash"], snapper, target_h, ground_y)
    f13_charge_base = place_pose_in_cell(cleaned_map["lunge"], snapper, target_h - 1, ground_y)
    f13_charge = make_charge_frame(f13_charge_base, ground_y)
    f14_hurt = make_hurt_frame(f3_walk2, ground_y)
    f15_die = make_die_frame(f0_idle, snapper, ground_y)

    frames_and_labels: list[tuple[str, Image.Image]] = [
        ("idle", f0_idle),
        ("idle_b", f1_idle_b),
        ("walk1", f2_walk1),
        ("walk2", f3_walk2),
        ("walk3", f4_walk3),
        ("walk4", f5_walk4),
        ("down_a", f6_down_a),
        ("down_b", f7_down_b),
        ("idle_up", f8_idle_up),
        ("up_a", f9_up_a),
        ("up_b", f10_up_b),
        ("attack", f11_atk),
        ("splash", f12_splash),
        ("charge", f13_charge),
        ("hurt", f14_hurt),
        ("die", f15_die),
    ]

    sheet = Image.new("RGBA", (CELL * len(frames_and_labels), CELL), (0, 0, 0, 0))
    for idx, (_lbl, cell) in enumerate(frames_and_labels):
        sheet.alpha_composite(cell, (idx * CELL, 0))

    # Build 5-state portrait strip (`face.png` -> `320x64`)
    face_path = src_dir / "face.png"
    raw_face = Image.open(face_path).convert("RGBA")
    portrait_strip, keyed_face, face_killed = build_portrait_strip(face_path, snapper, tolerance=tol)
    total_fringe_killed += face_killed
    preview_pairs.append(("face.png", raw_face, snapper.snap_image(keyed_face), face_killed))

    print(f"  [de-fringe] TOTAL killed across 11 poses: {total_fringe_killed} pixels")

    # Step 4: Contract assertions on both deliverables BEFORE saving
    sheet_info = assert_sheet_contract(
        sheet,
        label="player_velmira.png",
        expected_size=(1536, 96),
        max_colours=24,
        ground_y=ground_y,
        body_h_bounds=tuple(cfg["body_h_bounds"]),
    )
    port_info = assert_sheet_contract(
        portrait_strip,
        label="portrait_velmira.png",
        expected_size=(320, 64),
        max_colours=24,
        ground_y=None,
        body_h_bounds=None,
    )

    out_sheet: Path = cfg["out_sheet"]
    out_portrait: Path = cfg["out_portrait"]
    out_preview: Path = cfg["preview"]
    out_sheet.parent.mkdir(parents=True, exist_ok=True)
    out_portrait.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_sheet)
    portrait_strip.save(out_portrait)

    render_import_preview(
        raw_cleaned_pairs=preview_pairs,
        sheet=sheet,
        frame_labels=[lbl for (lbl, _c) in frames_and_labels],
        portrait_strip=portrait_strip,
        out_path=out_preview,
        sheet_colours=sheet_info["colours"],
        total_fringe_killed=total_fringe_killed,
    )

    print(
        f"wrote {out_sheet.relative_to(REPO_ROOT)}  "
        f"({sheet.size[0]}x{sheet.size[1]}, colours={sheet_info['colours']}/24, "
        f"f0_body_h={sheet_info['frames'][0][2]}, ground_y={ground_y})"
    )
    print(
        f"wrote {out_portrait.relative_to(REPO_ROOT)}  "
        f"({portrait_strip.size[0]}x{portrait_strip.size[1]}, colours={port_info['colours']}/24)"
    )
    print(f"wrote {out_preview.relative_to(REPO_ROOT)}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hero", default="velmira", choices=sorted(HERO_PRESETS))
    parser.add_argument("--tolerance", type=int, default=None, help="Override border flood-fill tolerance")
    parser.add_argument("--body-h", type=int, default=None, help="Override standing body height")
    args = parser.parse_args()

    cfg = dict(HERO_PRESETS[args.hero])
    if args.tolerance is not None:
        cfg["tolerance"] = args.tolerance
    if args.body_h is not None:
        cfg["target_body_h"] = args.body_h

    if args.hero == "velmira":
        import_velmira(cfg)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
