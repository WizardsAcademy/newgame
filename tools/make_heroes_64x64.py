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
# 3. SYLVARA — CURVY MEDIEVAL-FANTASY HUNTRESS ELF (15 frames x 64x64)
#    Green, White Blouse, Warm Leather, Hourglass Nice Body & Prominent Bust!
# ==============================================================================

def draw_sylvara_frame(f: int) -> Image.Image:
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    SKIN_SH = (212, 156, 130, 255)
    SKIN_MD = (244, 196, 168, 255)
    SKIN_HI = (255, 224, 202, 255)
    HAIR_SH = (182, 132, 38, 255)
    HAIR_MD = (234, 186, 66, 255)
    HAIR_HI = (255, 228, 122, 255)
    WHT_SH = (196, 206, 222, 255)
    WHT_HI = (250, 252, 255, 255)
    GRN_DK = (22, 80, 46, 255)
    GRN_MD = (40, 134, 76, 255)
    GRN_HI = (84, 192, 114, 255)
    LTH_DK = (82, 46, 26, 255)
    LTH_MD = (132, 76, 42, 255)
    LTH_HI = (176, 112, 66, 255)
    BOW_GD = (218, 166, 58, 255)
    EM_GLOW = (96, 252, 154, 255)

    cx = 31
    bob = -3 if f == 6 else (1 if f in (1, 2, 8, 10, 11, 13, 14) else 0)

    # --- FRONT (`9, 10, 11`) & BACK (`12, 13, 14`) ---
    if f >= 9:
        is_up = f >= 12
        step = -2 if f in (10, 13) else (2 if f in (11, 14) else 0)
        ly = 53 - (1 if step < 0 else 0)
        ry = 53 - (1 if step > 0 else 0)

        if not is_up:
            d.polygon([(cx - 10, 11 + bob), (cx + 10, 11 + bob), (cx + 12, 32 + bob), (cx - 12, 32 + bob)],
                      fill=HAIR_SH, outline=OUT)

        # Shapely bare thighs + fitted thigh-high brown leather boots (`ground_y = 54`)
        pill(d, cx - 6, 36 + bob, cx - 2, 44 + bob, 2, SKIN_HI)
        pill(d, cx + 2, 36 + bob, cx + 6, 44 + bob, 2, SKIN_HI)
        pill(d, cx - 6, 43 + bob, cx - 2, ly, 2, LTH_DK)
        pill(d, cx + 2, 43 + bob, cx + 6, ry, 2, LTH_MD)
        d.line([(cx - 6, 43 + bob), (cx - 2, 43 + bob)], fill=LTH_HI)
        d.line([(cx + 2, 43 + bob), (cx + 6, 43 + bob)], fill=LTH_HI)

        # Curvy Hourglass Hips + Emerald-Green Medieval-Fantasy Skirt with White Trim!
        d.polygon([
            (cx - 4, 29 + bob), (cx + 4, 29 + bob),
            (cx + 10, 35 + bob), (cx + 9, 40 + bob),
            (cx + 3, 40 + bob), (cx, 35 + bob),
            (cx - 3, 40 + bob), (cx - 9, 40 + bob), (cx - 10, 35 + bob)
        ], fill=GRN_MD, outline=OUT)
        d.line([(cx - 8, 39 + bob), (cx - 3, 39 + bob)], fill=WHT_HI)
        d.line([(cx + 3, 39 + bob), (cx + 8, 39 + bob)], fill=WHT_HI)
        d.line([(cx - 7, 34 + bob), (cx - 4, 31 + bob)], fill=GRN_HI)

        # Super-Cinched Narrow Brown Leather Corset Waist (`nice budy` hourglass!)
        d.polygon([(cx - 6, 26 + bob), (cx + 6, 26 + bob), (cx + 4, 30 + bob), (cx - 4, 30 + bob)],
                  fill=LTH_MD, outline=OUT)
        put(im, cx, 28 + bob, BOW_GD)

        # Slim White Fantasy Off-Shoulder Sleeves + Leather Bracers
        pill(d, cx - 11, 21 + bob, cx - 7, 26 + bob, 2, WHT_HI)
        pill(d, cx - 11, 25 + bob, cx - 8, 30 + bob, 1, LTH_MD)
        pill(d, cx + 7, 21 + bob, cx + 11, 26 + bob, 2, WHT_HI)
        pill(d, cx + 8, 25 + bob, cx + 11, 30 + bob, 1, LTH_MD)

        if not is_up:
            # Open Sweetheart Collarbone + Prominent Sculpted White-Blouse Bust (`sine hash bozorg`)!
            d.ellipse([cx - 5, 18 + bob, cx + 5, 23 + bob], fill=SKIN_HI, outline=OUT)
            # Full, rounded twin bust silhouette in crisp white blouse (soft shading, super readable!)
            d.ellipse([cx - 9, 20 + bob, cx + 1, 28 + bob], fill=WHT_HI, outline=OUT)
            d.ellipse([cx - 1, 20 + bob, cx + 9, 28 + bob], fill=WHT_HI, outline=OUT)
            d.rectangle([cx - 7, 21 + bob, cx + 7, 26 + bob], fill=WHT_HI)
            d.line([(cx - 7, 27 + bob), (cx - 2, 27 + bob)], fill=WHT_SH)
            d.line([(cx + 2, 27 + bob), (cx + 7, 27 + bob)], fill=WHT_SH)
            d.line([(cx, 21 + bob), (cx, 26 + bob)], fill=SKIN_SH)  # cleavage line!
            put(im, cx - 1, 21 + bob, SKIN_HI)
            put(im, cx + 1, 21 + bob, SKIN_HI)
        else:
            pill(d, cx - 7, 19 + bob, cx + 7, 27 + bob, 2, GRN_MD)
            d.polygon([(cx + 3, 18 + bob), (cx + 8, 19 + bob), (cx + 5, 30 + bob), (cx + 1, 29 + bob)],
                      fill=LTH_MD, outline=OUT)

        d.arc([cx + 7, 17 + bob, cx + 19, 39 + bob], start=-80, end=80, fill=BOW_GD, width=2)

        if not is_up:
            # Pointed Elf Ears + Pretty Rounded Face + Golden Blonde Hair + Emerald Circlet
            d.polygon([(cx - 11, 12 + bob), (cx - 5, 11 + bob), (cx - 5, 15 + bob)], fill=SKIN_HI, outline=OUT)
            d.polygon([(cx + 11, 12 + bob), (cx + 5, 11 + bob), (cx + 5, 15 + bob)], fill=SKIN_HI, outline=OUT)
            pill(d, cx - 6, 7 + bob, cx + 6, 18 + bob, 5, SKIN_HI)
            d.polygon([(cx - 8, 14 + bob), (cx - 6, 6 + bob), (cx + 6, 6 + bob), (cx + 8, 14 + bob),
                       (cx + 5, 10 + bob), (cx, 11 + bob), (cx - 5, 10 + bob)], fill=HAIR_HI, outline=OUT)
            put(im, cx, 8 + bob, EM_GLOW)
            put(im, cx - 3, 13 + bob, GRN_MD)
            put(im, cx + 3, 13 + bob, GRN_MD)
            put(im, cx, 16 + bob, SKIN_SH)
        else:
            d.polygon([(cx - 8, 6 + bob), (cx + 8, 6 + bob), (cx + 10, 28 + bob), (cx, 31 + bob), (cx - 10, 28 + bob)],
                      fill=HAIR_MD, outline=OUT)
            d.line([(cx - 3, 8 + bob), (cx - 4, 27 + bob)], fill=HAIR_HI, width=2)
            d.line([(cx + 4, 8 + bob), (cx + 4, 27 + bob)], fill=HAIR_SH, width=2)

        return im

    # --- SIDE / ARCHERY FRAMES (`0..8`, facing RIGHT) ---
    # Golden-blonde ponytail/locks flowing behind back (leaves hourglass waist visible!)
    d.polygon([
        (cx - 10, 7 + bob), (cx + 1, 7 + bob),
        (cx - 4, 24 + bob), (cx - 12, 26 + bob), (cx - 13, 16 + bob)
    ], fill=HAIR_MD, outline=OUT)
    d.line([(cx - 8, 9 + bob), (cx - 10, 23 + bob)], fill=HAIR_HI, width=2)

    # Shapely curved thighs + sleek brown leather boots (`ground_y = 54`, airborne in `f==6`)
    l_off = -3 if f == 1 else (3 if f == 2 else (-3 if f == 6 else 0))
    r_off = 3 if f == 1 else (-3 if f == 2 else (3 if f == 6 else 0))
    boot_bot = 49 if f == 6 else 53
    pill(d, cx - 5 + l_off, 36 + bob, cx - 1 + l_off, 43 + bob, 2, SKIN_SH)
    pill(d, cx - 6 + l_off, 42 + bob, cx + l_off, boot_bot, 2, LTH_DK)
    pill(d, cx + r_off, 36 + bob, cx + 5 + r_off, 43 + bob, 2, SKIN_HI)
    pill(d, cx + r_off, 42 + bob, cx + 6 + r_off, boot_bot, 2, LTH_MD)
    d.line([(cx + 1 + r_off, 42 + bob), (cx + 5 + r_off, 42 + bob)], fill=LTH_HI)

    # Curvy Flared Hips in Emerald-Green Ranger Skirt + White Trim!
    d.polygon([
        (cx - 3, 29 + bob), (cx + 3, 29 + bob),
        (cx + 8, 35 + bob), (cx + 8, 40 + bob),
        (cx + 2, 40 + bob), (cx, 35 + bob),
        (cx - 7, 40 + bob), (cx - 8, 35 + bob)
    ], fill=GRN_MD, outline=OUT)
    d.line([(cx - 6, 39 + bob), (cx + 7, 39 + bob)], fill=WHT_HI)
    d.line([(cx - 6, 34 + bob), (cx - 3, 31 + bob)], fill=GRN_HI)

    # Cinched Narrow Brown Leather Corset Waist (`6px` narrow hourglass!)
    d.polygon([(cx - 4, 26 + bob), (cx + 4, 26 + bob), (cx + 3, 30 + bob), (cx - 3, 30 + bob)],
              fill=LTH_MD, outline=OUT)
    put(im, cx + 2, 28 + bob, BOW_GD)

    # Rear arm holding Golden Recurve Bow (drawn BEFORE bust so bust curve stays 100% clear!)
    if f in (3, 4, 5):
        d.arc([cx + 9, 10 + bob, cx + 23, 34 + bob], start=-82, end=82, fill=BOW_GD, width=2)
    else:
        d.arc([cx + 7, 13 + bob, cx + 19, 36 + bob], start=-80, end=80, fill=BOW_GD, width=2)

    # Upper Torso + Prominent Full Sculpted White-Blouse Bust (`sine hash bozorg`)!
    pill(d, cx - 4, 19 + bob, cx + 5, 27 + bob, 3, WHT_HI)
    # Generous rounded bust projecting forward (`cx + 1 .. cx + 10`) with cleavage & under-shadow!
    d.ellipse([cx, 19 + bob, cx + 10, 27 + bob], fill=WHT_HI, outline=OUT)
    d.rectangle([cx - 2, 20 + bob, cx + 6, 25 + bob], fill=WHT_HI)
    d.line([(cx + 3, 26 + bob), (cx + 8, 26 + bob)], fill=WHT_SH)
    put(im, cx + 4, 20 + bob, SKIN_HI)  # upper neckline skin!
    put(im, cx + 5, 20 + bob, SKIN_SH)

    # Pretty Rounded Elf Head + Pointed Ear + Emerald Eye
    pill(d, cx - 4, 7 + bob, cx + 6, 18 + bob, 5, SKIN_HI)
    d.polygon([(cx - 9, 12 + bob), (cx - 3, 11 + bob), (cx - 3, 15 + bob)], fill=SKIN_HI, outline=OUT)
    d.polygon([(cx - 6, 12 + bob), (cx - 4, 6 + bob), (cx + 6, 7 + bob), (cx + 3, 10 + bob)],
              fill=HAIR_HI, outline=OUT)
    put(im, cx + 5, 8 + bob, EM_GLOW)
    put(im, cx + 3, 13 + bob, GRN_MD)
    put(im, cx + 4, 13 + bob, OUT)

    # Slim shoulder/arm & archery string (positioned cleanly so bust silhouette shines!)
    if f in (3, 4, 5):
        pill(d, cx - 5, 19 + bob, cx + 2, 23 + bob, 2, WHT_HI)
        pull_x = cx + 4 if f == 4 else (cx + 8 if f == 3 else cx + 15)
        d.line([(cx + 16, 11 + bob), (pull_x, 22 + bob), (cx + 16, 33 + bob)], fill=WHT_SH)
        if f in (3, 4):
            d.line([(pull_x, 22 + bob), (cx + 25, 22 + bob)], fill=EM_GLOW if f == 4 else BOW_GD, width=2 if f == 4 else 1)
            if f == 4:
                d.polygon([(cx + 25, 19 + bob), (cx + 30, 22 + bob), (cx + 25, 25 + bob)], fill=EM_GLOW, outline=OUT)
    else:
        pill(d, cx - 5, 20 + bob, cx, 27 + bob, 2, WHT_HI)
        pill(d, cx - 4, 25 + bob, cx + 1, 29 + bob, 1, LTH_MD)

    return im


