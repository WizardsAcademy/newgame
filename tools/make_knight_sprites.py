#!/usr/bin/env python
"""Generate Knight's 10-frame 96x96 Betrayed Fallen Knight sprite sheet.

Art direction:
  - Darkened, battle-scarred medieval plate armor with cracked silver trim,
  - Betrayal wound: jagged ember-glowing rift across the breastplate + broken
    spear shaft jutting from his back pauldron + tattered dark-crimson cape,
  - Visored Fallen Greathelm with haunting pale-cyan / ember glowing slit,
  - Scarred Dark-Iron Tower/Kite Shield + COLOSSAL Zweihander Greatsword!

Writes:
    assets/textures/player_bahman.png    960 x 96 (10 frames of 96x96)
    docs/images/knight_preview.png       review sheet

SHEET LAYOUT (matches scenes/player/Bahman.tscn):
    0 : idle
    1 : walk A
    2 : walk B
    3 : cleave windup   (colossal greatsword coiled high behind shoulder)
    4 : cleave sweep    (giant greatsword sweeping wide right + arc)
    5 : cleave spin     (full rotational follow-through spin + crescent)
    6 : guard           (Tower Shield raised firmly in front)
    7 : shield charge   (Shield locked forward, lunging Shift ram)
    8 : hurt            (recoiling stagger + sparks from betrayal crack)
    9 : blink           (visor glow dims)
"""

import math
from PIL import Image, ImageDraw

FRAME = 96
FRAMES = 10

OUTLINE = (10, 10, 16, 255)
STEEL_DARK = (34, 38, 50, 255)
STEEL_MID = (58, 65, 84, 255)
STEEL_LIT = (92, 104, 130, 255)
STEEL_HI = (146, 162, 192, 255)
BLADE_EDGE = (214, 226, 246, 255)
GOLD_DARK = (112, 82, 34, 255)
GOLD_LIT = (188, 146, 64, 255)
CAPE_DEEP = (46, 10, 22, 255)
CAPE_MID = (86, 18, 36, 255)
CAPE_HI = (132, 30, 52, 255)
SCAR_GLOW = (255, 112, 52, 255)
SCAR_CORE = (255, 214, 128, 255)
EYE_CYAN = (120, 232, 255, 255)
EYE_DIM = (52, 112, 142, 255)
WOOD_DARK = (72, 46, 28, 255)


def put(img: Image.Image, x: int, y: int, col) -> None:
    if 0 <= x < FRAME and 0 <= y < FRAME:
        img.putpixel((x, y), col)


def outlined_poly(img: Image.Image, pts, fill_col, hi_col=None) -> None:
    d = ImageDraw.Draw(img)
    ipts = [(int(round(x)), int(round(y))) for x, y in pts]
    d.polygon(ipts, fill=fill_col, outline=OUTLINE)
    if hi_col and len(ipts) >= 2:
        d.line([ipts[0], ipts[1]], fill=hi_col, width=1)


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


def draw_tattered_cape(img: Image.Image, cx: int, cy: int, sway_x: int = 0, flare: int = 0) -> None:
    """Ragged, battle-torn crimson Fallen Knight cloak."""
    pts = [
        (cx - 11, cy - 8),
        (cx + 9, cy - 8),
        (cx + 15 + flare + sway_x, cy + 32),
        (cx + 9 + sway_x, cy + 27),
        (cx + 4 + sway_x, cy + 35),
        (cx - 2 + sway_x, cy + 28),
        (cx - 8 + sway_x, cy + 36),
        (cx - 13 + sway_x, cy + 29),
        (cx - 19 - flare + sway_x, cy + 34),
    ]
    outlined_poly(img, pts, CAPE_DEEP)
    d = ImageDraw.Draw(img)
    inner = [
        (cx - 9, cy - 5),
        (cx + 6, cy - 5),
        (cx + 10 + sway_x, cy + 26),
        (cx - 3 + sway_x, cy + 24),
        (cx - 13 + sway_x, cy + 28),
    ]
    d.polygon(inner, fill=CAPE_MID)
    # Torn holes in the lower cloak
    for hx, hy in ((cx - 9 + sway_x, cy + 22), (cx + 5 + sway_x, cy + 24), (cx - 2 + sway_x, cy + 19)):
        for dy in range(-1, 2):
            for dx in range(-1, 2):
                put(img, hx + dx, hy + dy, (0, 0, 0, 0) if (dx == 0 and dy == 0) else OUTLINE)


