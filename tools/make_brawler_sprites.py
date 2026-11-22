#!/usr/bin/env python3
"""Build Behemoth's 32-frame (8x4 @ 224x224) sheet & 5-state 192x192 HUD portrait
directly from `assets/sprites/behemoth/behemoth_reference.png` (matching Velmira's
exact pipeline, uniform `BODY_H = 170`, `GROUND_Y = 200`, zero black boxes!).

Outputs:
  - assets/textures/player_borzo.png     (1792 x 896 RGBA, 8 cols x 4 rows of 224x224)
  - assets/textures/portrait_borzo.png   (960 x 192 RGBA, 5 x 192x192 circular states)
  - docs/images/brawler_preview.png      (visual verification sheet)
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
    extract_from_black_bg,
    make_calm_breath_variant,
    place_grounded,
)

ROOT = Path(__file__).resolve().parent.parent
REF_PATH = ROOT / "assets/sprites/behemoth/behemoth_reference.png"
OUT_HERO = ROOT / "assets/textures/player_borzo.png"
OUT_PORTRAIT = ROOT / "assets/textures/portrait_borzo.png"
OUT_PREVIEW = ROOT / "docs/images/brawler_preview.png"

COLS = 8
ROWS = 4
BODY_H = 170  # Broad pit-champion stands ~6px (~1 world px) taller than lithe Velmira/Sylvara


def make_brawler_side_blink(cell_im: Image.Image) -> Image.Image:
    """Close Behemoth's side-facing eye calmly for natural blink frame."""
    out = cell_im.copy()
    arr = np.array(out)
    # Locate bright sclera/iris pixel in head area (`y: 48..88, x: 108..148`)
    sub = arr[48:88, 108:148]
    r, g, b, a = sub[:, :, 0].astype(int), sub[:, :, 1].astype(int), sub[:, :, 2].astype(int), sub[:, :, 3]
    eye = (a > 180) & (r > 185) & (g > 140) & (b > 125)
    ys, xs = np.where(eye)
    if len(xs) > 0:
        for y, x in zip(ys + 48, xs + 108):
            arr[y, x] = (52, 34, 30, arr[y, x, 3])
    return Image.fromarray(arr, mode="RGBA")