def make_sylvara_portraits() -> Image.Image:
    strip = Image.new("RGBA", (320, 64), (0, 0, 0, 0))
    SKIN_SH = (212, 156, 130, 255)
    SKIN_HI = (255, 224, 202, 255)
    HAIR_MD = (234, 186, 66, 255)
    HAIR_HI = (255, 228, 122, 255)
    WHT_SH = (196, 206, 222, 255)
    WHT_HI = (250, 252, 255, 255)
    GRN_DK = (22, 80, 46, 255)
    GRN_MD = (40, 134, 76, 255)
    LTH_MD = (132, 76, 42, 255)
    BOW_GD = (218, 166, 58, 255)
    EM_GLOW = (96, 252, 154, 255)

    for i in range(5):
        fr = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(fr)
        d.ellipse([4, 4, 59, 59], fill=GRN_DK, outline=OUT)
        # Golden hair back
        d.polygon([(11, 53), (13, 14), (32, 7), (51, 14), (53, 53)], fill=HAIR_MD, outline=OUT)
        # Medieval-fantasy Emerald shoulders + Crisp White sweetheart blouse & cleavage + Leather strap!
        d.polygon([(8, 58), (16, 43), (48, 43), (56, 58)], fill=GRN_MD, outline=OUT)
        d.ellipse([17, 46, 33, 60], fill=WHT_HI, outline=OUT)
        d.ellipse([31, 46, 47, 60], fill=WHT_HI, outline=OUT)
        d.ellipse([24, 42, 40, 51], fill=SKIN_HI, outline=SKIN_SH)
        d.line([(32, 48), (32, 58)], fill=SKIN_SH)
        d.line([(18, 45), (26, 57)], fill=LTH_MD, width=3)

        # Long pointed elf ears + rounded feminine face
        d.polygon([(4, 26), (16, 23), (15, 33)], fill=SKIN_HI, outline=OUT)
        d.polygon([(60, 26), (48, 23), (49, 33)], fill=SKIN_HI, outline=OUT)
        d.rounded_rectangle([18, 16, 46, 43], radius=10, fill=SKIN_HI, outline=OUT)
        d.polygon([(16, 26), (20, 11), (32, 14), (44, 11), (48, 26), (41, 18), (32, 19), (23, 18)],
                  fill=HAIR_HI, outline=OUT)
        d.line([(21, 16), (43, 16)], fill=BOW_GD, width=2)
        d.ellipse([29, 13, 35, 19], fill=EM_GLOW, outline=OUT)

        if i == 2:
            d.line([(22, 28), (28, 28)], fill=OUT, width=2)
            d.line([(36, 28), (42, 28)], fill=OUT, width=2)
        elif i == 4:
            d.line([(22, 26), (28, 30)], fill=OUT, width=2)
            d.line([(28, 26), (22, 30)], fill=OUT, width=2)
            d.line([(36, 26), (42, 30)], fill=OUT, width=2)
            d.line([(42, 26), (36, 30)], fill=OUT, width=2)
        else:
            off = 1 if i == 1 else 0
            pill(d, 22, 25, 28, 31, 2, WHT_HI)
            pill(d, 36, 25, 42, 31, 2, WHT_HI)
            d.rectangle([23 + off, 26, 27 + off, 30], fill=GRN_MD)
            d.rectangle([37 + off, 26, 41 + off, 30], fill=GRN_MD)
            put(fr, 24 + off, 27, WHT_HI)
            put(fr, 38 + off, 27, WHT_HI)
        d.line([(29, 37), (35, 37)], fill=SKIN_SH)
        strip.alpha_composite(fr, (i * 64, 0))
    return strip


