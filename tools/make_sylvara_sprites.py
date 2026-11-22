#!/usr/bin/env python3
"""Generate Sylvara's 15-frame 96x96 Blonde Elven Ranger sheet.

Hero Art Contract (Phase 4):
  - 96x96 cells, standing height 72px (top_y=8 .. GROUND_Y=80), ~29% head ratio.
  - Silhouette: narrow, lithe elven ranger; curved Golden-Yew Recurve Bow hoop
    clearly visible with open negative space against the body, and feathered
    arrow quiver breaking the upper-back silhouette line.
  - Palette: 6 ramps x 4 steps = <=24 colours from the shared 32-colour ramp
    (`skin`, `emerald`, `gold`, `leather`, `steel`, `moon`).
  - Top-left 4-step shading + selective selout (zero `#000000`).
"""

from __future__ import annotations

import math
from PIL import Image, ImageDraw
from hero_art_lib import CELL, GROUND_Y, RAMPS, HeroCanvas


def _draw_quiver(c: HeroCanvas, qx: float, qy: float) -> None:
    """Diagonal leather arrow quiver + white fletched arrows breaking back line!"""
    c.limb(qx + 5, qy + 12, qx - 5, qy - 6, 3.2, "leather", bias=0.06)
    # Three silver-fletched arrows jutting above back shoulder
    for off in (-3, 0, 3):
        c.stroke(qx - 4 + off, qy - 6, qx - 8 + off, qy - 13, "leather", 2, width=1)
        c.poly(
            [(qx - 8 + off, qy - 13), (qx - 11 + off, qy - 15), (qx - 6 + off, qy - 15)],
            "moon",
            bias=0.35,
        )


def _draw_recurve_bow(
    c: HeroCanvas,
    bx: float,
    by: float,
    pull_px: float = 0.0,
    charged: bool = False,
) -> None:
    """Curved Golden-Yew Recurve Bow hoop with visible negative space & taut bowstring."""
    # Bow hoop curve (`x` arches forward `bx -> bx + 13`, `y = by - 22 .. by + 22`)
    c.arc_stroke(bx - 1, by, 13, 22, -74, 74, "gold", 2, width=2, selout_wrap=True)
    # Leather grip wrap in center
    c.rrect(bx + 10, by - 4, bx + 14, by + 4, 1, "leather")
    # Recurve tips
    top_x = bx + math.cos(math.radians(-74)) * 13 - 1
    top_y = by + math.sin(math.radians(-74)) * 22
    bot_x = bx + math.cos(math.radians(74)) * 13 - 1
    bot_y = by + math.sin(math.radians(74)) * 22
    c.dot(int(top_x), int(top_y), "gold", 3)
    c.dot(int(bot_x), int(bot_y), "gold", 3)

    # Bowstring (leaves crisp open D-shaped hoop between string and curved yew limb!)
    sx = top_x - pull_px
    c.stroke(top_x, top_y + 1, sx, by, "moon", 2, width=1)
    c.stroke(sx, by, bot_x, bot_y - 1, "moon", 2, width=1)

    if pull_px > 1.0:
        # Nocked emerald arrow shaft + blazing arrowhead!
        tip_x = bx + 18 + (3 if charged else 0)
        c.stroke(sx, by, tip_x, by, "emerald" if charged else "leather", 3 if charged else 2, width=2 if charged else 1)
        c.poly(
            [(tip_x, by - 3), (tip_x + 6, by), (tip_x, by + 3)],
            "emerald" if charged else "steel",
            bias=0.35,
        )
        if charged:
            c.ellipse(tip_x + 2, by, 4, 4, "emerald", bias=0.45, selout=False)