def draw_betrayal_spear_stub(img: Image.Image, cx: int, cy: int) -> None:
    """Broken enemy spear shaft & snapped iron head jutting from behind his shoulder —
    visual storytelling of the Betrayed / Fallen Knight!"""
    d = ImageDraw.Draw(img)
    x0, y0 = cx - 10, cy - 6
    x1, y1 = cx - 22, cy - 20
    d.line([(x0, y0), (x1, y1)], fill=OUTLINE, width=4)
    d.line([(x0, y0), (x1, y1)], fill=WOOD_DARK, width=2)
    # Splintered wood tip + tattered pennant scrap
    put(img, x1 - 1, y1 - 1, GOLD_LIT)
    put(img, x1, y1 - 2, GOLD_DARK)
    d.polygon([(x1 + 3, y1 + 3), (x1 - 2, y1 + 9), (x1 + 5, y1 + 11)], fill=CAPE_HI, outline=OUTLINE)


def draw_greathelm(img: Image.Image, cx: int, cy: int, dim_eyes: bool = False, hurt: bool = False) -> None:
    """Scarred Fallen Greathelm with jagged dark-iron crown, torn plume & glowing visor."""
    d = ImageDraw.Draw(img)
    # Torn crimson plume curving off back of helm
    plume = [
        (cx - 2, cy - 13),
        (cx - 12, cy - 18),
        (cx - 20, cy - 12),
        (cx - 15, cy - 7),
        (cx - 19, cy - 3),
        (cx - 7, cy - 6),
    ]
    outlined_poly(img, plume, CAPE_MID, CAPE_HI)

    # Helm dome & cheekguards
    d.rounded_rectangle([cx - 10, cy - 12, cx + 10, cy + 9], radius=4, fill=STEEL_MID, outline=OUTLINE)
    d.rectangle([cx - 8, cy - 10, cx + 8, cy - 5], fill=STEEL_LIT)
    d.line([(cx - 6, cy - 10), (cx + 4, cy - 10)], fill=STEEL_HI)

    # Jagged fallen crown horns/points on brow
    for hx in (cx - 8, cx, cx + 8):
        d.polygon([(hx - 2, cy - 11), (hx, cy - 16), (hx + 2, cy - 11)], fill=STEEL_DARK, outline=OUTLINE)
        put(img, hx, cy - 14, STEEL_LIT)

    # Dark T-visor slit
    d.rectangle([cx - 7, cy - 3, cx + 8, cy + 1], fill=OUTLINE)
    d.rectangle([cx + 1, cy + 1, cx + 3, cy + 7], fill=OUTLINE)
    # Breathing vent slits
    for vy in (cy + 3, cy + 6):
        for vx in (cx - 5, cx - 3, cx + 5, cx + 7):
            put(img, vx, vy, OUTLINE)

    # Diagonal crack across right brow of helmet
    d.line([(cx + 3, cy - 10), (cx + 7, cy - 4)], fill=OUTLINE)
    put(img, cx + 4, cy - 9, STEEL_HI)

    # Haunting glowing eyes inside visor!
    eye_col = SCAR_GLOW if hurt else (EYE_DIM if dim_eyes else EYE_CYAN)
    for ex in (cx - 3, cx + 5):
        put(img, ex, cy - 1, eye_col)
        put(img, ex + 1, cy - 1, SCAR_CORE if hurt else (EYE_CYAN if not dim_eyes else EYE_DIM))


