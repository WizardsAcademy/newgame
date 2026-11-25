#!/usr/bin/env python3
"""Generate crisp, sculpted 64x64 pixel-art hero sprite sheets & 320x64 portraits:
  1. Behemoth (`player_behemoth.png` 1024x64, 16f + `portrait_behemoth.png` 320x64):
     - Savage muscular Barbarian: long wild hair mane + long thick beard, NO forehead
       ribbon, NO iron gauntlets (bare muscular arms & bare knuckles), shirtless huge
       sculpted pecs/abs/shoulders, caveman shaggy beast-fur loincloth & fur boots.
  2. Knight (`player_knight.png` 1024x64, 16f + `portrait_knight.png` 320x64):
     - Classic gleaming Silver-Steel plate armor with Gold trim, Royal Blue cape with
       deep Navy-Blue stripes, Golden Lion Face crest on his shield, and the silver-and-brass
       Crusader Great Helm (`image-18.png` reference).
  3. Sylvara (`player_sylvara.png` 960x64, 15f + `portrait_sylvara.png` 320x64):
     - Curvy Medieval-Fantasy Elf Huntress in Emerald Green, Crisp White off-shoulder blouse,
       & Brown Leather corset/boots, hourglass "nice body" figure & prominent sculpted bust.
  4. Noa (`player_noa.png` 1024x64, 16f + `portrait_noa.png` 320x64):
     - Royal Aristocrat Vampire: mostly White Victorian-noble ballgown with gold brocade &
       crimson velvet trim, ornate Gold-and-Ruby Crown/Tiara, and Jeweled Ruby Necklace.
"""

from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
TEX_DIR = REPO_ROOT / "assets" / "textures"

OUT = (14, 12, 22, 255)  # Deep selout (never #000000!)


def put(im: Image.Image, x: int, y: int, col: tuple[int, int, int, int]) -> None:
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), col)


def pill(d: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int, r: int, fill, outline=OUT) -> None:
    if x1 < x0:
        x0, x1 = x1, x0
    if y1 < y0:
        y0, y1 = y1, y0
    d.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=fill, outline=outline)


# ==============================================================================
# 1. BEHEMOTH — SAVAGE MUSCULAR BARBARIAN (16 frames x 64x64)
# ==============================================================================