def _frame_portrait_crop(ref: Image.Image, box: tuple[int, int, int, int], P: int = 192) -> Image.Image:
    """Extract a close-up portrait box from black bg and fill 192x192 circle cleanly."""
    im = extract_from_black_bg(ref, box, bg_thresh=11, hole_thresh=-1, min_speck=24)
    # Scale so height/width covers medallion nicely
    s = max(P / float(max(im.width, 1)), (P * 0.96) / float(max(im.height, 1)))
    nw, nh = int(round(im.width * s)), int(round(im.height * s))
    im_s = im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (P, P), (0, 0, 0, 0))
    canvas.alpha_composite(im_s, ((P - nw) // 2, P - nh + 4))
    return canvas


def build_behemoth_portrait(ref: Image.Image) -> Image.Image:
    """Build 5-state 192x192 circular HUD portrait from Behemoth's sharp close-up portrait!"""
    P = 192
    # Top-right Box 1 (`(1002, 10, 1242, 141)`) = ultra-crisp fierce front-3/4 close-up!
    # Using this locked base across all 5 states keeps 0px jump between HUD states!
    base_idle = _frame_portrait_crop(ref, (1002, 10, 1242, 141), P)

    bg_in = (46, 28, 26)
    bg_out = (16, 10, 11)
    strip = Image.new("RGBA", (P * 5, P), (0, 0, 0, 0))

    # 0: idle_a
    strip.alpha_composite(apply_medallion_backdrop(base_idle, bg_in, bg_out), (0, 0))

    # 1: idle_b (calm subtle breath — zero wild jump!)
    b1 = base_idle.crop((2, 2, P - 2, P - 1)).resize((P, P), Image.Resampling.LANCZOS)
    strip.alpha_composite(apply_medallion_backdrop(b1, bg_in, bg_out), (P, 0))

    # 2: blink (close eyeballs at `y: 126..137, x: 82..104 | 132..150` cleanly under furrowed brow!)
    def _is_behemoth_eye(x: int, y: int, r: int, g: int, b: int) -> bool:
        if not (126 <= y <= 137 and ((82 <= x <= 104) or (132 <= x <= 150))):
            return False
        return (r > 175 and g > 150 and b > 140) or (r > 115 and r > g + 45)

    f2 = base_idle.copy()
    arr2 = np.array(f2)
    for y in range(126, 138):
        for x in range(82, 151):
            r, g, b, a = int(arr2[y, x, 0]), int(arr2[y, x, 1]), int(arr2[y, x, 2]), int(arr2[y, x, 3])
            if a > 180 and _is_behemoth_eye(x, y, r, g, b):
                arr2[y, x] = (92, 58, 50, a)
    f2 = Image.fromarray(arr2, mode="RGBA")
    strip.alpha_composite(apply_medallion_backdrop(f2, bg_in, bg_out), (P * 2, 0))

    # 3: low_hp (fierce glowing crimson eyes + battle-blood vignette, 0px jump!)
    f3 = base_idle.copy()
    px3 = f3.load()
    for y in range(P):
        for x in range(P):
            r, g, b, a = px3[x, y]
            if a < 20:
                continue
            if _is_behemoth_eye(x, y, r, g, b):
                px3[x, y] = (255, min(255, int(g * 0.35 + 36)), int(b * 0.25), a)
            else:
                dist = math.hypot((x - P * 0.50) / (P * 0.5), (y - P * 0.52) / (P * 0.5))
                vign = min(0.46, max(0.0, (dist - 0.28) * 0.68))
                nr = int(r * (1.0 - vign * 0.18) + 185 * vign * 0.38)
                ng = int(g * (1.0 - vign * 0.54))
                nb = int(b * (1.0 - vign * 0.52))
                px3[x, y] = (min(255, nr), max(0, ng), max(0, nb), a)
    strip.alpha_composite(apply_medallion_backdrop(f3, (58, 22, 24), (22, 8, 10)), (P * 3, 0))

    # 4: hurt (recoil tilt + crimson hit flash on closed-eye wince!)
    f4 = f2.rotate(-4.0, resample=Image.Resampling.BICUBIC, expand=False)
    px4 = f4.load()
    for y in range(P):
        for x in range(P):
            r, g, b, a = px4[x, y]
            if a < 20:
                continue
            px4[x, y] = (min(255, int(r * 1.18 + 26)), int(g * 0.82), int(b * 0.82), a)
    strip.alpha_composite(apply_medallion_backdrop(f4, (64, 22, 24), (24, 8, 10)), (P * 4, 0))
    return strip


def main() -> None:
    assert REF_PATH.exists(), f"Missing reference sheet: {REF_PATH}"
    ref = Image.open(REF_PATH).convert("RGBA")

    # --- ROW 1: Ultra-crisp Full-Body 4-Directional Idles ---
    idle_down_raw  = extract_from_black_bg(ref, (28, 12, 264, 345))
    idle_right_raw = extract_from_black_bg(ref, (300, 12, 490, 345))  # Faces RIGHT (+X)!
    idle_up_raw    = extract_from_black_bg(ref, (772, 12, 976, 345))

    # --- ROW 2: 4-Directional Walks ---
    walk_r0 = extract_from_black_bg(ref, (16, 448, 153, 607))
    walk_r1 = extract_from_black_bg(ref, (159, 446, 276, 607))
    # Flip WALK LEFT horizontally to get 2 additional right-facing stride frames for a 4-frame cycle!
    walk_r2 = extract_from_black_bg(ref, (317, 448, 437, 607)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    walk_r3 = extract_from_black_bg(ref, (451, 448, 558, 607)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)

    walk_u0 = extract_from_black_bg(ref, (634, 446, 736, 607))
    walk_u1 = extract_from_black_bg(ref, (752, 447, 843, 607))

    walk_d0 = extract_from_black_bg(ref, (896, 443, 1016, 607))
    walk_d1 = extract_from_black_bg(ref, (1026, 443, 1168, 607))

    # --- ROW 3: 3-Hit Punch Combo (`Attack 1`, `Attack 2`, `Attack 3`) + `Dash` ---
    atk1_0 = extract_from_black_bg(ref, (15, 665, 148, 814))
    atk1_1 = extract_from_black_bg(ref, (158, 664, 282, 814))
    atk2_0 = extract_from_black_bg(ref, (309, 666, 459, 814))
    atk2_1 = extract_from_black_bg(ref, (464, 660, 606, 814))
    atk3_0 = extract_from_black_bg(ref, (624, 664, 751, 814))
    atk3_1 = extract_from_black_bg(ref, (754, 650, 902, 814))
    dash_raw = extract_from_black_bg(ref, (940, 658, 1202, 814))

    # Fixed combat scale from `atk1_0` so `atk3_1` (pelt flying upward) never shrinks Behemoth!
    atk_scale = (BODY_H * 0.96) / float(atk1_0.height)

    # --- ROW 4 & 5: Guard, Hurt, Kneeling Fall & Prone Dead ---
    block_0 = extract_from_black_bg(ref, (33, 854, 147, 987))
    block_1 = extract_from_black_bg(ref, (173, 853, 284, 987))
    die_kneel  = extract_from_black_bg(ref, (657, 869, 852, 987))
    die_fallen = extract_from_black_bg(ref, (765, 1045, 1233, 1197))

    # Build calm grounded idle bases & subtle breathing variants (boots 100% locked!)
    f_idle0 = place_grounded(idle_right_raw, BODY_H)
    f_idle1 = make_calm_breath_variant(f_idle0, chest_lift_px=1.5, cape_sway_px=0.9)
    f_idle2 = make_calm_breath_variant(f_idle0, chest_lift_px=0.8, cape_sway_px=1.3)
    f_idle3 = make_brawler_side_blink(f_idle0)

    f_down0 = place_grounded(idle_down_raw, BODY_H, center_x_box=True)
    f_down1 = make_calm_breath_variant(f_down0, chest_lift_px=1.5, cape_sway_px=0.7)

    f_up0 = place_grounded(idle_up_raw, BODY_H, center_x_box=True)
    f_up1 = make_calm_breath_variant(f_up0, chest_lift_px=1.5, cape_sway_px=0.8)

    f_dash0 = place_grounded(dash_raw, fixed_scale=atk_scale, dx=4)
    f_dash1 = make_calm_breath_variant(f_dash0, chest_lift_px=1.2, cape_sway_px=1.8)

    frames: list[Image.Image] = [
        # Row 0 (0..7): Calm 4-frame Side Idle + 4-frame Right-Facing Walk (consistent fur-pelt flow!)
        f_idle0,
        f_idle1,
        f_idle2,
        f_idle3,
        place_grounded(walk_r0, BODY_H),
        f_idle0,
        place_grounded(walk_r1, BODY_H),
        f_idle2,

        # Row 1 (8..15): Front Idle (2f) + Front Walk (4f) + Back Idle (2f)
        f_down0,
        f_down1,
        place_grounded(walk_d0, BODY_H, center_x_box=True),
        f_down0,
        place_grounded(walk_d1, BODY_H, center_x_box=True),
        f_down1,
        f_up0,
        f_up1,

        # Row 2 (16..23): Back Walk (4f) + Attack 1 Jab (2f) + Attack 2 Cross (2f)
        place_grounded(walk_u0, BODY_H, center_x_box=True),
        f_up0,
        place_grounded(walk_u1, BODY_H, center_x_box=True),
        f_up1,
        place_grounded(atk1_0, fixed_scale=atk_scale),
        place_grounded(atk1_1, fixed_scale=atk_scale, dx=2),
        place_grounded(atk2_0, fixed_scale=atk_scale),
        place_grounded(atk2_1, fixed_scale=atk_scale, dx=8),

        # Row 3 (24..31): Attack 3 Uppercut (2f) + Guard + Shoulder Dash (2f) + Hurt + Death (2f)
        place_grounded(atk3_0, fixed_scale=atk_scale),
        place_grounded(atk3_1, fixed_scale=atk_scale, dx=6),
        place_grounded(block_0, BODY_H - 4),
        f_dash0,
        f_dash1,
        place_grounded(block_1, BODY_H - 4, dx=-4),
        place_grounded(die_kneel, target_h=126, center_x_box=True),
        place_grounded(die_fallen, target_h=72, center_x_box=True),
    ]
    assert len(frames) == 32

    sheet = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for idx, frm in enumerate(frames):
        sheet.alpha_composite(frm, ((idx % COLS) * CELL, (idx // COLS) * CELL))
    OUT_HERO.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT_HERO)

    portrait_strip = build_behemoth_portrait(ref)
    portrait_strip.save(OUT_PORTRAIT)

    prev = Image.new("RGBA", (1320, 860), (26, 22, 24, 255))
    pd = ImageDraw.Draw(prev)
    for i in range(5):
        pf = portrait_strip.crop((i * 192, 0, (i + 1) * 192, 192)).resize((104, 104), Image.Resampling.LANCZOS)
        px, py = 18 + i * 118, 14
        prev.alpha_composite(pf, (px, py))
        pd.ellipse((px - 2, py - 2, px + 106, py + 106), outline=(238, 168, 72, 255), width=2)
    pd.text((630, 52), "BEHEMOTH (PIT-BRAWLER) - 32x 224x224 + 5x 192x192 HUD Portrait", fill=(245, 224, 206, 255))

    labels = [
        "0:idle0", "1:idle1", "2:idle2", "3:blink", "4:walk0", "5:walk1", "6:walk2", "7:walk3",
        "8:down_i0", "9:down_i1", "10:down_w0", "11:down_w1", "12:down_w2", "13:down_w3", "14:up_i0", "15:up_i1",
        "16:up_w0", "17:up_w1", "18:up_w2", "19:up_w3", "20:jab_0", "21:jab_1", "22:cross_0", "23:cross_1",
        "24:up_cut0", "25:up_cut1", "26:guard", "27:dash0", "28:dash1", "29:hurt", "30:die_kneel", "31:die_fall",
    ]
    for idx, frm in enumerate(frames):
        c, r = idx % 8, idx // 8
        x, y = 18 + c * 160, 140 + r * 176
        pd.rectangle([x, y, x + 148, y + 148], fill=(38, 32, 34, 255), outline=(78, 62, 64, 255))
        gy = y + int(round(GROUND_Y * (148.0 / CELL)))
        pd.line([(x + 8, gy), (x + 140, gy)], fill=(235, 165, 75, 130), width=1)
        prev.alpha_composite(frm.resize((148, 148), Image.Resampling.LANCZOS), (x, y))
        pd.text((x + 16, y + 152), labels[idx], fill=(232, 212, 198, 255))

    OUT_PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    prev.save(OUT_PREVIEW)
    print(f"Wrote {OUT_HERO} ({sheet.size}) and {OUT_PORTRAIT} ({portrait_strip.size})")


if __name__ == "__main__":
    main()