def draw_colossal_greatsword(img: Image.Image, hand_x: float, hand_y: float, angle_deg: float,
                             draw_trail: int = 0) -> None:
    """Draw the massive 56px Zweihander Greatsword rotated around hand_x, hand_y!"""
    rad = math.radians(angle_deg)
    ux, uy = math.cos(rad), math.sin(rad)
    px, py = -uy, ux  # perpendicular

    d = ImageDraw.Draw(img)

    # Optional sweeping motion arc trail for cleave frames!
    if draw_trail > 0:
        span = 85 if draw_trail == 1 else 155
        a0 = angle_deg - span
        a1 = angle_deg
        for r_arc, col in ((48, (150, 185, 235, 115)), (44, (220, 238, 255, 185)), (38, (255, 140, 80, 95))):
            pts = []
            for k in range(18):
                aa = math.radians(a0 + (a1 - a0) * (k / 17.0))
                pts.append((hand_x + math.cos(aa) * r_arc, hand_y + math.sin(aa) * r_arc))
            d.line(pts, fill=col, width=3 if r_arc == 44 else 2)

    # Pommel & long two-handed leather grip behind hand
    pom_x, pom_y = hand_x - ux * 9, hand_y - uy * 9
    d.line([(pom_x, pom_y), (hand_x + ux * 2, hand_y + uy * 2)], fill=OUTLINE, width=5)
    d.line([(pom_x, pom_y), (hand_x + ux * 2, hand_y + uy * 2)], fill=WOOD_DARK, width=3)
    d.ellipse([pom_x - 3, pom_y - 3, pom_x + 3, pom_y + 3], fill=GOLD_LIT, outline=OUTLINE)

    # Wide medieval crossguard + ricasso lugs
    gx, gy = hand_x + ux * 3, hand_y + uy * 3
    d.line([(gx - px * 9, gy - py * 9), (gx + px * 9, gy + py * 9)], fill=OUTLINE, width=5)
    d.line([(gx - px * 8, gy - py * 8), (gx + px * 8, gy + py * 8)], fill=GOLD_LIT, width=2)

    # Colossal broad blade (length 44 px from guard to point!)
    blade_len = 43.0
    tip_x, tip_y = gx + ux * blade_len, gy + uy * blade_len
    shoulder_l = (gx + ux * 2 - px * 4.2, gy + uy * 2 - py * 4.2)
    shoulder_r = (gx + ux * 2 + px * 4.2, gy + uy * 2 + py * 4.2)
    near_tip_l = (gx + ux * (blade_len - 8) - px * 3.2, gy + uy * (blade_len - 8) - py * 3.2)
    near_tip_r = (gx + ux * (blade_len - 8) + px * 3.2, gy + uy * (blade_len - 8) + py * 3.2)

    outlined_poly(img, [shoulder_l, near_tip_l, (tip_x, tip_y), near_tip_r, shoulder_r], STEEL_MID)
    # Bright upper bevel + dark blood-fuller groove down the spine
    d.line([shoulder_l, near_tip_l, (tip_x, tip_y)], fill=BLADE_EDGE, width=1)
    d.line([(gx + ux * 5, gy + uy * 5), (gx + ux * (blade_len - 11), gy + uy * (blade_len - 11))],
           fill=STEEL_DARK, width=2)
    # Zweihander parrying hooks (flamberge/ricasso spikes)
    hook_c = (gx + ux * 9, gy + uy * 9)
    d.line([(hook_c[0] - px * 6, hook_c[1] - py * 6), (hook_c[0] + px * 6, hook_c[1] + py * 6)],
           fill=STEEL_HI, width=2)


def draw_tower_shield(img: Image.Image, sx: int, sy: int, front_facing: bool = False) -> None:
    """Scarred Fallen Tower/Kite Shield with broken silver cross crest."""
    d = ImageDraw.Draw(img)
    w = 11 if front_facing else 8
    pts = [
        (sx - w, sy - 14),
        (sx + w, sy - 14),
        (sx + w, sy + 3),
        (sx, sy + 16),
        (sx - w, sy + 3),
    ]
    outlined_poly(img, pts, STEEL_DARK)
    inner = [
        (sx - w + 2, sy - 12),
        (sx + w - 2, sy - 12),
        (sx + w - 2, sy + 2),
        (sx, sy + 13),
        (sx - w + 2, sy + 2),
    ]
    d.polygon(inner, fill=STEEL_MID)
    # Broken silver/gold cross emblem
    d.line([(sx, sy - 10), (sx, sy + 10)], fill=GOLD_LIT, width=2)
    d.line([(sx - w + 3, sy - 3), (sx + w - 3, sy - 3)], fill=GOLD_LIT, width=2)
    # Deep battle slash scar cutting diagonally across the crest!
    d.line([(sx - w + 2, sy - 8), (sx + w - 2, sy + 4)], fill=OUTLINE, width=2)
    put(img, sx, sy - 2, SCAR_GLOW)
    # Rim highlight
    d.line([(sx - w + 1, sy - 13), (sx + w - 1, sy - 13)], fill=STEEL_HI)


