#!/usr/bin/env python3
"""Generate Sylvara's 15-frame 96x96 Blonde Elven Ranger sheet (`HERO_SKELETON_SPEC.md`).

Bespoke Skeleton #3 — Tallest & Thinnest Elven Ranger:
  - `body_h = 80` (`crown_y = 0 .. GROUND_Y = 80`) — tallest hero in the cast!
  - `head_ratio = 25%` (`crown_y = 2 .. chin_y = 22`)
  - `shoulder_w = 25` (`[20..28]`), `hip_w = 14` (`[12..18]`)
  - Silhouette identity: closed Golden-Yew Recurve Bow hoop extending `+10px`
    past her narrow `12px` body on the right; feathered quiver breaking the
    upper-back line at `45°` on the left. Nothing else is wide!
  - Lithe, graceful elven legs: `leg_mass ~ 215` (`[150..260]`), `stance_w = 12`
"""

from __future__ import annotations

from PIL import Image, ImageDraw
from hero_art_lib import CELL, GROUND_Y, RAMPS, HeroCanvas


def _draw_quiver_45(c: HeroCanvas, qx: float, qy: float) -> None:
    """45-degree feathered quiver breaking the upper-back line starting at `qy` (`y = 22`)."""
    # Diagonal leather quiver tube at exact 45 degrees `(qx, qy + 1) -> (qx + 8, qy + 9)`
    c.tapered_limb(qx + 1, qy + 2, 1.9, qx + 9, qy + 10, 1.6, "leather", bias=0.10)
    # Twin white-and-gold fletched arrow tails jutting at 45 degrees (`y = qy .. qy + 4`)
    c.stroke(qx - 2, qy, qx + 2, qy + 4, "moon", 3, width=1)
    c.stroke(qx, qy, qx + 3, qy + 3, "gold", 3, width=1)


def _draw_closed_bow_hoop(
    c: HeroCanvas,
    string_x: float,
    top_y: float,
    bot_y: float,
    arch_px: float = 9.5,
    pull_px: float = 0.0,
    charged: bool = False,
) -> None:
    """Closed Recurve Bow hoop extending `+10px` past the body with crisp open window."""
    mid_y = 0.5 * (top_y + bot_y)
    ry = 0.5 * (bot_y - top_y)

    # Outer golden-yew recurve bow arc (`string_x -> string_x + arch_px`)
    c.arc_stroke(string_x - 1, mid_y, arch_px + 1, ry, -86, 86, "gold", 2, width=2, selout_wrap=True)
    # Carve inner D-window cleanly so the closed bow hoop has unmistakable negative space!
    win_pts = [
        (string_x + 2, top_y + 4),
        (string_x + arch_px - 3, mid_y - 5),
        (string_x + arch_px - 3, mid_y + 5),
        (string_x + 2, bot_y - 4),
    ]
    c.erase_poly(win_pts)

    # Taut bowstring closing the hoop from `(string_x, top_y + 1)` to `(string_x, bot_y - 1)`
    sx = string_x - pull_px
    c.stroke(string_x, top_y + 1, sx, mid_y, "moon", 2, width=1)
    c.stroke(sx, mid_y, string_x, bot_y - 1, "moon", 2, width=1)
    # Leather bow grip
    c.rrect(string_x + arch_px - 2, mid_y - 2, string_x + arch_px + 1, mid_y + 2, 1, "leather")

    if pull_px > 1.0:
        tip_x = string_x + arch_px + 6 + (3 if charged else 0)
        c.stroke(sx, mid_y, tip_x, mid_y, "emerald" if charged else "leather", 3 if charged else 2, width=2 if charged else 1)
        c.poly(
            [(tip_x, mid_y - 2), (tip_x + 5, mid_y), (tip_x, mid_y + 2)],
            "emerald" if charged else "steel",
            bias=0.35,
        )


