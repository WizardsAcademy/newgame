#!/usr/bin/env python
"""Generate Sylvara's 9-frame 96x96 Blonde Medieval Elven Ranger sheet.

Art direction:
  - Lush golden-blonde wavy locks + long pointed elven ears + silver-emerald
    circlet tiara + expressive emerald eyes,
  - Medieval forest-emerald ranger mantle & gold-trimmed leather bodice,
    feathered quiver on back, tall laced ranger boots,
  - Ornate Golden-Yew Elven Recurve Bow VISIBLY HELD IN HER HAND in every pose,
  - Clear Bow-Draw & Glowing Emerald Charge animation + Sylvan Leaf Vault + Hurt!

Writes:
    assets/textures/player_pari.png     864 x 96 (9 frames of 96x96)
    docs/images/sylvara_preview.png     review sheet

SHEET LAYOUT (matches scenes/player/Pari.tscn):
    0 : idle            (Recurve Bow held at ready)
    1 : walk A
    2 : walk B
    3 : bow draw        (raises Recurve Bow forward, nocks emerald arrow)
    4 : bow charge      (pulls glowing bowstring taut to cheek, blazing arrowhead!)
    5 : bow release     (bowstring snaps forward, open draw hand)
    6 : wind vault      (airborne Sylvan Windstep leap + swirling leaves)
    7 : hurt            (recoiling wince pose)
    8 : blink           (lashes gently closed)
"""

import math
from PIL import Image, ImageDraw

FRAME = 96
FRAMES = 9

OUTLINE = (11, 10, 14, 255)
SKIN = (248, 214, 198, 255)
SKIN_SHA = (212, 166, 150, 255)
BLUSH = (244, 152, 162, 255)

BLONDE_SHA = (176, 126, 42, 255)
BLONDE_MID = (224, 178, 72, 255)
BLONDE_LIT = (248, 216, 112, 255)
BLONDE_HI = (255, 242, 176, 255)

CLOAK_DEEP = (20, 62, 44, 255)
CLOAK_MID = (34, 98, 66, 255)
CLOAK_LIT = (58, 142, 92, 255)
LEATHER_DARK = (74, 46, 30, 255)
LEATHER_MID = (118, 76, 48, 255)
GOLD_MID = (208, 164, 62, 255)
GOLD_HI = (252, 224, 118, 255)

EMERALD_DARK = (18, 122, 78, 255)
EMERALD_BRIGHT = (72, 244, 152, 255)
EMERALD_GLOW = (196, 255, 218, 255)
STRING_COL = (226, 236, 232, 225)


def put(img: Image.Image, x: int, y: int, col) -> None:
    if 0 <= x < FRAME and 0 <= y < FRAME:
        img.putpixel((x, y), col)


def pill_limb(img: Image.Image, x0: float, y0: float, x1: float, y1: float, r: int,
              dark_c, mid_c, hi_c) -> None:
    steps = max(int(math.hypot(x1 - x0, y1 - y0) * 2), 4)
    d = ImageDraw.Draw(img)
    for pass_id in range(3):
        for i in range(steps + 1):
            t = i / steps
            cx = x0 + (x1 - x0) * t
            cy = y0 + (y1 - y0) * t
            if pass_id == 0:
                rr = r + 1
                d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=OUTLINE)
            elif pass_id == 1:
                d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=dark_c)
                rr2 = max(r - 1, 1)
                d.ellipse([cx - rr2, cy - rr2 - 1, cx + rr2, cy + rr2 - 1], fill=mid_c)
            else:
                rr3 = max(r - 2, 1)
                d.ellipse([cx - rr3, cy - rr3 - 1, cx + rr3 - 1, cy - 1], fill=hi_c)


