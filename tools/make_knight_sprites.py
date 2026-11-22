#!/usr/bin/env python3
"""Generate Knight's 16-frame 96x96 Fallen Knight sprite sheet.

Hero Art Contract (Phase 4):
  - 96x96 cells, standing height 72px (top_y=8 .. GROUND_Y=80), ~29% head ratio.
  - Silhouette: tall, upright plated warrior; colossal Zweihander Greatsword
    resting diagonally on the shoulder, scarred Tower Shield, and sweeping
    tattered crimson cape wedge behind.
  - Palette: 5 ramps x 4 steps = <=20 colours from the shared 32-colour ramp
    (`steel`, `obsidian`, `crimson`, `leather`, `gold`).
  - Top-left 4-step shading + selective selout (zero `#000000`).
"""

from __future__ import annotations

import math
from PIL import Image, ImageDraw
from hero_art_lib import CELL, GROUND_Y, RAMPS, HeroCanvas


def _draw_zweihander(c: HeroCanvas, gx: float, gy: float, angle_deg: float, length: float = 38.0) -> None:
    """Colossal two-handed Zweihander Greatsword with crossguard & fuller."""
    rad = math.radians(angle_deg)
    dx, dy = math.cos(rad), math.sin(rad)
    px, py = -dy, dx

    # Leather grip + gold pommel behind hand
    c.limb(gx - dx * 7, gy - dy * 7, gx, gy, 2.0, "leather")
    c.ellipse(gx - dx * 8, gy - dy * 8, 2.5, 2.5, "gold", bias=0.25)

    # Wide steel & gold crossguard
    c.limb(gx - px * 7, gy - py * 7, gx + px * 7, gy + py * 7, 2.2, "gold", bias=0.20)

    # Broad tapered steel blade
    tip_x = gx + dx * length
    tip_y = gy + dy * length
    b_pts = [
        (gx + dx * 2 - px * 3.5, gy + dy * 2 - py * 3.5),
        (gx + dx * (length * 0.78) - px * 2.8, gy + dy * (length * 0.78) - py * 2.8),
        (tip_x, tip_y),
        (gx + dx * (length * 0.78) + px * 2.8, gy + dy * (length * 0.78) + py * 2.8),
        (gx + dx * 2 + px * 3.5, gy + dy * 2 + py * 3.5),
    ]
    c.poly(b_pts, "steel", bias=0.20)
    # Bright blade fuller gleam along top-left edge
    c.stroke(gx + dx * 5, gy + dy * 5, gx + dx * (length * 0.85), gy + dy * (length * 0.85), "steel", 3)


def _draw_tower_shield(c: HeroCanvas, sx: float, sy: float, wide: bool = True) -> None:
    """Scarred Dark-Steel Tower Shield with gold crest."""
    hw = 9 if wide else 6
    pts = [
        (sx - hw, sy - 13),
        (sx + hw, sy - 13),
        (sx + hw, sy + 5),
        (sx, sy + 14),
        (sx - hw, sy + 5),
    ]
    c.poly(pts, "steel", bias=0.10)
    c.poly(
        [(sx - hw + 3, sy - 10), (sx + hw - 3, sy - 10), (sx + hw - 3, sy + 3), (sx, sy + 10), (sx - hw + 3, sy + 3)],
        "obsidian",
        bias=-0.05,
    )
    # Gold cross emblem + battle scar
    c.stroke(sx, sy - 7, sx, sy + 6, "gold", 2, width=2)
    c.stroke(sx - 4, sy - 2, sx + 4, sy - 2, "gold", 3, width=1)


