#!/usr/bin/env python
"""Generate 64x64 x 5-frame Close-Up Face Portrait sheets for the 4 Heroes!

Designed specifically for the circular bottom-left Hero HUD Medallion:
  - Shows ONLY the hero's close-up face/head in crisp, expressive 64x64 pixel art!
  - Sylvara (Blonde Elf Girl) & Velmira (Silver-White Gothic Vampire Girl)
    feature bespoke, ultra-expressive anime-medieval pixel eyes, lashes, hair
    strands, accessories, and facial expressions.
  - Knight keeps his scarred Fallen Greathelm on (`knight hamon ba kolah khod bashe`).
  - Behemoth features his scarred medieval pit-champion brow, headband & beard.

5 frames per 320x64 sheet:
    0 : idle_a    (calm / confident face)
    1 : idle_b    (subtle hair / plume / breathing motion)
    2 : blink     (eyes closed)
    3 : low_hp    (<= 35% HP: bruised, sweat drop, desperate grit!)
    4 : hurt      (taking a hit: 'AKH!' wince / shout / sparks!)

Writes:
    assets/textures/portrait_behemoth.png  (320 x 64)
    assets/textures/portrait_knight.png    (320 x 64)
    assets/textures/portrait_sylvara.png   (320 x 64)
    assets/textures/portrait_velmira.png   (320 x 64)
    docs/images/portraits_preview.png
"""

import math
from PIL import Image, ImageDraw

SZ = 64
FRAMES = 5
OUT = (10, 8, 14, 255)


def put(img: Image.Image, x: int, y: int, col) -> None:
    if 0 <= x < SZ and 0 <= y < SZ:
        img.putpixel((x, y), col)


def apply_circle_mask(img: Image.Image, bg_top, bg_bot) -> Image.Image:
    """Render portrait onto a crisp 2-tone pixel-art medallion disc clipped to r=29 (binary alpha)."""
    out = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    px_out = out.load()
    px_in = img.load()
    cx, cy = 31.5, 31.5
    for y in range(SZ):
        for x in range(SZ):
            dist = math.hypot(x - cx, y - cy)
            if dist <= 29.2:
                sr, sg, sb, sa = px_in[x, y]
                if sa >= 128:
                    r, g, b = sr, sg, sb
                    if (r, g, b) == (0, 0, 0):
                        r, g, b = OUT[0], OUT[1], OUT[2]
                    px_out[x, y] = (r, g, b, 255)
                else:
                    bc = bg_top if y < (33 + ((x + y) & 1) * 2) else bg_bot
                    px_out[x, y] = (bc[0], bc[1], bc[2], 255)
    return out