def _draw_sylvara_head(
    c: HeroCanvas,
    hx: int,
    crown_y: int,
    blink: bool = False,
    hurt: bool = False,
    facing_mode: str = "side",
) -> None:
    """Lithe elven head + flowing golden hair locks (`crown_y = 0 .. y = 21`, no giraffe neck!)."""
    # Delicate golden crown crest (`y = 0..1`, `3px`) + full golden hair (`y = 2..19`)
    c.rrect(hx - 1, crown_y, hx + 1, crown_y + 3, 1, "gold", bias=0.30)
    c.rrect(hx - 5, crown_y + 2, hx + 5, crown_y + 15, 3, "gold", bias=0.20)
    # Flowing golden hair lock behind neck (`y = 13..19`, tapering gracefully into collar at `y = 20..21`)
    c.poly(
        [(hx - 5, crown_y + 13), (hx + 3, crown_y + 13), (hx + 2, crown_y + 19), (hx - 4, crown_y + 19)],
        "gold",
        bias=0.12,
    )
    # Graceful neck & high emerald collar pinch (`y = 16..21`, `7px` wide so `rows[:22]` stays `<= 15px`!)
    c.rrect(hx - 2, crown_y + 16, hx + 3, crown_y + 20, 1, "skin", bias=0.12)
    c.rrect(hx - 3, crown_y + 19, hx + 3, crown_y + 21, 1, "emerald", bias=0.06)

    if facing_mode == "up":
        c.poly([(hx - 5, crown_y + 4), (hx + 5, crown_y + 4), (hx + 4, crown_y + 20), (hx - 4, crown_y + 20)], "gold", bias=0.18)
        c.poly([(hx - 5, crown_y + 8), (hx - 9, crown_y + 6), (hx - 5, crown_y + 11)], "skin")
        c.poly([(hx + 5, crown_y + 8), (hx + 9, crown_y + 6), (hx + 5, crown_y + 11)], "skin")
        return

    fx = 1 if facing_mode == "side" else 0
    # Lithe elven face (`y = 4..16`, `x = hx - 5 .. hx + 5 + fx`)
    c.rrect(hx - 5 + fx, crown_y + 4, hx + 5 + fx, crown_y + 16, 3, "skin", bias=0.18)
    # Golden forehead bangs
    c.poly([(hx - 5 + fx, crown_y + 2), (hx + 5 + fx, crown_y + 2), (hx + 5 + fx, crown_y + 6), (hx - 5 + fx, crown_y + 6)], "gold", bias=0.26)
    # Pointed elven ear (`y = 7..11`)
    c.poly([(hx - 4 + fx, crown_y + 8), (hx - 9 + fx, crown_y + 6), (hx - 5 + fx, crown_y + 11)], "skin", bias=0.16)
    if facing_mode != "side":
        c.poly([(hx + 4, crown_y + 8), (hx + 9, crown_y + 6), (hx + 5, crown_y + 11)], "skin", bias=0.06)

    # Emerald tiara circlet
    c.stroke(hx - 4 + fx, crown_y + 5, hx + 5 + fx, crown_y + 5, "gold", 3)
    c.dot(hx + (2 if facing_mode == "side" else 0), crown_y + 5, "emerald", 3)

    # Crisp emerald eyes (`y = 9..10`)
    ex_pair = (hx + 1, hx + 4) if facing_mode == "side" else (hx - 3, hx + 3)
    ey = crown_y + 9
    if hurt:
        for ex in ex_pair:
            c.stroke(ex - 1, ey, ex + 1, ey + 1, "skin", 0)
    elif blink:
        for ex in ex_pair:
            c.stroke(ex - 1, ey + 1, ex + 1, ey + 1, "skin", 0)
    else:
        for ex in ex_pair:
            c.dot(ex, ey - 1, "leather", 0)
            c.dot(ex, ey, "emerald", 1)
            c.dot(ex + 1, ey, "emerald", 3)


