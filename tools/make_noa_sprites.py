#!/usr/bin/env python3
"""Generate Noa's 16-frame 96x96 Silver-Haired Gothic Vampire sheet (`HERO_SKELETON_SPEC.md`).

Bespoke Skeleton #4 — Shortest Hero, Slender Vampire + Massive Asymmetric Hair:
  - `body_h = 64` (`crown_y = 16 .. GROUND_Y = 80`) — shortest hero in the cast!
  - `head_ratio = 33%` (`crown_y = 16 .. chin_y = 37`)
  - `shoulder_w = 23` (`[18..26]`): dainty `12px` gothic shoulders dwarfed by a
    continuous moonlit silver hair waterfall sweeping asymmetrically down her LEFT
    side only past her knee (`knee_y = 64`, tip at `y = 67`), plus a flared
    crimson-trimmed gothic skirt hem
  - `hip_w = 16` (`[12..18]`)
  - Dainty slender vampire legs: `leg_mass ~ 235` (`[150..260]`), `stance_w = 12`
"""

from __future__ import annotations

from PIL import Image, ImageDraw
from hero_art_lib import CELL, GROUND_Y, RAMPS, HeroCanvas


def _draw_asymmetric_hair(c: HeroCanvas, cx: int, crown_y: int, sway: int = 0) -> None:
    """Continuous moonlit silver-white hair waterfall — widest part of Noa!

    Connects seamlessly from the back of her head (`y = 30..36`, `11px` neck pinch
    so `chin_y = 37` -> `33%` `head_ratio`) into a billowing `23px` upper sweep
    (`y = 37..47`) and ONE long asymmetric fall down her LEFT side only, reaching
    below her knee (`knee_y = 64`, tip at `y = 67`)!
    """
    # Connecting back-hair lock behind choker (`y = 31..36`, `x = cx - 6 .. cx + 3` = `10px`,
    # keeping `y = 34..36` narrower than `16px` head so `chin_y = 37` pinches cleanly!)
    c.poly(
        [(cx - 6, crown_y + 15), (cx + 3, crown_y + 15), (cx + 2, crown_y + 21), (cx - 6, crown_y + 21)],
        "moon",
        bias=0.10,
    )

    # Billowing moonlit hair canopy (`y = 37..48`, `x = cx - 16 .. cx + 6` = `23px` wide!)
    canopy_pts = [
        (cx - 11, crown_y + 21),       # y = 37 (`chin_y = 37`, jumps >= 18px immediately!)
        (cx + 6, crown_y + 21),
        (cx + 5, crown_y + 28),
        (cx - 5 + sway, crown_y + 33),
        (cx - 15 + sway, crown_y + 31),
        (cx - 16 + sway, crown_y + 24),  # widest hair billow (`23px` scanline!)
    ]
    c.poly(canopy_pts, "moon", bias=0.18)

    # Single long asymmetric LEFT hair waterfall reaching below knee (`y = 45..67`, left ONLY!)
    fall_pts = [
        (cx - 14 + sway, crown_y + 29),  # y = 45
        (cx - 5 + sway, crown_y + 31),   # y = 47
        (cx - 5, crown_y + 39),          # y = 55 (tucked along left hip -> `hip_w = 16`!)
        (cx - 8 + sway, crown_y + 51),   # y = 67 (3px BELOW knee_y=64 on left only!)
        (cx - 12 + sway, crown_y + 48),  # y = 64
        (cx - 9, crown_y + 38),          # y = 54
    ]
    c.poly(fall_pts, "moon", bias=0.14)
    c.stroke(cx - 13 + sway, crown_y + 23, cx - 9 + sway, crown_y + 47, "moon", 3, width=1)


