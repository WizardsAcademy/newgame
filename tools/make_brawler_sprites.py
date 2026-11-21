#!/usr/bin/env python
"""Generate Behemoth's 10-frame 96x96 Medieval Pit-Champion Brawler sheet.

Art direction:
  - Medieval Arena / Guild Pit-Champion: riveted leather brigandine vest,
    iron-plated left pauldron, brass lion-head belt, crimson medieval sash &
    headband tails, battle scar, thick braided beard, muscular bare forearms,
    and heavy spiked medieval Iron Cestus gauntlets!
  - Clean articulated arm & fist animations: clearly coils back and punches
    with lead Jab, heavy rear Cross, skyward Uppercut, and lowered Shoulder
    Charge (`Shift`)!

Writes:
    assets/textures/player_borzo.png    960 x 96 (10 frames of 96x96)
    docs/images/brawler_preview.png     review sheet

SHEET LAYOUT (matches scenes/player/Player.tscn):
    0 : idle            (twin iron-cestus guard)
    1 : walk A
    2 : walk B
    3 : punch windup    (torso twists, rear right arm coils back)
    4 : punch jab       (lead left arm snaps straight forward + fist smear)
    5 : punch cross     (heavy right arm drives far forward + golden arc)
    6 : punch uppercut  (rising iron uppercut + golden shock-gleam)
    7 : shoulder charge (lowered iron-pauldron shoulder ramming pose)
    8 : hurt            (recoiling hit stagger + wincing face)
    9 : blink           (eyes shut)
"""

import math
from PIL import Image, ImageDraw

FRAME = 96
FRAMES = 10

OUTLINE = (12, 9, 10, 255)
SKIN_SHA = (176, 118, 86, 255)
SKIN_MID = (218, 158, 118, 255)
SKIN_HI = (244, 192, 152, 255)
HAIR_DARK = (48, 30, 20, 255)
HAIR_MID = (82, 52, 32, 255)
LEATHER_DARK = (64, 38, 24, 255)
LEATHER_MID = (104, 64, 38, 255)
LEATHER_HI = (146, 94, 56, 255)
PANTS_DARK = (38, 34, 42, 255)
PANTS_MID = (60, 54, 66, 255)
IRON_DARK = (46, 52, 66, 255)
IRON_MID = (82, 92, 112, 255)
IRON_HI = (152, 168, 194, 255)
BRASS_DARK = (138, 96, 28, 255)
BRASS_HI = (238, 192, 72, 255)
SASH_RED = (168, 28, 42, 255)
SASH_HI = (224, 62, 74, 255)


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


def draw_cestus_fist(img: Image.Image, fx: float, fy: float, dir_ang_deg: float = 0.0,
                     golden_gleam: bool = False) -> None:
    """Heavy medieval spiked Iron Cestus gauntlet at the end of Behemoth's arm!"""
    d = ImageDraw.Draw(img)
    ix, iy = int(round(fx)), int(round(fy))
    # Iron wrist bracer + heavy knuckle box
    d.rounded_rectangle([ix - 6, iy - 5, ix + 6, iy + 5], radius=2, fill=IRON_MID, outline=OUTLINE)
    d.rectangle([ix - 4, iy - 4, ix + 4, iy - 1], fill=IRON_HI)
    # Brass rivets + spiked knuckles pointing along dir_ang_deg
    rad = math.radians(dir_ang_deg)
    ux, uy = math.cos(rad), math.sin(rad)
    px, py = -uy, ux
    for k in (-3, 0, 3):
        sx = int(round(fx + ux * 7 + px * k))
        sy = int(round(fy + uy * 7 + py * k))
        put(img, sx, sy, BRASS_HI if golden_gleam else IRON_HI)
        put(img, int(round(fx + ux * 6 + px * k)), int(round(fy + uy * 6 + py * k)), OUTLINE)
    if golden_gleam:
        d.ellipse([ix - 9, iy - 9, ix + 9, iy + 9], outline=BRASS_HI)


