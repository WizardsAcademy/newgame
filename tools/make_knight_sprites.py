#!/usr/bin/env python3
"""Generate Knight's 16-frame 96x96 Fallen Knight sheet (`HERO_SKELETON_SPEC.md`).

Bespoke Skeleton #2 — Straight Human Baseline:
  - `body_h = 76` (`crown_y = 4 .. GROUND_Y = 80`), straight vertical spine
  - `head_ratio = 26%` (`crown_y = 4 .. chin_y = 24`)
  - `shoulder_w = 30` (`[26..34]`), `hip_w = 22` (`[16..24]`)
  - Silhouette identity: Zweihander Greatsword breaks the right edge from
    shoulder height upward; tattered crimson cape wedge on the left hip
  - Proportioned armored human legs visibly narrower than torso:
    `leg_mass ~ 310` (`[240..360]`), `stance_w = 16` (`[10..20]`)
"""

from __future__ import annotations

import math
from PIL import Image, ImageDraw
from hero_art_lib import CELL, GROUND_Y, RAMPS, HeroCanvas


def _draw_zweihander(c: HeroCanvas, gx: float, gy: float, angle_deg: float, length: float = 24.0) -> None:
    """Two-handed Zweihander Greatsword with golden crossguard & tapered blade."""
    rad = math.radians(angle_deg)
    dx, dy = math.cos(rad), math.sin(rad)
    px, py = -dy, dx

    c.tapered_limb(gx - dx * 5, gy - dy * 5, 1.4, gx, gy, 1.4, "leather")
    c.dot(int(round(gx - dx * 6)), int(round(gy - dy * 6)), "gold", 3)
    c.tapered_limb(gx - px * 5, gy - py * 5, 1.5, gx + px * 5, gy + py * 5, 1.5, "gold", bias=0.22)

    tip_x = gx + dx * length
    tip_y = gy + dy * length
    b_pts = [
        (gx + dx * 1.5 - px * 2.4, gy + dy * 1.5 - py * 2.4),
        (gx + dx * (length * 0.78) - px * 1.8, gy + dy * (length * 0.78) - py * 1.8),
        (tip_x, tip_y),
        (gx + dx * (length * 0.78) + px * 1.8, gy + dy * (length * 0.78) + py * 1.8),
        (gx + dx * 1.5 + px * 2.4, gy + dy * 1.5 + py * 2.4),
    ]
    c.poly(b_pts, "steel", bias=0.22)
    c.stroke(gx + dx * 4, gy + dy * 4, gx + dx * (length * 0.84), gy + dy * (length * 0.84), "steel", 3)


def _draw_tower_shield(c: HeroCanvas, sx: float, sy: float, hw: float = 6.5) -> None:
    """Scarred Dark-Steel Tower Shield with golden cross."""
    pts = [
        (sx - hw, sy - 11),
        (sx + hw, sy - 11),
        (sx + hw, sy + 4),
        (sx, sy + 12),
        (sx - hw, sy + 4),
    ]
    c.poly(pts, "steel", bias=0.12)
    c.poly(
        [(sx - hw + 2, sy - 8), (sx + hw - 2, sy - 8), (sx + hw - 2, sy + 3), (sx, sy + 9), (sx - hw + 2, sy + 3)],
        "obsidian",
    )
    c.stroke(sx, sy - 6, sx, sy + 5, "gold", 2, width=1)
    c.stroke(sx - 3, sy - 1, sx + 3, sy - 1, "gold", 3, width=1)