def _draw_sylvara_head(
    c: HeroCanvas,
    hx: int,
    hy: int,
    blink: bool = False,
    hurt: bool = False,
    facing_mode: str = "side",
) -> None:
    """Heroic ~20px elven head (`hy - 10 .. hy + 9`) with pointed ear & golden ponytail."""
    if facing_mode == "side":
        # Lush flowing golden-blonde ponytail streaming back
        c.poly(
            [(hx - 4, hy - 8), (hx - 15, hy - 4), (hx - 19, hy + 9), (hx - 9, hy + 8)],
            "gold",
            bias=0.16,
        )

    # Full golden hair crown
    c.ellipse(hx, hy - 4, 9, 7, "gold", bias=0.22)

    if facing_mode == "up":
        c.poly([(hx - 8, hy - 3), (hx + 8, hy - 3), (hx + 6, hy + 16), (hx, hy + 20), (hx - 6, hy + 16)], "gold", bias=0.16)
        c.poly([(hx - 7, hy - 1), (hx - 13, hy - 3), (hx - 8, hy + 2)], "skin")
        c.poly([(hx + 7, hy - 1), (hx + 13, hy - 3), (hx + 8, hy + 2)], "skin")
        return

    fx = 1 if facing_mode == "side" else 0
    # Lithe elven face (drawn BEFORE side hair & ear so face stays clean & unsplit!)
    c.rrect(hx - 6 + fx, hy - 5, hx + 6 + fx, hy + 7, 3, "skin", bias=0.18)

    # Golden forehead bangs & side temple lock (behind ear, framing face cleanly)
    c.poly([(hx - 7 + fx, hy - 8), (hx + 6 + fx, hy - 8), (hx + 5 + fx, hy - 4), (hx - 6 + fx, hy - 3)], "gold", bias=0.25)
    c.poly([(hx - 7 + fx, hy - 5), (hx - 4 + fx, hy - 5), (hx - 5 + fx, hy + 6), (hx - 8 + fx, hy + 3)], "gold", bias=0.18)

    # Pointed elven ear(s)
    c.poly([(hx - 5 + fx, hy - 1), (hx - 13 + fx, hy - 4), (hx - 6 + fx, hy + 3)], "skin", bias=0.16)
    if facing_mode != "side":
        c.poly([(hx + 5, hy - 1), (hx + 13, hy - 4), (hx + 6, hy + 3)], "skin", bias=0.06)

    # Emerald & gold elven tiara across brow
    c.stroke(hx - 5 + fx, hy - 5, hx + 6 + fx, hy - 5, "gold", 3, width=1)
    c.dot(hx + (3 if facing_mode == "side" else 0), hy - 5, "emerald", 3)

    # Crisp expressive emerald eyes with dark upper lash!
    ex_list = (hx + 1, hx + 5) if facing_mode == "side" else (hx - 3, hx + 3)
    if hurt:
        for ex in ex_list:
            c.stroke(ex - 1, hy - 1, ex + 1, hy + 1, "skin", 0)
    elif blink:
        for ex in ex_list:
            c.stroke(ex - 1, hy + 1, ex + 1, hy + 1, "skin", 0)
    else:
        for ex in ex_list:
            c.stroke(ex - 1, hy - 1, ex + 1, hy - 1, "leather", 0)
            c.dot(ex, hy, "emerald", 1)
            c.dot(ex + 1, hy, "emerald", 3)
            c.dot(ex, hy + 1, "emerald", 2)
            c.dot(ex, hy - 1, "moon", 3)