def _draw_noa_head(
    c: HeroCanvas,
    hx: int,
    crown_y: int,
    blink: bool = False,
    hurt: bool = False,
    facing_mode: str = "side",
) -> None:
    """Dainty petite vampire head (`crown_y = 16 .. y = 34`, velvet choker `y = 34..36`)."""
    # Rounded silver hair crown (`y = 16..31`, `x = hx - 7 .. hx + 7` = `15px` wide)
    c.rrect(hx - 5, crown_y, hx + 5, crown_y + 4, 2, "moon", bias=0.26)
    c.rrect(hx - 7, crown_y + 2, hx + 7, crown_y + 16, 5, "moon", bias=0.20)

    # Slender velvet choker neck (`y = 33..36`, `7px` wide)
    c.rrect(hx - 3, crown_y + 17, hx + 3, crown_y + 20, 1, "obsidian")
    c.dot(hx + 1, crown_y + 19, "crimson", 3)

    if facing_mode == "up":
        c.poly([(hx - 7, crown_y + 4), (hx + 7, crown_y + 4), (hx + 5, crown_y + 20), (hx - 6, crown_y + 20)], "moon", bias=0.18)
        c.ellipse(hx - 5, crown_y + 4, 3, 3, "crimson", bias=0.22)
        return

    fx = 1 if facing_mode == "side" else 0
    # Pale porcelain face (`y = 20..33`, `x = hx - 5 .. hx + 6`)
    c.rrect(hx - 5 + fx, crown_y + 4, hx + 5 + fx, crown_y + 17, 3, "moon", bias=0.34)
    c.dot(hx + 4 + fx, crown_y + 13, "skin", 2)

    # Swept silver forehead bangs & tapered side-locks (`y = 18..33`)
    c.poly([(hx - 6 + fx, crown_y + 2), (hx + 6 + fx, crown_y + 2), (hx + 5 + fx, crown_y + 6), (hx - 6 + fx, crown_y + 7)], "moon", bias=0.28)
    c.stroke(hx - 6 + fx, crown_y + 6, hx - 5 + fx, crown_y + 16, "moon", 3, width=1)
    # Pointed vampire ear
    c.poly([(hx - 5 + fx, crown_y + 9), (hx - 9 + fx, crown_y + 7), (hx - 5 + fx, crown_y + 12)], "moon", bias=0.24)

    # Luminous 2x2 crimson vampire eyes (`y = 25..26`)
    ex_pair = (hx, hx + 4) if facing_mode == "side" else (hx - 3, hx + 3)
    ey = crown_y + 9
    if hurt:
        for ex in ex_pair:
            c.stroke(ex - 1, ey, ex + 1, ey + 1, "crimson", 0)
    elif blink:
        for ex in ex_pair:
            c.stroke(ex - 1, ey + 1, ex + 1, ey + 1, "moon", 0)
    else:
        for ex in ex_pair:
            c.dot(ex, ey - 1, "obsidian", 0)
            c.dot(ex, ey, "crimson", 1)
            c.dot(ex + 1, ey, "crimson", 3)
        c.dot(hx + 2 + fx, crown_y + 14, "crimson", 2)
        c.dot(hx + 3 + fx, crown_y + 15, "moon", 3)

    # Signature Crimson Temple Rose (`y = 17..22`, stays inside `head_w = 16px`)
    c.dot(hx - 6 + fx, crown_y + 4, "emerald", 2)
    c.ellipse(hx - 4 + fx, crown_y + 4, 3, 3, "crimson", bias=0.24)
    c.dot(hx - 5 + fx, crown_y + 3, "crimson", 3)