# ==============================================================================
# 4. NOA — ROYAL ARISTOCRAT VAMPIRE (16 frames x 64x64)
#    Mostly Pure-White Victorian Noble Gown + Gold/Ruby Crown Tiara + Ruby Necklace!
# ==============================================================================

def draw_noa_frame(f: int) -> Image.Image:
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    SKIN_PALE = (255, 236, 242, 255)
    SKIN_SH = (222, 194, 208, 255)
    # Moonlit icy silver-lavender hair so Pure-White Royal Gown pops with crisp contrast!
    HAIR_HI = (232, 238, 255, 255)
    HAIR_MD = (198, 208, 238, 255)
    HAIR_SH = (158, 170, 208, 255)
    GOWN_W = (252, 250, 255, 255)     # Dominant Pure Pearl-White Aristocratic Gown!
    GOWN_IV = (224, 220, 236, 255)
    CRIM_DK = (118, 14, 34, 255)
    CRIM_MD = (196, 24, 54, 255)
    CRIM_HI = (252, 58, 92, 255)
    GOLD_MD = (218, 170, 54, 255)
    GOLD_HI = (255, 224, 108, 255)

    if f == 5:
        d.ellipse([20, 16, 44, 52], fill=CRIM_DK, outline=OUT)
        d.ellipse([23, 20, 41, 49], fill=CRIM_MD)
        d.ellipse([27, 25, 37, 43], fill=CRIM_HI)
        return im

    if f == 9:
        d.ellipse([10, 46, 54, 54], fill=CRIM_DK, outline=OUT)
        d.ellipse([15, 48, 49, 53], fill=CRIM_MD)
        d.ellipse([23, 49, 41, 52], fill=CRIM_HI)
        return im

    cx = 32
    bob = 1 if f in (1, 2, 7, 11, 12, 14, 15) else 0

    # --- FRONT (`10..12`) & BACK (`13..15`) ---
    if f >= 10:
        is_up = f >= 13
        step = -1 if f in (11, 14) else (1 if f in (12, 15) else 0)

        if not is_up:
            d.polygon([(cx - 11, 12 + bob), (cx + 11, 12 + bob), (cx + 13, 39 + bob), (cx - 13, 39 + bob)],
                      fill=HAIR_SH, outline=OUT)

        # Dainty white aristocratic heels (`ground_y = 54`)
        pill(d, cx - 5, 49, cx - 2, 53 - (1 if step < 0 else 0), 1, GOWN_IV)
        pill(d, cx + 2, 49, cx + 5, 53 - (1 if step > 0 else 0), 1, GOWN_W)

        # Voluminous Bell-Shaped Pure-White Royal Ballgown Skirt + Gold Scallops & Crimson Ribbon!
        d.polygon([
            (cx - 5, 29 + bob), (cx + 5, 29 + bob),
            (cx + 12, 37 + bob), (cx + 15, 50),
            (cx - 15, 50), (cx - 12, 37 + bob)
        ], fill=GOWN_W, outline=OUT)
        d.line([(cx - 4, 31 + bob), (cx - 9, 48)], fill=GOWN_IV)
        d.line([(cx + 4, 31 + bob), (cx + 9, 48)], fill=GOWN_IV)
        d.polygon([(cx - 3, 30 + bob), (cx + 3, 30 + bob), (cx + 5, 50), (cx - 5, 50)],
                  fill=GOWN_W, outline=GOLD_MD)
        d.line([(cx - 13, 48), (cx + 13, 48)], fill=CRIM_MD, width=2)
        d.line([(cx - 13, 46), (cx + 13, 46)], fill=GOLD_HI)

        # Hourglass White Royal Corset Bodice + Puffed Aristocratic Sleeves!
        d.polygon([(cx - 7, 20 + bob), (cx + 7, 20 + bob), (cx + 5, 30 + bob), (cx - 5, 30 + bob)],
                  fill=GOWN_W, outline=OUT)
        d.ellipse([cx - 12, 20 + bob, cx - 6, 27 + bob], fill=GOWN_W, outline=OUT)
        d.ellipse([cx + 6, 20 + bob, cx + 12, 27 + bob], fill=GOWN_W, outline=OUT)
        d.line([(cx - 11, 26 + bob), (cx - 7, 26 + bob)], fill=GOLD_HI)
        d.line([(cx + 7, 26 + bob), (cx + 11, 26 + bob)], fill=GOLD_HI)

        if not is_up:
            # Open Noble Décolletage + Jeweled Ruby Necklace (`gardan band`)!
            d.ellipse([cx - 5, 18 + bob, cx + 5, 24 + bob], fill=SKIN_PALE, outline=OUT)
            d.line([(cx - 4, 21 + bob), (cx + 4, 21 + bob)], fill=GOLD_HI)
            put(im, cx, 22 + bob, CRIM_HI)      # gleaming ruby pendant!
            put(im, cx - 2, 21 + bob, CRIM_MD)
            put(im, cx + 2, 21 + bob, CRIM_MD)
            # Gold & crimson corset waist lacing
            d.line([(cx - 3, 25 + bob), (cx - 2, 29 + bob)], fill=GOLD_MD)
            d.line([(cx + 3, 25 + bob), (cx + 2, 29 + bob)], fill=GOLD_MD)
            put(im, cx, 27 + bob, CRIM_HI)

            # Rounded Porcelain Aristocrat Face + Crimson Eyes
            pill(d, cx - 6, 8 + bob, cx + 6, 19 + bob, 5, SKIN_PALE)
            d.polygon([(cx - 8, 15 + bob), (cx - 6, 7 + bob), (cx + 6, 7 + bob), (cx + 8, 15 + bob),
                       (cx + 4, 11 + bob), (cx - 4, 11 + bob)], fill=HAIR_MD, outline=OUT)
            d.line([(cx - 4, 9 + bob), (cx + 4, 9 + bob)], fill=HAIR_HI)
            put(im, cx - 3, 14 + bob, CRIM_HI)
            put(im, cx + 3, 14 + bob, CRIM_HI)
        else:
            # Back view: Cascading silver-lavender hair + royal white collar
            d.polygon([(cx - 9, 8 + bob), (cx + 9, 8 + bob), (cx + 12, 36 + bob), (cx, 40 + bob), (cx - 12, 36 + bob)],
                      fill=HAIR_MD, outline=OUT)
            d.line([(cx - 4, 10 + bob), (cx - 5, 35 + bob)], fill=HAIR_HI, width=2)
            d.line([(cx + 4, 10 + bob), (cx + 5, 35 + bob)], fill=HAIR_SH, width=2)

        # Ornate Royal Gold & Ruby Crown / Tiara (`taj ro saresh`)!
        d.polygon([
            (cx - 6, 8 + bob), (cx - 5, 4 + bob), (cx - 2, 7 + bob),
            (cx, 2 + bob), (cx + 2, 7 + bob), (cx + 5, 4 + bob), (cx + 6, 8 + bob)
        ], fill=GOLD_HI, outline=OUT)
        put(im, cx, 5 + bob, CRIM_HI)
        return im

    # --- SIDE / BLOOD-MAGIC FRAMES (`0, 1, 2, 3, 4, 6, 7, 8`, facing RIGHT) ---
    if f == 6:
        cx = 29

    # Cascading moonlit silver-lavender hair behind back (contrasts cleanly with Pure-White Gown!)
    d.polygon([
        (cx - 10, 8 + bob), (cx + 1, 8 + bob),
        (cx - 3, 36 + bob), (cx - 13, 34 + bob), (cx - 12, 20 + bob)
    ], fill=HAIR_MD, outline=OUT)
    d.line([(cx - 8, 11 + bob), (cx - 10, 32 + bob)], fill=HAIR_HI, width=2)

    s_off = 2 if f == 1 else (-2 if f == 2 else 0)
    pill(d, cx - 3 - s_off, 49, cx - s_off, 53, 1, GOWN_IV)
    pill(d, cx + 1 + s_off, 49, cx + 5 + s_off, 53, 1, GOWN_W)

    # Voluminous Bell-Shaped Pure-White Aristocratic Gown Skirt + Gold & Crimson Trim!
    flare = 3 if f in (3, 4) else 0
    d.polygon([
        (cx - 4, 29 + bob), (cx + 4, 29 + bob),
        (cx + 10 + flare, 37 + bob), (cx + 13 + flare, 50),
        (cx - 12, 50), (cx - 10, 37 + bob)
    ], fill=GOWN_W, outline=OUT)
    d.line([(cx - 3, 32 + bob), (cx - 7, 48)], fill=GOWN_IV)
    d.line([(cx + 2, 32 + bob), (cx + 7 + flare, 48)], fill=GOWN_IV)
    d.line([(cx - 10, 48), (cx + 11 + flare, 48)], fill=CRIM_MD, width=2)
    d.line([(cx - 10, 46), (cx + 11 + flare, 46)], fill=GOLD_HI)

    # Curvy White Royal Corset Bodice + Gold Brocade + Ruby Necklace (`gardan band`)!
    d.polygon([(cx - 4, 19 + bob), (cx + 6, 19 + bob), (cx + 4, 30 + bob), (cx - 4, 30 + bob)],
              fill=GOWN_W, outline=OUT)
    d.ellipse([cx + 1, 20 + bob, cx + 8, 26 + bob], fill=GOWN_W, outline=OUT)
    d.line([(cx - 3, 29 + bob), (cx + 4, 29 + bob)], fill=GOLD_HI)
    # Porcelain neck + Gold & Ruby Necklace!
    d.rectangle([cx + 1, 18 + bob, cx + 5, 21 + bob], fill=SKIN_PALE)
    d.line([(cx, 20 + bob), (cx + 6, 20 + bob)], fill=GOLD_HI)
    put(im, cx + 5, 21 + bob, CRIM_HI)
    put(im, cx + 4, 21 + bob, CRIM_MD)

    # Rounded Porcelain Aristocrat Head + Crimson Eye + Ornate Gold/Ruby Crown (`taj`)!
    pill(d, cx - 4, 8 + bob, cx + 6, 18 + bob, 5, SKIN_PALE)
    d.polygon([(cx - 7, 14 + bob), (cx - 4, 7 + bob), (cx + 6, 8 + bob), (cx + 3, 11 + bob)],
              fill=HAIR_HI, outline=OUT)
    put(im, cx + 3, 13 + bob, CRIM_HI)
    put(im, cx + 4, 13 + bob, OUT)

    d.polygon([
        (cx - 4, 8 + bob), (cx - 3, 4 + bob), (cx, 7 + bob),
        (cx + 2, 2 + bob), (cx + 4, 7 + bob), (cx + 6, 4 + bob), (cx + 5, 8 + bob)
    ], fill=GOLD_HI, outline=OUT)
    put(im, cx + 2, 5 + bob, CRIM_HI)

    # Puffed White Royal Bell-Sleeve + Crimson Blood-Magic Slash!
    d.ellipse([cx - 5, 20 + bob, cx + 2, 26 + bob], fill=GOWN_W, outline=OUT)
    if f == 3:
        pill(d, cx + 1, 21, cx + 13, 25, 2, GOWN_W)
        put(im, cx + 14, 22, CRIM_HI)
    elif f == 4:
        pill(d, cx + 1, 20, cx + 15, 24, 2, GOWN_W)
        d.arc([cx + 10, 12, cx + 26, 34], start=-70, end=70, fill=CRIM_HI, width=2)
    else:
        pill(d, cx - 3, 24 + bob, cx + 4, 28 + bob, 2, GOWN_IV)
        if f == 8:
            put(im, cx + 7, 24 + bob, CRIM_HI)

    return im