def draw_behemoth_frame(f: int) -> Image.Image:
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    SKIN_SH = (154, 92, 60, 255)
    SKIN_MD = (204, 134, 90, 255)
    SKIN_HI = (238, 172, 124, 255)
    HAIR_DK = (48, 26, 16, 255)
    HAIR_MD = (84, 46, 26, 255)
    HAIR_HI = (126, 74, 42, 255)
    FUR_DK = (68, 50, 34, 255)
    FUR_MD = (114, 86, 58, 255)
    FUR_HI = (176, 144, 106, 255)
    BONE = (240, 228, 200, 255)
    SCAR = (172, 58, 58, 255)
    EYE_W = (248, 244, 232, 255)
    FIRE_O = (246, 112, 30, 255)
    FIRE_Y = (255, 214, 74, 255)

    cx = 32
    bob = 1 if f in (1, 2, 9, 11, 12, 14, 15) else 0
    if f == 7:
        cx = 35
    elif f == 8:
        cx = 29

    # --- FRONT (`10..12`) & BACK (`13..15`) ---
    if f >= 10:
        is_up = f >= 13
        step = -2 if f in (11, 14) else (2 if f in (12, 15) else 0)
        ly = 53 - (1 if step < 0 else 0)
        ry = 53 - (1 if step > 0 else 0)

        if not is_up:
            # Shaggy long wild barbarian mane flaring behind bare shoulders
            d.polygon([
                (cx - 11, 9 + bob), (cx + 11, 9 + bob),
                (cx + 15, 22 + bob), (cx + 13, 31 + bob),
                (cx - 13, 31 + bob), (cx - 15, 22 + bob)
            ], fill=HAIR_DK, outline=OUT)

        # Thick muscular quads/calves + shaggy fur caveman boots (`ground_y = 54`)
        pill(d, cx - 9, 38 + bob, cx - 3, ly - 4, 2, SKIN_MD)
        pill(d, cx + 3, 38 + bob, cx + 9, ry - 4, 2, SKIN_MD)
        put(im, cx - 6, 41 + bob, SKIN_HI)
        put(im, cx + 6, 41 + bob, SKIN_HI)
        d.rectangle([cx - 10, ly - 6, cx - 2, ly - 4], fill=FUR_HI, outline=OUT)
        pill(d, cx - 10, ly - 4, cx - 2, ly, 2, FUR_DK)
        d.rectangle([cx + 2, ry - 6, cx + 10, ry - 4], fill=FUR_HI, outline=OUT)
        pill(d, cx + 2, ry - 4, cx + 10, ry, 2, FUR_DK)

        # Caveman jagged beast-pelt loincloth + skull/fang clasp!
        d.polygon([
            (cx - 11, 33 + bob), (cx + 11, 33 + bob),
            (cx + 13, 41 + bob), (cx + 8, 44 + bob), (cx + 4, 40 + bob),
            (cx, 45 + bob), (cx - 4, 40 + bob), (cx - 8, 44 + bob), (cx - 13, 41 + bob)
        ], fill=FUR_MD, outline=OUT)
        d.line([(cx - 9, 34 + bob), (cx + 9, 34 + bob)], fill=FUR_HI)
        if not is_up:
            d.polygon([(cx - 3, 33 + bob), (cx + 3, 33 + bob), (cx + 2, 37 + bob), (cx - 2, 37 + bob)],
                      fill=BONE, outline=OUT)

        # HUGE Sculpted Bare Muscular Torso (rounded deltoids, broad pecs, 6-pack abs!)
        d.polygon([
            (cx - 13, 19 + bob), (cx + 13, 19 + bob),
            (cx + 14, 25 + bob), (cx + 10, 34 + bob),
            (cx - 10, 34 + bob), (cx - 14, 25 + bob)
        ], fill=SKIN_MD, outline=OUT)

        # Bulging round deltoids + bare muscular biceps & bare fists (NO gauntlets!)
        la_y = 20 + bob + (1 if step > 0 else 0)
        ra_y = 20 + bob + (1 if step < 0 else 0)
        d.ellipse([cx - 18, la_y, cx - 11, la_y + 8], fill=SKIN_HI, outline=OUT)
        pill(d, cx - 18, la_y + 6, cx - 12, la_y + 15, 2, SKIN_MD)
        put(im, cx - 15, la_y + 8, SKIN_HI)
        d.ellipse([cx + 11, ra_y, cx + 18, ra_y + 8], fill=SKIN_HI, outline=OUT)
        pill(d, cx + 12, ra_y + 6, cx + 18, ra_y + 15, 2, SKIN_MD)
        put(im, cx + 15, ra_y + 8, SKIN_HI)

        if not is_up:
            # Sculpted pectoral shading (soft muscle contour, no harsh black box!)
            d.rectangle([cx - 10, 21 + bob, cx - 2, 26 + bob], fill=SKIN_HI)
            d.rectangle([cx + 2, 21 + bob, cx + 10, 26 + bob], fill=SKIN_HI)
            d.line([(cx - 9, 27 + bob), (cx - 2, 27 + bob)], fill=SKIN_SH)
            d.line([(cx + 2, 27 + bob), (cx + 9, 27 + bob)], fill=SKIN_SH)
            d.line([(cx, 22 + bob), (cx, 33 + bob)], fill=SKIN_SH)
            for ay in (29, 31):
                d.line([(cx - 4, ay + bob), (cx - 2, ay + bob)], fill=SKIN_HI)
                d.line([(cx + 2, ay + bob), (cx + 4, ay + bob)], fill=SKIN_HI)
            d.line([(cx + 5, 22 + bob), (cx + 9, 25 + bob)], fill=SCAR)

            # Rounded barbarian head + wild hair crown (NO headband!) + long thick beard!
            pill(d, cx - 7, 8 + bob, cx + 7, 20 + bob, 4, SKIN_MD)
            d.polygon([
                (cx - 9, 14 + bob), (cx - 8, 7 + bob), (cx, 5 + bob),
                (cx + 8, 7 + bob), (cx + 9, 14 + bob), (cx + 5, 10 + bob),
                (cx, 11 + bob), (cx - 5, 10 + bob)
            ], fill=HAIR_MD, outline=OUT)
            d.line([(cx - 4, 7 + bob), (cx + 3, 7 + bob)], fill=HAIR_HI)
            # Fierce brow & eyes
            d.line([(cx - 5, 12 + bob), (cx - 2, 13 + bob)], fill=HAIR_DK)
            d.line([(cx + 2, 13 + bob), (cx + 5, 12 + bob)], fill=HAIR_DK)
            put(im, cx - 4, 14 + bob, EYE_W)
            put(im, cx - 3, 14 + bob, OUT)
            put(im, cx + 4, 14 + bob, EYE_W)
            put(im, cx + 3, 14 + bob, OUT)
            # Long thick barbarian beard & mustache cascading onto upper chest!
            d.polygon([
                (cx - 7, 16 + bob), (cx + 7, 16 + bob),
                (cx + 8, 22 + bob), (cx + 4, 27 + bob),
                (cx, 29 + bob), (cx - 4, 27 + bob), (cx - 8, 22 + bob)
            ], fill=HAIR_MD, outline=OUT)
            d.line([(cx - 3, 18 + bob), (cx - 2, 25 + bob)], fill=HAIR_HI)
            d.line([(cx + 3, 18 + bob), (cx + 2, 25 + bob)], fill=HAIR_DK)
        else:
            # Back view: sculpted V-taper back muscles + cascading wild barbarian hair mane!
            d.line([(cx, 22 + bob), (cx, 33 + bob)], fill=SKIN_SH)
            d.rectangle([cx - 10, 21 + bob, cx - 2, 26 + bob], fill=SKIN_HI)
            d.rectangle([cx + 2, 21 + bob, cx + 10, 26 + bob], fill=SKIN_HI)
            d.polygon([
                (cx - 10, 7 + bob), (cx, 5 + bob), (cx + 10, 7 + bob),
                (cx + 13, 25 + bob), (cx + 8, 29 + bob), (cx + 4, 26 + bob),
                (cx, 30 + bob), (cx - 4, 26 + bob), (cx - 8, 29 + bob), (cx - 13, 25 + bob)
            ], fill=HAIR_MD, outline=OUT)
            for hx in (-6, -2, 3, 7):
                d.line([(cx + hx, 9 + bob), (cx + hx, 25 + bob)], fill=HAIR_HI if hx < 0 else HAIR_DK)

        return im

    # --- SIDE / COMBAT FRAMES (`0..9`, facing RIGHT) ---
    # Shaggy long wild hair mane flowing down behind shoulders
    d.polygon([
        (cx - 11, 8 + bob), (cx + 2, 7 + bob),
        (cx - 2, 28 + bob), (cx - 8, 30 + bob),
        (cx - 11, 26 + bob), (cx - 15, 28 + bob), (cx - 13, 17 + bob)
    ], fill=HAIR_DK, outline=OUT)
    d.line([(cx - 10, 11 + bob), (cx - 12, 24 + bob)], fill=HAIR_MD, width=2)

    # Muscular legs + fur-cuffed hide boots (`ground_y = 54`)
    l_off = -3 if f == 1 else (3 if f == 2 else (-2 if f == 7 else 0))
    r_off = 3 if f == 1 else (-3 if f == 2 else (3 if f == 7 else 0))
    pill(d, cx - 7 + l_off, 38 + bob, cx - 1 + l_off, 48, 2, SKIN_SH)
    d.rectangle([cx - 8 + l_off, 46, cx + l_off, 48], fill=FUR_HI, outline=OUT)
    pill(d, cx - 8 + l_off, 48, cx + l_off, 53, 2, FUR_DK)

    pill(d, cx + 1 + r_off, 38 + bob, cx + 7 + r_off, 48, 2, SKIN_MD)
    put(im, cx + 4 + r_off, 41 + bob, SKIN_HI)
    d.rectangle([cx + r_off, 46, cx + 9 + r_off, 48], fill=FUR_HI, outline=OUT)
    pill(d, cx + r_off, 48, cx + 9 + r_off, 53, 2, FUR_DK)

    # Shaggy caveman fur loincloth + bone clasp
    d.polygon([
        (cx - 9, 33 + bob), (cx + 9, 33 + bob),
        (cx + 11, 41 + bob), (cx + 6, 44 + bob), (cx + 1, 40 + bob),
        (cx - 4, 44 + bob), (cx - 10, 40 + bob)
    ], fill=FUR_MD, outline=OUT)
    d.line([(cx - 7, 34 + bob), (cx + 7, 34 + bob)], fill=FUR_HI)
    d.rectangle([cx + 2, 33 + bob, cx + 6, 36 + bob], fill=BONE, outline=OUT)

    # Huge Sculpted Bare Muscular Torso (barrel chest + abs + scar!)
    d.polygon([
        (cx - 9, 18 + bob), (cx + 10, 18 + bob),
        (cx + 11, 25 + bob), (cx + 8, 34 + bob), (cx - 7, 34 + bob)
    ], fill=SKIN_MD, outline=OUT)
    d.ellipse([cx, 19 + bob, cx + 10, 27 + bob], fill=SKIN_HI)
    d.line([(cx + 1, 27 + bob), (cx + 9, 27 + bob)], fill=SKIN_SH)
    d.line([(cx + 3, 22 + bob), (cx + 7, 25 + bob)], fill=SCAR)
    for ay in (29, 31):
        d.line([(cx + 3, ay + bob), (cx + 6, ay + bob)], fill=SKIN_HI)
        put(im, cx + 2, ay + bob, SKIN_SH)

    # Rounded Barbarian Head + Wild Flowing Hair + Long Thick Beard (NO headband!)
    pill(d, cx - 5, 7 + bob, cx + 8, 19 + bob, 4, SKIN_MD)
    d.polygon([
        (cx - 9, 15 + bob), (cx - 7, 6 + bob), (cx + 2, 5 + bob),
        (cx + 8, 8 + bob), (cx + 4, 11 + bob), (cx - 3, 12 + bob)
    ], fill=HAIR_MD, outline=OUT)
    d.line([(cx - 4, 7 + bob), (cx + 3, 7 + bob)], fill=HAIR_HI)
    d.line([(cx + 2, 12 + bob), (cx + 6, 12 + bob)], fill=HAIR_DK)
    put(im, cx + 4, 13 + bob, EYE_W)
    put(im, cx + 5, 13 + bob, OUT)
    # Long thick beard reaching chest!
    d.polygon([
        (cx - 1, 15 + bob), (cx + 8, 15 + bob),
        (cx + 11, 22 + bob), (cx + 7, 28 + bob),
        (cx + 2, 27 + bob), (cx - 2, 21 + bob)
    ], fill=HAIR_MD, outline=OUT)
    d.line([(cx + 4, 17 + bob), (cx + 6, 25 + bob)], fill=HAIR_HI)

    # Bare Muscular Arms & Bare Fists (ZERO iron gloves, ZERO wristbands!)
    if f in (0, 1, 2, 9):
        ay = 20 + bob - (1 if f == 9 else 0)
        d.ellipse([cx - 10, ay, cx - 1, ay + 9], fill=SKIN_HI, outline=OUT)  # huge round shoulder/bicep
        pill(d, cx - 5, ay + 6, cx + 6, ay + 12, 2, SKIN_MD)
        d.ellipse([cx + 4, ay + 4, cx + 11, ay + 11], fill=SKIN_HI, outline=OUT)  # bare fist
    elif f == 3:
        d.ellipse([cx - 15, 19, cx - 5, 28], fill=SKIN_HI, outline=OUT)
        pill(d, cx - 15, 25, cx - 6, 32, 2, SKIN_MD)
    elif f == 4:
        d.ellipse([cx + 2, 19, cx + 14, 27], fill=SKIN_HI, outline=OUT)
        pill(d, cx + 12, 20, cx + 23, 26, 2, SKIN_MD)
        d.ellipse([cx + 21, 18, cx + 29, 27], fill=SKIN_HI, outline=OUT)
        d.arc([cx + 23, 15, cx + 31, 30], start=-65, end=65, fill=FIRE_Y, width=2)
    elif f == 5:
        d.ellipse([cx + 3, 18, cx + 16, 27], fill=SKIN_HI, outline=OUT)
        pill(d, cx + 14, 19, cx + 25, 26, 2, SKIN_MD)
        d.ellipse([cx + 23, 17, cx + 31, 27], fill=SKIN_HI, outline=OUT)
        d.arc([cx + 20, 12, cx + 32, 33], start=-70, end=70, fill=FIRE_O, width=2)
        d.arc([cx + 22, 14, cx + 31, 31], start=-55, end=55, fill=FIRE_Y, width=1)
    elif f == 6:
        d.ellipse([cx + 3, 15, cx + 14, 25], fill=SKIN_HI, outline=OUT)
        pill(d, cx + 9, 7, cx + 17, 18, 2, SKIN_MD)
        d.ellipse([cx + 9, 3, cx + 19, 11], fill=SKIN_HI, outline=OUT)
        d.arc([cx + 4, 3, cx + 28, 36], start=-85, end=65, fill=FIRE_O, width=2)
        d.arc([cx + 7, 5, cx + 26, 33], start=-75, end=50, fill=FIRE_Y, width=1)
    elif f == 7:
        d.ellipse([cx - 3, 18, cx + 14, 29], fill=SKIN_HI, outline=OUT)
        d.ellipse([cx + 9, 21, cx + 18, 30], fill=SKIN_MD, outline=OUT)
        d.arc([cx + 12, 14, cx + 27, 36], start=-70, end=70, fill=FIRE_Y, width=2)
    elif f == 8:
        d.ellipse([cx - 13, 18, cx - 4, 27], fill=SKIN_HI, outline=OUT)
        d.ellipse([cx + 5, 17, cx + 13, 25], fill=SKIN_MD, outline=OUT)

    return im


