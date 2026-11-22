#!/usr/bin/env python3
"""Build Knight's 32-frame (8x4 @ 224x224) sheet & 5-state 192x192 HUD portrait
directly from `assets/sprites/knight/knight_reference.png` (matching Velmira's
exact pipeline, uniform `BODY_H = 164`, `GROUND_Y = 200`, Golden-Lion Shield &
Crimson-Gold Heraldic Cape!).

Outputs:
  - assets/textures/player_bahman.png    (1792 x 896 RGBA, 8 cols x 4 rows of 224x224)
  - assets/textures/portrait_bahman.png  (960 x 192 RGBA, 5 x 192x192 circular states)
  - docs/images/knight_preview.png       (visual verification sheet)
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
    trim_rgba,
)

ROOT = Path(__file__).resolve().parent.parent
REF_PATH = ROOT / "assets/sprites/knight/knight_reference.png"
OUT_HERO = ROOT / "assets/textures/player_bahman.png"
OUT_PORTRAIT = ROOT / "assets/textures/portrait_bahman.png"
OUT_PREVIEW = ROOT / "docs/images/knight_preview.png"

COLS = 8
ROWS = 4
BODY_H = 164


def build_knight_portrait(shield_stance_im: Image.Image) -> Image.Image:
    """Build 5-state 192x192 circular HUD portrait from Knight's high-res helmet,
    crimson-gold cape collar, fluted pauldron & Golden-Lion Heater Shield!
    """
    P = 192
    # Tight heroic bust crop: Greathelm + Fluted Pauldron + Crimson Cape + Lion Shield top!
    w, h = shield_stance_im.size
    bust = shield_stance_im.crop((int(w * 0.36), 0, int(w * 0.96), int(h * 0.46)))
    s = (P * 1.34) / float(max(bust.width, bust.height))
    bw, bh = int(round(bust.width * s)), int(round(bust.height * s))
    bust_s = bust.resize((bw, bh), Image.Resampling.LANCZOS)

    base_raw = Image.new("RGBA", (P, P), (0, 0, 0, 0))
    base_raw.alpha_composite(bust_s, ((P - bw) // 2 + 2, 16))

    # Locate exact dark visor opening inside the Greathelm (`alpha > 200` and dark interior)
    arr_b = np.array(base_raw)
    ys_h, _ = np.where(arr_b[:, :, 3] > 200)
    top_y = int(ys_h.min()) if len(ys_h) else 24
    # Visor slit sits ~34px below top of Greathelm on the right side of the faceplate
    visor_box = arr_b[top_y + 20 : top_y + 52, 76:132]
    dark_visor = (visor_box[:, :, 3] > 220) & (visor_box[:, :, :3].max(axis=2) < 42)
    vy_s, vx_s = np.where(dark_visor)
    if len(vx_s) > 0:
        vx = int(np.median(vx_s)) + 76
        vy = int(np.median(vy_s)) + top_y + 20
    else:
        vx, vy = 104, top_y + 34

    bg_in = (42, 22, 28)
    bg_out = (14, 12, 20)
    strip = Image.new("RGBA", (P * 5, P), (0, 0, 0, 0))

    # 0: idle_a (stoic helmeted Knight + Lion Shield)
    strip.alpha_composite(apply_medallion_backdrop(base_raw, bg_in, bg_out), (0, 0))

    # 1: idle_b (calm subtle breath — helmet stays ON!)
    b1 = base_raw.crop((2, 2, P - 2, P - 1)).resize((P, P), Image.Resampling.LANCZOS)
    strip.alpha_composite(apply_medallion_backdrop(b1, bg_in, bg_out), (P, 0))

    # 2: blink (subtle visor shadow sweep across upper helmet slit)
    f2 = base_raw.copy()
    arr2 = np.array(f2)
    for y in range(max(0, vy - 10), min(P, vy + 12)):
        for x in range(max(0, vx - 22), min(P, vx + 22)):
            if arr2[y, x, 3] > 180 and int(arr2[y, x, :3].max()) < 95:
                arr2[y, x, :3] = (arr2[y, x, :3].astype(np.float32) * 0.62).astype(np.uint8)
    f2 = Image.fromarray(arr2, mode="RGBA")
    strip.alpha_composite(apply_medallion_backdrop(f2, bg_in, bg_out), (P * 2, 0))

    # 3: low_hp (smoldering crimson-amber ember INSIDE visor slit + battle vignette!)
    f3 = base_raw.copy()
    px3 = f3.load()
    for y in range(P):
        for x in range(P):
            r, g, b, a = px3[x, y]
            if a < 20:
                continue
            dist = math.hypot((x - P * 0.50) / (P * 0.5), (y - P * 0.48) / (P * 0.5))
            vign = min(0.45, max(0.0, (dist - 0.30) * 0.65))
            nr = int(r * (1.0 - vign * 0.18) + 175 * vign * 0.35)
            ng = int(g * (1.0 - vign * 0.48))
            nb = int(b * (1.0 - vign * 0.48))
            px3[x, y] = (min(255, nr), max(0, ng), max(0, nb), a)
    d3 = ImageDraw.Draw(f3)
    d3.ellipse((vx - 5, vy - 3, vx + 5, vy + 3), fill=(225, 48, 36, 215))
    d3.ellipse((vx - 2, vy - 1, vx + 3, vy + 2), fill=(255, 205, 115, 245))
    strip.alpha_composite(apply_medallion_backdrop(f3, (56, 20, 24), (20, 8, 12)), (P * 3, 0))

    # 4: hurt (armored recoil tilt + warm steel hit flash)
    f4 = base_raw.rotate(-4.0, resample=Image.Resampling.BICUBIC, expand=False)
    px4 = f4.load()
    for y in range(P):
        for x in range(P):
            r, g, b, a = px4[x, y]
            if a < 20:
                continue
            px4[x, y] = (min(255, int(r * 1.15 + 24)), min(255, int(g * 1.04 + 10)), int(b * 0.90), a)
    strip.alpha_composite(apply_medallion_backdrop(f4, (62, 24, 24), (22, 10, 14)), (P * 4, 0))
    return strip


def build_knight_death_poses(
    dash_fin0: Image.Image, idle_0: Image.Image, base_scale: float
) -> tuple[Image.Image, Image.Image]:
    """Build 2-stage collapse death (`die_kneel`, `die_fallen`) at FULL 1:1 Knight scale
    directly from Knight's authentic `knight_reference.png` sprite art!
    """
    # Stage 1 (`die_kneel`): Forward-bowed low collapse on one knee
    kneel_rot = trim_rgba(dash_fin0.rotate(-22.0, resample=Image.Resampling.BICUBIC, expand=True))
    f_kneel = place_grounded(kneel_rot, fixed_scale=base_scale * 0.90, center_x_box=True)

    # Stage 2 (`die_fallen`): Full-sized armored Knight collapsed prone on stone floor!
    fallen_rot = trim_rgba(idle_0.rotate(-84.0, resample=Image.Resampling.BICUBIC, expand=True))
    f_fallen = place_grounded(fallen_rot, fixed_scale=base_scale * 0.95, center_x_box=True)
    return f_kneel, f_fallen


def main() -> None:
    assert REF_PATH.exists(), f"Missing reference sheet: {REF_PATH}"
    ref = Image.open(REF_PATH).convert("RGBA")

    # --- ROW 1: Native 2-Frame Calm Idle, 3-Frame Walk, & Horizontal Slash ---
    idle_0 = extract_from_black_bg(ref, (20, 58, 164, 231))
    idle_1 = extract_from_black_bg(ref, (191, 62, 321, 231))

    walk_0 = extract_from_black_bg(ref, (412, 62, 565, 231))
    walk_1 = extract_from_black_bg(ref, (587, 62, 716, 231))
    walk_2 = extract_from_black_bg(ref, (737, 62, 870, 231))

    # Fixed character scale anchored to `idle_0` (`162px` -> `BODY_H = 164`) so overhead
    # sword coils or wide slashes NEVER shrink the Knight by even 1 pixel!
    base_scale = BODY_H / float(idle_0.height)

    atk1_2 = extract_from_black_bg(ref, (1326, 84, 1514, 231))

    # --- ROW 2: Overhead Sword Coil (`Atk2_1`) & Sweeping Silver Crescent Slash (`Atk3_0..2`) ---
    atk2_1 = extract_from_black_bg(ref, (215, 310, 401, 494))
    atk3_0 = extract_from_black_bg(ref, (789, 330, 972, 494))
    atk3_1 = extract_from_black_bg(ref, (1010, 318, 1260, 494))
    atk3_2 = extract_from_black_bg(ref, (1274, 362, 1505, 494))

    # --- ROW 3: Shield-Wall Dash (2f) & Dash Finish (2f) ---
    dash_0 = extract_from_black_bg(ref, (50, 576, 272, 736))
    # Crop `dash_1` starting at `x=405` so the Knight + trailing silver speed-streaks fit cleanly inside 224x224!
    dash_1 = extract_from_black_bg(ref, (405, 578, 692, 736))
    dash_fin0 = extract_from_black_bg(ref, (832, 566, 1088, 737))
    dash_fin1 = extract_from_black_bg(ref, (1182, 568, 1502, 737))

    # --- ROW 4: Golden-Lion Shield Raise (2f, drawn ~11% larger on sheet -> normalize to BODY_H!) ---
    shield_0 = extract_from_black_bg(ref, (42, 794, 254, 983))
    shield_1 = extract_from_black_bg(ref, (316, 800, 532, 983))

    # Build calm grounded idles (using BOTH native `Idle` frames + gentle intermediate breath!)
    f_idle0 = place_grounded(idle_0, fixed_scale=base_scale)
    f_idle1 = make_calm_breath_variant(f_idle0, chest_lift_px=0.9, cape_sway_px=0.7)
    f_idle2 = place_grounded(idle_1, fixed_scale=base_scale)
    f_idle3 = make_calm_breath_variant(f_idle2, chest_lift_px=0.6, cape_sway_px=0.5)

    f_w0 = place_grounded(walk_0, fixed_scale=base_scale)
    f_w1 = place_grounded(walk_1, fixed_scale=base_scale)
    f_w2 = place_grounded(walk_2, fixed_scale=base_scale)

    # 3/4-Front Lion-Shield ready stance for `down_idle` + calm breathing
    f_down0 = place_grounded(shield_0, BODY_H)
    f_down1 = make_calm_breath_variant(f_down0, chest_lift_px=1.2, cape_sway_px=0.7)

    f_die_kneel, f_die_fallen = build_knight_death_poses(dash_fin0, idle_0, base_scale)

    frames: list[Image.Image] = [
        # Row 0 (0..7): Calm 4-frame Side Idle + 4-frame Grounded Walk
        f_idle0,
        f_idle1,
        f_idle2,
        f_idle3,
        f_w0,
        f_w1,
        f_w2,
        f_w1,

        # Row 1 (8..15): Front-3/4 Idle (2f) + Walk (4f) + Up Idle (2f)
        f_down0,
        f_down1,
        f_w0,
        f_w1,
        f_w2,
        f_w1,
        f_idle0,
        f_idle2,

        # Row 2 (16..23): Up Walk (4f) + Greatsword Crescent Slash Combo (4f)
        f_w0,
        f_w1,
        f_w2,
        f_w1,
        place_grounded(atk2_1, fixed_scale=base_scale, dx=-2),   # 20: Overhead sword coil
        place_grounded(atk3_1, fixed_scale=base_scale, dx=8),    # 21: Wide downward slash
        place_grounded(atk3_2, fixed_scale=base_scale, dx=10),   # 22: Silver crescent cleave!
        place_grounded(atk1_2, fixed_scale=base_scale, dx=4),    # 23: Horizontal follow-through!

        # Row 3 (24..31): Golden-Lion Shield Guard (2f) + Dash (2f) + Thrust + Hurt + Collapse Death (2f)
        f_down0,                                                  # 24: Shield Raise 0
        place_grounded(shield_1, BODY_H, dx=2),                   # 25: Shield Raise 1 (locked guard!)
        place_grounded(dash_0, fixed_scale=base_scale, dx=2),     # 26: Dash start
        place_grounded(dash_1, fixed_scale=base_scale, dx=6),     # 27: Shield-Wall Charge + speed lines!
        place_grounded(dash_fin0, fixed_scale=base_scale, dx=2),  # 28: Dash finish sword lunge
        place_grounded(atk3_0, fixed_scale=base_scale, dx=-4),    # 29: Hurt recoil
        f_die_kneel,                                              # 30: Kneeling collapse
        f_die_fallen,                                             # 31: Fallen prone on ground
    ]
    assert len(frames) == 32

    sheet = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for idx, frm in enumerate(frames):
        sheet.alpha_composite(frm, ((idx % COLS) * CELL, (idx // COLS) * CELL))
    OUT_HERO.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT_HERO)

    portrait_strip = build_knight_portrait(shield_0)
    portrait_strip.save(OUT_PORTRAIT)

    prev = Image.new("RGBA", (1320, 860), (20, 22, 30, 255))
    pd = ImageDraw.Draw(prev)
    for i in range(5):
        pf = portrait_strip.crop((i * 192, 0, (i + 1) * 192, 192)).resize((104, 104), Image.Resampling.LANCZOS)
        px, py = 18 + i * 118, 14
        prev.alpha_composite(pf, (px, py))
        pd.ellipse((px - 2, py - 2, px + 106, py + 106), outline=(232, 188, 92, 255), width=2)
    pd.text((630, 52), "GOLDEN-LION KNIGHT (SER BAHMAN) - 32x 224x224 + 5x 192x192 HUD Portrait", fill=(235, 228, 215, 255))

    labels = [
        "0:idle0", "1:idle1", "2:idle2", "3:idle3", "4:walk0", "5:walk1", "6:walk2", "7:walk3",
        "8:down_i0", "9:down_i1", "10:down_w0", "11:down_w1", "12:down_w2", "13:down_w3", "14:up_i0", "15:up_i1",
        "16:up_w0", "17:up_w1", "18:up_w2", "19:up_w3", "20:atk_coil", "21:atk_cut", "22:atk_arc", "23:atk_fin",
        "24:guard_0", "25:guard_1", "26:dash_0", "27:dash_1", "28:lunge", "29:hurt", "30:die_kneel", "31:die_fall",
    ]
    for idx, frm in enumerate(frames):
        c, r = idx % 8, idx // 8
        x, y = 18 + c * 160, 140 + r * 176
        pd.rectangle([x, y, x + 148, y + 148], fill=(30, 33, 44, 255), outline=(72, 76, 96, 255))
        gy = y + int(round(GROUND_Y * (148.0 / CELL)))
        pd.line([(x + 8, gy), (x + 140, gy)], fill=(232, 188, 92, 130), width=1)
        prev.alpha_composite(frm.resize((148, 148), Image.Resampling.LANCZOS), (x, y))
        pd.text((x + 16, y + 152), labels[idx], fill=(224, 220, 212, 255))

    OUT_PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    prev.save(OUT_PREVIEW)
    print(f"Wrote {OUT_HERO} ({sheet.size}) and {OUT_PORTRAIT} ({portrait_strip.size})")


if __name__ == "__main__":
    main()