def build_sylvara_side(pose: str) -> Image.Image:
    c = HeroCanvas()
    cx = 42
    leg_l, leg_r = (-5, 79), (5, 79)

    if pose == "walk_a":
        leg_l, leg_r = (-10, 78), (9, 79)
    elif pose == "walk_b":
        leg_l, leg_r = (-2, 79), (4, 77)
    elif pose in ("bow_draw", "bow_charge", "bow_release"):
        cx = 40
        leg_l, leg_r = (-8, 79), (8, 79)
    elif pose == "wind_vault":
        cx = 44
        # Grounded wind-trail push off `y = 79` (`bottom_y = 80`, zero 11px hop!) while front knee tucks high!
        leg_l, leg_r = (-11, 79), (8, 70)
    elif pose == "hurt":
        cx = 38
        leg_l, leg_r = (-7, 79), (6, 79)

    hip_y = 52
    chest_y = 36

    # 1. Feathered Quiver jutting above back shoulder (silhouette!)
    _draw_quiver(c, cx - 8, chest_y - 4)

    # 2. Flowing forest-emerald ranger half-cloak behind narrow waist
    cloak_sway = -5 if pose == "wind_vault" else (-2 if pose.startswith("walk") else 0)
    c.poly(
        [
            (cx - 6, chest_y - 6),
            (cx + 4, chest_y - 6),
            (cx - 2 + cloak_sway, 66),
            (cx - 13 + cloak_sway, 63),
        ],
        "emerald",
        bias=0.04,
    )

    # 3. Slender agile ranger legs & tall laced leather boots (`bottom_y = 80`)
    for side_idx, (lx_off, fy) in enumerate((leg_l, leg_r)):
        hx0 = cx + (-3 if side_idx == 0 else 3)
        kx = cx + int(lx_off * 0.75)
        ky = (hip_y + fy) // 2
        c.limb(hx0, hip_y, kx, ky, 3.2, "emerald", bias=-0.06 if side_idx == 0 else 0.08)
        c.limb(kx, ky, cx + lx_off, fy - 4, 3.0, "leather", bias=0.08)
        bx = cx + lx_off
        c.rrect(bx - 4, fy - 7, bx + 5, fy, 2, "leather", bias=0.10)
        c.stroke(bx - 2, fy - 6, bx + 3, fy - 6, "gold", 2)

    if pose == "wind_vault":
        # Emerald wind-gust swirl under vaulting rear toe at y = 79
        c.arc_stroke(cx - 4, 75, 14, 4, 15, 165, "emerald", 3, width=1)

    # 4. Narrow tailored emerald tunic & gold-trimmed leather corset
    c.poly([(cx - 7, hip_y - 2), (cx + 8, hip_y - 2), (cx + 10, 61), (cx - 8, 61)], "emerald", bias=0.10)
    c.poly([(cx - 8, chest_y - 7), (cx + 8, chest_y - 7), (cx + 6, hip_y), (cx - 6, hip_y)], "emerald", bias=0.12)
    c.poly([(cx - 6, chest_y - 2), (cx + 6, chest_y - 2), (cx + 5, hip_y), (cx - 5, hip_y)], "leather", bias=0.08)
    c.rrect(cx - 7, hip_y - 2, cx + 7, hip_y + 1, 1, "gold", bias=0.20)

    # 5. Elven Head (`hy = 19` -> crown/quiver at `y = 8`, exact `72px` standing height!)
    _draw_sylvara_head(
        c,
        cx + 1,
        19,
        blink=(pose == "blink"),
        hurt=(pose == "hurt"),
        facing_mode="side",
    )

    # 6. Extended Bow Arm + Curved Golden-Yew Recurve Bow Hoop (unmistakable silhouette!)
    if pose in ("idle", "blink", "walk_a", "walk_b"):
        # Holds Recurve Bow out at ready (`cx + 16`), leaving crisp open space in bow hoop!
        c.limb(cx + 5, chest_y - 2, cx + 16, chest_y + 3, 2.5, "skin", bias=0.12)
        c.limb(cx - 5, chest_y - 1, cx + 2, chest_y + 5, 2.5, "emerald")
        _draw_recurve_bow(c, cx + 12, chest_y + 5, pull_px=0.0)
    elif pose == "bow_draw":
        c.limb(cx + 5, chest_y - 3, cx + 19, chest_y - 2, 2.5, "skin", bias=0.14)
        c.limb(cx - 4, chest_y - 3, cx + 6, chest_y - 2, 2.5, "emerald")
        _draw_recurve_bow(c, cx + 14, chest_y - 1, pull_px=7.0, charged=False)
    elif pose == "bow_charge":
        c.limb(cx + 5, chest_y - 3, cx + 20, chest_y - 2, 2.5, "skin", bias=0.14)
        c.limb(cx - 5, chest_y - 3, cx + 2, chest_y - 3, 2.5, "emerald")
        _draw_recurve_bow(c, cx + 15, chest_y - 1, pull_px=13.0, charged=True)
    elif pose == "bow_release":
        c.limb(cx + 5, chest_y - 3, cx + 20, chest_y - 2, 2.5, "skin", bias=0.14)
        c.limb(cx - 5, chest_y - 3, cx - 11, chest_y - 5, 2.5, "emerald")
        _draw_recurve_bow(c, cx + 15, chest_y - 1, pull_px=0.0, charged=False)
        c.stroke(cx + 28, chest_y - 1, cx + 42, chest_y - 1, "emerald", 3, width=1)
    elif pose == "wind_vault":
        c.limb(cx + 5, chest_y - 2, cx + 17, chest_y + 1, 2.5, "skin")
        _draw_recurve_bow(c, cx + 13, chest_y + 2, pull_px=0.0)
    elif pose == "hurt":
        c.limb(cx + 4, chest_y, cx + 13, chest_y + 5, 2.5, "skin")
        _draw_recurve_bow(c, cx + 10, chest_y + 6, pull_px=0.0)

    exact = 72 if pose == "idle" else None
    return c.finalize(ground_y=GROUND_Y, exact_height=exact)