def make_behemoth_portraits() -> Image.Image:
    strip = Image.new("RGBA", (320, 64), (0, 0, 0, 0))
    SKIN_SH = (154, 92, 60, 255)
    SKIN_MD = (204, 134, 90, 255)
    SKIN_HI = (238, 172, 124, 255)
    HAIR_DK = (48, 26, 16, 255)
    HAIR_MD = (84, 46, 26, 255)
    HAIR_HI = (126, 74, 42, 255)
    SCAR = (172, 58, 58, 255)
    EYE_W = (248, 244, 232, 255)

    for i in range(5):
        fr = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(fr)
        d.ellipse([4, 4, 59, 59], fill=(44, 22, 16, 255), outline=OUT)
        d.polygon([(8, 58), (18, 43), (46, 43), (56, 58)], fill=SKIN_MD, outline=OUT)
        d.ellipse([10, 45, 25, 58], fill=SKIN_HI, outline=OUT)
        d.ellipse([39, 45, 54, 58], fill=SKIN_HI, outline=OUT)
        # Wild shaggy hair mane
        d.polygon([(7, 48), (9, 14), (21, 6), (43, 6), (55, 14), (57, 48)], fill=HAIR_DK, outline=OUT)
        d.polygon([(11, 44), (13, 16), (23, 8), (41, 8), (51, 16), (53, 44)], fill=HAIR_MD)
        # Rounded rugged barbarian face (NO headband!)
        pill(d, 18, 15, 46, 42, 7, SKIN_MD)
        d.ellipse([21, 17, 43, 24], fill=SKIN_HI)
        d.line([(37, 27), (42, 33)], fill=SCAR, width=2)
        d.polygon([(16, 21), (23, 10), (32, 15), (41, 10), (48, 21), (40, 16), (32, 18), (24, 16)],
                  fill=HAIR_MD, outline=OUT)
        d.line([(23, 12), (30, 14)], fill=HAIR_HI)
        d.line([(21, 23), (29, 24)], fill=HAIR_DK, width=2)
        d.line([(35, 24), (43, 23)], fill=HAIR_DK, width=2)
        if i == 2:
            d.line([(22, 27), (28, 27)], fill=OUT, width=2)
            d.line([(36, 27), (42, 27)], fill=OUT, width=2)
        elif i == 4:
            d.line([(22, 25), (28, 28)], fill=OUT, width=2)
            d.line([(28, 25), (22, 28)], fill=OUT, width=2)
            d.line([(36, 25), (42, 28)], fill=OUT, width=2)
            d.line([(42, 25), (36, 28)], fill=OUT, width=2)
        else:
            pill(d, 22, 25, 28, 29, 1, EYE_W)
            pill(d, 36, 25, 42, 29, 1, EYE_W)
            off = 1 if i == 1 else 0
            d.rectangle([24 + off, 26, 26 + off, 28], fill=OUT)
            d.rectangle([38 + off, 26, 40 + off, 28], fill=OUT)
        # Long thick braided/shaggy barbarian beard!
        d.polygon([(15, 33), (49, 33), (50, 47), (41, 56), (32, 59), (23, 56), (14, 47)], fill=HAIR_MD, outline=OUT)
        d.line([(22, 37), (25, 53)], fill=HAIR_HI, width=2)
        d.line([(41, 37), (39, 53)], fill=HAIR_DK, width=2)
        pill(d, 27, 36, 37, 40, 1, EYE_W if i in (3, 4) else SKIN_SH)
        strip.alpha_composite(fr, (i * 64, 0))
    return strip