def build_noa_side(pose: str) -> Image.Image:
    c = HeroCanvas()
    # Positioned at `cx = 56` while her voluminous hair sweeps asymmetrically LEFT!
    cx = 56
    crown_y = 16  # exact 80 - 16 = 64px standing height (SHORTEST hero)!
    sway = 0
    l_leg_x, l_fy = 52, 79
    r_leg_x, r_fy = 58, 79

    if pose == "idle_b":
        sway = -1
    elif pose == "walk_a":
        l_leg_x, l_fy = 48, 78
        r_leg_x, r_fy = 58, 79
        sway = -2
    elif pose == "walk_b":
        l_leg_x, l_fy = 51, 79
        r_leg_x, r_fy = 55, 77
        sway = -1
    elif pose == "cast_windup":
        cx = 52
        sway = -2
    elif pose == "cast_slash":
        cx = 55
        l_leg_x, r_leg_x = 49, 59
        sway = -3
    elif pose == "dash_lunge":
        cx = 56
        l_leg_x, r_leg_x = 49, 59
        sway = -4
    elif pose == "die_kneel":
        # Collapsed gothic vampire pose (`h = 40 < 64 * 0.92`) with pooled hair & skirt!
        c.poly([(36, 73), (68, 73), (72, 79), (33, 79)], "obsidian", bias=0.06)
        c.stroke(37, 77, 67, 77, "crimson", 2, width=1)
        c.poly([(35, 60), (54, 58), (50, 76), (32, 75)], "moon", bias=0.16)
        c.poly([(46, 56), (56, 56), (59, 73), (44, 73)], "obsidian", bias=0.10)
        c.poly([(45, 55), (57, 55), (55, 60), (47, 60)], "crimson", bias=0.18)
        _draw_noa_head(c, 51, 39, blink=True, facing_mode="side")
        return c.finalize(ground_y=GROUND_Y)
    elif pose == "hurt":
        cx = 52
        crown_y = 23  # recoil crouch (`h = 57 < 64 * 0.92`) so `frame 0` is standing cell!
        l_leg_x, r_leg_x = 49, 56
        sway = 2

    sh_y = crown_y + 25     # 41
    waist_y = crown_y + 34  # 50
    hip_y = crown_y + 39    # 55

    # 1. Voluminous asymmetric moonlit silver hair (widest part of Noa!)
    _draw_asymmetric_hair(c, cx, crown_y, sway=sway)

    # 2. Dainty slender vampire legs (`y = 60..79`, `leg_mass ~ 235`, `stance_w = 12`)!
    for idx, (lx, fy) in enumerate(((l_leg_x, l_fy), (r_leg_x, r_fy))):
        hip_anchor = cx - 2 if idx == 0 else cx + 2
        knee_y = 64
        c.tapered_limb(hip_anchor, min(hip_y + 3, knee_y - 1), 1.4, lx, knee_y, 1.2, "moon", bias=0.18)
        c.tapered_limb(lx, knee_y, 1.3, lx, fy - 3, 1.1, "obsidian", bias=0.08)
        # Heeled gothic vampire boots (`stance_w = 12` on idle: `48..59`)
        if idx == 0:
            c.rrect(lx - 2, fy - 4, lx + 1, fy, 1, "obsidian", bias=0.08)
            c.dot(lx, fy - 4, "crimson", 2)
        else:
            c.rrect(lx - 1, fy - 4, lx + 3, fy, 1, "obsidian", bias=0.14)
            c.dot(lx + 1, fy - 4, "crimson", 3)

    # 3. Dainty `12px` gothic corset shoulders -> `10px` hourglass waist -> flared gothic skirt hem!
    c.poly(
        [
            (cx - 5, waist_y),
            (cx + 5, waist_y),
            (cx + 6, hip_y),       # y = 55 (`hip_w = 16` with left hair lock!)
            (cx + 12, hip_y + 4),  # y = 59: sharp gothic skirt hem flare!
            (cx + 5, hip_y + 5),   # y = 60: scalloped center hem point
            (cx - 2, hip_y + 4),
            (cx - 10, hip_y + 4),
        ],
        "obsidian",
        bias=0.08,
    )
    # Crimson velvet trim tucked INSIDE the gothic skirt flare (never poking out as a flat shelf!)
    c.stroke(cx - 7, hip_y + 3, cx + 9, hip_y + 3, "crimson", 2, width=1)

    # Flared crimson vampire collar (`y = 37..41`)
    c.poly(
        [(cx - 7, crown_y + 21), (cx + 7, crown_y + 21), (cx + 5, sh_y), (cx - 5, sh_y)],
        "crimson",
        bias=0.18,
    )
    # Ultra-narrow `12px` gothic corset bodice (`x = cx - 6 .. cx + 5`)
    c.poly([(cx - 6, sh_y - 1), (cx + 5, sh_y - 1), (cx + 4, waist_y), (cx - 4, waist_y)], "obsidian", bias=0.10)
    c.poly([(cx - 2, sh_y), (cx + 2, sh_y), (cx + 1, waist_y), (cx - 1, waist_y)], "crimson", bias=0.16)

    # 4. Dainty Vampire Head (`crown_y = 16 .. 36`)
    _draw_noa_head(
        c,
        cx,
        crown_y,
        blink=(pose == "blink"),
        hurt=(pose == "hurt"),
        facing_mode="side",
    )

    # 5. Graceful gothic bell-sleeve & crimson blood-magic claws
    if pose in ("idle", "idle_b", "blink", "walk_a", "walk_b"):
        ady = -1 if pose == "idle_b" else (1 if pose == "walk_a" else (-1 if pose == "walk_b" else 0))
        c.tapered_limb(cx + 3, sh_y + 1, 1.3, cx + 6, sh_y + 7 + ady, 1.6, "obsidian", bias=0.12)
        c.dot(cx + 7, sh_y + 8 + ady, "moon", 3)
    elif pose == "cast_windup":
        c.tapered_limb(cx + 3, sh_y + 1, 1.4, cx - 2, sh_y - 3, 1.5, "obsidian")
        c.stroke(cx - 3, sh_y - 4, cx + 1, sh_y - 5, "crimson", 3, width=2)
    elif pose == "cast_slash":
        c.tapered_limb(cx + 3, sh_y, 1.4, cx + 16, sh_y - 1, 1.6, "obsidian", bias=0.12)
        c.arc_stroke(cx + 12, sh_y + 1, 16, 13, -55, 50, "crimson", 3, width=2, selout_wrap=True)
    elif pose == "dash_lunge":
        c.tapered_limb(cx + 3, sh_y, 1.4, cx + 16, sh_y, 1.5, "crimson", bias=0.18)
        c.stroke(cx - 14, sh_y + 6, cx - 4, sh_y + 6, "crimson", 3, width=1)
    elif pose == "hurt":
        c.tapered_limb(cx + 3, sh_y + 1, 1.3, cx + 9, sh_y - 2, 1.4, "obsidian")

    return c.finalize(ground_y=GROUND_Y)