def build_knight_pose(pose: str) -> Image.Image:
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    cx, cy = 44, 48
    leg_l_dx, leg_r_dx = -6, 6
    leg_l_dy, leg_r_dy = 0, 0
    cape_sway, cape_flare = -2, 0
    dim_eyes = (pose == "blink")
    hurt = (pose == "hurt")

    if pose == "walk_a":
        cy -= 1
        leg_l_dx, leg_r_dx = -9, 8
        leg_l_dy, leg_r_dy = -3, 1
        cape_sway = -4
    elif pose == "walk_b":
        cy -= 1
        leg_l_dx, leg_r_dx = -3, 3
        leg_l_dy, leg_r_dy = 1, -3
        cape_sway = -1
    elif pose == "windup":
        cx -= 3
        cape_sway = 3
    elif pose == "sweep":
        cx = 35
        cape_sway, cape_flare = -6, 4
    elif pose == "spin":
        cx = 36
        cape_sway, cape_flare = -8, 6
    elif pose == "guard":
        cx -= 1
        cy += 1
    elif pose == "charge":
        cx += 6
        cy += 1
        leg_l_dx, leg_r_dx = -12, 9
        cape_sway, cape_flare = -10, 5
    elif pose == "hurt":
        cx -= 5
        cy += 1
        cape_sway = 5

    # 1. Tattered cloak & betrayal spear behind body
    draw_tattered_cape(img, cx, cy, cape_sway, cape_flare)
    draw_betrayal_spear_stub(img, cx, cy)

    # Sword behind body during windup
    if pose == "windup":
        draw_colossal_greatsword(img, cx - 8, cy - 10, -142)

    # 2. Heavy armored greaves & sabatons
    for lx, ly in ((cx + leg_l_dx, cy + 28 + leg_l_dy), (cx + leg_r_dx, cy + 28 + leg_r_dy)):
        pill_limb(img, lx, cy + 13, lx, ly, 4, STEEL_DARK, STEEL_MID, STEEL_LIT)
        d.rounded_rectangle([lx - 5, ly - 2, lx + 6, ly + 4], radius=2, fill=STEEL_MID, outline=OUTLINE)
        put(img, lx + 3, ly, STEEL_HI)

    # 3. Scarred Gothic Breastplate + Tassets
    torso_pts = [
        (cx - 12, cy - 8),
        (cx + 12, cy - 8),
        (cx + 9, cy + 14),
        (cx - 9, cy + 14),
    ]
    outlined_poly(img, torso_pts, STEEL_MID, STEEL_HI)
    d.rectangle([cx - 9, cy + 10, cx + 9, cy + 15], fill=STEEL_DARK, outline=OUTLINE)
    # Betrayal diagonal ember-scar across chest!
    d.line([(cx - 6, cy - 5), (cx + 6, cy + 8)], fill=OUTLINE, width=3)
    d.line([(cx - 5, cy - 4), (cx + 5, cy + 7)], fill=SCAR_GLOW, width=1)
    put(img, cx, cy + 1, SCAR_CORE)

    # Layered pauldrons
    for sx in (cx - 13, cx + 13):
        d.ellipse([sx - 6, cy - 10, sx + 6, cy + 1], fill=STEEL_MID, outline=OUTLINE)
        d.arc([sx - 5, cy - 9, sx + 5, cy], 190, 350, fill=STEEL_HI)

    # 4. Fallen Greathelm
    draw_greathelm(img, cx + (2 if pose == "charge" else (-2 if hurt else 0)), cy - 17,
                   dim_eyes=dim_eyes, hurt=hurt)

    # 5. Arms, Shield & Colossal Greatsword per pose!
    if pose in ("idle", "blink", "walk_a", "walk_b"):
        draw_tower_shield(img, cx - 14, cy + 3, front_facing=False)
        pill_limb(img, cx + 11, cy - 3, cx + 16, cy + 7, 3, STEEL_DARK, STEEL_MID, STEEL_HI)
        draw_colossal_greatsword(img, cx + 16, cy + 7, -48 if pose != "walk_a" else -42)
    elif pose == "windup":
        draw_tower_shield(img, cx - 14, cy + 4, front_facing=False)
        pill_limb(img, cx + 8, cy - 5, cx - 6, cy - 11, 3, STEEL_DARK, STEEL_MID, STEEL_HI)
    elif pose == "sweep":
        draw_tower_shield(img, cx - 14, cy + 3, front_facing=False)
        pill_limb(img, cx + 9, cy - 2, cx + 15, cy + 1, 3, STEEL_DARK, STEEL_MID, STEEL_HI)
        draw_colossal_greatsword(img, cx + 15, cy + 1, 6, draw_trail=1)
    elif pose == "spin":
        pill_limb(img, cx + 8, cy - 1, cx + 14, cy + 6, 3, STEEL_DARK, STEEL_MID, STEEL_HI)
        draw_colossal_greatsword(img, cx + 14, cy + 6, 46, draw_trail=2)
        draw_tower_shield(img, cx - 13, cy + 2, front_facing=False)
    elif pose == "guard":
        # Sword braced behind while Tower Shield locks in front!
        draw_colossal_greatsword(img, cx - 8, cy + 4, -118)
        draw_tower_shield(img, cx + 14, cy + 1, front_facing=True)
    elif pose == "charge":
        draw_colossal_greatsword(img, cx - 10, cy + 5, -135)
        draw_tower_shield(img, cx + 18, cy + 1, front_facing=True)
        # Kinetic ram shock-lines in front of shield
        for ky in (-9, 0, 9):
            d.line([(cx + 31, cy + ky), (cx + 38, cy + ky)], fill=EYE_CYAN, width=2)
    elif pose == "hurt":
        draw_tower_shield(img, cx - 17, cy + 5, front_facing=False)
        pill_limb(img, cx + 10, cy - 2, cx + 18, cy - 8, 3, STEEL_DARK, STEEL_MID, STEEL_HI)
        draw_colossal_greatsword(img, cx + 18, cy - 8, -25)
        # Sparks bursting from chest scar
        for sx, sy in ((cx + 8, cy - 4), (cx + 12, cy + 2), (cx + 5, cy + 9)):
            put(img, sx, sy, SCAR_CORE)
            put(img, sx + 1, sy, SCAR_GLOW)

    return img


