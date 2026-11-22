#!/usr/bin/env python3
"""Build Sylvara's 32-frame (8x4 @ 224x224) sheet & 5-state 192x192 HUD portrait
directly from `assets/sprites/sylvara/sylvara_reference.png` (matching Velmira's
exact pipeline, uniform `TARGET_BODY_H = 162`, `GROUND_Y = 200`, zero white halo!).

Outputs:
  - assets/textures/player_pari.png      (1792 x 896 RGBA, 8 cols x 4 rows of 224x224)
  - assets/textures/portrait_pari.png    (960 x 192 RGBA, 5 x 192x192 circular states)
  - docs/images/sylvara_preview.png      (visual verification sheet)
"""
from __future__ import annotations

import math
from pathlib import Path
import sys
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ref_sheet_kit import (
    CELL,
    GROUND_Y,
    apply_medallion_backdrop,
    extract_from_white_bg,
    make_calm_breath_variant,
    place_grounded,
)

ROOT = Path(__file__).resolve().parent.parent
REF_PATH = ROOT / "assets/sprites/sylvara/sylvara_reference.png"
OUT_HERO = ROOT / "assets/textures/player_pari.png"
OUT_PORTRAIT = ROOT / "assets/textures/portrait_pari.png"
OUT_PREVIEW = ROOT / "docs/images/sylvara_preview.png"

COLS = 8
ROWS = 4
BODY_H = 162