def make_noa_portraits() -> Image.Image:
    strip = Image.new("RGBA", (320, 64), (0, 0, 0, 0))
    SKIN_PALE = (255, 236, 242, 255)
    SKIN_SH = (222, 194, 208, 255)
    HAIR_HI = (232, 238, 255, 255)
    HAIR_MD = (198, 208, 238, 255)
    HAIR_SH = (158, 170, 208, 255)
    GOWN_W = (252, 250, 255, 255)
    CRIM_DK = (96, 12, 30, 255)
    CRIM_MD = (196, 24, 54, 255)
    CRIM_HI = (252, 58, 92, 255)
    GOLD_MD = (218, 170, 54, 255)
    GOLD_HI = (255, 224, 108, 255)

    for i in range(5):
        fr = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(fr)
        d.ellipse([4, 4, 59, 59], fill=CRIM_DK, outline=OUT)
        # Moonlit silver-lavender hair back
        d.polygon([(11, 54), (13, 15), (32, 9), (51, 15), (53, 54)], fill=HAIR_MD, outline=OUT)
        d.line([(15, 22), (15, 50)], fill=HAIR_SH, width=2)
        d.line([(49, 22), (49, 50)], fill=HAIR_SH, width=2)

        # Puffed Royal White Aristocratic Gown Shoulders & Collar + Gold Filigree!
        d.polygon([(7, 58), (14, 42), (50, 42), (57, 58)], fill=GOWN_W, outline=OUT)
        d.ellipse([7, 44, 21, 57], fill=GOWN_W, outline=OUT)
        d.ellipse([43, 44, 57, 57], fill=GOWN_W, outline=OUT)
        d.line([(18, 44), (24, 57)], fill=GOLD_MD, width=2)
        d.line([(46, 44), (40, 57)], fill=GOLD_MD, width=2)

        # Porcelain Neck + Jeweled Ruby Necklace (`gardan band`)!
        d.ellipse([23, 41, 41, 53], fill=SKIN_PALE, outline=SKIN_SH)
        d.line([(24, 46), (40, 46)], fill=GOLD_HI, width=2)
        d.polygon([(32, 45), (35, 49), (32, 53), (29, 49)], fill=CRIM_HI, outline=OUT)
        put(fr, 27, 46, CRIM_MD)
        put(fr, 37, 46, CRIM_MD)

        # Rounded Porcelain Aristocrat Face
        d.rounded_rectangle([18, 17, 46, 43], radius=10, fill=SKIN_PALE, outline=OUT)
        d.polygon([(16, 26), (20, 13), (32, 16), (44, 13), (48, 26), (40, 19), (32, 21), (24, 19)],
                  fill=HAIR_HI, outline=OUT)

        # Ornate Royal Gold & Ruby Crown / Tiara (`taj ro saresh`)!
        d.polygon([
            (18, 15), (20, 7), (26, 13), (32, 3),
            (38, 13), (44, 7), (46, 15)
        ], fill=GOLD_HI, outline=OUT)
        d.line([(19, 15), (45, 15)], fill=GOLD_MD, width=2)
        d.ellipse([29, 7, 35, 13], fill=CRIM_HI, outline=OUT)
        put(fr, 22, 11, CRIM_MD)
        put(fr, 42, 11, CRIM_MD)

        if i == 2:
            d.line([(22, 29), (28, 29)], fill=OUT, width=2)
            d.line([(36, 29), (42, 29)], fill=OUT, width=2)
        elif i == 4:
            d.line([(22, 27), (28, 31)], fill=OUT, width=2)
            d.line([(28, 27), (22, 31)], fill=OUT, width=2)
            d.line([(36, 27), (42, 31)], fill=OUT, width=2)
            d.line([(42, 27), (36, 31)], fill=OUT, width=2)
        else:
            off = 1 if i == 1 else 0
            pill(d, 22, 26, 28, 32, 2, GOWN_W)
            pill(d, 36, 26, 42, 32, 2, GOWN_W)
            d.rectangle([23 + off, 27, 27 + off, 31], fill=CRIM_HI)
            d.rectangle([37 + off, 27, 41 + off, 31], fill=CRIM_HI)
            put(fr, 24 + off, 28, GOWN_W)
            put(fr, 38 + off, 28, GOWN_W)
        d.line([(29, 38), (35, 38)], fill=CRIM_MD)
        put(fr, 30, 39, GOWN_W)
        strip.alpha_composite(fr, (i * 64, 0))
    return strip