# ==============================================================================
# 2. KNIGHT — SILVER & GOLD CRUSADER + BLUE CAPE + LION SHIELD (16 frames x 64x64)
# ==============================================================================

def draw_lion_shield(im: Image.Image, d: ImageDraw.ImageDraw, x0: int, y0: int, w: int, h: int, cols: dict) -> None:
    pts = [
        (x0, y0), (x0 + w, y0),
        (x0 + w, y0 + int(h * 0.62)),
        (x0 + w // 2, y0 + h),
        (x0, y0 + int(h * 0.62)),
    ]
    d.polygon(pts, fill=cols["GOLD_MD"], outline=OUT)
    in_pts = [
        (x0 + 2, y0 + 2), (x0 + w - 2, y0 + 2),
        (x0 + w - 2, y0 + int(h * 0.58)),
        (x0 + w // 2, y0 + h - 2),
        (x0 + 2, y0 + int(h * 0.58)),
    ]
    d.polygon(in_pts, fill=cols["BLUE_DK"], outline=cols["GOLD_HI"])
    lx, ly = x0 + w // 2, y0 + h // 2 - 1
    d.ellipse([lx - 4, ly - 4, lx + 4, ly + 4], fill=cols["GOLD_MD"], outline=OUT)
    d.ellipse([lx - 2, ly - 2, lx + 2, ly + 2], fill=cols["GOLD_HI"])
    put(im, lx - 1, ly - 1, OUT)
    put(im, lx + 1, ly - 1, OUT)
    put(im, lx, ly + 1, cols["GOLD_SH"])


def draw_crusader_helm(im: Image.Image, d: ImageDraw.ImageDraw, cx: int, top_y: int, facing_mode: str, cols: dict) -> None:
    d.polygon([
        (cx - 6, top_y), (cx + 6, top_y),
        (cx + 7, top_y + 12), (cx, top_y + 14), (cx - 7, top_y + 12)
    ], fill=cols["STEEL_MD"], outline=OUT)
    d.line([(cx - 5, top_y + 1), (cx + 5, top_y + 1)], fill=cols["STEEL_HI"])
    d.line([(cx - 4, top_y + 2), (cx - 5, top_y + 11)], fill=cols["STEEL_HI"], width=2)
    d.line([(cx + 5, top_y + 2), (cx + 5, top_y + 11)], fill=cols["STEEL_SH"])

    if facing_mode == "back":
        d.line([(cx, top_y + 2), (cx, top_y + 12)], fill=cols["STEEL_SH"])
        d.line([(cx - 6, top_y + 11), (cx + 6, top_y + 11)], fill=cols["GOLD_MD"])
        return

    shift = 2 if facing_mode == "side" else 0
    gx = cx + shift
    d.rectangle([cx - 6, top_y + 5, cx + 6, top_y + 8], fill=cols["GOLD_MD"], outline=OUT)
    d.line([(cx - 4 + shift, top_y + 6), (cx + 5, top_y + 6)], fill=OUT)
    d.line([(gx, top_y + 2), (gx, top_y + 12)], fill=cols["GOLD_HI"], width=2)
    put(im, gx - 1, top_y + 3, cols["GOLD_MD"])
    put(im, gx + 1, top_y + 3, cols["GOLD_MD"])
    put(im, gx - 1, top_y + 11, cols["GOLD_MD"])
    put(im, gx + 1, top_y + 11, cols["GOLD_MD"])
    for by in (top_y + 9, top_y + 11):
        put(im, cx + 4, by, OUT)
        if facing_mode == "front":
            put(im, cx - 4, by, OUT)


def draw_knight_frame(f: int) -> Image.Image:
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    cols = {
        "STEEL_SH": (104, 114, 132, 255),
        "STEEL_MD": (162, 174, 194, 255),
        "STEEL_HI": (222, 232, 246, 255),
        "GOLD_SH": (146, 104, 28, 255),
        "GOLD_MD": (214, 168, 54, 255),
        "GOLD_HI": (250, 218, 104, 255),
        "BLUE_NV": (18, 38, 92, 255),
        "BLUE_DK": (32, 72, 156, 255),
        "BLUE_MD": (54, 114, 214, 255),
        "BLUE_HI": (112, 176, 252, 255),
    }

    cx = 30 if f in (0, 1, 2, 3, 6, 9) else (34 if f == 7 else 32)
    bob = 1 if f in (1, 2, 9, 11, 12, 14, 15) else 0

    if f >= 10:
        is_up = f >= 13
        step = -2 if f in (11, 14) else (2 if f in (12, 15) else 0)
        ly = 53 - (1 if step < 0 else 0)
        ry = 53 - (1 if step > 0 else 0)

        if not is_up:
            d.polygon([(cx - 13, 19 + bob), (cx + 13, 19 + bob), (cx + 16, 47), (cx - 16, 47)],
                      fill=cols["BLUE_MD"], outline=OUT)
            d.line([(cx - 12, 21 + bob), (cx - 14, 46)], fill=cols["BLUE_NV"], width=2)
            d.line([(cx + 12, 21 + bob), (cx + 14, 46)], fill=cols["BLUE_NV"], width=2)

        pill(d, cx - 8, 38 + bob, cx - 2, ly, 2, cols["STEEL_MD"])
        pill(d, cx + 2, 38 + bob, cx + 8, ry, 2, cols["STEEL_MD"])
        d.line([(cx - 7, 43 + bob), (cx - 3, 43 + bob)], fill=cols["GOLD_HI"])
        d.line([(cx + 3, 43 + bob), (cx + 7, 43 + bob)], fill=cols["GOLD_HI"])

        pill(d, cx - 10, 20 + bob, cx + 10, 38 + bob, 3, cols["STEEL_MD"])
        d.rectangle([cx - 5, 22 + bob, cx + 5, 39 + bob], fill=cols["BLUE_MD"], outline=cols["GOLD_MD"])
        d.line([(cx, 23 + bob), (cx, 38 + bob)], fill=cols["BLUE_NV"], width=2)
        d.line([(cx - 9, 33 + bob), (cx + 9, 33 + bob)], fill=cols["GOLD_HI"], width=2)

        # Rounded Gold-Trimmed Silver Pauldrons
        d.ellipse([cx - 15, 19 + bob, cx - 7, 27 + bob], fill=cols["STEEL_HI"], outline=OUT)
        d.line([(cx - 13, 25 + bob), (cx - 8, 25 + bob)], fill=cols["GOLD_MD"])
        d.ellipse([cx + 7, 19 + bob, cx + 15, 27 + bob], fill=cols["STEEL_HI"], outline=OUT)
        d.line([(cx + 8, 25 + bob), (cx + 13, 25 + bob)], fill=cols["GOLD_MD"])

        if is_up:
            d.polygon([(cx - 12, 20 + bob), (cx + 12, 20 + bob), (cx + 16, 48), (cx - 16, 48)],
                      fill=cols["BLUE_MD"], outline=OUT)
            for sx in (-10, -4, 4, 10):
                d.line([(cx + sx, 22 + bob), (cx + sx + (1 if sx > 0 else -1), 46)], fill=cols["BLUE_NV"], width=2)
            d.line([(cx - 14, 46), (cx + 14, 46)], fill=cols["GOLD_MD"])
            d.polygon([(cx + 14, 28 + bob), (cx + 17, 28 + bob), (cx + 21, 51), (cx + 18, 52)],
                      fill=cols["STEEL_HI"], outline=OUT)
            draw_crusader_helm(im, d, cx, 6 + bob, "back", cols)
        else:
            d.line([(cx - 14, 27 + bob), (cx - 18, 49)], fill=cols["STEEL_HI"], width=3)
            d.line([(cx - 17, 28 + bob), (cx - 10, 30 + bob)], fill=cols["GOLD_HI"], width=2)
            draw_lion_shield(im, d, cx + 4, 23 + bob, 12, 16, cols)
            draw_crusader_helm(im, d, cx, 6 + bob, "front", cols)

        return im

    cape_flare = 6 if f in (4, 5, 7) else 0
    d.polygon([
        (cx - 8, 19 + bob), (cx + 2, 19 + bob),
        (cx - 4 - cape_flare, 46), (cx - 15 - cape_flare, 44)
    ], fill=cols["BLUE_MD"], outline=OUT)
    d.line([(cx - 7, 21 + bob), (cx - 12 - cape_flare, 43)], fill=cols["BLUE_NV"], width=2)
    d.line([(cx - 3, 21 + bob), (cx - 7 - cape_flare, 44)], fill=cols["BLUE_NV"], width=2)
    d.line([(cx - 14 - cape_flare, 44), (cx - 4 - cape_flare, 45)], fill=cols["GOLD_MD"])

    l_off = -3 if f == 1 else (3 if f == 2 else (-2 if f == 7 else 0))
    r_off = 3 if f == 1 else (-3 if f == 2 else (3 if f == 7 else 0))
    pill(d, cx - 6 + l_off, 38 + bob, cx + l_off, 53, 2, cols["STEEL_SH"])
    d.line([(cx - 5 + l_off, 43 + bob), (cx - 1 + l_off, 43 + bob)], fill=cols["GOLD_MD"])
    pill(d, cx + 1 + r_off, 38 + bob, cx + 8 + r_off, 53, 2, cols["STEEL_MD"])
    d.line([(cx + 2 + r_off, 43 + bob), (cx + 7 + r_off, 43 + bob)], fill=cols["GOLD_HI"])

    pill(d, cx - 7, 20 + bob, cx + 8, 38 + bob, 3, cols["STEEL_MD"])
    d.rectangle([cx - 3, 21 + bob, cx + 6, 30 + bob], fill=cols["STEEL_HI"])
    d.rectangle([cx - 5, 33 + bob, cx + 7, 39 + bob], fill=cols["BLUE_MD"], outline=cols["GOLD_MD"])
    d.line([(cx - 6, 32 + bob), (cx + 7, 32 + bob)], fill=cols["GOLD_HI"], width=2)

    d.ellipse([cx - 7, 19 + bob, cx + 4, 27 + bob], fill=cols["STEEL_HI"], outline=OUT)
    d.line([(cx - 5, 25 + bob), (cx + 3, 25 + bob)], fill=cols["GOLD_HI"])

    draw_crusader_helm(im, d, cx + 1, 6 + bob, "side", cols)

    if f in (0, 1, 2, 9):
        draw_lion_shield(im, d, cx - 9, 23 + bob, 11, 15, cols)
        d.polygon([(cx + 8, 29 + bob), (cx + 24, 12 + bob), (cx + 26, 14 + bob), (cx + 10, 31 + bob)],
                  fill=cols["STEEL_HI"], outline=OUT)
        d.line([(cx + 6, 26 + bob), (cx + 12, 32 + bob)], fill=cols["GOLD_HI"], width=2)
    elif f == 3:
        draw_lion_shield(im, d, cx - 8, 24, 11, 14, cols)
        d.polygon([(cx - 2, 18), (cx - 16, 4), (cx - 13, 3), (cx + 1, 17)], fill=cols["STEEL_HI"], outline=OUT)
        d.line([(cx - 4, 20), (cx + 3, 15)], fill=cols["GOLD_HI"], width=2)
    elif f == 4:
        d.polygon([(cx + 6, 24), (cx + 29, 21), (cx + 31, 25), (cx + 6, 28)], fill=cols["STEEL_HI"], outline=OUT)
        d.line([(cx + 6, 20), (cx + 6, 30)], fill=cols["GOLD_HI"], width=2)
        d.arc([cx - 2, 8, cx + 31, 44], start=-75, end=65, fill=cols["BLUE_HI"], width=2)
    elif f == 5:
        d.polygon([(cx + 5, 27), (cx + 27, 37), (cx + 25, 40), (cx + 3, 30)], fill=cols["STEEL_HI"], outline=OUT)
        d.arc([cx - 6, 10, cx + 31, 48], start=-60, end=110, fill=cols["BLUE_HI"], width=2)
        d.arc([cx - 3, 13, cx + 28, 45], start=-45, end=95, fill=cols["GOLD_HI"], width=1)
    elif f == 6:
        d.polygon([(cx - 6, 28), (cx - 16, 14), (cx - 13, 13), (cx - 3, 27)], fill=cols["STEEL_MD"], outline=OUT)
        draw_lion_shield(im, d, cx + 4, 18, 13, 20, cols)
    elif f == 7:
        draw_lion_shield(im, d, cx + 6, 18, 13, 19, cols)
        d.line([(cx + 20, 19), (cx + 24, 27), (cx + 20, 35)], fill=cols["BLUE_HI"], width=2)
    elif f == 8:
        draw_lion_shield(im, d, cx - 10, 24, 11, 14, cols)
        d.polygon([(cx + 7, 26), (cx + 21, 16), (cx + 23, 18), (cx + 9, 28)], fill=cols["STEEL_MD"], outline=OUT)

    return im


def make_knight_portraits() -> Image.Image:
    strip = Image.new("RGBA", (320, 64), (0, 0, 0, 0))
    STEEL_SH = (104, 114, 132, 255)
    STEEL_MD = (162, 174, 194, 255)
    STEEL_HI = (222, 232, 246, 255)
    GOLD_SH = (146, 104, 28, 255)
    GOLD_MD = (214, 168, 54, 255)
    GOLD_HI = (250, 218, 104, 255)
    BLUE_NV = (18, 38, 92, 255)
    BLUE_MD = (54, 114, 214, 255)
    EYE_GLOW = (112, 196, 255, 255)

    for i in range(5):
        fr = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(fr)
        d.ellipse([4, 4, 59, 59], fill=BLUE_NV, outline=OUT)
        d.polygon([(8, 58), (16, 42), (48, 42), (56, 58)], fill=BLUE_MD, outline=OUT)
        d.line([(16, 44), (13, 57)], fill=BLUE_NV, width=2)
        d.line([(48, 44), (51, 57)], fill=BLUE_NV, width=2)
        d.ellipse([9, 43, 23, 57], fill=STEEL_MD, outline=OUT)
        d.ellipse([41, 43, 55, 57], fill=STEEL_MD, outline=OUT)
        d.line([(11, 45), (21, 45)], fill=GOLD_HI, width=2)
        d.line([(43, 45), (53, 45)], fill=GOLD_HI, width=2)

        d.polygon([(20, 10), (44, 10), (48, 28), (47, 48), (32, 55), (17, 48), (16, 28)],
                  fill=STEEL_MD, outline=OUT)
        d.polygon([(21, 12), (28, 12), (26, 49), (19, 46)], fill=STEEL_HI)
        d.polygon([(39, 12), (43, 12), (45, 46), (39, 49)], fill=STEEL_SH)
        pill(d, 20, 10, 44, 14, 1, STEEL_HI)
        for rx in (24, 32, 40):
            put(fr, rx, 12, STEEL_SH)

        d.rectangle([17, 25, 47, 33], fill=GOLD_MD, outline=OUT)
        d.line([(18, 26), (46, 26)], fill=GOLD_HI)
        d.rectangle([19, 28, 29, 30], fill=OUT)
        d.rectangle([35, 28, 45, 30], fill=OUT)
        if i != 2:
            col_e = (255, 196, 84, 255) if i == 4 else EYE_GLOW
            off = 1 if i == 1 else 0
            put(fr, 24 + off, 29, col_e)
            put(fr, 40 + off, 29, col_e)

        d.polygon([
            (32, 15), (36, 19), (34, 20), (34, 47),
            (36, 49), (32, 53), (28, 49), (30, 47),
            (30, 20), (28, 19)
        ], fill=GOLD_HI, outline=GOLD_SH)
        for ry in (19, 29, 48):
            put(fr, 32, ry, GOLD_SH)
        for bx in (22, 26, 38, 42):
            for by in (37, 41, 45):
                put(fr, bx, by, OUT)
        strip.alpha_composite(fr, (i * 64, 0))
    return strip


# ==============================================================================
# 3 & 4. SYLVARA & NOA — RESTORED CLASSIC 64x64 MASTER CONVERSIONS
# ==============================================================================

MASTER_DIR = REPO_ROOT / "tools" / "masters_96"
SRC_CELL = 96
DST_CELL = 64


def _iter_px(im: Image.Image):
    if hasattr(im, "get_flattened_data"):
        return im.get_flattened_data()
    return im.getdata()


def _lum(c: tuple[int, int, int, int]) -> float:
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def downsample_cell_96_to_64(
    cell96: Image.Image, darkest_selout: tuple[int, int, int, int]
) -> Image.Image:
    sp = cell96.load()
    out = Image.new("RGBA", (DST_CELL, DST_CELL), (0, 0, 0, 0))
    dp = out.load()

    for by in range(32):
        sy0 = by * 3
        dy0 = by * 2
        for bx in range(32):
            sx0 = bx * 3
            dx0 = bx * 2
            center_c = sp[sx0 + 1, sy0 + 1]
            for oy, sy_pair in ((0, (sy0, sy0 + 1)), (1, (sy0 + 1, sy0 + 2))):
                for ox, sx_pair in ((0, (sx0, sx0 + 1)), (1, (sx0 + 1, sx0 + 2))):
                    ax = sx_pair[ox]
                    ay = sy_pair[oy]
                    samples = (
                        sp[ax, ay],
                        sp[sx_pair[1 - ox], ay],
                        sp[ax, sy_pair[1 - oy]],
                        sp[sx_pair[1 - ox], sy_pair[1 - oy]],
                    )
                    opaque = [c for c in samples if c[3] >= 128]
                    if not opaque:
                        if samples[0][3] > 0:
                            dp[dx0 + ox, dy0 + oy] = samples[0]
                        continue

                    if samples[0][3] >= 128:
                        chosen = samples[0]
                        for cand in (center_c, samples[1], samples[2]):
                            if cand[3] >= 128 and cand != chosen:
                                sat_c = max(cand[:3]) - min(cand[:3])
                                sat_a = max(chosen[:3]) - min(chosen[:3])
                                if (_lum(cand) > _lum(chosen) + 55) or (sat_c > sat_a + 65):
                                    chosen = cand
                                    break
                                if _lum(chosen) > 180 and cand[1] > cand[0] + 28 and cand[1] > cand[2] + 18:
                                    chosen = cand
                                    break
                        dp[dx0 + ox, dy0 + oy] = (chosen[0], chosen[1], chosen[2], 255)
                    elif len(opaque) >= 2:
                        c0 = opaque[0]
                        dp[dx0 + ox, dy0 + oy] = (c0[0], c0[1], c0[2], 255)

    snap = out.copy()
    qp = snap.load()
    for y in range(DST_CELL):
        for x in range(DST_CELL):
            c = qp[x, y]
            if c[3] < 255:
                continue
            on_edge = (
                x == 0
                or x == DST_CELL - 1
                or y == 0
                or y == DST_CELL - 1
                or qp[x - 1, y][3] == 0
                or qp[x + 1, y][3] == 0
                or qp[x, y - 1][3] == 0
                or qp[x, y + 1][3] == 0
            )
            if on_edge and _lum(c) > 78:
                op_n = sum(
                    1
                    for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
                    if 0 <= nx < DST_CELL and 0 <= ny < DST_CELL and qp[nx, ny][3] == 255
                )
                if op_n >= 3:
                    dp[x, y] = darkest_selout

    return out


def convert_hero_sheet(src_path: Path, dst_path: Path) -> tuple[int, int, int]:
    src = Image.open(src_path).convert("RGBA")
    if src.height == DST_CELL:
        return src.width, src.height, src.width // DST_CELL

    frames = src.width // SRC_CELL
    cols = {
        (r, g, b, 255)
        for (r, g, b, a) in _iter_px(src)
        if a == 255 and (r, g, b) != (0, 0, 0)
    }
    darkest = min(cols, key=_lum)

    out_sheet = Image.new("RGBA", (frames * DST_CELL, DST_CELL), (0, 0, 0, 0))
    for f in range(frames):
        c96 = src.crop((f * SRC_CELL, 0, (f + 1) * SRC_CELL, SRC_CELL))
        c64 = downsample_cell_96_to_64(c96, darkest)
        out_sheet.alpha_composite(c64, (f * DST_CELL, 0))

    f0_bb = out_sheet.crop((0, 0, DST_CELL, DST_CELL)).getbbox()
    if f0_bb is not None:
        target_gy = 53
        dy = target_gy - f0_bb[3]
        if dy != 0 and abs(dy) <= 4:
            shifted_sheet = Image.new("RGBA", out_sheet.size, (0, 0, 0, 0))
            for f in range(frames):
                cell = out_sheet.crop((f * DST_CELL, 0, (f + 1) * DST_CELL, DST_CELL))
                bb = cell.getbbox()
                if bb is None:
                    continue
                crop = cell.crop(bb)
                ny = max(0, min(DST_CELL - (bb[3] - bb[1]), bb[1] + dy))
                shifted_sheet.alpha_composite(crop, (f * DST_CELL + bb[0], ny))
            out_sheet = shifted_sheet

    out_sheet.save(dst_path)
    return out_sheet.width, out_sheet.height, frames


def build_sheet(draw_fn, frame_count: int, out_path: Path) -> None:
    sheet = Image.new("RGBA", (frame_count * 64, 64), (0, 0, 0, 0))
    for f in range(frame_count):
        sheet.alpha_composite(draw_fn(f), (f * 64, 0))
    sheet.save(out_path)
    print(f"wrote {out_path.relative_to(REPO_ROOT)} ({sheet.width}x{sheet.height}, {frame_count} frames)")


def main() -> None:
    TEX_DIR.mkdir(parents=True, exist_ok=True)
    # Keep redesigned Behemoth & Knight (64x64 sheets + portraits)
    build_sheet(draw_behemoth_frame, 16, TEX_DIR / "player_behemoth.png")
    build_sheet(draw_knight_frame, 16, TEX_DIR / "player_knight.png")

    for name, fn in (
        ("portrait_behemoth.png", make_behemoth_portraits),
        ("portrait_knight.png", make_knight_portraits),
    ):
        p = TEX_DIR / name
        im = fn()
        im.save(p)
        print(f"wrote {p.relative_to(REPO_ROOT)} ({im.width}x{im.height})")

    # Restore classic Sylvara & Noa 64x64 sheets from 96x96 masters
    for fname in ("player_sylvara.png", "player_noa.png"):
        dst = TEX_DIR / fname
        master = MASTER_DIR / fname
        src_p = master if master.exists() else dst
        w, h, fcount = convert_hero_sheet(src_p, dst)
        print(f"wrote {dst.relative_to(REPO_ROOT)} ({w}x{h}, {fcount} frames of 64x64)")


if __name__ == "__main__":
    main()