def build_sylvara_vertical(pose: str) -> Image.Image:
    c = HeroCanvas()
    cx = 48
    is_up = pose.startswith("up_")
    step = -1 if pose.endswith("_a") else (1 if pose.endswith("_b") else 0)
    l_fy = 79 - (2 if step > 0 else 0)
    r_fy = 79 - (2 if step < 0 else 0)
    hip_y, chest_y = 52, 36

    if not is_up:
        _draw_quiver(c, cx - 8, chest_y - 4)
        c.poly([(cx - 9, chest_y - 6), (cx + 9, chest_y - 6), (cx + 11, 65), (cx - 11, 65)], "emerald")

    for side_idx, (lx_off, fy) in enumerate(((-5, l_fy), (5, r_fy))):
        kx = cx + lx_off
        ky = (hip_y + fy) // 2
        c.limb(cx + (-3 if side_idx == 0 else 3), hip_y, kx, ky, 3.2, "emerald")
        c.limb(kx, ky, kx, fy - 4, 3.0, "leather")
        c.rrect(kx - 4, fy - 7, kx + 4, fy, 2, "leather")

    if is_up:
        c.poly([(cx - 9, chest_y - 6), (cx + 9, chest_y - 6), (cx + 12, 66), (cx - 12, 66)], "emerald", bias=0.08)
        _draw_quiver(c, cx + 6, chest_y - 2)
    else:
        c.poly([(cx - 8, chest_y - 7), (cx + 8, chest_y - 7), (cx + 6, hip_y + 1), (cx - 6, hip_y + 1)], "emerald", bias=0.12)
        c.poly([(cx - 5, chest_y - 2), (cx + 5, chest_y - 2), (cx + 4, hip_y), (cx - 4, hip_y)], "leather")
        c.rrect(cx - 7, hip_y - 2, cx + 7, hip_y + 1, 1, "gold")

    # Held Recurve Bow visible out to side even in front/back walk
    bow_side = cx + 11 if not is_up else cx - 22
    _draw_recurve_bow(c, bow_side, chest_y + 5, pull_px=0.0)
    c.limb(cx - 8, chest_y - 2, cx - 12, chest_y + 6 + step * 2, 2.5, "emerald")
    c.limb(cx + 8, chest_y - 2, cx + 13, chest_y + 5 - step * 2, 2.5, "skin")

    _draw_sylvara_head(c, cx, 19, facing_mode="up" if is_up else "down")
    return c.finalize(ground_y=GROUND_Y)


def main() -> None:
    poses = [
        "idle", "walk_a", "walk_b", "bow_draw", "bow_charge", "bow_release", "wind_vault", "hurt", "blink",
        "down_idle", "down_walk_a", "down_walk_b", "up_idle", "up_walk_a", "up_walk_b",
    ]
    sheet = Image.new("RGBA", (CELL * len(poses), CELL), (0, 0, 0, 0))
    for i, p in enumerate(poses):
        fr = build_sylvara_vertical(p) if p.startswith(("down_", "up_")) else build_sylvara_side(p)
        sheet.alpha_composite(fr, (i * CELL, 0))
    sheet.save("assets/textures/player_sylvara.png")
    print("wrote assets/textures/player_sylvara.png", sheet.size)

    zoom, pad = 2, 10
    w = pad + len(poses) * (CELL * zoom + pad)
    h = 30 + CELL * zoom + 24
    prev = Image.new("RGBA", (w, h), (16, 26, 20, 255))
    d = ImageDraw.Draw(prev)
    d.text((pad, 8), "SYLVARA (HEROIC PASS) - 15 frames x 96x96", fill=RAMPS["emerald"][3])
    for i, p in enumerate(poses):
        x = pad + i * (CELL * zoom + pad)
        fr = sheet.crop((i * CELL, 0, (i + 1) * CELL, CELL))
        prev.alpha_composite(fr.resize((CELL * zoom, CELL * zoom), Image.NEAREST), (x, 28))
        d.text((x, 28 + CELL * zoom + 4), f"{i}:{p}", fill=RAMPS["gold"][3])
    prev.save("docs/images/sylvara_preview.png")


if __name__ == "__main__":
    main()