def _draw_greathelm(c: HeroCanvas, hx: int, hy: int, blink: bool = False, facing_mode: str = "side") -> None:
    """Upright horned/crowned Fallen Greathelm (`hy - 11 .. hy + 9`, ~20px = 28% of 72px)."""
    # Swept side-crest wings on helmet
    c.poly([(hx - 7, hy - 5), (hx - 11, hy - 11), (hx - 3, hy - 8)], "steel", bias=0.22)
    if facing_mode != "side":
        c.poly([(hx + 7, hy - 5), (hx + 11, hy - 11), (hx + 3, hy - 8)], "steel", bias=0.14)
    else:
        c.poly([(hx + 3, hy - 8), (hx + 6, hy - 11), (hx + 7, hy - 5)], "steel", bias=0.18)

    # Helmet bucket
    c.rrect(hx - 8, hy - 9, hx + 8, hy + 8, 3, "steel", bias=0.12)

    if facing_mode == "up":
        c.stroke(hx, hy - 7, hx, hy + 5, "obsidian", 1, width=2)
        return

    vx = 2 if facing_mode == "side" else 0
    # T-visor dark slit
    c.stroke(hx - 4 + vx, hy - 1, hx + 5 + vx, hy - 1, "obsidian", 0, width=2)
    c.stroke(hx + 1 + vx, hy - 1, hx + 1 + vx, hy + 6, "obsidian", 0, width=2)
    if not blink:
        # Glowing golden-ember fallen knight visor slit!
        c.dot(hx - 2 + vx, hy - 1, "gold", 3)
        c.dot(hx + 3 + vx, hy - 1, "gold", 3)