def build_sheet(draw_fn, frame_count: int, out_path: Path) -> None:
    sheet = Image.new("RGBA", (frame_count * 64, 64), (0, 0, 0, 0))
    for f in range(frame_count):
        sheet.alpha_composite(draw_fn(f), (f * 64, 0))
    sheet.save(out_path)
    print(f"wrote {out_path.relative_to(REPO_ROOT)} ({sheet.width}x{sheet.height}, {frame_count} frames)")


def main() -> None:
    TEX_DIR.mkdir(parents=True, exist_ok=True)
    build_sheet(draw_behemoth_frame, 16, TEX_DIR / "player_behemoth.png")
    build_sheet(draw_knight_frame, 16, TEX_DIR / "player_knight.png")
    build_sheet(draw_sylvara_frame, 15, TEX_DIR / "player_sylvara.png")
    build_sheet(draw_noa_frame, 16, TEX_DIR / "player_noa.png")

    for name, fn in (
        ("portrait_behemoth.png", make_behemoth_portraits),
        ("portrait_knight.png", make_knight_portraits),
        ("portrait_sylvara.png", make_sylvara_portraits),
        ("portrait_noa.png", make_noa_portraits),
    ):
        p = TEX_DIR / name
        im = fn()
        im.save(p)
        print(f"wrote {p.relative_to(REPO_ROOT)} ({im.width}x{im.height})")


if __name__ == "__main__":
    main()
