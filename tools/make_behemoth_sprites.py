#!/usr/bin/env python3
"""Generate Behemoth's 16-frame 96x96 Medieval Pit-Champion Brawler sheet.

Hero Art Contract (Phase 4):
  - 96x96 cells, standing height 72px (top_y=8 .. GROUND_Y=80), ~29% head ratio.
  - Silhouette: broad, hunched pit-champion; shoulders much wider than hips,
    spiked iron left pauldron, crimson headband tail, massive iron cestus fists
    held forward in guard.
  - Palette: 6 ramps x 4 steps = <=24 colours from the shared 32-colour ramp
    (`skin`, `leather`, `steel`, `gold`, `crimson`, `obsidian`).
  - Top-left 4-step shading + selective selout (zero `#000000`).
"""

from __future__ import annotations

from PIL import Image, ImageDraw
from hero_art_lib import CELL, GROUND_Y, RAMPS, HeroCanvas


def _draw_cestus(c: HeroCanvas, fx: float, fy: float, rx: float = 7.0, ry: float = 6.0, spike_dir: int = 1) -> None:
    """Heavy riveted Iron Cestus gauntlet with brass studs & knuckle spikes."""
    c.rrect(fx - rx, fy - ry, fx + rx, fy + ry, 3, "steel", bias=0.06)
    # Leather wrist wrap behind fist
    wx0 = fx - rx - 3 if spike_dir >= 0 else fx + rx - 2
    wx1 = fx - rx + 2 if spike_dir >= 0 else fx + rx + 3
    c.rrect(wx0, fy - ry + 1, wx1, fy + ry - 1, 2, "leather")
    # Knuckle spikes
    sx = fx + rx if spike_dir >= 0 else fx - rx
    for sy in (-3, 0, 3):
        c.poly(
            [(sx, fy + sy - 1), (sx + 3 * spike_dir, fy + sy), (sx, fy + sy + 1)],
            "steel",
            bias=0.25,
        )
    # Brass knuckle rivet gleam
    c.dot(int(fx - 1), int(fy - 2), "gold", 3)
    c.dot(int(fx + 2 * spike_dir), int(fy - 2), "steel", 3)


