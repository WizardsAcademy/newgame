#!/usr/bin/env python3
"""Generate Velmira's 16-frame 96x96 Silver-White Gothic Vampire sheet.

Built in the exact same crisp 96x96 house pixel-art style as Sylvara, Behemoth,
and Knight (`OUTLINE = (11, 10, 14, 255)`, grounded boots at `cy + 26 = 76`,
matching `portrait_velmira` in `tools/make_hero_portraits.py` 1:1!):
  - Flowing moonlit silver-white hair + signature crimson temple rose,
  - Pointed pale vampire ears + luminous ruby-crimson eyes + cute vampire fang,
  - High-collared crimson & obsidian gothic dress, black choker with ruby drop,
    and dark laced vampire boots,
  - Smooth normal idle (`idle` + `idle_b` gentle breath + `blink`), grounded
    4-directional walks (`walk_a/b`, `down_walk_a/b`, `up_walk_a/b`), graceful
    Blood-Splash cast (`cast_windup`, `cast_slash`), `hurt`, and `die_pool`.

Writes:
    assets/textures/player_velmira.png   1536 x 96 (16 frames of 96x96)
    docs/images/velmira_preview.png      review sheet
"""

import math
from PIL import Image, ImageDraw

FRAME = 96

OUTLINE = (11, 10, 14, 255)
SKIN = (244, 224, 232, 255)
SKIN_SHA = (196, 162, 178, 255)
BLUSH = (232, 164, 184, 255)

HAIR_SHA = (154, 144, 182, 255)
HAIR_MID = (224, 220, 240, 255)
HAIR_LIT = (242, 240, 252, 255)
HAIR_HI = (252, 250, 255, 255)

DRESS_DARK = (22, 14, 28, 255)
DRESS_MID = (38, 24, 46, 255)
DRESS_LIT = (62, 40, 72, 255)

CRIMSON_DEEP = (92, 10, 34, 255)
CRIMSON_MID = (168, 20, 52, 255)
CRIMSON_BRIGHT = (228, 36, 74, 255)
CRIMSON_GLOW = (255, 142, 168, 255)
LEAF_DARK = (28, 72, 48, 255)


def put(img: Image.Image, x: int, y: int, col) -> None:
    if 0 <= x < FRAME and 0 <= y < FRAME:
        img.putpixel((x, y), col)


def pill_limb(
    img: Image.Image,
    x0: float,
    y0: float,
    x1: float,
    y1: float,
    r: int,
    dark_c,
    mid_c,
    hi_c,
) -> None:
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


