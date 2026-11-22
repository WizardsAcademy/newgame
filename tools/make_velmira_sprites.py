#!/usr/bin/env python3
"""Generate Velmira's 16-frame 96x96 Silver-Haired Gothic Vampire sheet.

Hero Art Contract (Phase 4):
  - 96x96 cells, standing height 72px (top_y=8 .. GROUND_Y=80), ~29% head ratio.
  - Silhouette: narrow gothic shoulders & slender corset waist contrasted with a
    voluminous asymmetric silver-white hair mass cascading down her left/back
    side past her hips, flared high vampire collar, and heeled gothic boots.
  - Palette: 5 ramps x 4 steps = <=20 colours from the shared 32-colour ramp
    (`moon`, `obsidian`, `crimson`, `emerald`, `skin`).
  - Top-left 4-step shading + selective selout (zero `#000000`, zero stray orbs).
"""

from __future__ import annotations

from PIL import Image, ImageDraw
from hero_art_lib import CELL, GROUND_Y, RAMPS, HeroCanvas


def _draw_asymmetric_hair_back(c: HeroCanvas, cx: int, hy: int, sway: int = 0) -> None:
    """Heavy moonlit silver-white hair mass sweeping asymmetrically down one side!"""
    pts = [
        (cx - 10, hy - 8),
        (cx + 8, hy - 7),
        (cx + 6 + sway // 2, hy + 20),
        (cx - 4 + sway, hy + 36),
        (cx - 11 + sway, hy + 51),   # long asymmetric cascade reaching knee level!
        (cx - 19 + sway, hy + 44),
        (cx - 15 + sway, hy + 34),
        (cx - 24 + sway, hy + 38),   # secondary outer lock breaking left silhouette!
        (cx - 22 + sway, hy + 18),
        (cx - 16, hy + 2),
    ]
    c.poly(pts, "moon", bias=0.14)
    # Crisp moonlit silver highlight strands along top-left cascade
    c.stroke(cx - 13, hy - 2, cx - 18 + sway, hy + 32, "moon", 3, width=2)
    c.stroke(cx - 7, hy + 4, cx - 11 + sway, hy + 44, "moon", 2, width=2)


def _draw_velmira_head(
    c: HeroCanvas,
    hx: int,
    hy: int,
    blink: bool = False,
    hurt: bool = False,
    facing_mode: str = "side",
) -> None:
    """Heroic ~20px porcelain vampire head (`hy - 10 .. hy + 9`) + crimson temple rose."""
    # Silver hair crown
    c.ellipse(hx, hy - 3, 9, 8, "moon", bias=0.18)

    if facing_mode == "up":
        c.poly(
            [
                (hx - 11, hy - 4),
                (hx + 9, hy - 4),
                (hx + 10, hy + 28),
                (hx + 2, hy + 44),
                (hx - 8, hy + 50),
                (hx - 16, hy + 36),
            ],
            "moon",
            bias=0.16,
        )
        c.ellipse(hx - 8, hy - 6, 4, 4, "crimson", bias=0.20)
        return

    fx = 1 if facing_mode == "side" else 0
    # Pale porcelain face FIRST (kept completely unsplit so crimson eyes read clearly!)
    c.rrect(hx - 6 + fx, hy - 5, hx + 7 + fx, hy + 7, 3, "moon", bias=0.34)
    c.dot(hx + 5 + fx, hy + 3, "skin", 2)

    # Swept moonlit crown bangs across top forehead & temple lock behind cheek (no vertical split line across face!)
    c.poly(
        [(hx - 8 + fx, hy - 8), (hx + 7 + fx, hy - 8), (hx + 6 + fx, hy - 4), (hx - 7 + fx, hy - 3)],
        "moon",
        bias=0.28,
        selout=True,
    )
    c.poly(
        [(hx - 9 + fx, hy - 4), (hx - 5 + fx, hy - 4), (hx - 6 + fx, hy + 7), (hx - 10 + fx, hy + 4)],
        "moon",
        bias=0.22,
    )

    # Pointed pale vampire ear jutting back through silver locks
    c.poly([(hx - 6 + fx, hy - 1), (hx - 13 + fx, hy - 4), (hx - 7 + fx, hy + 3)], "moon", bias=0.26)

    # Luminous 2x2 crimson vampire eyes + dark upper lash + tiny porcelain fang!
    ex_list = (hx + 1, hx + 5) if facing_mode == "side" else (hx - 3, hx + 3)
    if hurt:
        for ex in ex_list:
            c.stroke(ex - 1, hy - 1, ex + 1, hy + 1, "crimson", 0)
    elif blink:
        for ex in ex_list:
            c.stroke(ex - 1, hy + 1, ex + 1, hy + 1, "moon", 0)
    else:
        for ex in ex_list:
            c.stroke(ex - 1, hy - 2, ex + 1, hy - 2, "obsidian", 0)
            c.dot(ex, hy - 1, "crimson", 1)
            c.dot(ex + 1, hy - 1, "crimson", 2)
            c.dot(ex, hy, "crimson", 2)
            c.dot(ex + 1, hy, "crimson", 3)
            c.dot(ex, hy - 1, "moon", 3)
        c.dot(hx + 3 + fx, hy + 4, "crimson", 2)
        c.dot(hx + 4 + fx, hy + 5, "moon", 3)  # single porcelain fang

    # Emerald rose leaf + 4-step crimson rose on left temple (`y = hy - 11 .. hy - 4`)
    c.poly([(hx - 11 + fx, hy - 6), (hx - 7 + fx, hy - 3), (hx - 6 + fx, hy - 7)], "emerald", bias=0.12)
    c.ellipse(hx - 6 + fx, hy - 7, 4, 4, "crimson", bias=0.24)
    c.dot(hx - 7 + fx, hy - 8, "crimson", 3)


def build_velmira_side(pose: str) -> Image.Image:
    c = HeroCanvas()
    cx = 47
    sway = 0
    leg_l, leg_r = (-4, 79), (5, 79)
    crouch_y = 0

    if pose == "idle_b":
        sway = 1
    elif pose == "walk_a":
        leg_l, leg_r = (-8, 78), (8, 79)
        sway = -2
    elif pose == "walk_b":
        leg_l, leg_r = (-2, 79), (3, 77)
        sway = -1
    elif pose == "cast_windup":
        cx = 45
        leg_l, leg_r = (-6, 79), (6, 79)
        sway = -2
    elif pose == "cast_slash":
        cx = 50
        leg_l, leg_r = (-8, 79), (9, 79)
        sway = -5
    elif pose == "dash_lunge":
        cx = 51
        leg_l, leg_r = (-10, 79), (9, 79)
        sway = -6
    elif pose == "die_kneel":
        cx = 45
        crouch_y = 5
        leg_l, leg_r = (-7, 79), (6, 79)
        sway = 2
    elif pose == "hurt":
        cx = 43
        sway = 3

    hip_y = 52 + crouch_y
    chest_y = 36 + crouch_y
    head_y = 19 + crouch_y

    # 1. Heavy asymmetric moonlit hair cascade behind left/back side (silhouette!)
    _draw_asymmetric_hair_back(c, cx, head_y, sway=sway)

    # 2. Slender legs & tall obsidian-crimson heeled vampire boots (`bottom_y = 80`)
    for side_idx, (lx_off, fy) in enumerate((leg_l, leg_r)):
        hx0 = cx + (-3 if side_idx == 0 else 3)
        kx = cx + int(lx_off * 0.75)
        ky = (hip_y + fy) // 2
        c.limb(hx0, hip_y, kx, ky, 2.8, "moon", bias=0.14)
        c.limb(kx, ky, cx + lx_off, fy - 4, 3.0, "obsidian", bias=0.08)
        bx = cx + lx_off
        c.rrect(bx - 4, fy - 9, bx + 4, fy, 2, "obsidian", bias=0.10)
        c.stroke(bx - 3, fy - 8, bx + 3, fy - 8, "crimson", 2)

    # 3. Narrow gothic shoulders, sharp flared crimson collar, & hourglass obsidian dress!
    # Flared gothic skirt (`y = 50 .. 67`) with crimson ruffled hem kept strictly inside contour
    c.poly(
        [
            (cx - 6, hip_y - 2),
            (cx + 6, hip_y - 2),
            (cx + 12 + sway // 2, hip_y + 14),
            (cx - 10 + sway // 2, hip_y + 14),
        ],
        "obsidian",
        bias=0.08,
    )
    c.stroke(cx - 8 + sway // 2, hip_y + 12, cx + 10 + sway // 2, hip_y + 12, "crimson", 2, width=2)

    # Sharp flared high crimson vampire collar behind neck
    c.poly(
        [(cx - 10, chest_y - 11), (cx + 9, chest_y - 10), (cx + 6, chest_y - 3), (cx - 6, chest_y - 3)],
        "crimson",
        bias=0.16,
    )

    # Narrow-shouldered corset bodice (`width = 13px`)
    c.poly([(cx - 7, chest_y - 6), (cx + 7, chest_y - 6), (cx + 5, hip_y), (cx - 5, hip_y)], "obsidian", bias=0.10)
    c.poly([(cx - 3, chest_y - 5), (cx + 3, chest_y - 5), (cx + 2, hip_y - 1), (cx - 2, hip_y - 1)], "crimson", bias=0.14)
    c.dot(cx + 1, chest_y - 5, "crimson", 3)

    # 4. Vampire Head (`head_y = 19` -> crown/rose at `y = 8`, exact `72px` standing height!)
    _draw_velmira_head(
        c,
        cx + 1,
        head_y,
        blink=(pose in ("blink", "die_kneel")),
        hurt=(pose == "hurt"),
        facing_mode="side",
    )

    # 5. Flared gothic bell-sleeves & crimson-clawed hands (zero floating orbs or baked arcs!)
    if pose in ("idle", "idle_b", "blink", "walk_a", "walk_b"):
        ady = -1 if pose == "idle_b" else (2 if pose == "walk_a" else (-1 if pose == "walk_b" else 0))
        c.poly(
            [
                (cx + 3, chest_y - 4),
                (cx + 14, chest_y + 1 + ady),
                (cx + 13, chest_y + 7 + ady),
                (cx + 3, chest_y + 1),
            ],
            "obsidian",
            bias=0.12,
        )
        c.rrect(cx + 13, chest_y + 1 + ady, cx + 17, chest_y + 5 + ady, 1, "moon", bias=0.30)
        c.dot(cx + 18, chest_y + 3 + ady, "crimson", 3)
    elif pose == "cast_windup":
        c.limb(cx + 4, chest_y - 3, cx - 3, chest_y - 7, 2.4, "obsidian")
        c.stroke(cx - 4, chest_y - 8, cx, chest_y - 10, "crimson", 3, width=2)
    elif pose == "cast_slash":
        c.limb(cx + 5, chest_y - 3, cx + 21, chest_y - 2, 2.5, "obsidian", bias=0.12)
        c.poly([(cx + 20, chest_y - 4), (cx + 27, chest_y - 2), (cx + 21, chest_y + 1)], "crimson", bias=0.28)
    elif pose == "dash_lunge":
        c.limb(cx + 5, chest_y - 3, cx + 18, chest_y - 1, 2.4, "crimson", bias=0.16)
    elif pose == "die_kneel":
        c.limb(cx + 4, chest_y - 1, cx + 10, chest_y + 9, 2.3, "obsidian")
    elif pose == "hurt":
        c.limb(cx + 4, chest_y - 2, cx + 12, chest_y - 5, 2.3, "obsidian")

    exact = 72 if pose == "idle" else None
    return c.finalize(ground_y=GROUND_Y, exact_height=exact)


def build_velmira_vertical(pose: str) -> Image.Image:
    c = HeroCanvas()
    cx = 49
    is_up = pose.startswith("up_")
    step = -1 if pose.endswith("_a") else (1 if pose.endswith("_b") else 0)
    l_fy = 79 - (2 if step > 0 else 0)
    r_fy = 79 - (2 if step < 0 else 0)
    hip_y, chest_y = 52, 36

    if not is_up:
        _draw_asymmetric_hair_back(c, cx, 19, sway=step)

    for side_idx, (lx_off, fy) in enumerate(((-4, l_fy), (4, r_fy))):
        kx = cx + lx_off
        ky = (hip_y + fy) // 2
        c.limb(cx + (-3 if side_idx == 0 else 3), hip_y, kx, ky, 2.8, "moon")
        c.limb(kx, ky, kx, fy - 4, 3.0, "obsidian")
        c.rrect(kx - 4, fy - 9, kx + 4, fy, 2, "obsidian")
        if not is_up:
            c.stroke(kx - 3, fy - 8, kx + 3, fy - 8, "crimson", 2)

    c.poly([(cx - 7, hip_y - 2), (cx + 7, hip_y - 2), (cx + 12, hip_y + 14), (cx - 12, hip_y + 14)], "obsidian")
    c.stroke(cx - 9, hip_y + 12, cx + 9, hip_y + 12, "crimson", 2, width=2)
    c.poly([(cx - 10, chest_y - 11), (cx + 10, chest_y - 11), (cx + 7, chest_y - 3), (cx - 7, chest_y - 3)], "crimson", bias=0.14)
    c.poly([(cx - 7, chest_y - 6), (cx + 7, chest_y - 6), (cx + 5, hip_y), (cx - 5, hip_y)], "obsidian")
    if not is_up:
        c.poly([(cx - 3, chest_y - 5), (cx + 3, chest_y - 5), (cx + 2, hip_y - 1), (cx - 2, hip_y - 1)], "crimson", bias=0.14)

    c.limb(cx - 7, chest_y - 3, cx - 12, chest_y + 5 + step * 2, 2.2, "obsidian")
    c.limb(cx + 7, chest_y - 3, cx + 12, chest_y + 5 - step * 2, 2.2, "obsidian")
    _draw_velmira_head(c, cx, 19, facing_mode="up" if is_up else "down")
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
        fr = build_velmira_vertical(p) if p.startswith(("down_", "up_")) else build_velmira_side(p)
        sheet.alpha_composite(fr, (i * CELL, 0))
    sheet.save("assets/textures/player_velmira.png")
    print("wrote assets/textures/player_velmira.png", sheet.size)

    zoom, pad = 2, 10
    w = pad + len(poses) * (CELL * zoom + pad)
    h = 30 + CELL * zoom + 24
    prev = Image.new("RGBA", (w, h), (22, 16, 26, 255))
    d = ImageDraw.Draw(prev)
    d.text((pad, 8), "VELMIRA (HEROIC PASS) - 16 frames x 96x96", fill=RAMPS["crimson"][3])
    for i, p in enumerate(poses):
        x = pad + i * (CELL * zoom + pad)
        fr = sheet.crop((i * CELL, 0, (i + 1) * CELL, CELL))
        prev.alpha_composite(fr.resize((CELL * zoom, CELL * zoom), Image.NEAREST), (x, 28))
        d.text((x, 28 + CELL * zoom + 4), f"{i}:{p}", fill=RAMPS["moon"][2])
    prev.save("docs/images/velmira_preview.png")


if __name__ == "__main__":
    main()