def build_knight_side(pose: str) -> Image.Image:
    c = HeroCanvas()
    cx = 46
    leg_l, leg_r = (-7, 79), (7, 79)
    cape_flare = 0

    if pose == "walk_a":
        leg_l, leg_r = (-11, 78), (10, 79)
        cape_flare = 3
    elif pose == "walk_b":
        leg_l, leg_r = (-3, 79), (4, 78)
        cape_flare = 1
    elif pose == "windup":
        cx = 44
        cape_flare = 2
    elif pose == "sweep":
        cx = 45
        leg_l, leg_r = (-10, 79), (11, 79)
        cape_flare = 6
    elif pose == "spin":
        cx = 46
        leg_l, leg_r = (-11, 79), (11, 79)
        cape_flare = 8
    elif pose == "guard":
        cx = 43
        leg_l, leg_r = (-9, 79), (9, 79)
    elif pose == "charge":
        cx = 48
        leg_l, leg_r = (-13, 79), (11, 79)
        cape_flare = 9
    elif pose == "hurt":
        cx = 40
        cape_flare = -3

    hip_y = 52
    chest_y = 36

    # 1. Sweeping tattered crimson betrayal cape wedge behind Knight (silhouette!)
    cape_pts = [
        (cx - 6, chest_y - 8),
        (cx + 4, chest_y - 6),
        (cx - 4 - cape_flare // 2, 74),
        (cx - 14 - cape_flare, 71),
        (cx - 22 - cape_flare, 64),
        (cx - 16 - cape_flare // 2, 46),
    ]
    c.poly(cape_pts, "crimson", bias=0.04)

    # 2. Shoulder-resting Zweihander on idle/walk: hilt held in front gauntlet,
    #    colossal 44px steel blade jutting diagonally UP-BACK past helmet (silhouette!)
    if pose in ("idle", "blink", "walk_a", "walk_b"):
        _draw_zweihander(c, cx + 11, chest_y + 1, angle_deg=-144, length=46.0)
    elif pose == "windup":
        _draw_zweihander(c, cx + 4, chest_y - 2, angle_deg=-154, length=44.0)
    elif pose in ("guard", "charge"):
        _draw_zweihander(c, cx - 2, chest_y + 2, angle_deg=-148, length=40.0)
    elif pose == "hurt":
        _draw_zweihander(c, cx + 8, chest_y + 2, angle_deg=22, length=36.0)

    # 3. Tall armored greaves & sabatons (`bottom_y = 80`)
    for side_idx, (lx_off, fy) in enumerate((leg_l, leg_r)):
        hx0 = cx + (-4 if side_idx == 0 else 4)
        kx = cx + int(lx_off * 0.8)
        ky = (hip_y + fy) // 2
        c.limb(hx0, hip_y, kx, ky, 4.5, "obsidian")
        c.limb(kx, ky, cx + lx_off, fy - 4, 4.2, "steel", bias=0.08 if side_idx == 1 else -0.06)
        c.ellipse(kx + 1, ky, 4, 3, "steel", bias=0.22)
        bx = cx + lx_off
        c.rrect(bx - 5, fy - 6, bx + 7, fy, 2, "steel", bias=0.14)

    # 4. Upright plated cuirass + tattered dark surcoat + crimson betrayal rift
    c.poly([(cx - 9, hip_y - 2), (cx + 9, hip_y - 2), (cx + 11, 64), (cx - 10, 64)], "obsidian")
    c.poly([(cx - 13, chest_y - 8), (cx + 13, chest_y - 8), (cx + 9, hip_y + 1), (cx - 9, hip_y + 1)], "steel", bias=0.12)
    # Glowing crimson-gold betrayal crack across breastplate
    c.stroke(cx - 4, chest_y - 3, cx + 5, chest_y + 4, "crimson", 3, width=2)
    c.dot(cx + 1, chest_y, "gold", 3)
    c.rrect(cx - 10, hip_y - 2, cx + 10, hip_y + 2, 1, "leather")
    c.dot(cx + 2, hip_y, "gold", 3)

    # Layered steel pauldrons
    c.ellipse(cx - 11, chest_y - 5, 6, 5, "steel", bias=0.22)
    c.ellipse(cx + 10, chest_y - 4, 6, 5, "steel", bias=0.08)

    # 5. Upright Visored Greathelm (`hy = 19` -> horns at `y = 8`, exact `72px` standing height!)
    _draw_greathelm(c, cx + 1, 19, blink=(pose == "blink"), facing_mode="side")

    # 6. Foreground Sword Cleave OR Raised Tower Shield!
    if pose in ("idle", "blink", "walk_a", "walk_b"):
        # Gauntlet gripping Zweihander hilt in front + scarred Tower Shield slung on flank
        c.limb(cx + 5, chest_y + 1, cx + 12, chest_y + 1, 3.6, "steel", bias=0.16)
        _draw_tower_shield(c, cx - 5, chest_y + 11, wide=False)
    elif pose == "windup":
        c.limb(cx - 4, chest_y - 2, cx - 6, chest_y - 6, 3.5, "steel")
        _draw_tower_shield(c, cx + 10, chest_y + 8, wide=False)
    elif pose == "sweep":
        # Colossal horizontal greatsword cleave + steel-crimson slash arc!
        c.limb(cx + 6, chest_y - 1, cx + 14, chest_y, 3.8, "steel", bias=0.18)
        _draw_zweihander(c, cx + 14, chest_y, angle_deg=-8, length=34.0)
        c.arc_stroke(cx + 12, chest_y + 2, 34, 18, -55, 35, "steel", 3, width=2, selout_wrap=True)
    elif pose == "spin":
        # Full rotational follow-through spin cleave!
        c.limb(cx + 6, chest_y, cx + 15, chest_y + 3, 3.8, "steel", bias=0.18)
        _draw_zweihander(c, cx + 15, chest_y + 3, angle_deg=18, length=33.0)
        c.arc_stroke(cx + 10, chest_y + 2, 35, 20, -25, 65, "crimson", 3, width=2, selout_wrap=True)
    elif pose == "guard":
        # Scarred Tower Shield locked upright in front (`RMB / E`)!
        _draw_tower_shield(c, cx + 14, chest_y + 6, wide=True)
    elif pose == "charge":
        # Shield-Wall Shift Ram!
        _draw_tower_shield(c, cx + 17, chest_y + 6, wide=True)
        c.stroke(cx + 27, chest_y - 4, cx + 31, chest_y + 12, "gold", 3, width=1)

    exact = 72 if pose == "idle" else None
    return c.finalize(ground_y=GROUND_Y, exact_height=exact)


def build_knight_vertical(pose: str) -> Image.Image:
    c = HeroCanvas()
    cx = 48
    is_up = pose.startswith("up_")
    step = -1 if pose.endswith("_a") else (1 if pose.endswith("_b") else 0)
    l_fy = 79 - (2 if step > 0 else 0)
    r_fy = 79 - (2 if step < 0 else 0)
    hip_y, chest_y = 52, 36

    if not is_up:
        c.poly([(cx - 13, chest_y - 6), (cx + 13, chest_y - 6), (cx + 16, 73), (cx - 16, 73)], "crimson")

    _draw_zweihander(c, cx + (10 if not is_up else -10), chest_y - 2, angle_deg=-120 if not is_up else -60, length=32.0)

    for side_idx, (lx_off, fy) in enumerate(((-7, l_fy), (7, r_fy))):
        kx = cx + lx_off
        ky = (hip_y + fy) // 2
        c.limb(cx + (-4 if side_idx == 0 else 4), hip_y, kx, ky, 4.2, "obsidian")
        c.limb(kx, ky, kx, fy - 4, 4.0, "steel")
        c.rrect(kx - 5, fy - 6, kx + 5, fy, 2, "steel")

    if is_up:
        c.poly([(cx - 13, chest_y - 7), (cx + 13, chest_y - 7), (cx + 17, 73), (cx - 17, 73)], "crimson", bias=0.06)
    else:
        c.poly([(cx - 13, chest_y - 8), (cx + 13, chest_y - 8), (cx + 9, hip_y + 2), (cx - 9, hip_y + 2)], "steel", bias=0.12)
        c.stroke(cx - 4, chest_y - 3, cx + 4, chest_y + 4, "crimson", 3, width=2)
        _draw_tower_shield(c, cx - 12, chest_y + 9, wide=False)

    c.ellipse(cx - 12, chest_y - 5, 5, 5, "steel", bias=0.20)
    c.ellipse(cx + 12, chest_y - 5, 5, 5, "steel", bias=0.08)
    _draw_greathelm(c, cx, 19, facing_mode="up" if is_up else "down")
    return c.finalize(ground_y=GROUND_Y)


def main() -> None:
    poses = [
        "idle", "walk_a", "walk_b", "windup", "sweep", "spin", "guard", "charge", "hurt", "blink",
        "down_idle", "down_walk_a", "down_walk_b", "up_idle", "up_walk_a", "up_walk_b",
    ]
    sheet = Image.new("RGBA", (CELL * len(poses), CELL), (0, 0, 0, 0))
    for i, p in enumerate(poses):
        fr = build_knight_vertical(p) if p.startswith(("down_", "up_")) else build_knight_side(p)
        sheet.alpha_composite(fr, (i * CELL, 0))
    sheet.save("assets/textures/player_knight.png")
    print("wrote assets/textures/player_knight.png", sheet.size)

    zoom, pad = 2, 10
    w = pad + len(poses) * (CELL * zoom + pad)
    h = 30 + CELL * zoom + 24
    prev = Image.new("RGBA", (w, h), (18, 20, 28, 255))
    d = ImageDraw.Draw(prev)
    d.text((pad, 8), "KNIGHT (HEROIC PASS) - 16 frames x 96x96", fill=RAMPS["steel"][3])
    for i, p in enumerate(poses):
        x = pad + i * (CELL * zoom + pad)
        fr = sheet.crop((i * CELL, 0, (i + 1) * CELL, CELL))
        prev.alpha_composite(fr.resize((CELL * zoom, CELL * zoom), Image.NEAREST), (x, 28))
        d.text((x, 28 + CELL * zoom + 4), f"{i}:{p}", fill=RAMPS["steel"][2])
    prev.save("docs/images/knight_preview.png")


if __name__ == "__main__":
    main()