def _draw_behemoth_head(
    c: HeroCanvas,
    hx: int,
    hy: int,
    blink: bool = False,
    hurt: bool = False,
    facing_mode: str = "side",
) -> None:
    """Heroic ~20px head (`hy - 10 .. hy + 10`) with crimson headband & braided beard."""
    if facing_mode == "side":
        # Fluttering crimson headband tails behind skull (breaks back-head silhouette)
        c.poly([(hx - 7, hy - 5), (hx - 20, hy - 9), (hx - 17, hy - 3)], "crimson", bias=0.05)
        c.poly([(hx - 7, hy - 3), (hx - 18, hy + 2), (hx - 13, hy + 5)], "crimson", bias=-0.10)

    # Skull & dark hair dome
    c.ellipse(hx, hy - 2, 8, 8, "leather", bias=-0.12)

    if facing_mode == "up":
        c.rrect(hx - 8, hy - 6, hx + 8, hy - 3, 1, "crimson", bias=0.10)
        c.poly([(hx - 3, hy - 4), (hx - 9, hy + 4), (hx - 5, hy + 6)], "crimson")
        c.poly([(hx + 3, hy - 4), (hx + 9, hy + 3), (hx + 5, hy + 5)], "crimson")
        return

    # Broad jaw & brow face
    fx_off = 2 if facing_mode == "side" else 0
    c.rrect(hx - 7 + fx_off, hy - 5, hx + 7 + fx_off, hy + 7, 3, "skin", bias=0.08)

    # Crimson pit-champion headband across brow
    c.rrect(hx - 8 + fx_off // 2, hy - 7, hx + 8 + fx_off, hy - 4, 1, "crimson", bias=0.12)
    c.dot(hx + 2 + fx_off, hy - 6, "gold", 3)

    # Thick braided dark beard along jaw (`hy + 3 .. hy + 10`)
    c.poly(
        [
            (hx - 6 + fx_off, hy + 2),
            (hx + 7 + fx_off, hy + 2),
            (hx + 5 + fx_off, hy + 10),
            (hx - 3 + fx_off, hy + 10),
        ],
        "leather",
        bias=-0.18,
    )
    c.dot(hx + 2 + fx_off, hy + 9, "gold", 2)  # beard ring

    # Eyes (identity!)
    if facing_mode == "side":
        ex1, ex2 = hx + 1, hx + 6
    else:
        ex1, ex2 = hx - 4, hx + 3

    if hurt:
        c.stroke(ex1 - 1, hy - 1, ex1 + 1, hy + 1, "skin", 0)
        c.stroke(ex2 - 1, hy + 1, ex2 + 1, hy - 1, "skin", 0)
    elif blink:
        c.stroke(ex1 - 1, hy, ex1 + 1, hy, "skin", 0)
        c.stroke(ex2 - 1, hy, ex2 + 1, hy, "skin", 0)
    else:
        for ex in (ex1, ex2):
            c.stroke(ex - 1, hy - 2, ex + 1, hy - 2, "leather", 0)  # strong dark brow ridge
            c.dot(ex, hy - 1, "obsidian", 0)
            c.dot(ex, hy, "obsidian", 0)
            c.dot(ex + 1, hy - 1, "gold", 3)  # fierce amber-gold pit-fighter eye glint!
            c.dot(ex + 1, hy, "skin", 3)


def build_behemoth_side(pose: str) -> Image.Image:
    c = HeroCanvas()
    # Grounded at y = 79 (`bottom_y = 80`), head crown at y = 8 (`body_h = 72`).
    cx = 42
    hunch_y = 0
    leg_l = (-9, 79)
    leg_r = (9, 79)

    if pose == "walk_a":
        leg_l, leg_r = (-13, 78), (12, 79)
        hunch_y = -1
    elif pose == "walk_b":
        leg_l, leg_r = (-4, 79), (5, 77)
        hunch_y = -1
    elif pose == "windup":
        cx = 37
        leg_l, leg_r = (-11, 79), (11, 79)
    elif pose == "jab":
        cx = 44
        leg_l, leg_r = (-12, 79), (12, 79)
    elif pose == "cross":
        cx = 46
        leg_l, leg_r = (-14, 79), (13, 79)
    elif pose == "uppercut":
        cx = 44
        leg_l, leg_r = (-10, 79), (11, 72)  # rear pivot boot planted at y=79, lead knee drives up!
        hunch_y = -2
    elif pose == "charge":
        cx = 48
        hunch_y = 2
        leg_l, leg_r = (-15, 79), (12, 79)
    elif pose == "hurt":
        cx = 36
        hunch_y = 1
        leg_l, leg_r = (-10, 79), (9, 79)

    hip_y = 53 + hunch_y
    chest_y = 37 + hunch_y

    # 1. Rear arm (when behind torso)
    if pose in ("idle", "blink", "walk_a", "walk_b"):
        ry_off = -2 if pose == "walk_a" else (1 if pose == "walk_b" else 0)
        c.limb(cx + 8, chest_y - 1, cx + 17, chest_y + 6 + ry_off, 4.5, "skin")
        _draw_cestus(c, cx + 24, chest_y + 5 + ry_off, rx=6.5, ry=5.5)
    elif pose == "windup":
        # Coiled far behind back!
        c.limb(cx - 8, chest_y, cx - 20, chest_y + 4, 5.0, "skin")
        _draw_cestus(c, cx - 24, chest_y + 5, rx=6.5, ry=5.5, spike_dir=-1)

    # 2. Muscular wide-planted legs & iron-capped pit boots (`bottom_y = 80`)
    for side_idx, (lx_off, foot_y) in enumerate((leg_l, leg_r)):
        hip_x = cx + (-5 if side_idx == 0 else 5)
        knee_x = cx + int(lx_off * 0.75)
        knee_y = (hip_y + foot_y) // 2 - 1
        c.limb(hip_x, hip_y, knee_x, knee_y, 5.0, "obsidian", bias=-0.10 if side_idx == 0 else 0.08)
        c.limb(knee_x, knee_y, cx + lx_off, foot_y - 5, 4.2, "leather")
        # Iron knee pad
        c.ellipse(knee_x + 1, knee_y, 4, 3, "steel", bias=0.12)
        # Grounded heavy boot (`foot_y` = 79 -> `bottom_y = 80`)
        bx = cx + lx_off
        c.rrect(bx - 6, foot_y - 7, bx + 7, foot_y, 2, "leather", bias=0.05)
        c.rrect(bx + 1, foot_y - 4, bx + 7, foot_y, 1, "steel", bias=0.15)

    # 3. Broad V-taper hunched brigandine torso (shoulders much wider than hips!)
    torso_pts = [
        (cx - 17, chest_y - 8),   # broad left shoulder
        (cx + 16, chest_y - 7),   # broad right shoulder
        (cx + 11, hip_y + 1),     # narrow right waist
        (cx - 11, hip_y + 1),     # narrow left waist
    ]
    c.poly(torso_pts, "leather", bias=0.06)
    # Brigandine steel chest plates & brass rivets
    c.poly(
        [(cx - 12, chest_y - 5), (cx + 12, chest_y - 5), (cx + 9, chest_y + 6), (cx - 9, chest_y + 6)],
        "steel",
        bias=-0.05,
    )
    for rx_off in (-6, 0, 6):
        c.dot(cx + rx_off, chest_y - 2, "gold", 3)
        c.dot(cx + rx_off, chest_y + 3, "gold", 2)

    # Crimson pit-champion sash & heavy brass championship belt (`y ~ 50..56`)
    c.rrect(cx - 12, hip_y - 3, cx + 12, hip_y + 3, 2, "crimson", bias=0.08)
    c.ellipse(cx + 3, hip_y, 5, 4, "gold", bias=0.22)
    c.poly([(cx - 6, hip_y + 2), (cx - 2, hip_y + 2), (cx - 4, hip_y + 11), (cx - 9, hip_y + 10)], "crimson")

    # 4. Massive asymmetric spiked iron left pauldron (silhouette anchor!)
    px_off = 8 if pose == "charge" else -13
    py_off = chest_y - 5
    c.ellipse(cx + px_off, py_off, 9, 7, "steel", bias=0.18)
    # Two iron spikes on pauldron
    c.poly([(cx + px_off - 5, py_off - 5), (cx + px_off - 9, py_off - 12), (cx + px_off - 1, py_off - 7)], "steel", bias=0.25)
    c.poly([(cx + px_off + 1, py_off - 6), (cx + px_off + 1, py_off - 13), (cx + px_off + 5, py_off - 6)], "steel", bias=0.30)

    # 5. Head (`hy = 18` -> crown/headband at `y = 8..10`, ~29% of 72px!)
    head_x = cx + (5 if pose == "charge" else 3)
    head_y = 19 + hunch_y
    _draw_behemoth_head(
        c,
        head_x,
        head_y,
        blink=(pose == "blink"),
        hurt=(pose == "hurt"),
        facing_mode="side",
    )

    # 6. Lead / Punching foreground arm & massive Iron Cestus!
    if pose in ("idle", "blink", "walk_a", "walk_b"):
        ly_off = 2 if pose == "walk_a" else (-2 if pose == "walk_b" else 0)
        c.limb(cx - 6, chest_y + 1, cx + 8, chest_y + 9 + ly_off, 5.0, "skin", bias=0.10)
        _draw_cestus(c, cx + 16, chest_y + 6 + ly_off, rx=7.5, ry=6.0)
    elif pose == "windup":
        # Guard lead fist up by chin while rear fist coils
        c.limb(cx + 6, chest_y, cx + 15, chest_y - 2, 4.5, "skin")
        _draw_cestus(c, cx + 19, chest_y - 4, rx=6.5, ry=5.5)
    elif pose == "jab":
        # Snapping straight lead Jab far forward (`x` up to 88)!
        c.limb(cx + 6, chest_y - 1, cx + 28, chest_y - 2, 5.0, "skin", bias=0.14)
        _draw_cestus(c, cx + 36, chest_y - 2, rx=8.0, ry=6.5)
        c.stroke(cx + 18, chest_y - 7, cx + 38, chest_y - 7, "gold", 3, width=1)
    elif pose == "cross":
        # Crushing full-body right Cross + golden shock arc (`x` up to 92)!
        c.limb(cx - 4, chest_y, cx + 30, chest_y - 1, 5.5, "skin", bias=0.16)
        _draw_cestus(c, cx + 39, chest_y - 1, rx=8.5, ry=7.0)
        c.arc_stroke(cx + 26, chest_y, 20, 14, -45, 45, "gold", 3, width=2, selout_wrap=True)
    elif pose == "uppercut":
        # Rising skyward Uppercut (`top_y ~ 5`, `bottom_y = 80`)!
        c.limb(cx + 4, chest_y + 2, cx + 20, chest_y - 16, 5.5, "skin", bias=0.16)
        _draw_cestus(c, cx + 22, chest_y - 24, rx=7.5, ry=7.5)
        c.arc_stroke(cx + 16, chest_y - 8, 16, 20, -85, 25, "gold", 3, width=2, selout_wrap=True)
    elif pose == "charge":
        # Shoulder-ram brace: massive cestus tucked tight behind spiked pauldron!
        c.limb(cx - 4, chest_y + 2, cx + 14, chest_y + 5, 5.5, "skin")
        _draw_cestus(c, cx + 22, chest_y + 4, rx=8.0, ry=6.5)
    elif pose == "hurt":
        c.limb(cx - 8, chest_y + 1, cx - 16, chest_y - 4, 4.5, "skin")
        _draw_cestus(c, cx + 13, chest_y + 6, rx=7.0, ry=5.5)

    exact = 72 if pose == "idle" else None
    return c.finalize(ground_y=GROUND_Y, exact_height=exact)


def build_behemoth_vertical(pose: str) -> Image.Image:
    c = HeroCanvas()
    cx = 48
    is_up = pose.startswith("up_")
    step = -1 if pose.endswith("_a") else (1 if pose.endswith("_b") else 0)
    l_fy = 79 - (2 if step > 0 else 0)
    r_fy = 79 - (2 if step < 0 else 0)
    hip_y, chest_y = 53, 37

    for side_idx, (lx_off, fy) in enumerate(((-9, l_fy), (9, r_fy))):
        kx = cx + lx_off
        ky = (hip_y + fy) // 2
        c.limb(cx + (-5 if side_idx == 0 else 5), hip_y, kx, ky, 5.0, "obsidian")
        c.limb(kx, ky, kx, fy - 5, 4.2, "leather")
        c.ellipse(kx, ky, 4, 3, "steel", bias=0.10)
        c.rrect(kx - 6, fy - 7, kx + 6, fy, 2, "leather")

    c.poly([(cx - 18, chest_y - 8), (cx + 18, chest_y - 8), (cx + 11, hip_y + 1), (cx - 11, hip_y + 1)], "leather")
    if not is_up:
        c.poly([(cx - 13, chest_y - 5), (cx + 13, chest_y - 5), (cx + 9, chest_y + 6), (cx - 9, chest_y + 6)], "steel")
        c.rrect(cx - 12, hip_y - 3, cx + 12, hip_y + 3, 2, "crimson")
        c.ellipse(cx, hip_y, 5, 4, "gold", bias=0.20)
    else:
        c.rrect(cx - 12, hip_y - 3, cx + 12, hip_y + 3, 2, "crimson")

    # Asymmetric spiked left pauldron
    px = cx - 16 if not is_up else cx + 16
    c.ellipse(px, chest_y - 5, 8, 6, "steel", bias=0.18)
    c.poly([(px - 3, chest_y - 10), (px, chest_y - 16), (px + 3, chest_y - 10)], "steel", bias=0.25)

    # Arms + twin iron cestus gauntlets
    c.limb(cx - 17, chest_y - 1, cx - 22, chest_y + 9 + step * 2, 4.5, "skin")
    c.limb(cx + 17, chest_y - 1, cx + 22, chest_y + 9 - step * 2, 4.5, "skin")
    _draw_cestus(c, cx - 22, chest_y + 13 + step * 2, rx=6.5, ry=5.5, spike_dir=-1)
    _draw_cestus(c, cx + 22, chest_y + 13 - step * 2, rx=6.5, ry=5.5, spike_dir=1)

    _draw_behemoth_head(c, cx, 19, facing_mode="up" if is_up else "down")
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
    prev = Image.new("RGBA", (w, h), (24, 19, 18, 255))
    d = ImageDraw.Draw(prev)
    d.text((pad, 8), "BEHEMOTH (HEROIC PASS) - 16 frames x 96x96", fill=RAMPS["gold"][3])
    for i, p in enumerate(poses):
        x = pad + i * (CELL * zoom + pad)
        fr = sheet.crop((i * CELL, 0, (i + 1) * CELL, CELL))
        prev.alpha_composite(fr.resize((CELL * zoom, CELL * zoom), Image.NEAREST), (x, 28))
        d.text((x, 28 + CELL * zoom + 4), f"{i}:{p}", fill=RAMPS["gold"][2])
    prev.save("docs/images/behemoth_preview.png")


if __name__ == "__main__":
    main()