def _draw_greathelm(c: HeroCanvas, hx: int, crown_y: int, blink: bool = False, facing_mode: str = "side") -> None:
    """Upright Fallen Greathelm + armored gorget (`crown_y = 4 .. y = 24`, `13px` wide)."""
    # Armored chainmail/plate gorget connecting helm seamlessly to cuirass (`y = crown_y + 16 .. crown_y + 21`)
    c.rrect(hx - 4, crown_y + 16, hx + 4, crown_y + 21, 1, "obsidian", bias=0.05)

    # Crown crest (`y = crown_y .. crown_y + 3`)
    c.rrect(hx - 4, crown_y, hx + 4, crown_y + 4, 1, "steel", bias=0.26)
    # Tall visored helm bucket (`x = hx - 6 .. hx + 6` = `13px` wide, `y = crown_y + 2 .. crown_y + 17`)
    c.rrect(hx - 6, crown_y + 2, hx + 6, crown_y + 17, 2, "steel", bias=0.14)

    if facing_mode == "up":
        c.stroke(hx, crown_y + 4, hx, crown_y + 15, "obsidian", 1, width=2)
        return

    vx = 1 if facing_mode == "side" else 0
    vy = crown_y + 9
    c.stroke(hx - 4 + vx, vy, hx + 4 + vx, vy, "obsidian", 0, width=2)
    c.stroke(hx + vx, vy, hx + vx, vy + 6, "obsidian", 0, width=2)
    if not blink:
        c.dot(hx - 2 + vx, vy, "gold", 3)
        c.dot(hx + 2 + vx, vy, "gold", 3)