def make_side_blink(cell_im: Image.Image) -> Image.Image:
    """Close Sylvara's side-facing emerald eye gently for a natural blink frame."""
    out = cell_im.copy()
    arr = np.array(out)
    # Locate emerald iris pixels in head region (`y: 55..98, x: 95..148`)
    sub = arr[55:98, 95:148]
    r, g, b, a = sub[:, :, 0].astype(int), sub[:, :, 1].astype(int), sub[:, :, 2].astype(int), sub[:, :, 3]
    iris = (a > 180) & (g > r + 8) & (g > b + 6) & (g > 65)
    ys, xs = np.where(iris)
    if len(xs) > 0:
        x0, x1 = int(xs.min()) + 95, int(xs.max()) + 95
        y0, y1 = int(ys.min()) + 55, int(ys.max()) + 55
        for y in range(y0 - 1, y1 + 2):
            for x in range(x0 - 1, x1 + 2):
                if arr[y, x, 3] > 160:
                    arr[y, x] = (236, 204, 188, arr[y, x, 3])
        out = Image.fromarray(arr, mode="RGBA")
        d = ImageDraw.Draw(out)
        ym = (y0 + y1) // 2 + 1
        d.line([(x0 - 2, ym), ((x0 + x1) // 2, ym + 1), (x1 + 2, ym)], fill=(44, 24, 22, 245), width=2)
    return out


def build_sylvara_portrait(ref: Image.Image) -> Image.Image:
    """Build 5-state 192x192 circular HUD portrait from Sylvara's left full-res bust artwork."""
    P = 192
    # Extract full-res left artwork cleanly from white background first!
    art = extract_from_white_bg(ref, (6, 5, 296, 450), clear_enclosed_holes=True, min_speck=48)
    # Crop close-up face + pointed ears + tiara + quiver + emerald collar (matching Velmira's zoom!)
    bust = art.crop((24, 2, min(art.width, 214), min(art.height, 192)))
    canvas = Image.new("RGBA", (P, P), (0, 0, 0, 0))
    s = (P * 1.02) / float(max(bust.width, bust.height))
    bw = int(round(bust.width * s))
    bh = int(round(bust.height * s))
    bust_s = bust.resize((bw, bh), Image.Resampling.LANCZOS)
    canvas.alpha_composite(bust_s, ((P - bw) // 2 + 4, P - bh + 8))
    base_raw = canvas

    bg_in = (24, 52, 38)
    bg_out = (10, 22, 16)
    strip = Image.new("RGBA", (P * 5, P), (0, 0, 0, 0))

    # Locate emerald iris pixels in 192x192 bust (`y: 66..122, x: 76..162`)
    def is_emerald_iris(x: int, y: int, r: int, g: int, b: int) -> bool:
        if not (76 <= x <= 162 and 66 <= y <= 122):
            return False
        return (g > r + 6 and g > b + 6 and g > 55) or (r < 55 and g > 42 and 70 <= y <= 116 and 82 <= x <= 156)

    # 0: idle_a
    strip.alpha_composite(apply_medallion_backdrop(base_raw, bg_in, bg_out), (0, 0))

    # 1: idle_b (subtle calm breath/zoom — matching Velmira!)
    b1 = base_raw.crop((2, 2, P - 2, P - 1)).resize((P, P), Image.Resampling.LANCZOS)
    strip.alpha_composite(apply_medallion_backdrop(b1, bg_in, bg_out), (P, 0))

    # 2: blink (eyelids closed with delicate dark-golden lashes)
    f2 = base_raw.copy()
    arr2 = np.array(f2)
    ys_i, xs_i = [], []
    for y in range(66, 122):
        for x in range(76, 162):
            r, g, b, a = int(arr2[y, x, 0]), int(arr2[y, x, 1]), int(arr2[y, x, 2]), int(arr2[y, x, 3])
            if a > 180 and is_emerald_iris(x, y, r, g, b):
                arr2[y, x] = (238, 206, 190, a)
                ys_i.append(y)
                xs_i.append(x)
    f2 = Image.fromarray(arr2, mode="RGBA")
    if xs_i:
        # Split left & right eye clusters around x_mid
        xm = (min(xs_i) + max(xs_i)) // 2
        d2 = ImageDraw.Draw(f2)
        for cluster_x in ([x for x in xs_i if x < xm], [x for x in xs_i if x >= xm]):
            if cluster_x:
                xa, xb = min(cluster_x), max(cluster_x)
                ym = int(np.median([y for x, y in zip(xs_i, ys_i) if xa <= x <= xb])) + 1
                d2.line([(xa - 2, ym - 1), ((xa + xb) // 2, ym + 1), (xb + 2, ym - 1)], fill=(44, 24, 22, 245), width=2)
    strip.alpha_composite(apply_medallion_backdrop(f2, bg_in, bg_out), (P * 2, 0))

    # 3: low_hp (radiant emerald eyes + subtle crimson battle vignette)
    f3 = base_raw.copy()
    px3 = f3.load()
    for y in range(P):
        for x in range(P):
            r, g, b, a = px3[x, y]
            if a < 20:
                continue
            if is_emerald_iris(x, y, r, g, b):
                px3[x, y] = (int(r * 0.7), min(255, int(g * 1.38 + 34)), min(255, int(b * 1.05 + 18)), a)
            else:
                dist = math.hypot((x - P * 0.52) / (P * 0.5), (y - P * 0.50) / (P * 0.5))
                vign = min(0.42, max(0.0, (dist - 0.32) * 0.62))
                nr = int(r * (1.0 - vign * 0.22) + 165 * vign * 0.34)
                ng = int(g * (1.0 - vign * 0.52))
                nb = int(b * (1.0 - vign * 0.48))
                px3[x, y] = (min(255, nr), max(0, ng), max(0, nb), a)
    strip.alpha_composite(apply_medallion_backdrop(f3, (38, 28, 28), (18, 10, 12)), (P * 3, 0))

    # 4: hurt (wince recoil tilt + warm hit flash)
    f4 = f2.rotate(-4.0, resample=Image.Resampling.BICUBIC, expand=False)
    px4 = f4.load()
    for y in range(P):
        for x in range(P):
            r, g, b, a = px4[x, y]
            if a < 20:
                continue
            px4[x, y] = (min(255, int(r * 1.14 + 24)), int(g * 0.85), int(b * 0.85), a)
    strip.alpha_composite(apply_medallion_backdrop(f4, (44, 24, 24), (20, 10, 12)), (P * 4, 0))
    return strip


def main() -> None:
    assert REF_PATH.exists(), f"Missing reference sheet: {REF_PATH}"
    ref = Image.open(REF_PATH).convert("RGBA")

    # --- ROW 1 CROPS: Idles & 4-Frame Side Walk ---
    idle_front_raw = extract_from_white_bg(ref, (342, 49, 488, 239))
    idle_right_raw = extract_from_white_bg(ref, (546, 54, 680, 239))
    idle_back_raw  = extract_from_white_bg(ref, (742, 48, 870, 239))

    walk_r0 = extract_from_white_bg(ref, (1118, 54, 1244, 238))
    walk_r1 = extract_from_white_bg(ref, (1247, 55, 1370, 238))
    walk_r2 = extract_from_white_bg(ref, (1372, 55, 1495, 238))
    walk_r3 = extract_from_white_bg(ref, (1503, 53, 1624, 238))

    # --- ROW 2 CROPS: 4-Frame Walk Up & 4-Frame Walk Down ---
    walk_u0 = extract_from_white_bg(ref, (763, 282, 866, 445))
    walk_u1 = extract_from_white_bg(ref, (871, 283, 967, 445))
    walk_u2 = extract_from_white_bg(ref, (971, 283, 1069, 445))
    walk_u3 = extract_from_white_bg(ref, (1077, 283, 1177, 445))

    walk_d0 = extract_from_white_bg(ref, (1228, 292, 1330, 445))
    walk_d1 = extract_from_white_bg(ref, (1350, 292, 1446, 445))
    walk_d2 = extract_from_white_bg(ref, (1465, 293, 1560, 445))
    walk_d3 = extract_from_white_bg(ref, (1580, 292, 1676, 445))

    # --- ROW 3 CROPS: Bow Attack (Normal 4f) & Charged Bow Shot ---
    # Note: Attack row on sheet is drawn at ~130px body height vs 180px on Row 1;
    # compute exact attack-row scale from `atk_n0` (standing archer height -> BODY_H)
    # so `chg_3`'s vertical golden bow aura NEVER shrinks Sylvara!
    atk_n0 = extract_from_white_bg(ref, (18, 493, 153, 622))
    atk_n1 = extract_from_white_bg(ref, (154, 493, 275, 622))
    atk_n2 = extract_from_white_bg(ref, (276, 482, 394, 621))
    atk_n3 = extract_from_white_bg(ref, (398, 482, 552, 620))

    atk_scale = BODY_H / float(atk_n0.height)
    chg_1 = extract_from_white_bg(ref, (1298, 493, 1424, 621))
    chg_2 = extract_from_white_bg(ref, (1432, 491, 1547, 621))
    chg_3 = extract_from_white_bg(ref, (1549, 471, 1703, 625))

    # --- ROW 4 & 5 CROPS: Dash Vault, Hurt, & Kneel -> Fallen Death ---
    dash_1 = extract_from_white_bg(ref, (568, 671, 694, 756), min_speck=140)
    dash_2 = extract_from_white_bg(ref, (956, 657, 1082, 756), min_speck=140)
    hurt_0 = extract_from_white_bg(ref, (26, 669, 138, 765), min_speck=100)
    die_kneel  = extract_from_white_bg(ref, (1140, 672, 1313, 775))
    die_fallen = extract_from_white_bg(ref, (1316, 720, 1514, 777))

    # Build calm grounded idle bases & subtle breathing variants (boots 100% locked!)
    f_idle0 = place_grounded(idle_right_raw, BODY_H)
    f_idle1 = make_calm_breath_variant(f_idle0, chest_lift_px=1.4, cape_sway_px=0.9)
    f_idle2 = make_calm_breath_variant(f_idle0, chest_lift_px=0.7, cape_sway_px=1.3)
    f_idle3 = make_side_blink(f_idle0)

    f_down0 = place_grounded(idle_front_raw, BODY_H, center_x_box=True)
    f_down1 = make_calm_breath_variant(f_down0, chest_lift_px=1.4, cape_sway_px=0.7)

    f_up0 = place_grounded(idle_back_raw, BODY_H, center_x_box=True)
    f_up1 = make_calm_breath_variant(f_up0, chest_lift_px=1.4, cape_sway_px=0.8)

    frames: list[Image.Image] = [
        # Row 0 (0..7): Calm 4-frame Side Idle + 4-frame Side Walk
        f_idle0,
        f_idle1,
        f_idle2,
        f_idle3,
        place_grounded(walk_r0, BODY_H),
        place_grounded(walk_r1, BODY_H),
        place_grounded(walk_r2, BODY_H),
        place_grounded(walk_r3, BODY_H),

        # Row 1 (8..15): Front Idle (2f) + Front Walk (4f) + Back Idle (2f)
        f_down0,
        f_down1,
        place_grounded(walk_d0, BODY_H, center_x_box=True),
        place_grounded(walk_d1, BODY_H, center_x_box=True),
        place_grounded(walk_d2, BODY_H, center_x_box=True),
        place_grounded(walk_d3, BODY_H, center_x_box=True),
        f_up0,
        f_up1,

        # Row 2 (16..23): Back Walk (4f) + Normal Bow Attack (4f)
        place_grounded(walk_u0, BODY_H, center_x_box=True),
        place_grounded(walk_u1, BODY_H, center_x_box=True),
        place_grounded(walk_u2, BODY_H, center_x_box=True),
        place_grounded(walk_u3, BODY_H, center_x_box=True),
        place_grounded(atk_n0, fixed_scale=atk_scale),
        place_grounded(atk_n1, fixed_scale=atk_scale),
        place_grounded(atk_n2, fixed_scale=atk_scale),
        place_grounded(atk_n3, fixed_scale=atk_scale, dx=4),

        # Row 3 (24..31): Bow Charge (3f) + Sylvan Vault Dash (2f) + Hurt + Kneel/Fallen Death (2f)
        place_grounded(chg_1, fixed_scale=atk_scale),
        place_grounded(chg_2, fixed_scale=atk_scale),
        place_grounded(chg_3, fixed_scale=atk_scale, dx=6, dy=6),
        place_grounded(dash_1, target_h=142, dy=-4),
        place_grounded(dash_2, target_h=148, dy=-6),
        place_grounded(hurt_0, target_h=148, dx=-3),
        place_grounded(die_kneel, target_h=124, center_x_box=True),
        place_grounded(die_fallen, target_h=66, center_x_box=True),
    ]
    assert len(frames) == 32

    sheet = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for idx, frm in enumerate(frames):
        sheet.alpha_composite(frm, ((idx % COLS) * CELL, (idx // COLS) * CELL))
    OUT_HERO.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT_HERO)

    portrait_strip = build_sylvara_portrait(ref)
    portrait_strip.save(OUT_PORTRAIT)

    # Save visual verification sheet on dark dungeon stone backdrop!
    prev = Image.new("RGBA", (1320, 860), (24, 28, 36, 255))
    pd = ImageDraw.Draw(prev)
    for i in range(5):
        pf = portrait_strip.crop((i * 192, 0, (i + 1) * 192, 192)).resize((104, 104), Image.Resampling.LANCZOS)
        px, py = 18 + i * 118, 14
        prev.alpha_composite(pf, (px, py))
        pd.ellipse((px - 2, py - 2, px + 106, py + 106), outline=(120, 224, 164, 255), width=2)
    pd.text((630, 52), "SYLVARA (HIGH-ELF ARCHER) - 32x 224x224 + 5x 192x192 HUD Portrait", fill=(220, 245, 230, 255))

    labels = [
        "0:idle0", "1:idle1", "2:idle2", "3:blink", "4:walk0", "5:walk1", "6:walk2", "7:walk3",
        "8:down_i0", "9:down_i1", "10:down_w0", "11:down_w1", "12:down_w2", "13:down_w3", "14:up_i0", "15:up_i1",
        "16:up_w0", "17:up_w1", "18:up_w2", "19:up_w3", "20:bow_n0", "21:bow_n1", "22:bow_n2", "23:bow_rel",
        "24:chg_0", "25:chg_1", "26:chg_aura", "27:dash0", "28:dash1", "29:hurt", "30:die_kneel", "31:die_fall",
    ]
    for idx, frm in enumerate(frames):
        c, r = idx % 8, idx // 8
        x, y = 18 + c * 160, 140 + r * 176
        pd.rectangle([x, y, x + 148, y + 148], fill=(32, 38, 48, 255), outline=(58, 72, 88, 255))
        gy = y + int(round(GROUND_Y * (148.0 / CELL)))
        pd.line([(x + 8, gy), (x + 140, gy)], fill=(90, 215, 140, 130), width=1)
        prev.alpha_composite(frm.resize((148, 148), Image.Resampling.LANCZOS), (x, y))
        pd.text((x + 16, y + 152), labels[idx], fill=(210, 232, 220, 255))

    OUT_PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    prev.save(OUT_PREVIEW)
    print(f"Wrote {OUT_HERO} ({sheet.size}) and {OUT_PORTRAIT} ({portrait_strip.size})")


if __name__ == "__main__":
    main()