def draw_silver_hair_back(img: Image.Image, cx: int, cy: int, sway: int = 0) -> None:
    """Long cascading moonlit silver-white hair locks reaching past her waist."""
    d = ImageDraw.Draw(img)
    pts = [
        (cx - 13, cy - 22),
        (cx + 12, cy - 22),
        (cx + 19 + sway, cy + 5),
        (cx + 15 + sway, cy + 18),
        (cx + 8 + sway, cy + 12),
        (cx + 2 + sway, cy + 20),
        (cx - 5 + sway, cy + 13),
        (cx - 13 + sway, cy + 19),
        (cx - 20 + sway, cy + 6),
    ]
    d.polygon(pts, fill=HAIR_SHA, outline=OUTLINE)
    inner = [
        (cx - 11, cy - 19),
        (cx + 10, cy - 19),
        (cx + 15 + sway, cy + 8),
        (cx - 1 + sway, cy + 15),
        (cx - 15 + sway, cy + 8),
    ]
    d.polygon(inner, fill=HAIR_MID)
    for lx in (-9, -2, 6):
        d.line([(cx + lx, cy - 12), (cx + lx + sway // 2, cy + 9)], fill=HAIR_HI, width=2)


def draw_crimson_rose(img: Image.Image, rx: int, ry: int) -> None:
    """Velmira's signature crimson temple rose + dark emerald leaf."""
    d = ImageDraw.Draw(img)
    d.polygon([(rx - 5, ry + 1), (rx - 2, ry + 4), (rx, ry + 1)], fill=LEAF_DARK, outline=OUTLINE)
    d.ellipse([rx - 4, ry - 4, rx + 4, ry + 4], fill=CRIMSON_DEEP, outline=OUTLINE)
    d.ellipse([rx - 2, ry - 2, rx + 3, ry + 3], fill=CRIMSON_BRIGHT)
    put(img, rx - 1, ry - 1, CRIMSON_GLOW)


def draw_vampire_head(
    img: Image.Image,
    cx: int,
    cy: int,
    blink: bool = False,
    hurt: bool = False,
    cast_focus: bool = False,
    sway: int = 0,
) -> None:
    d = ImageDraw.Draw(img)
    # Silver-white crown hair dome
    d.ellipse([cx - 13, cy - 14, cx + 13, cy + 8], fill=HAIR_MID, outline=OUTLINE)
    d.arc([cx - 10, cy - 12, cx + 10, cy - 2], 195, 345, fill=HAIR_HI, width=2)

    # Pointed pale Vampire ears
    d.polygon([(cx - 10, cy - 1), (cx - 18, cy - 5), (cx - 11, cy + 4)], fill=SKIN, outline=OUTLINE)
    d.polygon([(cx + 10, cy - 1), (cx + 18, cy - 5), (cx + 11, cy + 4)], fill=SKIN, outline=OUTLINE)
    put(img, cx - 14, cy - 3, SKIN_SHA)
    put(img, cx + 14, cy - 3, SKIN_SHA)

    # Porcelain face + soft rose blush
    d.rounded_rectangle([cx - 9, cy - 7, cx + 9, cy + 9], radius=5, fill=SKIN, outline=OUTLINE)
    put(img, cx - 6, cy + 3, BLUSH)
    put(img, cx + 6, cy + 3, BLUSH)

    # Luminous Ruby-Crimson Vampire Eyes
    if hurt:
        d.line([(cx - 6, cy - 1), (cx - 2, cy + 1)], fill=OUTLINE)
        d.line([(cx - 2, cy + 1), (cx - 6, cy + 3)], fill=OUTLINE)
        d.line([(cx + 6, cy - 1), (cx + 2, cy + 1)], fill=OUTLINE)
        d.line([(cx + 2, cy + 1), (cx + 6, cy + 3)], fill=OUTLINE)
        d.rectangle([cx - 1, cy + 5, cx + 2, cy + 7], fill=CRIMSON_MID)
    elif blink:
        d.line([(cx - 6, cy + 1), (cx - 2, cy + 1)], fill=OUTLINE)
        d.line([(cx + 2, cy + 1), (cx + 6, cy + 1)], fill=OUTLINE)
        put(img, cx, cy + 5, SKIN_SHA)
    else:
        for ex in (cx - 5, cx + 2):
            d.rectangle([ex, cy - 2, ex + 3, cy + 2], fill=CRIMSON_DEEP)
            d.line([(ex - 1, cy - 2), (ex + 3, cy - 2)], fill=OUTLINE)
            put(img, ex + 1, cy, CRIMSON_BRIGHT)
            put(img, ex + 2, cy + 1, CRIMSON_GLOW if cast_focus else CRIMSON_BRIGHT)
            put(img, ex, cy - 1, (255, 255, 255, 255))
        # Subtle cute vampire mouth + single white fang
        d.line([(cx - 1, cy + 5), (cx + 2, cy + 5)], fill=CRIMSON_MID)
        put(img, cx + 2, cy + 6, (255, 255, 255, 255))

    # Swept silver-white side curls & gothic bangs
    d.polygon(
        [(cx - 11, cy - 8), (cx - 7, cy - 8), (cx - 9 + sway, cy + 10), (cx - 13 + sway, cy + 4)],
        fill=HAIR_LIT,
        outline=OUTLINE,
    )
    d.polygon(
        [(cx + 7, cy - 8), (cx + 11, cy - 8), (cx + 13 + sway, cy + 4), (cx + 9 + sway, cy + 10)],
        fill=HAIR_LIT,
        outline=OUTLINE,
    )
    for bx0, bx1, tx, ty in ((-6, -1, -4, -2), (-1, 4, 1, -2), (3, 7, 5, -3)):
        d.polygon([(cx + bx0, cy - 10), (cx + bx1, cy - 10), (cx + tx, cy + ty)], fill=HAIR_HI)

    # Signature Crimson Rose on left temple!
    draw_crimson_rose(img, cx - 9, cy - 9)


def build_velmira_pose(pose: str) -> Image.Image:
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    cx, cy = 44, 50
    sway = 0
    leg_l, leg_r = (-5, 26), (5, 26)

    if pose == "idle_b":
        sway = 1
    elif pose == "walk_a":
        cy -= 1
        leg_l, leg_r = (-8, 24), (7, 27)
        sway = -2
    elif pose == "walk_b":
        cy -= 1
        leg_l, leg_r = (-2, 27), (3, 23)
        sway = -1
    elif pose == "cast_windup":
        cx -= 2
        leg_l, leg_r = (-7, 26), (5, 26)
        sway = -2
    elif pose == "cast_slash":
        cx += 4
        leg_l, leg_r = (-8, 26), (9, 26)
        sway = -5
    elif pose == "dash_mist":
        cx += 5
        cy += 1
        leg_l, leg_r = (-9, 25), (8, 25)
        sway = -6
    elif pose == "die_pool":
        cx -= 2
        cy += 6
        leg_l, leg_r = (-7, 20), (6, 20)
        sway = 3
    elif pose == "hurt":
        cx -= 4
        cy += 1
        sway = 4

    # 1. Flowing silver-white back hair + crimson-lined gothic cape
    draw_silver_hair_back(img, cx, cy, sway=sway)
    cape_outer = [
        (cx - 10, cy - 8),
        (cx + 10, cy - 8),
        (cx + 15 + sway, cy + 19),
        (cx - 15 + sway, cy + 19),
    ]
    d.polygon(cape_outer, fill=CRIMSON_DEEP, outline=OUTLINE)

    # 2. Slender legs & dark gothic heeled vampire boots (grounded at cy + 26 = 76!)
    for lx, ly in ((cx + leg_l[0], cy + leg_l[1]), (cx + leg_r[0], cy + leg_r[1])):
        pill_limb(
            img,
            cx + (leg_l[0] // 2 if lx < cx else leg_r[0] // 2),
            cy + 12,
            lx,
            ly - 6,
            3,
            SKIN_SHA,
            SKIN,
            SKIN,
        )
        d.rounded_rectangle([lx - 4, ly - 8, lx + 4, ly + 2], radius=2, fill=DRESS_DARK, outline=OUTLINE)
        d.line([(lx - 3, ly - 7), (lx + 3, ly - 7)], fill=CRIMSON_BRIGHT)

    # 3. Layered Obsidian & Crimson-Trimmed Gothic Vampire Dress + High Collar
    skirt = [
        (cx - 9, cy + 4),
        (cx + 9, cy + 4),
        (cx + 14 + sway // 2, cy + 17),
        (cx - 14 + sway // 2, cy + 17),
    ]
    d.polygon(skirt, fill=DRESS_MID, outline=OUTLINE)
    d.line([(cx - 12 + sway // 2, cy + 16), (cx + 12 + sway // 2, cy + 16)], fill=CRIMSON_BRIGHT, width=2)

    # High flared crimson vampire collar behind neck
    d.polygon(
        [(cx - 13, cy - 13), (cx + 13, cy - 13), (cx + 10, cy - 5), (cx - 10, cy - 5)],
        fill=CRIMSON_MID,
        outline=OUTLINE,
    )

    bodice = [
        (cx - 9, cy - 8),
        (cx + 9, cy - 8),
        (cx + 7, cy + 6),
        (cx - 7, cy + 6),
    ]
    d.polygon(bodice, fill=DRESS_DARK, outline=OUTLINE)
    # Crimson corset lacing + ruby brooch + black choker
    d.polygon([(cx - 4, cy - 7), (cx + 4, cy - 7), (cx + 2, cy + 5), (cx - 2, cy + 5)], fill=CRIMSON_MID)
    d.ellipse([cx - 2, cy - 7, cx + 2, cy - 3], fill=CRIMSON_BRIGHT, outline=OUTLINE)
    put(img, cx, cy - 6, CRIMSON_GLOW)

    # 4. Silver-White Vampire Head
    draw_vampire_head(
        img,
        cx,
        cy - 18,
        blink=(pose in ("blink", "die_pool")),
        hurt=(pose == "hurt"),
        cast_focus=(pose in ("cast_windup", "cast_slash", "dash_mist")),
        sway=sway // 2,
    )

    # 5. Gothic flared sleeves & Blood-Magic hands (clean body poses; slash VFX lives in velmira_fx.png)
    if pose in ("idle", "idle_b", "blink", "walk_a", "walk_b"):
        arm_dy = -1 if pose == "idle_b" else (2 if pose == "walk_a" else (-1 if pose == "walk_b" else 0))
        pill_limb(img, cx - 8, cy - 4, cx - 12, cy + 4 - arm_dy, 2, DRESS_DARK, DRESS_MID, SKIN)
        pill_limb(img, cx + 8, cy - 4, cx + 14, cy + 2 + arm_dy, 2, DRESS_DARK, DRESS_MID, SKIN)
    elif pose == "cast_windup":
        # Coils lead claw arm back across chest to strike (no floating orb).
        pill_limb(img, cx - 8, cy - 4, cx - 14, cy + 2, 2, DRESS_DARK, DRESS_MID, SKIN)
        pill_limb(img, cx + 6, cy - 5, cx - 2, cy - 9, 2, DRESS_DARK, CRIMSON_MID, SKIN)
        d.line([(cx - 3, cy - 10), (cx + 1, cy - 12)], fill=CRIMSON_BRIGHT, width=2)
    elif pose == "cast_slash":
        # Full forward crimson-claw slash follow-through (no floating orb or duplicate baked arc).
        pill_limb(img, cx - 8, cy - 4, cx - 16, cy + 3, 2, DRESS_DARK, DRESS_MID, SKIN)
        pill_limb(img, cx + 8, cy - 5, cx + 23, cy - 3, 2, DRESS_DARK, CRIMSON_MID, SKIN)
        d.polygon([(cx + 22, cy - 5), (cx + 28, cy - 4), (cx + 23, cy - 1)], fill=CRIMSON_BRIGHT, outline=OUTLINE)
    elif pose == "dash_mist":
        pill_limb(img, cx - 8, cy - 4, cx - 17, cy + 2, 2, DRESS_DARK, CRIMSON_MID, SKIN)
        pill_limb(img, cx + 8, cy - 4, cx + 19, cy - 2, 2, DRESS_DARK, CRIMSON_MID, SKIN)
    elif pose == "die_pool":
        pill_limb(img, cx - 8, cy - 2, cx - 13, cy + 8, 2, DRESS_DARK, DRESS_MID, SKIN)
        pill_limb(img, cx + 8, cy - 2, cx + 12, cy + 9, 2, DRESS_DARK, DRESS_MID, SKIN)
    elif pose == "hurt":
        pill_limb(img, cx - 8, cy - 4, cx - 13, cy - 1, 2, DRESS_DARK, DRESS_MID, SKIN)
        pill_limb(img, cx + 8, cy - 4, cx + 14, cy - 2, 2, DRESS_DARK, DRESS_MID, SKIN)

    return img


def build_velmira_vertical_pose(pose: str) -> Image.Image:
    """Front-facing (`down_*`) & Back-facing (`up_*`) 96x96 poses for Velmira!"""
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = 48, 50
    is_up = pose.startswith("up_")
    step = -1 if pose.endswith("_a") else (1 if pose.endswith("_b") else 0)
    l_dy = -3 * step
    r_dy = 3 * step

    if not is_up:
        # Front: silver hair + crimson cape + gothic dress + symmetrical ruby-eyed face
        d.polygon(
            [(cx - 11, cy - 8), (cx + 11, cy - 8), (cx + 15, cy + 18), (cx - 15, cy + 18)],
            fill=CRIMSON_DEEP,
            outline=OUTLINE,
        )
        for side, dy in ((-5, l_dy), (5, r_dy)):
            lx, ly = cx + side, cy + 26 + min(0, dy)
            pill_limb(img, cx + side // 2, cy + 12, lx, ly - 6, 3, SKIN_SHA, SKIN, SKIN)
            d.rounded_rectangle([lx - 4, ly - 8, lx + 4, ly + 2], radius=2, fill=DRESS_DARK, outline=OUTLINE)
            d.line([(lx - 3, ly - 7), (lx + 3, ly - 7)], fill=CRIMSON_BRIGHT)
        d.polygon([(cx - 9, cy + 4), (cx + 9, cy + 4), (cx + 14, cy + 17), (cx - 14, cy + 17)], fill=DRESS_MID, outline=OUTLINE)
        d.line([(cx - 12, cy + 16), (cx + 12, cy + 16)], fill=CRIMSON_BRIGHT, width=2)
        d.polygon([(cx - 13, cy - 13), (cx + 13, cy - 13), (cx + 10, cy - 5), (cx - 10, cy - 5)], fill=CRIMSON_MID, outline=OUTLINE)
        d.polygon([(cx - 9, cy - 8), (cx + 9, cy - 8), (cx + 7, cy + 6), (cx - 7, cy + 6)], fill=DRESS_DARK, outline=OUTLINE)
        d.polygon([(cx - 3, cy - 7), (cx + 3, cy - 7), (cx + 2, cy + 5), (cx - 2, cy + 5)], fill=CRIMSON_MID)
        d.ellipse([cx - 2, cy - 7, cx + 2, cy - 3], fill=CRIMSON_BRIGHT, outline=OUTLINE)
        pill_limb(img, cx - 10, cy - 4, cx - 14, cy + 3 + l_dy, 2, DRESS_DARK, DRESS_MID, SKIN)
        pill_limb(img, cx + 10, cy - 4, cx + 14, cy + 3 + r_dy, 2, DRESS_DARK, DRESS_MID, SKIN)
        draw_vampire_head(img, cx, cy - 18)
    else:
        # Back: boots + obsidian-crimson gothic cloak + cascading moonlit silver-white hair!
        for side, dy in ((-5, l_dy), (5, r_dy)):
            lx, ly = cx + side, cy + 26 + min(0, dy)
            pill_limb(img, cx + side // 2, cy + 12, lx, ly - 6, 3, SKIN_SHA, SKIN, SKIN)
            d.rounded_rectangle([lx - 4, ly - 8, lx + 4, ly + 2], radius=2, fill=DRESS_DARK, outline=OUTLINE)
        d.polygon(
            [(cx - 11, cy - 9), (cx + 11, cy - 9), (cx + 15 + step, cy + 18), (cx - 15 + step, cy + 18)],
            fill=DRESS_MID,
            outline=OUTLINE,
        )
        d.line([(cx - 12 + step, cy + 17), (cx + 12 + step, cy + 17)], fill=CRIMSON_BRIGHT, width=2)
        d.polygon([(cx - 13, cy - 13), (cx + 13, cy - 13), (cx + 10, cy - 5), (cx - 10, cy - 5)], fill=CRIMSON_MID, outline=OUTLINE)
        hy = cy - 18
        d.polygon([(cx - 10, hy - 2), (cx - 16, hy - 5), (cx - 10, hy + 2)], fill=SKIN_SHA, outline=OUTLINE)
        d.polygon([(cx + 10, hy - 2), (cx + 16, hy - 5), (cx + 10, hy + 2)], fill=SKIN_SHA, outline=OUTLINE)
        hair_pts = [
            (cx - 11, hy - 10),
            (cx + 11, hy - 10),
            (cx + 14 + step, hy + 18),
            (cx + 6 + step, hy + 24),
            (cx + step, hy + 19),
            (cx - 6 + step, hy + 24),
            (cx - 14 + step, hy + 18),
        ]
        d.polygon(hair_pts, fill=HAIR_MID, outline=OUTLINE)
        d.line([(cx - 6, hy - 7), (cx - 5 + step, hy + 17)], fill=HAIR_LIT, width=2)
        d.line([(cx + 4, hy - 7), (cx + 5 + step, hy + 17)], fill=HAIR_HI, width=2)
        draw_crimson_rose(img, cx - 9, hy - 7)

    return img


def main() -> None:
    poses = [
        "idle",         # 0
        "walk_a",       # 1
        "walk_b",       # 2
        "cast_windup",  # 3
        "cast_slash",   # 4
        "dash_mist",    # 5
        "hurt",         # 6
        "blink",        # 7
        "idle_b",       # 8
        "die_pool",     # 9
        "down_idle",    # 10
        "down_walk_a",  # 11
        "down_walk_b",  # 12
        "up_idle",      # 13
        "up_walk_a",    # 14
        "up_walk_b",    # 15
    ]
    sheet = Image.new("RGBA", (FRAME * len(poses), FRAME), (0, 0, 0, 0))
    for i, p in enumerate(poses):
        fr = build_velmira_vertical_pose(p) if p.startswith(("down_", "up_")) else build_velmira_pose(p)
        sheet.alpha_composite(fr, (i * FRAME, 0))
    sheet.save("assets/textures/player_velmira.png")
    print("wrote assets/textures/player_velmira.png", sheet.size)

    zoom, pad = 2, 10
    w = pad + len(poses) * (FRAME * zoom + pad)
    h = 30 + FRAME * zoom + 24
    prev = Image.new("RGBA", (w, h), (22, 16, 26, 255))
    d = ImageDraw.Draw(prev)
    d.text((pad, 8), "VELMIRA (GOTHIC VAMPIRE) - 16 frames x 96x96", fill=(248, 214, 226, 255))
    for i, p in enumerate(poses):
        x = pad + i * (FRAME * zoom + pad)
        fr = sheet.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME))
        prev.alpha_composite(fr.resize((FRAME * zoom, FRAME * zoom), Image.Resampling.NEAREST), (x, 28))
        d.text((x, 28 + FRAME * zoom + 4), f"{i}:{p}", fill=(228, 176, 196, 255))
    prev.save("docs/images/velmira_preview.png")


if __name__ == "__main__":
    main()