def build_knight_side(pose: str) -> Image.Image:
    c = HeroCanvas()
    cx = 49
    crown_y = 4  # exact 80 - 4 = 76px standing height!
    l_leg_x, l_fy = 45, 79
    r_leg_x, r_fy = 53, 79
    cape_flare = 0

    if pose == "walk_a":
        l_leg_x, l_fy = 42, 78
        r_leg_x, r_fy = 54, 79
        cape_flare = 2
        crown_y = 5
    elif pose == "walk_b":
        l_leg_x, l_fy = 45, 79
        r_leg_x, r_fy = 51, 77
        cape_flare = 1
        crown_y = 5
    elif pose == "windup":
        cx = 46
        crown_y = 5
        cape_flare = 2
    elif pose == "sweep":
        cx = 46
        crown_y = 5
        l_leg_x, r_leg_x = 41, 53
        cape_flare = 4
    elif pose == "spin":
        cx = 47
        crown_y = 5
        l_leg_x, r_leg_x = 41, 54
        cape_flare = 5
    elif pose == "guard":
        cx = 46
        crown_y = 5
        l_leg_x, r_leg_x = 42, 53
    elif pose == "charge":
        cx = 49
        crown_y = 6
        l_leg_x, r_leg_x = 41, 56
        cape_flare = 6
    elif pose == "hurt":
        cx = 44
        crown_y = 9
        l_leg_x, r_leg_x = 40, 51

    sh_y = 30
    waist_y = 44
    hip_y = 51

    # 1. Crimson Betrayal Cape Wedge on the LEFT hip (`y = 29..55`, cleanly above `leg_top = 57`)!
    c.poly(
        [
            (cx - 8, sh_y - 1),
            (cx - 2, sh_y),
            (cx - 4, hip_y + 4),
            (cx - 13 - cape_flare, hip_y + 1),  # crisp cape wedge breaking left hip!
            (cx - 11 - cape_flare // 2, waist_y - 4),
        ],
        "crimson",
        bias=0.08,
    )

    # 2. Zweihander Greatsword breaking the RIGHT edge from shoulder height upward!
    if pose in ("idle", "blink", "walk_a", "walk_b"):
        # Rises diagonally from right shoulder/hand `(58, 31)` up-right to `(62, 11)`!
        _draw_zweihander(c, cx + 10, sh_y + 1, angle_deg=-77, length=20.0)
    elif pose == "windup":
        _draw_zweihander(c, cx - 5, sh_y - 2, angle_deg=-145, length=26.0)
    elif pose in ("guard", "charge"):
        _draw_zweihander(c, cx - 4, sh_y + 2, angle_deg=-138, length=24.0)
    elif pose == "hurt":
        _draw_zweihander(c, cx + 8, sh_y + 3, angle_deg=24, length=26.0)

    # 3. Proportioned human armored legs (`y = 53..79`, `leg_mass ~ 310`, `stance_w = 16`),
    #    visibly narrower than his `30px` armored shoulders with clear daylight between greaves!
    for idx, (lx, fy) in enumerate(((l_leg_x, l_fy), (r_leg_x, r_fy))):
        hip_anchor = cx - 4 if idx == 0 else cx + 4
        knee_x = int(round(0.4 * hip_anchor + 0.6 * lx))
        knee_y = 65
        c.tapered_limb(hip_anchor, hip_y + 1, 2.3, knee_x, knee_y, 2.0, "obsidian", bias=-0.04 if idx == 0 else 0.06)
        c.tapered_limb(knee_x, knee_y, 2.1, lx, fy - 3, 1.8, "steel", bias=0.12 if idx == 1 else -0.04)
        c.rrect(knee_x - 2, knee_y - 1, knee_x + 2, knee_y + 1, 1, "steel", bias=0.22)
        # Sabatons (`stance_w = 16` on idle: `41..56`)
        if idx == 0:
            c.rrect(lx - 3, fy - 3, lx + 2, fy, 1, "steel", bias=0.12)
        else:
            c.rrect(lx - 2, fy - 3, lx + 4, fy, 1, "steel", bias=0.18)

    # 4. Sloping human cuirass (`y = 24 -> 30` rounded pauldrons, `shoulder_w = 30`, `hip_w = 22`)
    c.poly(
        [
            (cx - 11, crown_y + 20),  # y = 24 (`chin_y = 24` -> exact `26%` head_ratio!)
            (cx + 11, crown_y + 20),
            (cx + 13, sh_y - 1),
            (cx + 13, sh_y + 2),
            (cx + 9, waist_y),
            (cx + 8, hip_y + 3),
            (cx - 8, hip_y + 3),
            (cx - 9, waist_y),
            (cx - 12, sh_y + 2),
            (cx - 12, sh_y - 1),
        ],
        "steel",
        bias=0.12,
    )
    # Dark surcoat tassets at hips (`y = 45..55`) + betrayal rift scar across breastplate
    c.poly([(cx - 8, waist_y + 1), (cx + 8, waist_y + 1), (cx + 8, hip_y + 4), (cx - 7, hip_y + 4)], "obsidian")
    c.stroke(cx - 4, sh_y - 2, cx + 4, sh_y + 5, "crimson", 3, width=2)
    c.rrect(cx - 9, waist_y - 1, cx + 9, waist_y + 2, 1, "leather")
    c.dot(cx + 1, waist_y, "gold", 3)

    # Rounded layered pauldrons (`x = 35..64` with sword guard = `30px` `shoulder_w`!)
    c.ellipse(cx - 9, sh_y - 1, 4, 4, "steel", bias=0.22)
    c.ellipse(cx + 9, sh_y - 1, 4, 4, "steel", bias=0.08)

    # 5. Upright Visored Greathelm (`crown_y = 4 .. 23`)
    _draw_greathelm(c, cx, crown_y, blink=(pose == "blink"), facing_mode="side")

    # 6. Foreground Gauntlet / Sword Cleave / Tower Shield
    if pose in ("idle", "blink", "walk_a", "walk_b"):
        c.tapered_limb(cx + 6, sh_y + 1, 2.1, cx + 11, sh_y + 1, 1.9, "steel", bias=0.16)
        c.tapered_limb(cx - 8, sh_y + 1, 2.1, cx - 7, waist_y - 1, 1.9, "steel", bias=0.14)
    elif pose == "windup":
        c.tapered_limb(cx - 5, sh_y, 2.1, cx - 7, sh_y - 3, 1.9, "steel")
        _draw_tower_shield(c, cx + 9, sh_y + 8, hw=5.5)
    elif pose == "sweep":
        c.tapered_limb(cx + 6, sh_y, 2.2, cx + 14, sh_y + 1, 2.0, "steel", bias=0.18)
        _draw_zweihander(c, cx + 14, sh_y + 1, angle_deg=-8, length=30.0)
        c.arc_stroke(cx + 12, sh_y + 2, 30, 16, -50, 35, "steel", 3, width=2, selout_wrap=True)
    elif pose == "spin":
        c.tapered_limb(cx + 5, sh_y + 1, 2.2, cx + 13, sh_y + 3, 2.0, "steel", bias=0.18)
        _draw_zweihander(c, cx + 13, sh_y + 3, angle_deg=14, length=29.0)
        c.arc_stroke(cx + 10, sh_y + 3, 30, 14, -25, 65, "crimson", 3, width=2, selout_wrap=True)
    elif pose == "guard":
        _draw_tower_shield(c, cx + 10, sh_y + 8, hw=6.5)
    elif pose == "charge":
        _draw_tower_shield(c, cx + 14, sh_y + 7, hw=6.5)
        c.arc_stroke(cx + 16, sh_y + 7, 10, 12, -55, 55, "gold", 3, width=1, selout_wrap=True)
    elif pose == "hurt":
        c.tapered_limb(cx + 4, sh_y + 1, 2.1, cx + 9, sh_y + 4, 1.9, "steel")

    return c.finalize(ground_y=GROUND_Y)


def build_knight_vertical(pose: str) -> Image.Image:
    c = HeroCanvas()
    cx = 48
    crown_y = 4
    is_up = pose.startswith("up_")
    step = -1 if pose.endswith("_a") else (1 if pose.endswith("_b") else 0)
    l_fy = 79 - (2 if step > 0 else 0)
    r_fy = 79 - (2 if step < 0 else 0)
    sh_y, waist_y, hip_y = 30, 44, 51

    if not is_up:
        c.poly([(cx - 11, sh_y), (cx + 11, sh_y), (cx + 12, hip_y + 4), (cx - 13, hip_y + 3)], "crimson")

    sw_x = cx + 11 if not is_up else cx - 11
    _draw_zweihander(c, sw_x, sh_y, angle_deg=-75 if not is_up else -105, length=21.0)

    for idx, (lx, fy) in enumerate(((cx - 5, l_fy), (cx + 5, r_fy))):
        c.tapered_limb(lx, hip_y + 1, 2.2, lx, 65, 1.9, "obsidian")
        c.tapered_limb(lx, 65, 2.0, lx, fy - 3, 1.8, "steel")
        c.rrect(lx - 3, fy - 3, lx + 3, fy, 1, "steel")

    c.poly(
        [
            (cx - 10, crown_y + 20),
            (cx + 10, crown_y + 20),
            (cx + 14, sh_y + 1),
            (cx + 9, waist_y),
            (cx + 8, hip_y + 3),
            (cx - 8, hip_y + 3),
            (cx - 9, waist_y),
            (cx - 14, sh_y + 1),
        ],
        "steel",
        bias=0.12,
    )
    if is_up:
        c.poly([(cx - 11, sh_y - 2), (cx + 11, sh_y - 2), (cx + 13, hip_y + 5), (cx - 13, hip_y + 5)], "crimson", bias=0.10)
    else:
        c.poly([(cx - 8, waist_y + 1), (cx + 8, waist_y + 1), (cx + 8, hip_y + 4), (cx - 8, hip_y + 4)], "obsidian")
        c.stroke(cx - 4, sh_y - 2, cx + 4, sh_y + 5, "crimson", 3, width=2)
        c.rrect(cx - 9, waist_y - 1, cx + 9, waist_y + 2, 1, "leather")
        _draw_tower_shield(c, cx - 11, sh_y + 8, hw=5.0)

    c.ellipse(cx - 11, sh_y - 1, 4, 4, "steel", bias=0.20)
    c.ellipse(cx + 11, sh_y - 1, 4, 4, "steel", bias=0.08)
    _draw_greathelm(c, cx, crown_y, facing_mode="up" if is_up else "down")
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
    d.text((pad, 8), "KNIGHT (SKELETON SPEC: 76px, 30w shoulders, 300 leg_mass)", fill=RAMPS["gold"][3])
    for i, p in enumerate(poses):
        x = pad + i * (CELL * zoom + pad)
        fr = sheet.crop((i * CELL, 0, (i + 1) * CELL, CELL))
        prev.alpha_composite(fr.resize((CELL * zoom, CELL * zoom), Image.NEAREST), (x, 28))
        d.text((x, 28 + CELL * zoom + 4), f"{i}:{p}", fill=RAMPS["moon"][2])
    prev.save("docs/images/knight_preview.png")


if __name__ == "__main__":
    main()