def build_knight_vertical_pose(pose: str) -> Image.Image:
    """Front-facing (`down_*`) & Back-facing (`up_*`) 96x96 poses for Fallen Knight!"""
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = 48, 48
    is_up = pose.startswith("up_")
    step = -1 if pose.endswith("_a") else (1 if pose.endswith("_b") else 0)
    l_dy = -3 * step
    r_dy = 3 * step

    if not is_up:
        # Front: tattered cape behind legs + greaves + scarred breastplate + visor eyes + shield & sword!
        d.polygon([(cx - 13, cy - 8), (cx + 13, cy - 8), (cx + 16, cy + 22), (cx - 16, cy + 22)], fill=CAPE_DEEP, outline=OUTLINE)
        for side, dy in ((-6, l_dy), (6, r_dy)):
            lx, ly = cx + side, cy + 28 + min(0, dy)
            pill_limb(img, lx, cy + 13, lx, ly, 4, STEEL_DARK, STEEL_MID, STEEL_LIT)
            d.rounded_rectangle([lx - 5, ly - 2, lx + 5, ly + 4], radius=2, fill=STEEL_MID, outline=OUTLINE)
        outlined_poly(img, [(cx - 12, cy - 8), (cx + 12, cy - 8), (cx + 9, cy + 14), (cx - 9, cy + 14)], STEEL_MID, STEEL_HI)
        d.line([(cx - 6, cy - 5), (cx + 6, cy + 8)], fill=SCAR_GLOW, width=2)
        for sx in (cx - 13, cx + 13):
            d.ellipse([sx - 6, cy - 10, sx + 6, cy + 1], fill=STEEL_MID, outline=OUTLINE)
        # Symmetrical front Greathelm with glowing cyan visor T-slit!
        hy = cy - 17
        d.rounded_rectangle([cx - 9, hy - 11, cx + 9, hy + 8], radius=3, fill=STEEL_MID, outline=OUTLINE)
        d.rectangle([cx - 6, hy - 2, cx + 6, hy + 1], fill=OUTLINE)
        d.line([(cx - 4, hy - 1), (cx + 4, hy - 1)], fill=EYE_CYAN, width=1)
        d.line([(cx, hy - 2), (cx, hy + 6)], fill=OUTLINE, width=2)
        draw_colossal_greatsword(img, cx - 15, cy + 4 + l_dy, 108)
        draw_tower_shield(img, cx + 13, cy + 3 + r_dy, front_facing=True)
    else:
        # Back: greaves + greatsword & shield at sides + full tattered crimson cloak & betrayal spear!
        for side, dy in ((-6, l_dy), (6, r_dy)):
            lx, ly = cx + side, cy + 28 + min(0, dy)
            pill_limb(img, lx, cy + 13, lx, ly, 4, STEEL_DARK, STEEL_MID, STEEL_LIT)
            d.rounded_rectangle([lx - 5, ly - 2, lx + 5, ly + 4], radius=2, fill=STEEL_DARK, outline=OUTLINE)
        draw_tower_shield(img, cx - 14, cy + 3 + l_dy, front_facing=False)
        draw_colossal_greatsword(img, cx + 15, cy + 4 + r_dy, 72)
        for sx in (cx - 13, cx + 13):
            d.ellipse([sx - 6, cy - 10, sx + 6, cy + 1], fill=STEEL_MID, outline=OUTLINE)
        # Full tattered crimson cape draped down his back!
        cape_pts = [
            (cx - 13, cy - 9), (cx + 13, cy - 9),
            (cx + 17 + step, cy + 21), (cx + 9 + step, cy + 17),
            (cx + step, cy + 23), (cx - 9 + step, cy + 18), (cx - 17 + step, cy + 21),
        ]
        d.polygon(cape_pts, fill=CAPE_MID, outline=OUTLINE)
        d.line([(cx - 6, cy - 6), (cx - 8 + step, cy + 16)], fill=CAPE_DEEP, width=2)
        d.line([(cx + 5, cy - 6), (cx + 7 + step, cy + 16)], fill=CAPE_HI, width=1)
        # Broken betrayal spear jutting from back shoulder
        d.line([(cx + 3, cy - 3), (cx + 13, cy - 17)], fill=WOOD_DARK, width=3)
        # Back of Greathelm
        hy = cy - 17
        d.rounded_rectangle([cx - 9, hy - 11, cx + 9, hy + 8], radius=3, fill=STEEL_DARK, outline=OUTLINE)
        d.line([(cx, hy - 10), (cx, hy + 6)], fill=STEEL_HI, width=2)
    return img