def draw_arm_with_cestus(img: Image.Image, sx: float, sy: float, ex: float, ey: float,
                         fx: float, fy: float, golden: bool = False) -> None:
    """Articulated muscular upper-arm -> elbow -> forearm -> Iron Cestus fist!"""
    pill_limb(img, sx, sy, ex, ey, 4, SKIN_SHA, SKIN_MID, SKIN_HI)
    pill_limb(img, ex, ey, fx, fy, 4, SKIN_SHA, SKIN_MID, SKIN_HI)
    # Leather forearm wrap just behind the gauntlet
    wx, wy = ex + (fx - ex) * 0.62, ey + (fy - ey) * 0.62
    pill_limb(img, wx, wy, fx, fy, 4, LEATHER_DARK, LEATHER_MID, BRASS_DARK)
    ang = math.degrees(math.atan2(fy - ey, fx - ex))
    draw_cestus_fist(img, fx, fy, ang, golden_gleam=golden)


def draw_brawler_head(img: Image.Image, cx: int, cy: int, blink: bool = False, hurt: bool = False,
                      tail_sway: int = 0) -> None:
    d = ImageDraw.Draw(img)
    # Flowing crimson medieval headband tails behind head
    d.polygon([
        (cx - 8, cy - 6),
        (cx - 21 - tail_sway, cy - 3),
        (cx - 18 - tail_sway, cy + 3),
        (cx - 23 - tail_sway, cy + 7),
        (cx - 9, cy + 1),
    ], fill=SASH_RED, outline=OUTLINE)
    d.line([(cx - 9, cy - 4), (cx - 18 - tail_sway, cy - 2)], fill=SASH_HI)

    # Thick brown hair crown & head silhouette
    d.rounded_rectangle([cx - 9, cy - 11, cx + 9, cy + 9], radius=4, fill=SKIN_MID, outline=OUTLINE)
    d.rounded_rectangle([cx - 9, cy - 12, cx + 9, cy - 5], radius=3, fill=HAIR_DARK, outline=OUTLINE)
    d.line([(cx - 6, cy - 10), (cx + 4, cy - 10)], fill=HAIR_MID)

    # Crimson & iron-studded medieval brow headband
    d.rectangle([cx - 9, cy - 7, cx + 9, cy - 3], fill=SASH_RED, outline=OUTLINE)
    for rx in (cx - 5, cx + 1, cx + 6):
        put(img, rx, cy - 5, BRASS_HI)

    # Battle scar over left eye
    d.line([(cx - 3, cy - 3), (cx - 1, cy + 3)], fill=SASH_RED)

    # Eyes
    if hurt:
        d.line([(cx - 4, cy - 1), (cx - 2, cy + 1)], fill=OUTLINE)
        d.line([(cx + 5, cy - 1), (cx + 3, cy + 1)], fill=OUTLINE)
    elif blink:
        d.line([(cx - 4, cy), (cx - 1, cy)], fill=OUTLINE)
        d.line([(cx + 3, cy), (cx + 6, cy)], fill=OUTLINE)
    else:
        for ex in (cx - 3, cx + 4):
            put(img, ex, cy - 1, OUTLINE)
            put(img, ex + 1, cy - 1, BRASS_HI)
            put(img, ex, cy, OUTLINE)

    # Thick medieval braided beard & mustache!
    d.rounded_rectangle([cx - 7, cy + 3, cx + 8, cy + 10], radius=3, fill=HAIR_DARK, outline=OUTLINE)
    d.line([(cx - 5, cy + 4), (cx + 6, cy + 4)], fill=HAIR_MID, width=2)
    if hurt:
        # Shouting mouth inside beard
        d.rectangle([cx + 1, cy + 5, cx + 5, cy + 7], fill=SASH_RED)
        put(img, cx + 2, cy + 5, (255, 255, 255, 255))
    else:
        # Brass beard clasp
        put(img, cx + 2, cy + 9, BRASS_HI)