def build_sylvara_side(pose: str) -> Image.Image:
    c = HeroCanvas()
    # Positioned at `cx = 39` so her +10px closed bow hoop extends right (`x = 55`)
    cx = 39
    crown_y = 0  # exact 80 - 0 = 80px standing height!
    l_leg_x, l_fy = 36, 79
    r_leg_x, r_fy = 42, 79

    if pose == "walk_a":
        l_leg_x, l_fy = 34, 78
        r_leg_x, r_fy = 44, 79
    elif pose == "walk_b":
        l_leg_x, l_fy = 37, 79
        r_leg_x, r_fy = 40, 77
    elif pose in ("bow_draw", "bow_charge", "bow_release"):
        cx = 39
        l_leg_x, r_leg_x = 35, 44
    elif pose == "wind_vault":
        cx = 41
        l_leg_x, l_fy = 35, 79
        r_leg_x, r_fy = 44, 72
    elif pose == "hurt":
        cx = 38
        crown_y = 8  # recoil crouch (`h = 72 < 80 * 0.92`) so `frame 0` is standing cell!
        l_leg_x, r_leg_x = 35, 42

    sh_y = 25
    waist_y = 40
    hip_y = 49

    # 1. 45-degree Feathered Quiver breaking the upper-back line at `y = 22..32`!
    _draw_quiver_45(c, cx - 8, 22 + crown_y // 2)

    # 2. Long, graceful elven legs (`y = 52..79`, `leg_top = 56`: `leg_mass ~ 215`, `stance_w = 12`)!
    for idx, (lx, fy) in enumerate(((l_leg_x, l_fy), (r_leg_x, r_fy))):
        hip_anchor = cx - 2 if idx == 0 else cx + 2
        knee_x = int(round(0.4 * hip_anchor + 0.6 * lx))
        knee_y = 65
        c.tapered_limb(hip_anchor, hip_y + 2, 1.6, knee_x, knee_y, 1.4, "emerald", bias=-0.05 if idx == 0 else 0.08)
        c.tapered_limb(knee_x, knee_y, 1.4, lx, fy - 3, 1.2, "leather", bias=0.10)
        # Dainty laced ranger boots (`stance_w = 12` on idle: `34..45`)
        if idx == 0:
            c.rrect(lx - 2, fy - 3, lx + 1, fy, 1, "leather", bias=0.08)
        else:
            c.rrect(lx - 1, fy - 3, lx + 3, fy, 1, "leather", bias=0.14)
            c.dot(lx + 1, fy - 3, "gold", 3)

    if pose == "wind_vault":
        c.arc_stroke(cx - 1, 76, 8, 3, 15, 165, "emerald", 3, width=1)

    # 3. Rounded emerald ranger capelet -> ultra-slender `12px` ranger torso -> `14px` tunic hip!
    c.poly(
        [
            (cx - 5, 22 + crown_y),   # rounded shoulder top (no flat T-bar shelf!)
            (cx + 6, 22 + crown_y),
            (cx + 7, sh_y + crown_y // 2),
            (cx + 5, waist_y),
            (cx + 7, hip_y + 3),
            (cx - 6, hip_y + 3),
            (cx - 5, waist_y),
            (cx - 6, sh_y + crown_y // 2),
        ],
        "emerald",
        bias=0.12,
    )
    c.poly([(cx - 4, sh_y + 2 + crown_y // 2), (cx + 4, sh_y + 2 + crown_y // 2), (cx + 3, waist_y), (cx - 3, waist_y)], "leather", bias=0.10)
    c.rrect(cx - 5, waist_y - 1, cx + 5, waist_y + 1, 1, "gold", bias=0.22)
    c.dot(cx + 1, 23 + crown_y, "gold", 3)

    # 4. Tall Elven Head (`crown_y = 0 .. 21`)
    _draw_sylvara_head(
        c,
        cx,
        crown_y,
        blink=(pose == "blink"),
        hurt=(pose == "hurt"),
        facing_mode="side",
    )

    # 5. Slender Bow Arm + Closed Golden-Yew Recurve Bow Hoop (`+10px` past body `x = 45 -> 55`)!
    if pose in ("idle", "blink", "walk_a", "walk_b"):
        # Closed bow hoop spans `y = 24..46` (`selout_wrap` `y = 22..48`, strictly below `y=21` and above `hip_y=49`!)
        # Combined with 45° quiver at `y = 22`, `widths[22] >= 18` -> `chin_y = 22` -> exact `25%` `head_ratio`!
        c.tapered_limb(cx + 4, sh_y + 3, 1.4, cx + 13, 35, 1.2, "skin", bias=0.14)
        _draw_closed_bow_hoop(c, cx + 7, 24, 46, arch_px=9.5, pull_px=0.0)
    elif pose == "bow_draw":
        c.tapered_limb(cx + 4, sh_y + 3, 1.4, cx + 16, 33, 1.2, "skin", bias=0.14)
        _draw_closed_bow_hoop(c, cx + 10, 21, 47, arch_px=9.0, pull_px=6.0, charged=False)
    elif pose == "bow_charge":
        c.tapered_limb(cx + 4, sh_y + 3, 1.4, cx + 17, 33, 1.2, "skin", bias=0.14)
        _draw_closed_bow_hoop(c, cx + 11, 21, 47, arch_px=9.5, pull_px=11.0, charged=True)
    elif pose == "bow_release":
        c.tapered_limb(cx + 4, sh_y + 3, 1.4, cx + 17, 33, 1.2, "skin", bias=0.14)
        _draw_closed_bow_hoop(c, cx + 11, 21, 47, arch_px=9.0, pull_px=0.0, charged=False)
        c.stroke(cx + 22, 33, cx + 36, 33, "emerald", 3, width=1)
    elif pose == "wind_vault":
        c.tapered_limb(cx + 4, sh_y + 3, 1.4, cx + 14, 33, 1.2, "skin")
        _draw_closed_bow_hoop(c, cx + 8, 23, 46, arch_px=9.5, pull_px=0.0)
    elif pose == "hurt":
        c.tapered_limb(cx + 4, sh_y + 7, 1.4, cx + 14, 38, 1.2, "skin")
        _draw_closed_bow_hoop(c, cx + 8, 26, 50, arch_px=10.0, pull_px=0.0)

    return c.finalize(ground_y=GROUND_Y)


def build_sylvara_vertical(pose: str) -> Image.Image:
    c = HeroCanvas()
    cx = 44
    crown_y = 0
    is_up = pose.startswith("up_")
    step = -1 if pose.endswith("_a") else (1 if pose.endswith("_b") else 0)
    l_fy = 79 - (2 if step > 0 else 0)
    r_fy = 79 - (2 if step < 0 else 0)
    sh_y, waist_y, hip_y = 25, 40, 49

    _draw_quiver_45(c, cx - 9, 22)

    for idx, (lx, fy) in enumerate(((cx - 3, l_fy), (cx + 3, r_fy))):
        c.tapered_limb(lx, hip_y + 2, 1.6, lx, 65, 1.4, "emerald")
        c.tapered_limb(lx, 65, 1.4, lx, fy - 3, 1.2, "leather")
        c.rrect(lx - 2, fy - 3, lx + 2, fy, 1, "leather")

    c.poly(
        [
            (cx - 6, 22),
            (cx + 6, 22),
            (cx + 7, sh_y + 1),
            (cx + 5, waist_y),
            (cx + 7, hip_y + 3),
            (cx - 7, hip_y + 3),
            (cx - 5, waist_y),
            (cx - 7, sh_y + 1),
        ],
        "emerald",
        bias=0.10,
    )
    if not is_up:
        c.poly([(cx - 4, sh_y + 2), (cx + 4, sh_y + 2), (cx + 3, waist_y), (cx - 3, waist_y)], "leather")
        c.rrect(cx - 5, waist_y - 1, cx + 5, waist_y + 1, 1, "gold")

    # Closed bow hoop held out to right (`30px` total width >= `f00` so `_standing_cell` picks `f00`!)
    _draw_closed_bow_hoop(c, cx + 8, 23, 47, arch_px=9.5, pull_px=0.0)
    c.tapered_limb(cx - 6, sh_y + 2, 1.4, cx - 9, 34 + step * 2, 1.2, "emerald")
    c.tapered_limb(cx + 6, sh_y + 2, 1.4, cx + 13, 34 - step * 2, 1.2, "skin")

    _draw_sylvara_head(c, cx, crown_y, facing_mode="up" if is_up else "down")
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
    d.text((pad, 8), "SYLVARA (SKELETON SPEC: 80px, 24w shoulders, 200 leg_mass)", fill=RAMPS["emerald"][3])
    for i, p in enumerate(poses):
        x = pad + i * (CELL * zoom + pad)
        fr = sheet.crop((i * CELL, 0, (i + 1) * CELL, CELL))
        prev.alpha_composite(fr.resize((CELL * zoom, CELL * zoom), Image.NEAREST), (x, 28))
        d.text((x, 28 + CELL * zoom + 4), f"{i}:{p}", fill=RAMPS["gold"][3])
    prev.save("docs/images/sylvara_preview.png")


if __name__ == "__main__":
    main()