def main() -> None:
    poses = [
        "idle", "walk_a", "walk_b", "windup", "sweep", "spin", "guard", "charge", "hurt", "blink",
        "down_idle", "down_walk_a", "down_walk_b", "up_idle", "up_walk_a", "up_walk_b",
    ]
    sheet = Image.new("RGBA", (FRAME * len(poses), FRAME), (0, 0, 0, 0))
    for i, p in enumerate(poses):
        fr = build_knight_vertical_pose(p) if p.startswith(("down_", "up_")) else build_knight_pose(p)
        sheet.alpha_composite(fr, (i * FRAME, 0))
    sheet.save("assets/textures/player_bahman.png")
    print("wrote assets/textures/player_bahman.png", sheet.size)

    zoom, pad = 2, 10
    w = pad + len(poses) * (FRAME * zoom + pad)
    h = 30 + FRAME * zoom + 24
    prev = Image.new("RGBA", (w, h), (18, 20, 28, 255))
    d = ImageDraw.Draw(prev)
    d.text((pad, 8), "FALLEN KNIGHT - 10 frames x 96x96 (Colossal Greatsword + Tower Shield)", fill=(210, 226, 248, 255))
    for i, p in enumerate(poses):
        x = pad + i * (FRAME * zoom + pad)
        fr = sheet.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME))
        prev.alpha_composite(fr.resize((FRAME * zoom, FRAME * zoom), Image.NEAREST), (x, 28))
        d.text((x, 28 + FRAME * zoom + 4), f"{i}:{p}", fill=(175, 195, 224, 255))
    prev.save("docs/images/knight_preview.png")


if __name__ == "__main__":
    main()
