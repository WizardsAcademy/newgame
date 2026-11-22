#!/usr/bin/env python3
"""Generate Behemoth's 16-frame 96x96 Pit-Champion Brawler sheet (`HERO_SKELETON_SPEC.md`).

Bespoke Skeleton #1 — Thickest, Hunched Pit-Champion (NOT tallest):
  - `body_h = 68` (`crown_y = 12 .. GROUND_Y = 80`)
  - `head_ratio = 31%` (`crown_y = 12 .. chin_y = 33`), head sunk between bull-traps
    and pushed `+3px` FORWARD (`hx = cx + 3`)
  - `shoulder_w = 48` (`x = 23..70`), `20px` wider than `hip_w = 28` (`x = 34..61`)
  - Heavy gorilla-like brawler arms hang DOWN from massive boulder pauldrons so
    both Iron Cestus fists hang BELOW the belt/hip line (`y = 52..58`)
  - Muscular pit-fighter legs visibly narrower than torso:
    `leg_mass ~ 485` (`[380..560]`), `stance_w = 26` (`x = 34..59`)
"""

from __future__ import annotations

from PIL import Image, ImageDraw
from hero_art_lib import CELL, GROUND_Y, RAMPS, HeroCanvas


def _draw_cestus(c: HeroCanvas, fx: float, fy: float, rx: float = 5.0, ry: float = 4.2, spike_dir: int = 1) -> None:
    """Heavy riveted Iron Cestus gauntlet with brass knuckle studs."""
    c.rrect(fx - rx, fy - ry, fx + rx, fy + ry, 2, "steel", bias=0.10)
    c.rrect(fx - rx + 1, fy - ry, fx + rx - 1, fy - ry + 2, 1, "leather")
    sx = int(round(fx + rx)) if spike_dir >= 0 else int(round(fx - rx))
    for sy in (-2, 1):
        c.dot(sx + spike_dir, int(round(fy + sy)), "steel", 3)
    c.dot(int(round(fx)), int(round(fy - 1)), "gold", 3)


def _draw_behemoth_head(
    c: HeroCanvas,
    hx: int,
    crown_y: int,
    blink: bool = False,
    hurt: bool = False,
    facing_mode: str = "side",
) -> None:
    """Sunk, forward-jutting pit-fighter head + thick bull neck (`y = crown_y .. crown_y + 21`)."""
    # Thick muscular bull neck connecting skull straight into hunched traps (`y = crown_y + 13 .. crown_y + 22`)
    c.rrect(hx - 6, crown_y + 13, hx + 6, crown_y + 22, 2, "skin", bias=-0.04)

    # Skull & dark cropped hair dome (`y = crown_y .. crown_y + 15`)
    c.rrect(hx - 7, crown_y, hx + 7, crown_y + 15, 4, "leather", bias=-0.10)

    if facing_mode == "up":
        # Back of cropped hair + crimson headband knot & twin tails resting on bull neck
        c.rrect(hx - 8, crown_y + 3, hx + 8, crown_y + 6, 1, "crimson", bias=0.12)
        c.dot(hx, crown_y + 5, "gold", 3)
        c.poly([(hx - 2, crown_y + 6), (hx - 6, crown_y + 16), (hx - 2, crown_y + 17)], "crimson")
        c.poly([(hx + 2, crown_y + 6), (hx + 6, crown_y + 16), (hx + 2, crown_y + 17)], "crimson")
        return

    fx = 1 if facing_mode == "side" else 0
    # Broad scarred brow & face (`x = hx - 7 .. hx + 8` = `16px` wide)
    c.rrect(hx - 7, crown_y + 3, hx + 7 + fx, crown_y + 15, 3, "skin", bias=0.10)

    # Crimson pit-champion headband (`y = crown_y + 3 .. crown_y + 6`)
    c.rrect(hx - 8, crown_y + 3, hx + 7 + fx, crown_y + 6, 1, "crimson", bias=0.14)
    c.dot(hx + 2 + fx, crown_y + 4, "gold", 3)

    # Thick braided dark beard (`y = crown_y + 11 .. crown_y + 19`)
    c.poly(
        [
            (hx - 6, crown_y + 11),
            (hx + 6 + fx, crown_y + 11),
            (hx + 5 + fx, crown_y + 19),
            (hx - 5, crown_y + 19),
        ],
        "leather",
        bias=-0.14,
    )
    c.dot(hx + 1 + fx, crown_y + 18, "gold", 3)

    # Fierce sunken eyes under heavy brow
    ex_pair = (hx, hx + 5) if facing_mode == "side" else (hx - 4, hx + 3)
    ey = crown_y + 9
    if hurt:
        for ex in ex_pair:
            c.stroke(ex - 1, ey - 1, ex + 1, ey + 1, "skin", 0)
    elif blink:
        for ex in ex_pair:
            c.stroke(ex - 1, ey, ex + 1, ey, "skin", 0)
    else:
        for ex in ex_pair:
            c.stroke(ex - 1, ey - 1, ex + 1, ey - 1, "leather", 0)
            c.dot(ex, ey, "obsidian", 0)
            c.dot(ex + 1, ey, "gold", 3)