def build_noa_vertical(pose: str) -> Image.Image:
    c = HeroCanvas()
    cx = 50
    crown_y = 16
    is_up = pose.startswith("up_")
    step = -1 if pose.endswith("_a") else (1 if pose.endswith("_b") else 0)
    l_fy = 79 - (2 if step > 0 else 0)
    r_fy = 79 - (2 if step < 0 else 0)
    sh_y, waist_y, hip_y = 41, 50, 55

    _draw_asymmetric_hair(c, cx, crown_y, sway=-2 + step)

    for idx, (lx, fy) in enumerate(((cx - 3, l_fy), (cx + 3, r_fy))):
        c.tapered_limb(lx, hip_y + 3, 1.4, lx, 64, 1.2, "moon")
        c.tapered_limb(lx, 64, 1.3, lx, fy - 3, 1.1, "obsidian")
        c.rrect(lx - 2, fy - 4, lx + 2, fy, 1, "obsidian")

    c.poly(
        [
            (cx - 5, waist_y),
            (cx + 5, waist_y),
            (cx + 6, hip_y),
            (cx + 13, hip_y + 4),
            (cx + 4, hip_y + 5),
            (cx - 3, hip_y + 4),
            (cx - 11, hip_y + 4),
            (cx - 6, hip_y),
        ],
        "obsidian",
    )
    c.stroke(cx - 8, hip_y + 3, cx + 10, hip_y + 3, "crimson", 2)
    c.poly([(cx - 7, crown_y + 21), (cx + 8, crown_y + 21), (cx + 5, sh_y), (cx - 5, sh_y)], "crimson", bias=0.16)
    c.poly([(cx - 6, sh_y - 1), (cx + 6, sh_y - 1), (cx + 4, waist_y), (cx - 4, waist_y)], "obsidian")
    if not is_up:
        c.poly([(cx - 2, sh_y), (cx + 2, sh_y), (cx + 1, waist_y), (cx - 1, waist_y)], "crimson", bias=0.16)

    c.tapered_limb(cx + 5, sh_y + 1, 1.3, cx + 11, sh_y + 7 - step * 2, 1.4, "obsidian")
    _draw_noa_head(c, cx, crown_y, facing_mode="up" if is_up else "down")
    return c.finalize(ground_y=GROUND_Y)


def main() -> None:
    poses = [
        "idle",         # 0
        "walk_a",       # 1
        "walk_b",       # 2
        "cast_windup",  # 3
        "cast_slash",   # 4
        "dash_lunge",   # 5
        "hurt",         # 6
        "blink",        # 7
        "idle_b",       # 8
        "die_kneel",    # 9
        "down_idle",    # 10
        "down_walk_a",  # 11
        "down_walk_b",  # 12
        "up_idle",      # 13
        "up_walk_a",    # 14
        "up_walk_b",    # 15
    ]
    sheet = Image.new("RGBA", (CELL * len(poses), CELL), (0, 0, 0, 0))
    for i, p in enumerate(poses):
        fr = build_noa_vertical(p) if p.startswith(("down_", "up_")) else build_noa_side(p)
        sheet.alpha_composite(fr, (i * CELL, 0))
    sheet.save("assets/textures/player_noa.png")
    print("wrote assets/textures/player_noa.png", sheet.size)

    zoom, pad = 2, 10
    w = pad + len(poses) * (CELL * zoom + pad)
    h = 30 + CELL * zoom + 24
    prev = Image.new("RGBA", (w, h), (22, 16, 26, 255))
    d = ImageDraw.Draw(prev)
    d.text((pad, 8), "NOA (SKELETON SPEC: 64px, asymmetric hair, 200 leg_mass)", fill=RAMPS["crimson"][3])
    for i, p in enumerate(poses):
        x = pad + i * (CELL * zoom + pad)
        fr = sheet.crop((i * CELL, 0, (i + 1) * CELL, CELL))
        prev.alpha_composite(fr.resize((CELL * zoom, CELL * zoom), Image.NEAREST), (x, 28))
        d.text((x, 28 + CELL * zoom + 4), f"{i}:{p}", fill=RAMPS["moon"][2])
    prev.save("docs/images/noa_preview.png")


if __name__ == "__main__":
    main()