def build_brawler_pose(pose: str) -> Image.Image:
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    cx, cy = 44, 49
    leg_l, leg_r = (-7, 27), (7, 27)
    tail_sway = 0

    if pose == "walk_a":
        cy -= 1
        leg_l, leg_r = (-10, 25), (9, 28)
        tail_sway = 2
    elif pose == "walk_b":
        cy -= 1
        leg_l, leg_r = (-3, 28), (4, 24)
        tail_sway = 1
    elif pose == "windup":
        cx -= 4
        leg_l, leg_r = (-9, 27), (8, 27)
    elif pose == "jab":
        cx += 3
        leg_l, leg_r = (-9, 27), (10, 27)
        tail_sway = 3
    elif pose == "cross":
        cx += 6
        leg_l, leg_r = (-11, 27), (11, 27)
        tail_sway = 5
    elif pose == "uppercut":
        cx += 4
        cy -= 3
        leg_l, leg_r = (-8, 29), (9, 26)
        tail_sway = 4
    elif pose == "charge":
        cx += 7
        cy += 2
        leg_l, leg_r = (-14, 26), (10, 26)
        tail_sway = 7
    elif pose == "hurt":
        cx -= 5
        cy += 1
        tail_sway = -3

    # 1. Rear Arm (drawn behind torso so torso overlap reads 3D!)
    if pose in ("idle", "blink", "walk_a", "walk_b"):
        draw_arm_with_cestus(img, cx + 8, cy - 5, cx + 15, cy + 2, cx + 21, cy - 3)
    elif pose == "windup":
        # Rear right arm pulled far back behind hip!
        draw_arm_with_cestus(img, cx - 8, cy - 4, cx - 18, cy + 2, cx - 22, cy - 4)
    elif pose == "jab":
        # Guard hand tucked by chin while lead arm jabs!
        draw_arm_with_cestus(img, cx - 7, cy - 4, cx - 12, cy + 3, cx - 5, cy + 1)
    elif pose == "hurt":
        draw_arm_with_cestus(img, cx + 8, cy - 5, cx + 16, cy - 12, cx + 21, cy - 16)

    # 2. Medieval Trousers & Heavy Studded Boots
    for lx, ly in ((cx + leg_l[0], cy + leg_l[1]), (cx + leg_r[0], cy + leg_r[1])):
        pill_limb(img, cx + (leg_l[0] // 2 if lx < cx else leg_r[0] // 2), cy + 12, lx, ly - 5, 4,
                  PANTS_DARK, PANTS_MID, PANTS_MID)
        d.rounded_rectangle([lx - 5, ly - 6, lx + 6, ly + 2], radius=2, fill=LEATHER_DARK, outline=OUTLINE)
        d.line([(lx - 4, ly - 5), (lx + 4, ly - 5)], fill=LEATHER_HI)
        put(img, lx + 3, ly - 2, IRON_HI)

    # 3. Broad Medieval Brigandine Vest + Brass Championship Belt + Crimson Sash
    torso = [
        (cx - 12, cy - 9),
        (cx + 12, cy - 9),
        (cx + 9, cy + 13),
        (cx - 9, cy + 13),
    ]
    d.polygon(torso, fill=LEATHER_MID, outline=OUTLINE)
    # V-neck bare muscular chest V + stitched leather studs
    d.polygon([(cx - 3, cy - 8), (cx + 5, cy - 8), (cx + 1, cy + 1)], fill=SKIN_MID)
    for sy in (cy - 4, cy + 2, cy + 7):
        put(img, cx - 7, sy, BRASS_HI)
        put(img, cx + 7, sy, BRASS_HI)
    # Crimson waist sash + wide brass lion-buckle belt
    d.polygon([(cx - 9, cy + 11), (cx - 4, cy + 11), (cx - 7, cy + 21), (cx - 12, cy + 19)],
              fill=SASH_RED, outline=OUTLINE)
    d.rectangle([cx - 10, cy + 9, cx + 10, cy + 14], fill=LEATHER_DARK, outline=OUTLINE)
    d.rounded_rectangle([cx - 3, cy + 8, cx + 5, cy + 14], radius=1, fill=BRASS_HI, outline=OUTLINE)
    put(img, cx + 1, cy + 11, BRASS_DARK)

    # Iron-plated medieval pauldron on lead shoulder
    px_sh = cx + (11 if pose == "charge" else -11)
    d.ellipse([px_sh - 6, cy - 11, px_sh + 6, cy - 1], fill=IRON_MID, outline=OUTLINE)
    d.arc([px_sh - 5, cy - 10, px_sh + 5, cy - 2], 190, 350, fill=IRON_HI)

    # 4. Head
    draw_brawler_head(img, cx + (5 if pose == "charge" else (-2 if pose == "hurt" else 1)),
                      cy - 18, blink=(pose == "blink"), hurt=(pose == "hurt"), tail_sway=tail_sway)

    # 5. Foreground Punching / Charging Arm + Clean Motion Smears!
    if pose in ("idle", "blink"):
        draw_arm_with_cestus(img, cx - 9, cy - 4, cx - 4, cy + 5, cx + 10, cy + 1)
    elif pose == "walk_a":
        draw_arm_with_cestus(img, cx - 9, cy - 4, cx - 5, cy + 5, cx + 8, cy + 3)
    elif pose == "walk_b":
        draw_arm_with_cestus(img, cx - 9, cy - 4, cx - 2, cy + 4, cx + 12, cy - 1)
    elif pose == "windup":
        draw_arm_with_cestus(img, cx + 8, cy - 4, cx + 13, cy + 2, cx + 17, cy - 3)
    elif pose == "jab":
        # Crisp white-gold straight jab speed lines + extended fist!
        d.line([(cx + 14, cy - 5), (cx + 36, cy - 5)], fill=(255, 244, 196, 190), width=3)
        d.line([(cx + 18, cy - 1), (cx + 34, cy - 1)], fill=(255, 195, 92, 150), width=2)
        draw_arm_with_cestus(img, cx + 9, cy - 5, cx + 22, cy - 5, cx + 36, cy - 4)
    elif pose == "cross":
        # Heavy cross punch sweeping across body with curved golden motion trail!
        pts = [(cx - 4 + k * 3, cy + 6 - int(math.sin(k / 13.0 * math.pi) * 9)) for k in range(15)]
        d.line(pts, fill=(255, 208, 92, 190), width=4)
        draw_arm_with_cestus(img, cx - 6, cy - 4, cx + 16, cy - 2, cx + 40, cy - 2, golden=True)
    elif pose == "uppercut":
        # Skyward rising uppercut arc!
        pts = [(cx + 12 + int(math.sin(k / 12.0 * math.pi) * 16), cy + 16 - k * 3) for k in range(13)]
        d.line(pts, fill=(255, 224, 110, 215), width=4)
        draw_arm_with_cestus(img, cx + 6, cy - 2, cx + 21, cy + 3, cx + 25, cy - 24, golden=True)
    elif pose == "charge":
        # Heavy Shoulder-Smash brace: iron pauldron & crossed cestus braced forward!
        draw_arm_with_cestus(img, cx + 4, cy - 4, cx + 16, cy + 2, cx + 22, cy - 5, golden=True)
        for ky in (-10, -2, 7):
            d.line([(cx + 27, cy + ky), (cx + 36, cy + ky)], fill=BRASS_HI, width=2)
    elif pose == "hurt":
        draw_arm_with_cestus(img, cx - 9, cy - 3, cx - 17, cy - 9, cx - 21, cy - 14)

    return img


def main() -> None:
    poses = ["idle", "walk_a", "walk_b", "windup", "jab", "cross", "uppercut", "charge", "hurt", "blink"]
    sheet = Image.new("RGBA", (FRAME * len(poses), FRAME), (0, 0, 0, 0))
    for i, p in enumerate(poses):
        sheet.alpha_composite(build_brawler_pose(p), (i * FRAME, 0))
    sheet.save("assets/textures/player_borzo.png")
    print("wrote assets/textures/player_borzo.png", sheet.size)

    zoom, pad = 2, 10
    w = pad + len(poses) * (FRAME * zoom + pad)
    h = 30 + FRAME * zoom + 24
    prev = Image.new("RGBA", (w, h), (24, 19, 18, 255))
    d = ImageDraw.Draw(prev)
    d.text((pad, 8), "MEDIEVAL BRAWLER (BEHEMOTH) - 10 frames x 96x96", fill=(248, 222, 182, 255))
    for i, p in enumerate(poses):
        x = pad + i * (FRAME * zoom + pad)
        fr = sheet.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME))
        prev.alpha_composite(fr.resize((FRAME * zoom, FRAME * zoom), Image.NEAREST), (x, 28))
        d.text((x, 28 + FRAME * zoom + 4), f"{i}:{p}", fill=(224, 192, 148, 255))
    prev.save("docs/images/brawler_preview.png")


if __name__ == "__main__":
    main()