def build_behemoth_side(pose: str) -> Image.Image:
    c = HeroCanvas()
    # Spine centered at cx = 43; head pushed +3px FORWARD (`hx = 46`)!
    cx = 43
    crown_y = 12  # exact 80 - 12 = 68px standing height!
    l_leg_x, l_fy = 35, 79
    r_leg_x, r_fy = 51, 79

    if pose == "walk_a":
        l_leg_x, l_fy = 36, 78
        r_leg_x, r_fy = 57, 79
        crown_y = 13
    elif pose == "walk_b":
        l_leg_x, l_fy = 41, 79
        r_leg_x, r_fy = 52, 77
        crown_y = 13
    elif pose == "windup":
        cx = 44
        crown_y = 13
        l_leg_x, r_leg_x = 36, 54
    elif pose == "jab":
        cx = 50
        crown_y = 13
        l_leg_x, r_leg_x = 37, 58
    elif pose == "cross":
        cx = 52
        crown_y = 13
        l_leg_x, r_leg_x = 37, 59
    elif pose == "uppercut":
        cx = 48
        crown_y = 14
        l_leg_x, l_fy = 38, 79
        r_leg_x, r_fy = 56, 73
    elif pose == "charge":
        cx = 51
        crown_y = 15
        l_leg_x, r_leg_x = 37, 59
    elif pose == "hurt":
        cx = 43
        crown_y = 15
        l_leg_x, r_leg_x = 36, 53

    hip_y = 54
    waist_y = 50
    sh_y = 39

    # 1. Muscular pit-fighter legs (`y = 55..79`), VISIBLY NARROWER than the 48px boulder shoulders!
    #    Beefy thighs (`r = 3.2`) + iron kneecaps + wrapped calves (`leg_mass ~ 485`, `stance_w = 26`).
    for idx, (lx, fy) in enumerate(((l_leg_x, l_fy), (r_leg_x, r_fy))):
        hip_anchor = cx - 6 if idx == 0 else cx + 6
        knee_x = int(round(0.4 * hip_anchor + 0.6 * lx))
        knee_y = 66
        c.tapered_limb(hip_anchor, hip_y, 3.2, knee_x, knee_y, 2.6, "obsidian", bias=-0.06 if idx == 0 else 0.08)
        c.tapered_limb(knee_x, knee_y, 2.6, lx, fy - 4, 2.2, "leather", bias=0.06)
        c.rrect(knee_x - 3, knee_y - 2, knee_x + 3, knee_y + 1, 1, "steel", bias=0.14)
        # Planted iron-capped pit boots (`stance_w = 26` on idle: `35..60`)
        if idx == 0:
            c.rrect(lx - 4, fy - 4, lx + 3, fy, 1, "leather", bias=0.06)
            c.rrect(lx - 4, fy - 2, lx, fy, 1, "steel", bias=0.14)
        else:
            c.rrect(lx - 3, fy - 4, lx + 5, fy, 1, "leather", bias=0.08)
            c.rrect(lx + 1, fy - 2, lx + 5, fy, 1, "steel", bias=0.18)

    # 2. Sloping Bull-Trap V-Taper Torso (`22px` traps at `chin_y = 33` -> `48px` boulder shoulders -> `20px` waist!)
    torso_pts = [
        (cx - 10, crown_y + 21),  # sloping traps begin at y=33 (`23px` > 17*1.10 -> chin_y=33 -> 31% head!)
        (cx + 12, crown_y + 21),
        (cx + 22, sh_y - 2),
        (cx + 23, sh_y + 2),      # right boulder shoulder (`x = 70` on idle)
        (cx + 11, waist_y),       # narrow 21px waist
        (cx + 9, hip_y + 2),
        (cx - 9, hip_y + 2),
        (cx - 10, waist_y),
        (cx - 24, sh_y + 2),      # left boulder shoulder (`x = 23` on idle -> exact `48px` span!)
        (cx - 22, sh_y - 2),
    ]
    c.poly(torso_pts, "leather", bias=0.08)

    # Brigandine steel chest harness & rivets (`y = 36..48`)
    c.poly(
        [(cx - 13, sh_y - 3), (cx + 14, sh_y - 3), (cx + 9, waist_y - 2), (cx - 9, waist_y - 2)],
        "steel",
        bias=-0.02,
    )
    for rx_off in (-6, 0, 6):
        c.dot(cx + rx_off, sh_y + 1, "gold", 3)

    # Rounded spiked iron left pauldron (`spike stays at y >= 34` below `chin_y = 33`)
    c.ellipse(cx - 18, sh_y, 6, 5, "steel", bias=0.20)
    c.poly([(cx - 20, sh_y - 3), (cx - 23, sh_y - 5), (cx - 16, sh_y - 4)], "steel", bias=0.28)
    # Heavy right iron pauldron
    c.ellipse(cx + 18, sh_y, 5, 5, "steel", bias=0.08)

    # Crimson championship belt & brass buckle (`y = 49..54`)
    c.rrect(cx - 10, waist_y - 1, cx + 10, waist_y + 3, 1, "crimson", bias=0.10)
    c.rrect(cx - 2, waist_y - 1, cx + 4, waist_y + 3, 1, "gold", bias=0.24)

    # 3. Sunk, forward-pushed head (`hx = cx + 3 = 50`, nestled down into bull traps!)
    _draw_behemoth_head(
        c,
        cx + 3,
        crown_y,
        blink=(pose == "blink"),
        hurt=(pose == "hurt"),
        facing_mode="side",
    )

    # 4. Heavy Gorilla/Pit-Champion Arms hanging DOWN so both Cestus fists hang BELOW hip line!
    if pose in ("idle", "blink", "walk_a", "walk_b"):
        sw = -2 if pose == "walk_a" else (2 if pose == "walk_b" else 0)
        # Massive biceps -> forearms hanging vertically-inward so fists sit at `y = 54..58`
        # (`hip_w` at `y = 54` = `28px` spanning `x = 34..61`, strictly above `leg_top = 59`!)
        c.tapered_limb(cx - 19, sh_y + 3, 3.8, cx - 13, 47, 3.2, "skin", bias=0.12)
        c.tapered_limb(cx - 13, 47, 3.0, cx - 9, 53 - sw, 2.7, "skin", bias=0.10)
        _draw_cestus(c, cx - 8, 55 - sw // 2, rx=4.8, ry=3.5, spike_dir=-1)

        c.tapered_limb(cx + 18, sh_y + 3, 3.6, cx + 14, 47, 3.0, "skin", bias=0.06)
        c.tapered_limb(cx + 14, 47, 2.9, cx + 10, 53 + sw, 2.6, "skin", bias=0.04)
        _draw_cestus(c, cx + 9, 55 + sw // 2, rx=4.8, ry=3.5, spike_dir=1)
    elif pose == "windup":
        c.tapered_limb(cx - 18, sh_y + 2, 3.6, cx - 26, sh_y + 7, 3.0, "skin")
        _draw_cestus(c, cx - 28, sh_y + 8, rx=5.5, ry=4.5, spike_dir=-1)
        c.tapered_limb(cx + 16, sh_y + 2, 3.4, cx + 21, sh_y + 5, 2.8, "skin")
        _draw_cestus(c, cx + 24, sh_y + 5, rx=5.5, ry=4.5, spike_dir=1)
    elif pose == "jab":
        c.tapered_limb(cx - 18, sh_y + 3, 3.4, cx - 10, 53, 2.7, "skin")
        _draw_cestus(c, cx - 8, 55, rx=4.8, ry=3.6, spike_dir=-1)
        c.tapered_limb(cx + 14, sh_y, 3.8, cx + 29, sh_y - 1, 3.1, "skin", bias=0.14)
        _draw_cestus(c, cx + 35, sh_y - 1, rx=6.5, ry=5.0, spike_dir=1)
        c.stroke(cx + 20, sh_y - 6, cx + 38, sh_y - 6, "gold", 3)
    elif pose == "cross":
        c.tapered_limb(cx - 16, sh_y + 3, 3.2, cx - 12, 52, 2.6, "skin")
        _draw_cestus(c, cx - 10, 54, rx=4.5, ry=3.5, spike_dir=-1)
        # Muscular shoulder -> elbow -> explosive heavy cross (no wooden-pole arm!)
        c.tapered_limb(cx + 10, sh_y - 1, 4.0, cx + 23, sh_y + 1, 3.5, "skin", bias=0.16)
        c.tapered_limb(cx + 23, sh_y + 1, 3.4, cx + 33, sh_y - 1, 3.0, "skin", bias=0.18)
        _draw_cestus(c, cx + 38, sh_y - 1, rx=7.0, ry=5.5, spike_dir=1)
        c.arc_stroke(cx + 28, sh_y, 15, 12, -48, 48, "gold", 3, width=2, selout_wrap=True)
    elif pose == "uppercut":
        c.tapered_limb(cx - 17, sh_y + 3, 3.2, cx - 10, 53, 2.6, "skin")
        _draw_cestus(c, cx - 9, 55, rx=4.5, ry=3.5, spike_dir=-1)
        c.tapered_limb(cx + 11, sh_y + 2, 3.8, cx + 21, 30, 3.2, "skin", bias=0.14)
        c.tapered_limb(cx + 21, 30, 3.2, cx + 24, 21, 2.9, "skin", bias=0.18)
        _draw_cestus(c, cx + 25, 18, rx=6.0, ry=4.8, spike_dir=1)
        c.arc_stroke(cx + 18, 28, 14, 15, -80, 25, "gold", 3, width=2, selout_wrap=True)
    elif pose == "charge":
        c.tapered_limb(cx - 10, sh_y + 2, 3.8, cx + 18, sh_y + 3, 3.2, "skin", bias=0.12)
        _draw_cestus(c, cx + 23, sh_y + 2, rx=6.5, ry=5.0, spike_dir=1)
        c.ellipse(cx + 16, sh_y - 1, 6, 5, "steel", bias=0.22)
    elif pose == "hurt":
        c.tapered_limb(cx - 18, sh_y + 2, 3.4, cx - 22, sh_y - 2, 2.8, "skin")
        _draw_cestus(c, cx - 24, sh_y - 3, rx=4.5, ry=3.8, spike_dir=-1)
        c.tapered_limb(cx + 16, sh_y + 3, 3.2, cx + 19, sh_y + 8, 2.6, "skin")
        _draw_cestus(c, cx + 20, sh_y + 10, rx=5.0, ry=4.0, spike_dir=1)

    return c.finalize(ground_y=GROUND_Y)


def build_behemoth_vertical(pose: str) -> Image.Image:
    c = HeroCanvas()
    cx = 48
    crown_y = 12
    is_up = pose.startswith("up_")
    step = -1 if pose.endswith("_a") else (1 if pose.endswith("_b") else 0)
    l_fy = 79 - (2 if step > 0 else 0)
    r_fy = 79 - (2 if step < 0 else 0)
    hip_y, waist_y, sh_y = 54, 50, 39

    for idx, (lx, fy) in enumerate(((cx - 8, l_fy), (cx + 8, r_fy))):
        c.tapered_limb(lx, hip_y, 3.1, lx, 66, 2.5, "obsidian")
        c.tapered_limb(lx, 66, 2.5, lx, fy - 4, 2.1, "leather")
        c.rrect(lx - 3, 64, lx + 3, 67, 1, "steel")
        c.rrect(lx - 4, fy - 4, lx + 4, fy, 1, "leather")

    # 50px front/back boulder shoulders (>= side idle 48px so `_standing_cell` picks `f00`)
    c.poly(
        [
            (cx - 12, crown_y + 21),
            (cx + 12, crown_y + 21),
            (cx + 25, sh_y + 1),
            (cx + 11, waist_y),
            (cx + 10, hip_y + 2),
            (cx - 10, hip_y + 2),
            (cx - 11, waist_y),
            (cx - 25, sh_y + 1),
        ],
        "leather",
        bias=0.06,
    )
    if not is_up:
        c.poly([(cx - 13, sh_y - 3), (cx + 13, sh_y - 3), (cx + 9, waist_y - 2), (cx - 9, waist_y - 2)], "steel")
    else:
        # Crossed leather back-harness straps on back view!
        c.stroke(cx - 12, sh_y - 3, cx + 9, waist_y - 1, "obsidian", 2, width=2)
        c.stroke(cx + 12, sh_y - 3, cx - 9, waist_y - 1, "obsidian", 2, width=2)

    sp_x = cx - 19 if not is_up else cx + 19
    c.ellipse(sp_x, sh_y, 6, 5, "steel", bias=0.20)
    c.poly([(sp_x - 2, sh_y - 3), (sp_x, sh_y - 6), (sp_x + 3, sh_y - 3)], "steel", bias=0.28)
    c.ellipse(cx + (19 if not is_up else -19), sh_y, 5, 5, "steel", bias=0.08)

    c.rrect(cx - 11, waist_y - 1, cx + 11, waist_y + 3, 1, "crimson")
    if not is_up:
        c.rrect(cx - 3, waist_y - 1, cx + 3, waist_y + 3, 1, "gold")

    # Draw head BEFORE or WITH bull neck so head sits cleanly into traps on both down & up!
    _draw_behemoth_head(c, cx, crown_y, facing_mode="up" if is_up else "down")

    c.tapered_limb(cx - 20, sh_y + 3, 3.6, cx - 12, 53 + step * 2, 2.7, "skin")
    _draw_cestus(c, cx - 10, 55 + step * 2, rx=4.8, ry=3.5, spike_dir=-1)
    c.tapered_limb(cx + 20, sh_y + 3, 3.6, cx + 12, 53 - step * 2, 2.7, "skin")
    _draw_cestus(c, cx + 10, 55 - step * 2, rx=4.8, ry=3.5, spike_dir=1)

    return c.finalize(ground_y=GROUND_Y)


def main() -> None:
    poses = [
        "idle", "walk_a", "walk_b", "windup", "jab", "cross", "uppercut", "charge", "hurt", "blink",
        "down_idle", "down_walk_a", "down_walk_b", "up_idle", "up_walk_a", "up_walk_b",
    ]
    sheet = Image.new("RGBA", (CELL * len(poses), CELL), (0, 0, 0, 0))
    for i, p in enumerate(poses):
        fr = build_behemoth_vertical(p) if p.startswith(("down_", "up_")) else build_behemoth_side(p)
        sheet.alpha_composite(fr, (i * CELL, 0))
    sheet.save("assets/textures/player_behemoth.png")
    print("wrote assets/textures/player_behemoth.png", sheet.size)

    zoom, pad = 2, 10
    w = pad + len(poses) * (CELL * zoom + pad)
    h = 30 + CELL * zoom + 24
    prev = Image.new("RGBA", (w, h), (26, 20, 18, 255))
    d = ImageDraw.Draw(prev)
    d.text((pad, 8), "BEHEMOTH (SKELETON SPEC: 68px, 48w shoulders, 470 leg_mass)", fill=RAMPS["gold"][3])
    for i, p in enumerate(poses):
        x = pad + i * (CELL * zoom + pad)
        fr = sheet.crop((i * CELL, 0, (i + 1) * CELL, CELL))
        prev.alpha_composite(fr.resize((CELL * zoom, CELL * zoom), Image.NEAREST), (x, 28))
        d.text((x, 28 + CELL * zoom + 4), f"{i}:{p}", fill=RAMPS["moon"][2])
    prev.save("docs/images/behemoth_preview.png")


if __name__ == "__main__":
    main()