def clamp_sheet_palette(sheet: Image.Image, max_colours: int = 24) -> Image.Image:
    """Ensure <= max_colours opaque RGB values, zero #000000, and 100% binary alpha."""
    w, h = sheet.size
    alpha = sheet.getchannel("A")
    rgb = sheet.convert("RGB")
    quant = rgb.quantize(colors=max_colours, method=Image.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    qpx = quant.load()
    apx = alpha.load()
    for y in range(h):
        for x in range(w):
            if apx[x, y] >= 128:
                r, g, b = qpx[x, y]
                if (r, g, b) == (0, 0, 0):
                    r, g, b = OUT[0], OUT[1], OUT[2]
                opx[x, y] = (r, g, b, 255)
    return out


def draw_anime_eye(img: Image.Image, ex: int, ey: int, iris_dark, iris_mid, iris_hi,
                   state: str, is_left: bool) -> None:
    """Rich 9x8 pixel-art anime/fantasy eye with curved lashes & dual catchlights."""
    d = ImageDraw.Draw(img)
    if state == "blink":
        d.arc([ex - 4, ey - 2, ex + 4, ey + 3], 15, 165, fill=OUT, width=2)
        put(img, ex - 4 if is_left else ex + 4, ey + 1, OUT)
        return
    if state == "hurt":
        # Tight > < wince!
        if is_left:
            d.line([(ex - 4, ey - 3), (ex + 3, ey)], fill=OUT, width=2)
            d.line([(ex + 3, ey), (ex - 4, ey + 3)], fill=OUT, width=2)
        else:
            d.line([(ex + 4, ey - 3), (ex - 3, ey)], fill=OUT, width=2)
            d.line([(ex - 3, ey), (ex + 4, ey + 3)], fill=OUT, width=2)
        return

    # Sclera white
    d.rounded_rectangle([ex - 4, ey - 3, ex + 4, ey + 4], radius=2, fill=(252, 248, 252, 255))
    # Iris oval
    d.ellipse([ex - 3, ey - 3, ex + 3, ey + 4], fill=iris_dark)
    d.ellipse([ex - 2, ey - 1, ex + 2, ey + 3], fill=iris_mid)
    d.line([(ex - 1, ey + 2), (ex + 1, ey + 2)], fill=iris_hi)
    # Dark pupil center
    d.rectangle([ex - 1, ey - 1, ex + 1, ey + 1], fill=OUT)
    # Thick upper lash arch + wing flick!
    d.line([(ex - 4, ey - 3), (ex + 4, ey - 3)], fill=OUT, width=2)
    wing_x = ex - 5 if is_left else ex + 5
    put(img, wing_x, ey - 4, OUT)
    put(img, wing_x, ey - 3, OUT)
    # Dual starlight catchlights
    put(img, ex - 2, ey - 2, (255, 255, 255, 255))
    put(img, ex - 1, ey - 2, (255, 255, 255, 255))
    put(img, ex - 2, ey - 1, (255, 255, 255, 255))
    put(img, ex + 2, ey + 2, (255, 255, 255, 255))

    if state == "low_hp":
        # Furrowed desperate brow above eye
        if is_left:
            d.line([(ex - 4, ey - 5), (ex + 3, ey - 7)], fill=OUT, width=2)
        else:
            d.line([(ex - 3, ey - 7), (ex + 4, ey - 5)], fill=OUT, width=2)
    else:
        d.line([(ex - 3, ey - 6), (ex + 3, ey - 6)], fill=OUT, width=1)


def draw_sweat_and_bruise(img: Image.Image, cheek_x: int, cheek_y: int) -> None:
    d = ImageDraw.Draw(img)
    # Sweat droplet on temple
    d.polygon([(46, 21), (44, 26), (48, 26)], fill=(150, 228, 255, 255), outline=OUT)
    put(img, 46, 25, (255, 255, 255, 255))
    # Cheek scratch / bruise marks
    d.line([(cheek_x, cheek_y), (cheek_x + 4, cheek_y - 2)], fill=(185, 76, 90, 255))
    d.line([(cheek_x + 2, cheek_y + 2), (cheek_x + 5, cheek_y)], fill=(185, 76, 90, 255))


# ---------------------------------------------------------------------------
# 1. SYLVARA (Blonde Elf Girl Close-Up)
# ---------------------------------------------------------------------------
def portrait_sylvara(state: str) -> Image.Image:
    img = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    sway = 1 if state == "idle_b" else (-1 if state == "hurt" else 0)
    by = 1 if state == "hurt" else 0

    skin = (250, 218, 202, 255)
    skin_sha = (218, 174, 156, 255)
    bl_sha = (176, 126, 40, 255)
    bl_mid = (232, 184, 74, 255)
    bl_hi = (255, 238, 158, 255)

    # Back blonde hair mass + 45° feathered quiver tip + emerald collar shoulders
    d.line([(6, 14 + by), (16, 24 + by)], fill=(142, 92, 52, 255), width=3)
    d.line([(4, 12 + by), (9, 17 + by)], fill=(242, 244, 252, 255), width=2)
    d.ellipse([8 + sway, 8 + by, 56 + sway, 62 + by], fill=bl_sha, outline=OUT)
    d.ellipse([11 + sway, 10 + by, 53 + sway, 58 + by], fill=bl_mid)
    d.polygon([(14, 52 + by), (50, 52 + by), (56, 64), (8, 64)], fill=(34, 104, 70, 255), outline=OUT)
    d.line([(18, 53 + by), (30, 63)], fill=(142, 92, 52, 255), width=2)
    d.ellipse([29, 53 + by, 35, 59 + by], fill=(252, 224, 118, 255), outline=OUT)

    # Delicate long pointed Elven ears!
    d.polygon([(15, 31 + by), (3, 25 + by), (15, 39 + by)], fill=skin, outline=OUT)
    d.polygon([(49, 31 + by), (61, 25 + by), (49, 39 + by)], fill=skin, outline=OUT)
    d.line([(6, 27 + by), (13, 33 + by)], fill=skin_sha)
    d.line([(58, 27 + by), (51, 33 + by)], fill=skin_sha)

    # Neck & Face oval
    d.rectangle([27, 46 + by, 37, 55 + by], fill=skin_sha, outline=OUT)
    d.rounded_rectangle([16, 17 + by, 48, 49 + by], radius=12, fill=skin, outline=OUT)

    # Soft rosy blush
    d.ellipse([18, 37 + by, 24, 41 + by], fill=(246, 158, 168, 255))
    d.ellipse([40, 37 + by, 46, 41 + by], fill=(246, 158, 168, 255))

    # Big sparkling Emerald Eyes
    draw_anime_eye(img, 24, 33 + by, (16, 102, 66, 255), (52, 214, 132, 255), (186, 255, 214, 255), state, True)
    draw_anime_eye(img, 40, 33 + by, (16, 102, 66, 255), (52, 214, 132, 255), (186, 255, 214, 255), state, False)

    # Cute nose + Mouth per state
    put(img, 32, 38 + by, skin_sha)
    if state == "hurt":
        # Open 'AKH!' mouth
        d.rounded_rectangle([29, 42 + by, 35, 46 + by], radius=2, fill=(178, 52, 68, 255), outline=OUT)
        d.line([(30, 43 + by), (34, 43 + by)], fill=(255, 255, 255, 255))
    elif state == "low_hp":
        # Gritted worried mouth + sweat & scratch
        d.line([(29, 44 + by), (35, 43 + by)], fill=OUT, width=1)
        draw_sweat_and_bruise(img, 19, 41 + by)
    else:
        # Gentle warm smile
        d.arc([29, 41 + by, 35, 45 + by], 20, 160, fill=(186, 98, 104, 255), width=1)

    # Lush Golden-Blonde bangs & wavy side-curls + Silver-Emerald Tiara!
    for side in (-1, 1):
        sx = 32 + side * 15
        d.polygon([
            (32 + side * 10, 14 + by),
            (32 + side * 19, 20 + by),
            (32 + side * 20 + sway, 42 + by),
            (32 + side * 14 + sway, 54 + by),
            (32 + side * 11, 45 + by),
            (32 + side * 12, 26 + by),
        ], fill=bl_mid, outline=OUT)
        d.line([(sx + sway // 2, 20 + by), (sx + side * 1 + sway, 46 + by)], fill=bl_hi, width=2)
        d.line([(32 + side * 13, 28 + by), (32 + side * 13 + sway, 48 + by)], fill=bl_sha, width=1)

    d.chord([15, 8 + by, 49, 26 + by], 180, 360, fill=bl_mid, outline=OUT)
    d.arc([18, 10 + by, 46, 22 + by], 195, 345, fill=bl_hi, width=2)
    for bx0, bx1, tip_x, tip_y in ((18, 26, 21, 29), (24, 33, 29, 30), (31, 39, 35, 29), (37, 46, 42, 28)):
        d.polygon([(bx0, 15 + by), (bx1, 15 + by), (tip_x + sway, tip_y + by)], fill=bl_hi, outline=OUT)
        d.line([(bx0 + 2, 16 + by), (tip_x + sway, tip_y - 2 + by)], fill=(255, 248, 204, 255))

    d.arc([17, 13 + by, 47, 24 + by], 195, 345, fill=(252, 228, 128, 255), width=2)
    d.ellipse([29, 14 + by, 35, 21 + by], fill=(42, 232, 138, 255), outline=OUT)
    put(img, 31, 16 + by, (255, 255, 255, 255))
    put(img, 32, 18 + by, (186, 255, 214, 255))

    return apply_circle_mask(img, (18, 44, 34), (10, 22, 18))


# ---------------------------------------------------------------------------
# 2. VELMIRA (Silver-White Haired Gothic Vampire Girl Close-Up)
# ---------------------------------------------------------------------------
def portrait_velmira(state: str) -> Image.Image:
    img = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    sway = 1 if state == "idle_b" else (-1 if state == "hurt" else 0)
    by = 1 if state == "hurt" else 0

    skin = (244, 224, 232, 255)
    skin_sha = (196, 162, 178, 255)
    wh_sha = (154, 144, 182, 255)
    wh_mid = (224, 220, 240, 255)
    wh_hi = (252, 250, 255, 255)

    # Flowing moonlit silver-white hair mass + high gothic crimson-black collar
    d.ellipse([7 + sway, 7 + by, 57 + sway, 62 + by], fill=wh_sha, outline=OUT)
    d.ellipse([10 + sway, 9 + by, 54 + sway, 58 + by], fill=wh_mid)
    # High gothic vampire collar behind neck
    d.polygon([(12, 46 + by), (22, 54 + by), (10, 64), (54, 64), (42, 54 + by), (52, 46 + by)],
              fill=(98, 14, 38, 255), outline=OUT)
    d.polygon([(18, 53 + by), (46, 53 + by), (50, 64), (14, 64)], fill=(28, 18, 32, 255), outline=OUT)

    # Pointed pale Vampire ears
    d.polygon([(16, 32 + by), (6, 28 + by), (16, 39 + by)], fill=skin, outline=OUT)
    d.polygon([(48, 32 + by), (58, 28 + by), (48, 39 + by)], fill=skin, outline=OUT)

    # Neck + gothic black lace choker with ruby drop + Face
    d.rectangle([27, 46 + by, 37, 55 + by], fill=skin_sha, outline=OUT)
    d.line([(27, 51 + by), (37, 51 + by)], fill=OUT, width=2)
    put(img, 32, 52 + by, (238, 38, 74, 255))
    d.rounded_rectangle([16, 17 + by, 48, 49 + by], radius=12, fill=skin, outline=OUT)

    # Soft gothic rose blush
    d.ellipse([18, 37 + by, 24, 41 + by], fill=(232, 164, 184, 255))
    d.ellipse([40, 37 + by, 46, 41 + by], fill=(232, 164, 184, 255))

    # Luminous Ruby-Crimson Vampire Eyes!
    draw_anime_eye(img, 24, 33 + by, (92, 10, 34, 255), (218, 28, 68, 255), (255, 132, 160, 255), state, True)
    draw_anime_eye(img, 40, 33 + by, (92, 10, 34, 255), (218, 28, 68, 255), (255, 132, 160, 255), state, False)

    # Nose + Cute Vampire Fang Mouth!
    put(img, 32, 38 + by, skin_sha)
    if state == "hurt":
        d.rounded_rectangle([28, 42 + by, 36, 46 + by], radius=2, fill=(148, 18, 46, 255), outline=OUT)
        put(img, 30, 43 + by, (255, 255, 255, 255))
        put(img, 34, 43 + by, (255, 255, 255, 255))
    elif state == "low_hp":
        d.line([(28, 44 + by), (36, 44 + by)], fill=(148, 18, 46, 255), width=2)
        put(img, 34, 45 + by, (255, 255, 255, 255))  # fang + crimson corner trickle
        put(img, 35, 46 + by, (210, 24, 56, 255))
        draw_sweat_and_bruise(img, 19, 41 + by)
    else:
        d.line([(29, 43 + by), (35, 43 + by)], fill=(156, 56, 82, 255))
        put(img, 34, 44 + by, (255, 255, 255, 255))  # cute single white fang!

    # Asymmetric moonlit silver-white curls (extra-broad billowing LEFT fall matching skeleton!)
    for side in (-1, 1):
        w_extra = 4 if side == -1 else -2
        sx = 32 + side * (15 + (2 if side == -1 else 0))
        d.polygon([
            (32 + side * 10, 13 + by),
            (32 + side * (20 + w_extra), 19 + by),
            (32 + side * (21 + w_extra) + sway, 46 + by),
            (32 + side * (15 + w_extra) + sway, 60 + by),
            (32 + side * 11, 46 + by),
            (32 + side * 12, 26 + by),
        ], fill=wh_mid, outline=OUT)
        d.line([(sx + sway // 2, 19 + by), (sx + side * 1 + sway, 50 + by)], fill=wh_hi, width=2)
        d.line([(32 + side * 13, 27 + by), (32 + side * 13 + sway, 49 + by)], fill=wh_sha, width=1)

    d.chord([14, 7 + by, 50, 25 + by], 180, 360, fill=wh_mid, outline=OUT)
    d.arc([17, 9 + by, 47, 21 + by], 195, 345, fill=wh_hi, width=2)
    for bx0, bx1, tip_x, tip_y in ((18, 26, 21, 29), (25, 33, 29, 31), (31, 39, 35, 30), (37, 46, 42, 28)):
        d.polygon([(bx0, 14 + by), (bx1, 14 + by), (tip_x + sway, tip_y + by)], fill=wh_hi, outline=OUT)
        d.line([(bx0 + 1, 15 + by), (tip_x + sway, tip_y - 2 + by)], fill=(255, 255, 255, 255))

    rx, ry = 17, 19 + by
    d.polygon([(rx - 8, ry + 2), (rx - 3, ry + 6), (rx - 1, ry + 2)], fill=(28, 72, 48, 255), outline=OUT)
    d.ellipse([rx - 6, ry - 6, rx + 6, ry + 6], fill=(92, 10, 32, 255), outline=OUT)
    d.ellipse([rx - 4, ry - 4, rx + 4, ry + 4], fill=(186, 24, 58, 255))
    d.arc([rx - 3, ry - 3, rx + 3, ry + 3], 15, 275, fill=(252, 98, 128, 255))
    put(img, rx - 1, ry - 1, (255, 180, 198, 255))

    return apply_circle_mask(img, (44, 14, 32), (18, 8, 18))


# ---------------------------------------------------------------------------
# 3. KNIGHT (Fallen Knight IN GREATHELM - `knight hamon ba kolah khod bashe`)
# ---------------------------------------------------------------------------
def portrait_knight(state: str) -> Image.Image:
    img = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    sway = 2 if state == "idle_b" else (-2 if state == "hurt" else 0)
    by = 2 if state == "hurt" else 0

    st_dark = (34, 38, 52, 255)
    st_mid = (64, 74, 96, 255)
    st_lit = (106, 120, 150, 255)
    st_hi = (168, 186, 218, 255)

    # Tattered crimson plume + Zweihander greatsword blade behind right shoulder + armored gorget
    d.polygon([(14, 16 + by), (4 + sway, 9 + by), (6 + sway, 24 + by), (18, 26 + by)],
              fill=(124, 24, 44, 255), outline=OUT)
    d.polygon([(47, 48 + by), (56, 12 + by), (59, 14 + by), (52, 50 + by)], fill=st_hi, outline=OUT)
    d.line([(45, 44 + by), (55, 47 + by)], fill=(232, 184, 74, 255), width=2)
    d.polygon([(8, 50 + by), (56, 50 + by), (60, 64), (4, 64)], fill=st_dark, outline=OUT)
    # Glowing betrayal scar across collar
    d.line([(22, 53 + by), (40, 61 + by)], fill=(255, 118, 54, 255), width=2)

    # Imposing Fallen Greathelm Dome + Jagged Crown Horns
    d.rounded_rectangle([15, 14 + by, 49, 51 + by], radius=8, fill=st_mid, outline=OUT)
    d.rounded_rectangle([18, 16 + by, 46, 28 + by], radius=4, fill=st_lit)
    d.line([(21, 18 + by), (41, 18 + by)], fill=st_hi, width=2)
    for hx in (19, 32, 45):
        d.polygon([(hx - 3, 15 + by), (hx, 7 + by), (hx + 3, 15 + by)], fill=st_dark, outline=OUT)
        put(img, hx, 10 + by, st_hi)

    # Gold nasal cross-brace + Deep T-Visor Slit
    d.rectangle([30, 24 + by, 34, 49 + by], fill=(184, 142, 62, 255), outline=OUT)
    d.rectangle([19, 29 + by, 45, 35 + by], fill=OUT)
    d.rectangle([30, 35 + by, 34, 47 + by], fill=OUT)

    # Cheekplate breathing slits + battle crack over right brow
    for vy in (39 + by, 43 + by, 47 + by):
        for vx in (22, 26, 38, 42):
            put(img, vx, vy, OUT)
    d.line([(38, 17 + by), (43, 28 + by)], fill=OUT, width=2)
    if state in ("low_hp", "hurt"):
        # Extra glowing ember fissures when low HP or taking a hit!
        d.line([(20, 20 + by), (26, 28 + by)], fill=(255, 120, 52, 255), width=1)
        d.line([(39, 18 + by), (43, 28 + by)], fill=(255, 156, 72, 255), width=1)

    # Glowing eyes inside the dark visor!
    if state == "blink":
        eye_c = (48, 96, 126, 255)
        for ex in (24, 39):
            d.line([(ex - 1, 32 + by), (ex + 2, 32 + by)], fill=eye_c)
    elif state == "hurt":
        # Blazing impact sparks & jolted ember eyes!
        for ex in (24, 39):
            d.rectangle([ex - 2, 30 + by, ex + 2, 33 + by], fill=(255, 224, 132, 255))
        for sx, sy in ((13, 26), (51, 23), (48, 39)):
            d.line([(sx, sy), (sx + 3, sy - 3)], fill=(255, 214, 118, 255), width=2)
    elif state == "low_hp":
        # Desperate burning crimson-amber visor glow!
        for ex in (24, 39):
            d.ellipse([ex - 3, 30 + by, ex + 3, 34 + by], fill=(255, 92, 46, 255))
            put(img, ex, 32 + by, (255, 240, 180, 255))
    else:
        # Cold haunting cyan Fallen Knight eye-glow
        for ex in (24, 39):
            d.ellipse([ex - 2, 30 + by, ex + 2, 34 + by], fill=(92, 218, 255, 255))
            put(img, ex, 32 + by, (230, 252, 255, 255))

    return apply_circle_mask(img, (24, 32, 52), (12, 14, 24))


# ---------------------------------------------------------------------------
# 4. BEHEMOTH (Medieval Pit-Champion Brawler Close-Up)
# ---------------------------------------------------------------------------
def portrait_brawler(state: str) -> Image.Image:
    img = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    sway = 2 if state == "idle_b" else (-2 if state == "hurt" else 0)
    by = 1 if state == "hurt" else 0

    skin = (224, 164, 124, 255)
    skin_sha = (182, 122, 88, 255)
    hair = (58, 36, 22, 255)
    hair_hi = (98, 64, 40, 255)

    # Crimson headband tail + massive hunched bull-traps & spiked iron pauldron!
    d.polygon([(14, 22 + by), (4 + sway, 26 + by), (7 + sway, 34 + by), (16, 29 + by)],
              fill=(178, 30, 44, 255), outline=OUT)
    d.polygon([(2, 44 + by), (62, 44 + by), (62, 64), (2, 64)], fill=(104, 64, 38, 255), outline=OUT)
    d.ellipse([3, 42 + by, 18, 56 + by], fill=(116, 132, 162, 255), outline=OUT)
    d.polygon([(7, 43 + by), (10, 35 + by), (14, 43 + by)], fill=(184, 200, 226, 255), outline=OUT)

    # Rugged square jaw & hair crown
    d.rounded_rectangle([16, 15 + by, 48, 50 + by], radius=9, fill=skin, outline=OUT)
    d.rounded_rectangle([15, 11 + by, 49, 23 + by], radius=5, fill=hair, outline=OUT)
    d.line([(20, 14 + by), (42, 14 + by)], fill=hair_hi, width=2)

    # Studded Medieval Crimson Headband across brow
    d.rectangle([15, 20 + by, 49, 26 + by], fill=(178, 30, 44, 255), outline=OUT)
    for rx in (21, 32, 43):
        d.ellipse([rx - 1, 22 + by, rx + 1, 24 + by], fill=(242, 196, 76, 255))

    # Diagonal battle scar across left eye/cheek
    d.line([(22, 27 + by), (26, 40 + by)], fill=(168, 48, 56, 255), width=2)

    # Fierce Amber Brawler Eyes
    if state == "blink":
        d.line([(21, 33 + by), (28, 33 + by)], fill=OUT, width=2)
        d.line([(36, 33 + by), (43, 33 + by)], fill=OUT, width=2)
    elif state == "hurt":
        d.line([(20, 30 + by), (27, 33 + by)], fill=OUT, width=2)
        d.line([(27, 33 + by), (20, 36 + by)], fill=OUT, width=2)
        d.line([(44, 30 + by), (37, 33 + by)], fill=OUT, width=2)
        d.line([(37, 33 + by), (44, 36 + by)], fill=OUT, width=2)
    else:
        for ex in (24, 40):
            d.rectangle([ex - 3, 31 + by, ex + 3, 35 + by], fill=(250, 246, 242, 255), outline=OUT)
            d.rectangle([ex - 1, 32 + by, ex + 1, 34 + by], fill=(238, 168, 42, 255))
            put(img, ex, 33 + by, OUT)
            put(img, ex - 1, 32 + by, (255, 255, 255, 255))
        # Fierce brows
        d.line([(19, 28 + by), (28, 30 + by)], fill=OUT, width=2)
        d.line([(45, 28 + by), (36, 30 + by)], fill=OUT, width=2)

    # Broad nose + Thick Medieval Braided Beard & Mustache!
    d.rectangle([30, 34 + by, 34, 39 + by], fill=skin_sha)
    d.rounded_rectangle([17, 40 + by, 47, 55 + by], radius=6, fill=hair, outline=OUT)
    d.line([(21, 42 + by), (43, 42 + by)], fill=hair_hi, width=2)
    if state == "hurt":
        # Roaring 'AKH!' mouth open inside beard!
        d.rounded_rectangle([27, 43 + by, 37, 49 + by], radius=2, fill=(168, 34, 44, 255), outline=OUT)
        d.line([(28, 44 + by), (36, 44 + by)], fill=(255, 255, 255, 255), width=2)
    elif state == "low_hp":
        # Clenched white teeth grin + sweat & bruise
        d.rectangle([28, 44 + by, 36, 47 + by], fill=(248, 244, 236, 255), outline=OUT)
        draw_sweat_and_bruise(img, 38, 38 + by)
    else:
        # Gold beard ring clasp at chin
        d.rectangle([29, 51 + by, 35, 55 + by], fill=(242, 196, 76, 255), outline=OUT)

    return apply_circle_mask(img, (54, 32, 22), (26, 14, 12))


def main() -> None:
    states = ["idle_a", "idle_b", "blink", "low_hp", "hurt"]
    builders = [
        ("portrait_behemoth.png", "BEHEMOTH", portrait_brawler),
        ("portrait_knight.png", "FALLEN KNIGHT", portrait_knight),
        ("portrait_sylvara.png", "SYLVARA (ELF)", portrait_sylvara),
        ("portrait_velmira.png", "VELMIRA (VAMPIRE)", portrait_velmira),
    ]

    zoom, pad = 2, 12
    pw = pad + FRAMES * (SZ * zoom + pad) + 120
    ph = pad + len(builders) * (SZ * zoom + pad)
    preview = Image.new("RGBA", (pw, ph), (18, 16, 24, 255))
    pd = ImageDraw.Draw(preview)

    for row, (fname, title, fn) in enumerate(builders):
        raw_sheet = Image.new("RGBA", (SZ * FRAMES, SZ), (0, 0, 0, 0))
        for col, st in enumerate(states):
            fr = fn(st)
            raw_sheet.alpha_composite(fr, (col * SZ, 0))
        sheet = clamp_sheet_palette(raw_sheet, max_colours=22)
        for col in range(FRAMES):
            fr = sheet.crop((col * SZ, 0, (col + 1) * SZ, SZ))
            x = 120 + pad + col * (SZ * zoom + pad)
            y = pad + row * (SZ * zoom + pad)
            preview.alpha_composite(fr.resize((SZ * zoom, SZ * zoom), Image.NEAREST), (x, y))
            if row == 0:
                pd.text((x, 2), states[col], fill=(220, 214, 236, 255))
        pd.text((10, pad + row * (SZ * zoom + pad) + 54), title, fill=(244, 228, 196, 255))
        out_path = f"assets/textures/{fname}"
        sheet.save(out_path)
        print("wrote", out_path, sheet.size)

    preview.save("docs/images/portraits_preview.png")
    print("wrote docs/images/portraits_preview.png")


if __name__ == "__main__":
    main()