def draw_blonde_hair_back(img: Image.Image, cx: int, cy: int, sway: int = 0) -> None:
    """Long cascading golden-blonde back hair locks reaching down past her waist!"""
    d = ImageDraw.Draw(img)
    pts = [
        (cx - 13, cy - 22),
        (cx + 12, cy - 22),
        (cx + 18 + sway, cy + 4),
        (cx + 14 + sway, cy + 16),
        (cx + 8 + sway, cy + 11),
        (cx + 2 + sway, cy + 19),
        (cx - 5 + sway, cy + 12),
        (cx - 12 + sway, cy + 18),
        (cx - 19 + sway, cy + 6),
    ]
    d.polygon(pts, fill=BLONDE_SHA, outline=OUTLINE)
    inner = [
        (cx - 11, cy - 19),
        (cx + 10, cy - 19),
        (cx + 14 + sway, cy + 7),
        (cx - 1 + sway, cy + 13),
        (cx - 14 + sway, cy + 7),
    ]
    d.polygon(inner, fill=BLONDE_MID)
    # Wavy sunlit golden highlights down the locks
    for lx in (-9, -2, 6):
        d.line([(cx + lx, cy - 12), (cx + lx + sway // 2, cy + 8)], fill=BLONDE_LIT, width=2)


def draw_quiver(img: Image.Image, cx: int, cy: int) -> None:
    """Feathered elven leather quiver peeking above her left shoulder!"""
    d = ImageDraw.Draw(img)
    d.polygon([(cx - 10, cy - 8), (cx - 17, cy - 22), (cx - 12, cy - 24), (cx - 6, cy - 9)],
              fill=LEATHER_MID, outline=OUTLINE)
    # Emerald & white arrow fletchings sticking out
    for fx, fy in ((cx - 17, cy - 26), (cx - 14, cy - 28), (cx - 11, cy - 26)):
        d.line([(fx + 2, fy + 4), (fx, fy)], fill=EMERALD_BRIGHT, width=2)
        put(img, fx, fy - 1, GOLD_HI)


def draw_elf_head(img: Image.Image, cx: int, cy: int, blink: bool = False,
                  hurt: bool = False, charge_focus: bool = False) -> None:
    d = ImageDraw.Draw(img)
    # Crown hair dome
    d.ellipse([cx - 13, cy - 14, cx + 13, cy + 8], fill=BLONDE_MID, outline=OUTLINE)
    d.arc([cx - 10, cy - 12, cx + 10, cy - 2], 195, 345, fill=BLONDE_HI, width=2)

    # Long delicate pointed Elven ears jutting out both sides!
    d.polygon([(cx - 10, cy - 1), (cx - 19, cy - 5), (cx - 11, cy + 4)], fill=SKIN, outline=OUTLINE)
    d.polygon([(cx + 10, cy - 1), (cx + 19, cy - 5), (cx + 11, cy + 4)], fill=SKIN, outline=OUTLINE)
    put(img, cx - 15, cy - 3, SKIN_SHA)
    put(img, cx + 15, cy - 3, SKIN_SHA)

    # Soft heart-shaped pixel face
    d.rounded_rectangle([cx - 9, cy - 7, cx + 9, cy + 9], radius=5, fill=SKIN, outline=OUTLINE)
    # Rosy cheeks
    put(img, cx - 6, cy + 3, BLUSH)
    put(img, cx + 6, cy + 3, BLUSH)

    # Expressive Emerald Anime-Pixel Eyes!
    if hurt:
        d.line([(cx - 6, cy - 1), (cx - 2, cy + 1)], fill=OUTLINE)
        d.line([(cx - 2, cy + 1), (cx - 6, cy + 3)], fill=OUTLINE)
        d.line([(cx + 6, cy - 1), (cx + 2, cy + 1)], fill=OUTLINE)
        d.line([(cx + 2, cy + 1), (cx + 6, cy + 3)], fill=OUTLINE)
        d.rectangle([cx - 1, cy + 5, cx + 2, cy + 7], fill=(185, 65, 78, 255))
    elif blink:
        d.line([(cx - 6, cy + 1), (cx - 2, cy + 1)], fill=OUTLINE)
        d.line([(cx + 2, cy + 1), (cx + 6, cy + 1)], fill=OUTLINE)
        put(img, cx, cy + 5, SKIN_SHA)
    else:
        for ex in (cx - 5, cx + 2):
            # Dark upper lash + vibrant emerald iris + white starlight catchlight!
            d.rectangle([ex, cy - 2, ex + 3, cy + 2], fill=EMERALD_DARK)
            d.line([(ex - 1, cy - 2), (ex + 3, cy - 2)], fill=OUTLINE)
            put(img, ex + 1, cy, EMERALD_BRIGHT)
            put(img, ex + 2, cy + 1, EMERALD_GLOW if charge_focus else EMERALD_BRIGHT)
            put(img, ex, cy - 1, (255, 255, 255, 255))
        put(img, cx, cy + 5, SKIN_SHA)

    # Side bangs & golden forelocks framing cheeks + Silver-Emerald Tiara!
    d.polygon([(cx - 11, cy - 8), (cx - 7, cy - 8), (cx - 9, cy + 9), (cx - 12, cy + 4)],
              fill=BLONDE_LIT, outline=OUTLINE)
    d.polygon([(cx + 7, cy - 8), (cx + 11, cy - 8), (cx + 12, cy + 4), (cx + 9, cy + 9)],
              fill=BLONDE_LIT, outline=OUTLINE)
    d.polygon([(cx - 5, cy - 10), (cx + 5, cy - 10), (cx + 1, cy - 3), (cx - 2, cy - 4)],
              fill=BLONDE_HI)
    # Tiara circlet + glowing emerald center gem
    d.line([(cx - 8, cy - 9), (cx + 8, cy - 9)], fill=GOLD_HI, width=2)
    d.ellipse([cx - 2, cy - 11, cx + 2, cy - 7], fill=EMERALD_BRIGHT, outline=OUTLINE)
    put(img, cx - 1, cy - 10, EMERALD_GLOW)


def draw_recurve_bow(img: Image.Image, gx: float, gy: float, angle_deg: float,
                     pull_px: float = 0.0, arrow_state: str = "none") -> None:
    """Ornate Golden-Yew Elven Recurve Bow held at (gx, gy), with taut string
    and optional nocked / blazing emerald-charged Great-Arrow!"""
    rad = math.radians(angle_deg)
    ux, uy = math.cos(rad), math.sin(rad)
    px, py = -uy, ux
    d = ImageDraw.Draw(img)

    # Recurve bow arc: bends deeper as pull_px increases!
    bend = 5.0 + pull_px * 0.25
    half_span = 18.0 - pull_px * 0.12
    bow_pts = []
    for i in range(17):
        s = -1.0 + 2.0 * (i / 16.0)
        # Recurve S-tips flare slightly forward at the very ends!
        recurve = -bend * (s * s) + (2.2 * (abs(s) - 0.78) * 4.5 if abs(s) > 0.78 else 0.0)
        bx = gx + ux * recurve + px * (s * half_span)
        by = gy + uy * recurve + py * (s * half_span)
        bow_pts.append((bx, by))

    tip_top = bow_pts[0]
    tip_bot = bow_pts[-1]
    nock_pt = (gx - ux * (4.5 + pull_px), gy - uy * (4.5 + pull_px))

    # Bowstring (2 taut segments from tips to nock point!)
    d.line([tip_top, nock_pt, tip_bot], fill=STRING_COL, width=1)

    # Curved Yew & Gold bow stave
    d.line(bow_pts, fill=OUTLINE, width=5)
    d.line(bow_pts, fill=GOLD_MID, width=3)
    d.line(bow_pts[4:13], fill=GOLD_HI, width=1)
    # Emerald leaf riser gem at bow grip
    ix, iy = int(round(gx + ux * 1)), int(round(gy + uy * 1))
    d.ellipse([ix - 2, iy - 2, ix + 2, iy + 2], fill=EMERALD_BRIGHT, outline=OUTLINE)

    # Nocked / Charged Emerald Arrow!
    if arrow_state in ("nocked", "charged"):
        shaft_end = (gx + ux * 11.0, gy + uy * 11.0)
        d.line([nock_pt, shaft_end], fill=OUTLINE, width=3)
        d.line([nock_pt, shaft_end], fill=GOLD_HI if arrow_state == "charged" else LEATHER_MID, width=1)
        # Arrowhead
        tx, ty = int(round(shaft_end[0])), int(round(shaft_end[1]))
        if arrow_state == "charged":
            # Radiant emerald starlight aura at arrowhead!
            d.ellipse([tx - 6, ty - 6, tx + 6, ty + 6], fill=(72, 244, 152, 95))
            d.ellipse([tx - 3, ty - 3, tx + 3, ty + 3], fill=EMERALD_BRIGHT, outline=OUTLINE)
            for dx, dy in ((-7, 0), (7, 0), (0, -7), (0, 7)):
                d.line([(tx, ty), (tx + dx, ty + dy)], fill=EMERALD_GLOW, width=1)
            put(img, tx, ty, (255, 255, 255, 255))
        else:
            d.polygon([
                (tx + ux * 4, ty + uy * 4),
                (tx - px * 3, ty - py * 3),
                (tx + px * 3, ty + py * 3),
            ], fill=EMERALD_BRIGHT, outline=OUTLINE)
    elif arrow_state == "released":
        # Snap vibration lines + emerald streak leaving the bow!
        d.line([(gx + ux * 6, gy + uy * 6), (gx + ux * 26, gy + uy * 26)],
               fill=EMERALD_GLOW, width=2)


def build_sylvara_pose(pose: str) -> Image.Image:
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    cx, cy = 44, 50
    sway = 0
    leg_l, leg_r = (-5, 26), (5, 26)

    if pose == "walk_a":
        cy -= 1
        leg_l, leg_r = (-8, 24), (7, 27)
        sway = -2
    elif pose == "walk_b":
        cy -= 1
        leg_l, leg_r = (-2, 27), (3, 23)
        sway = -1
    elif pose == "draw":
        cx += 1
        sway = -2
    elif pose == "charge":
        cx -= 1
        leg_l, leg_r = (-8, 26), (8, 26)
        sway = -4
    elif pose == "release":
        cx += 2
        sway = -3
    elif pose == "vault":
        cx += 4
        cy -= 6
        leg_l, leg_r = (-11, 21), (8, 18)
        sway = -8
    elif pose == "hurt":
        cx -= 4
        cy += 1
        sway = 4

    # 1. Flowing blonde hair back + feathered quiver + forest cloak
    draw_quiver(img, cx, cy)
    draw_blonde_hair_back(img, cx, cy, sway=sway)

    cloak = [
        (cx - 10, cy - 8),
        (cx + 10, cy - 8),
        (cx + 14 + sway, cy + 18),
        (cx - 14 + sway, cy + 18),
    ]
    d.polygon(cloak, fill=CLOAK_DEEP, outline=OUTLINE)

    # 2. Slender legs & tall laced ranger boots
    for lx, ly in ((cx + leg_l[0], cy + leg_l[1]), (cx + leg_r[0], cy + leg_r[1])):
        pill_limb(img, cx + (leg_l[0] // 2 if lx < cx else leg_r[0] // 2), cy + 12, lx, ly - 6, 3,
                  SKIN_SHA, SKIN, SKIN)
        d.rounded_rectangle([lx - 4, ly - 8, lx + 4, ly + 2], radius=2, fill=LEATHER_DARK, outline=OUTLINE)
        d.line([(lx - 3, ly - 7), (lx + 3, ly - 7)], fill=GOLD_MID)
        put(img, lx, ly - 4, GOLD_HI)

    # 3. Fitted Emerald & Gold-Laced Medieval Ranger Tunic + Skirt
    skirt = [
        (cx - 9, cy + 5),
        (cx + 9, cy + 5),
        (cx + 13, cy + 16),
        (cx - 13, cy + 16),
    ]
    d.polygon(skirt, fill=CLOAK_MID, outline=OUTLINE)
    d.line([(cx - 11, cy + 15), (cx + 11, cy + 15)], fill=GOLD_HI)

    bodice = [
        (cx - 9, cy - 8),
        (cx + 9, cy - 8),
        (cx + 7, cy + 7),
        (cx - 7, cy + 7),
    ]
    d.polygon(bodice, fill=LEATHER_MID, outline=OUTLINE)
    # Emerald shoulder mantle capelet with gold clasp
    d.polygon([(cx - 11, cy - 9), (cx + 11, cy - 9), (cx + 9, cy - 1), (cx, cy + 2), (cx - 9, cy - 1)],
              fill=CLOAK_LIT, outline=OUTLINE)
    d.ellipse([cx - 2, cy - 6, cx + 2, cy - 2], fill=GOLD_HI, outline=OUTLINE)

    # 4. Blonde Elven Head
    draw_elf_head(img, cx, cy - 18, blink=(pose == "blink"), hurt=(pose == "hurt"),
                  charge_focus=(pose == "charge"))

    # 5. Arms + ALWAYS-HELD Golden-Yew Recurve Bow!
    if pose in ("idle", "blink", "walk_a", "walk_b"):
        # Left hand holds bow comfortably at her right side, always visible!
        pill_limb(img, cx + 8, cy - 4, cx + 16, cy + 2, 2, CLOAK_DEEP, CLOAK_LIT, SKIN)
        draw_recurve_bow(img, cx + 19, cy + 2, 22 if pose != "walk_a" else 14, pull_px=0.0)
    elif pose == "draw":
        # Raises bow straight ahead & nocks arrow!
        pill_limb(img, cx + 8, cy - 5, cx + 22, cy - 4, 2, CLOAK_DEEP, CLOAK_LIT, SKIN)
        draw_recurve_bow(img, cx + 25, cy - 4, 0.0, pull_px=4.0, arrow_state="nocked")
        pill_limb(img, cx - 5, cy - 5, cx + 14, cy - 4, 2, CLOAK_DEEP, CLOAK_LIT, SKIN)
    elif pose == "charge":
        # Full taut bow draw — glowing emerald arrow pulled right back to cheek!
        pill_limb(img, cx + 8, cy - 5, cx + 24, cy - 5, 2, CLOAK_DEEP, CLOAK_LIT, SKIN)
        draw_recurve_bow(img, cx + 27, cy - 5, 0.0, pull_px=11.0, arrow_state="charged")
        pill_limb(img, cx - 6, cy - 5, cx + 10, cy - 5, 2, CLOAK_DEEP, CLOAK_LIT, SKIN)
    elif pose == "release":
        pill_limb(img, cx + 8, cy - 5, cx + 24, cy - 5, 2, CLOAK_DEEP, CLOAK_LIT, SKIN)
        draw_recurve_bow(img, cx + 27, cy - 5, 0.0, pull_px=0.0, arrow_state="released")
        pill_limb(img, cx - 6, cy - 5, cx - 12, cy - 8, 2, CLOAK_DEEP, CLOAK_LIT, SKIN)
    elif pose == "vault":
        # Airborne Sylvan Windstep leap with swirling emerald leaves!
        pill_limb(img, cx + 8, cy - 5, cx + 19, cy - 9, 2, CLOAK_DEEP, CLOAK_LIT, SKIN)
        draw_recurve_bow(img, cx + 22, cy - 9, -28.0, pull_px=0.0)
        for lx, ly in ((cx - 22, cy + 2), (cx - 16, cy + 14), (cx - 26, cy - 8), (cx + 12, cy + 18)):
            d.ellipse([lx - 3, ly - 1, lx + 3, ly + 2], fill=EMERALD_BRIGHT, outline=OUTLINE)
    elif pose == "hurt":
        pill_limb(img, cx + 6, cy - 4, cx + 14, cy - 2, 2, CLOAK_DEEP, CLOAK_LIT, SKIN)
        draw_recurve_bow(img, cx + 16, cy - 2, 35.0, pull_px=0.0)

    return img


def main() -> None:
    poses = ["idle", "walk_a", "walk_b", "draw", "charge", "release", "vault", "hurt", "blink"]
    sheet = Image.new("RGBA", (FRAME * len(poses), FRAME), (0, 0, 0, 0))
    for i, p in enumerate(poses):
        sheet.alpha_composite(build_sylvara_pose(p), (i * FRAME, 0))
    sheet.save("assets/textures/player_pari.png")
    print("wrote assets/textures/player_pari.png", sheet.size)

    zoom, pad = 2, 10
    w = pad + len(poses) * (FRAME * zoom + pad)
    h = 30 + FRAME * zoom + 24
    prev = Image.new("RGBA", (w, h), (16, 26, 22, 255))
    d = ImageDraw.Draw(prev)
    d.text((pad, 8), "SYLVARA (BLONDE ELVEN RANGER) - 9 frames x 96x96", fill=(214, 248, 222, 255))
    for i, p in enumerate(poses):
        x = pad + i * (FRAME * zoom + pad)
        fr = sheet.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME))
        prev.alpha_composite(fr.resize((FRAME * zoom, FRAME * zoom), Image.NEAREST), (x, 28))
        d.text((x, 28 + FRAME * zoom + 4), f"{i}:{p}", fill=(176, 232, 192, 255))
    prev.save("docs/images/sylvara_preview.png")


if __name__ == "__main__":
    main()
