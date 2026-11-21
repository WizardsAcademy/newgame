#!/usr/bin/env python3
"""Hand-craft the redesigned 24-frame (8x3, 128x128) Dark Knight spritesheet.

Inspired by dark-fantasy Gothic plate knights (reference-only — 100% original
procedural pixel art built from scratch with `tools/pixel_art_kit.py`):
  - Pointed crested V-slit dark-steel greathelm (kept ON in all frames & HUD!)
  - Layered midnight-navy tattered cloak & neck scarf
  - Fluted dark-slate plate cuirass, pauldrons, poleyns, greaves & sabatons
  - Heraldic pointed Heater Shield with silver-gold star-cross crest
  - Forged Dark-Moon Greatsword with fuller groove & crescent cleave arcs
  - Calm, subtle 4-frame side idle (`idle_0..3`), 2-frame front/back idles,
    4-frame grounded 4-dir walks, Greatsword combo, Shield Guard, Shield Charge,
    Hurt, and 2-stage Kneel -> Fallen collapse death (`die`)!

Outputs:
  - assets/textures/player_bahman.png   (1024 x 384 RGBA, 8 cols x 3 rows of 128x128)
  - docs/images/knight_preview.png      (3x crisp nearest-neighbor labeled contact sheet)
"""
from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
from pixel_art_kit import Layer, hex_rgba, lerp_col

CELL = 128
COLS = 8
ROWS = 3
GROUND_Y = 108  # locked boot baseline across ALL standing/walking/combat frames

OUT_KNIGHT = hex_rgba("#090c14")
OUT_CLOAK = hex_rgba("#070910")
OUT_GOLD = hex_rgba("#1e160b")

STEEL_RAMP = [
    hex_rgba("#191f2d"),
    hex_rgba("#293247"),
    hex_rgba("#3e4b66"),
    hex_rgba("#5d6e8f"),
    hex_rgba("#8da0c2"),
    hex_rgba("#ccd9f0"),
]

DARK_STEEL_RAMP = [
    hex_rgba("#121722"),
    hex_rgba("#1e2638"),
    hex_rgba("#2e3952"),
    hex_rgba("#465575"),
    hex_rgba("#6c7ea1"),
]

CLOAK_RAMP = [
    hex_rgba("#0d121f"),
    hex_rgba("#161f33"),
    hex_rgba("#222f4b"),
    hex_rgba("#324468"),
    hex_rgba("#485d87"),
]

SCARF_RAMP = [
    hex_rgba("#121829"),
    hex_rgba("#1d2740"),
    hex_rgba("#2d3b5c"),
    hex_rgba("#42547d"),
]

GOLD_RAMP = [
    hex_rgba("#47371e"),
    hex_rgba("#755c34"),
    hex_rgba("#ab8b52"),
    hex_rgba("#dab97c"),
    hex_rgba("#f8e6b8"),
]

BLADE_RAMP = [
    hex_rgba("#273145"),
    hex_rgba("#445370"),
    hex_rgba("#6e81a3"),
    hex_rgba("#a8bbd9"),
    hex_rgba("#eaf2ff"),
]

LEATHER_RAMP = [
    hex_rgba("#17110e"),
    hex_rgba("#291e19"),
    hex_rgba("#402f27"),
    hex_rgba("#5c4438"),
]


def draw_tattered_cloak_side(
    dst: Layer,
    shoulder_x: float,
    shoulder_y: float,
    sway_px: float = 0.0,
    flare: float = 0.0,
) -> None:
    """Draw multi-strip tattered dark-navy cloak flowing behind the Knight."""
    c = Layer(CELL, CELL)
    strips = [
        (-4, -2, -16 - flare * 12 - sway_px * 0.8, 99 - flare * 8, 6.5, 2.2),
        (-1, 0, -11 - flare * 9 - sway_px * 1.0, 102 - flare * 6, 6.8, 2.0),
        (2, 1, -5 - flare * 6 - sway_px * 0.7, 101 - flare * 4, 6.2, 2.0),
        (4, 2, 0 - flare * 3 - sway_px * 0.4, 97 - flare * 2, 5.0, 1.6),
    ]
    for ox, oy, tx, ty, r0, r1 in strips:
        sx = shoulder_x + ox
        sy = shoulder_y + oy
        mx = sx + (tx * 0.48)
        my = sy + (ty - sy) * 0.52
        c.ribbon([(sx, sy), (mx, my), (shoulder_x + tx, ty)], r0, r1, CLOAK_RAMP[2], steps=28)
    c.shade_ramp(CLOAK_RAMP, light_dir=(-0.6, -0.7), dither=0.30)
    # Crisp tattered notch dark folds between cloak strips
    for k in range(3):
        fx = int(round(shoulder_x - 5 - k * 4 - sway_px * 0.6 - flare * 5))
        c.line(shoulder_x - 2 - k * 2, shoulder_y + 14, fx, 95 - k * 2 - int(flare * 5), CLOAK_RAMP[0])
    c.outline(OUT_CLOAK)
    c.blit_onto(dst)


def draw_armored_leg_side(
    dst: Layer,
    hip_x: float,
    hip_y: float,
    knee_x: float,
    knee_y: float,
    foot_x: float,
    foot_y: float,
    is_back: bool = False,
) -> None:
    """Draw articulated cuisse, winged poleyn knee-cop, greave, and pointed sabaton."""
    leg = Layer(CELL, CELL)
    ramp = DARK_STEEL_RAMP if is_back else STEEL_RAMP
    # Cuisse (thigh) + Schynbald (greave)
    leg.capsule(hip_x, hip_y, knee_x, knee_y, 4.4, 3.7, ramp[2])
    leg.capsule(knee_x, knee_y, foot_x, foot_y - 4, 3.8, 3.3, ramp[2])
    # Pointed Sabaton (facing right +X) planted flat at foot_y
    sab_pts = [
        (foot_x - 4.5, foot_y - 5.0),
        (foot_x + 4.5, foot_y - 4.5),
        (foot_x + 8.5, foot_y - 1.5),
        (foot_x + 7.5, foot_y),
        (foot_x - 5.0, foot_y),
    ]
    leg.poly(sab_pts, ramp[2])
    leg.shade_ramp(ramp, light_dir=(-0.5, -0.8), dither=0.22, rim_right=not is_back)
    # Poleyn knee-cop plate highlight & articulation joint line
    leg.disc(knee_x + 1.0, knee_y, 3.2, ramp[-2])
    leg.pset(int(round(knee_x + 2)), int(round(knee_y - 1)), ramp[-1])
    leg.line(foot_x - 4, foot_y - 4, foot_x + 4, foot_y - 4, ramp[0])
    leg.outline(OUT_KNIGHT, skip_bottom_y=GROUND_Y)
    leg.blit_onto(dst)


def draw_knight_torso_side(dst: Layer, cx: float, cy: float, lean_x: float = 0.0) -> None:
    """Draw Gothic fluted breastplate, leather belt, and segmented fauld/tassets."""
    t = Layer(CELL, CELL)
    # Upper breastplate (slight heroic V-taper)
    pts = [
        (cx - 8.5 + lean_x, cy - 11),
        (cx + 9.0 + lean_x, cy - 11),
        (cx + 10.0 + lean_x * 0.7, cy - 2),
        (cx + 7.5 + lean_x * 0.4, cy + 7),
        (cx - 7.5 + lean_x * 0.4, cy + 7),
        (cx - 9.0 + lean_x * 0.7, cy - 2),
    ]
    t.poly(pts, STEEL_RAMP[2])
    # Segmented fauld / tasset plates over hips
    t.poly(
        [
            (cx - 8.5, cy + 7),
            (cx + 8.5, cy + 7),
            (cx + 10.0, cy + 16),
            (cx - 9.5, cy + 16),
        ],
        DARK_STEEL_RAMP[2],
    )
    t.shade_ramp(STEEL_RAMP, light_dir=(-0.55, -0.75), dither=0.25, rim_right=True)
    # Breastplate central ridge + fluted lines
    t.line(cx + 2 + lean_x * 0.7, cy - 9, cx + 2, cy + 5, STEEL_RAMP[4])
    t.line(cx - 3 + lean_x * 0.6, cy - 6, cx - 2, cy + 5, STEEL_RAMP[1])
    # Fauld horizontal lames
    for ly in (cy + 10, cy + 13):
        t.line(cx - 8, ly, cx + 8, ly, STEEL_RAMP[0])
        t.line(cx - 7, ly + 1, cx + 7, ly + 1, STEEL_RAMP[3])
    # Dark leather sword-belt + silver-gold buckle
    t.line(cx - 8, cy + 6, cx + 8, cy + 6, LEATHER_RAMP[1], r=1.0)
    t.line(cx - 8, cy + 7, cx + 8, cy + 7, LEATHER_RAMP[3])
    t.disc(cx + 2, cy + 6.5, 1.8, GOLD_RAMP[3])
    t.pset(int(round(cx + 2)), int(round(cy + 6)), GOLD_RAMP[4])
    t.outline(OUT_KNIGHT)
    t.blit_onto(dst)


def draw_scarf_collar_side(dst: Layer, cx: float, neck_y: float, sway_px: float = 0.0) -> None:
    """Draw thick dark-navy wrapped neck scarf & trailing scarf tail."""
    s = Layer(CELL, CELL)
    s.ellipse(cx, neck_y + 2, 9.5, 4.2, SCARF_RAMP[2])
    # Trailing scarf tail fluttering slightly behind neck
    s.ribbon(
        [(cx - 6, neck_y + 2), (cx - 14 - sway_px * 0.6, neck_y + 5), (cx - 19 - sway_px, neck_y + 12)],
        3.6,
        1.2,
        SCARF_RAMP[2],
        steps=16,
    )
    s.shade_ramp(SCARF_RAMP, light_dir=(-0.5, -0.8), dither=0.22)
    s.line(cx - 7, neck_y + 2, cx + 7, neck_y + 3, SCARF_RAMP[0])
    s.outline(OUT_CLOAK)
    s.blit_onto(dst)


def draw_greathelm_side(
    dst: Layer, cx: float, hy: float, blink: bool = False, tilt_y: float = 0.0
) -> None:
    """Draw sleek pointed Gothic V-slit dark-steel visor helm (facing right)."""
    h = Layer(CELL, CELL)
    # Pointed sallet/close-helm skull + angled visor + bevor chin
    pts = [
        (cx - 7.5, hy - 5),
        (cx - 2.0, hy - 10.5),
        (cx + 4.5, hy - 9.0),
        (cx + 8.5, hy - 3.0),
        (cx + 10.0, hy + 2.0 + tilt_y),
        (cx + 6.5, hy + 8.5 + tilt_y),
        (cx - 1.5, hy + 9.0),
        (cx - 8.0, hy + 5.0),
        (cx - 8.5, hy - 1.0),
    ]
    h.poly(pts, STEEL_RAMP[2])
    h.shade_ramp(STEEL_RAMP, light_dir=(-0.55, -0.8), dither=0.24, rim_right=True)

    # Raised central helm crest ridge catching cold moonlight
    h.line(cx - 2, hy - 10, cx + 5, hy - 8, STEEL_RAMP[5])
    h.line(cx + 5, hy - 8, cx + 9, hy + 1 + tilt_y, STEEL_RAMP[4])

    # Visor brow plate & narrow dark V-slit eye opening
    vy = int(round(hy - 0.5 + tilt_y * 0.6))
    h.line(cx + 1, vy - 1, cx + 9, vy, OUT_KNIGHT)
    h.line(cx + 1, vy, cx + 9, vy + 1, OUT_KNIGHT)
    # Vertical T-slit nasal opening
    h.line(cx + 6, vy + 1, cx + 6, vy + 6, OUT_KNIGHT)
    if not blink:
        # Subtle pale-steel inner eye gleam inside the dark visor slit
        h.pset(int(round(cx + 4)), vy, hex_rgba("#9cc8f5"))
        h.pset(int(round(cx + 5)), vy, hex_rgba("#dff0ff"))
    # Cheek breath-holes
    for bx, by in ((cx + 3, vy + 4), (cx + 4, vy + 6), (cx + 2, vy + 6)):
        h.pset(int(round(bx)), int(round(by)), OUT_KNIGHT)

    h.outline(OUT_KNIGHT)
    h.blit_onto(dst)


def draw_heater_shield(
    dst: Layer, sx: float, sy: float, profile_scale: float = 0.78, guard_glow: bool = False
) -> None:
    """Draw pointed dark-steel Heraldic Heater Shield with silver-gold star-cross crest."""
    sh = Layer(CELL, CELL)
    hw = 8.5 * profile_scale
    pts = [
        (sx - hw, sy - 11),
        (sx + hw, sy - 10),
        (sx + hw * 0.95, sy + 1),
        (sx + hw * 0.55, sy + 8),
        (sx, sy + 13),
        (sx - hw * 0.60, sy + 8),
        (sx - hw * 0.95, sy + 1),
    ]
    sh.poly(pts, DARK_STEEL_RAMP[2])
    sh.shade_ramp(DARK_STEEL_RAMP, light_dir=(-0.6, -0.7), dither=0.2)
    # Bright bevelled steel rim
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        col = STEEL_RAMP[5] if guard_glow else (STEEL_RAMP[4] if i in (0, 1, 6) else STEEL_RAMP[2])
        sh.line(x0, y0, x1, y1, col)
    # Ornate silver-gold star-cross crest on shield face
    if profile_scale >= 0.45:
        sh.line(sx, sy - 7, sx, sy + 8, GOLD_RAMP[3])
        sh.line(sx - hw * 0.55, sy - 1, sx + hw * 0.55, sy - 1, GOLD_RAMP[3])
        sh.disc(sx, sy - 1, 1.6, GOLD_RAMP[4])
    sh.outline(OUT_KNIGHT)
    sh.blit_onto(dst)


def draw_greatsword(
    dst: Layer,
    hx: float,
    hy: float,
    angle_deg: float,
    blade_len: float = 38.0,
) -> None:
    """Draw forged Dark-Moon Greatsword from hilt `(hx, hy)` along `angle_deg`."""
    sw = Layer(CELL, CELL)
    ang = math.radians(angle_deg)
    dx, dy = math.cos(ang), math.sin(ang)
    px, py = -dy, dx  # perpendicular

    # Pommel & leather grip behind hand
    pom_x, pom_y = hx - dx * 6.5, hy - dy * 6.5
    guard_x, guard_y = hx + dx * 2.5, hy + dy * 2.5
    tip_x, tip_y = guard_x + dx * blade_len, guard_y + dy * blade_len

    # Broad double-edged steel blade polygon with diamond tip
    bw = 2.6
    b_pts = [
        (guard_x + px * bw, guard_y + py * bw),
        (guard_x + dx * (blade_len - 6) + px * (bw * 0.78), guard_y + dy * (blade_len - 6) + py * (bw * 0.78)),
        (tip_x, tip_y),
        (guard_x + dx * (blade_len - 6) - px * (bw * 0.78), guard_y + dy * (blade_len - 6) - py * (bw * 0.78)),
        (guard_x - px * bw, guard_y - py * bw),
    ]
    sw.poly(b_pts, BLADE_RAMP[2])
    sw.shade_ramp(BLADE_RAMP, light_dir=(-0.5, -0.8), dither=0.15)
    # Bright razor upper edge + dark fuller groove down center
    sw.line(
        guard_x - px * (bw * 0.7),
        guard_y - py * (bw * 0.7),
        tip_x,
        tip_y,
        BLADE_RAMP[4],
    )
    sw.line(
        guard_x + dx * 3,
        guard_y + dy * 3,
        guard_x + dx * (blade_len - 9),
        guard_y + dy * (blade_len - 9),
        BLADE_RAMP[0],
    )
    # Winged silver-gold crossguard + grip + wheel pommel
    sw.line(
        guard_x - px * 6.5 + dx * 1.0,
        guard_y - py * 6.5 + dy * 1.0,
        guard_x + px * 6.5 + dx * 1.0,
        guard_y + py * 6.5 + dy * 1.0,
        GOLD_RAMP[3],
        r=1.0,
    )
    sw.line(pom_x, pom_y, guard_x, guard_y, LEATHER_RAMP[2], r=1.1)
    sw.disc(pom_x, pom_y, 2.0, GOLD_RAMP[3])
    sw.pset(int(round(pom_x)), int(round(pom_y - 1)), GOLD_RAMP[4])
    sw.outline(OUT_KNIGHT)
    sw.blit_onto(dst)


def draw_arm_pauldron_side(
    dst: Layer, sx: float, sy: float, ex: float, ey: float, hx: float, hy: float
) -> None:
    """Draw fluted pauldron + rerebrace + vambrace + armored gauntlet."""
    arm = Layer(CELL, CELL)
    arm.capsule(sx, sy, ex, ey, 3.6, 3.0, STEEL_RAMP[2])
    arm.capsule(ex, ey, hx, hy, 3.0, 2.7, STEEL_RAMP[2])
    arm.disc(hx, hy, 2.9, DARK_STEEL_RAMP[3])
    # Layered Gothic pauldron over shoulder
    arm.ellipse(sx - 0.5, sy - 0.5, 6.2, 5.2, STEEL_RAMP[3], angle_deg=-15)
    arm.shade_ramp(STEEL_RAMP, light_dir=(-0.55, -0.75), dither=0.22, rim_right=True)
    arm.line(sx - 5, sy + 1, sx + 5, sy + 2, STEEL_RAMP[0])
    arm.line(sx - 4, sy - 2, sx + 4, sy - 1, STEEL_RAMP[4])
    arm.outline(OUT_KNIGHT)
    arm.blit_onto(dst)


def draw_crescent_slash(
    dst: Layer, cx: float, cy: float, rx: float, ry: float, deg0: float, deg1: float
) -> None:
    """Hand-pixelled moonlit-steel crescent sword arc trailing cleanly behind blade tip."""
    fx = Layer(CELL, CELL)
    steps = 72
    for i in range(steps + 1):
        t = i / steps  # 0 = trailing tail (thin), 1 = leading blade edge (wide -> sharp tip)
        ang = math.radians(deg0 + (deg1 - deg0) * t)
        # Asymmetric swoosh taper: thin tail -> full belly near t=0.72 -> crisp point at t=1.0
        envelope = (t ** 0.75) * (math.sin(math.pi * min(1.0, t * 0.96 + 0.04)) ** 0.85)
        w = 0.5 + 4.8 * envelope
        x = cx + math.cos(ang) * rx
        y = cy + math.sin(ang) * ry
        fx.disc(x, y, w, hex_rgba("#243759", 210))
        fx.disc(x + math.cos(ang) * 1.4, y + math.sin(ang) * 1.4, w * 0.65, hex_rgba("#6f98cf", 245))
        if t > 0.18:
            fx.disc(x + math.cos(ang) * 2.5, y + math.sin(ang) * 2.5, max(0.6, w * 0.34), hex_rgba("#eef7ff", 255))
    fx.blit_onto(dst)


def render_knight_side_pose(
    breath_dy: float = 0.0,
    cloak_sway: float = 0.0,
    cloak_flare: float = 0.0,
    blink: bool = False,
    lean_x: float = 0.0,
    l_leg: tuple = (-4, 91, -6, 108),
    r_leg: tuple = (5, 91, 5, 108),
    shield_pos: tuple | None = (8.5, 61, 0.58),
    shield_front: bool = False,
    guard_glow: bool = False,
    arm_pose: tuple = (-2, 50, 4, 59, 13, 62),
    sword_angle: float = -42.0,
    sword_len: float = 38.0,
    slash_arc: tuple | None = None,
    wind_lines: bool = False,
    sparks: bool = False,
) -> Layer:
    """Compose a complete side-facing Knight frame with locked `GROUND_Y = 108`."""
    frame = Layer(CELL, CELL)
    cx = 62.0 + lean_x

    # 1. Back tattered midnight cloak
    draw_tattered_cloak_side(frame, cx - 4, 46 + breath_dy * 0.5, sway_px=cloak_sway, flare=cloak_flare)

    # 2. Back leg & front leg (feet locked to GROUND_Y = 108!)
    draw_armored_leg_side(frame, cx - 2, 74, cx + l_leg[0], l_leg[1], cx + l_leg[2], l_leg[3], is_back=True)
    draw_armored_leg_side(frame, cx + 2, 74, cx + r_leg[0], r_leg[1], cx + r_leg[2], r_leg[3], is_back=False)

    # 3. Shield behind torso if carried on off-shoulder/back-side
    if shield_pos is not None and not shield_front:
        draw_heater_shield(
            frame, cx + shield_pos[0], shield_pos[1] + breath_dy * 0.6, shield_pos[2], guard_glow=guard_glow
        )

    # 4. Fluted breastplate & fauld torso
    draw_knight_torso_side(frame, cx, 57 + breath_dy * 0.6, lean_x=lean_x * 0.4)

    # 5. Wrapped scarf collar + Crested V-Slit Greathelm (head stays steady on calm idle!)
    draw_scarf_collar_side(frame, cx, 43 + breath_dy * 0.4, sway_px=cloak_sway)
    draw_greathelm_side(frame, cx + 1, 34, blink=blink, tilt_y=lean_x * 0.15)

    # 6. Greatsword + Main Gauntleted Arm & Pauldron
    sx, sy, ex, ey, hx, hy = arm_pose
    draw_greatsword(frame, cx + hx, hy + breath_dy * 0.5, sword_angle, blade_len=sword_len)
    draw_arm_pauldron_side(
        frame, cx + sx, sy + breath_dy * 0.6, cx + ex, ey + breath_dy * 0.5, cx + hx, hy + breath_dy * 0.5
    )

    # 7. Shield in front when guarding / ramming
    if shield_pos is not None and shield_front:
        draw_heater_shield(
            frame, cx + shield_pos[0], shield_pos[1] + breath_dy * 0.5, shield_pos[2], guard_glow=guard_glow
        )

    # 8. Optional crescent slash / wind streaks / hurt sparks
    if slash_arc is not None:
        draw_crescent_slash(frame, *slash_arc)
    if wind_lines:
        for wy, wx0, wx1 in ((52, 18, 36), (68, 12, 32), (86, 20, 38)):
            frame.line(wx0, wy, wx1, wy, hex_rgba("#9ec7f5", 210))
            frame.line(wx0 + 4, wy + 1, wx1, wy + 1, hex_rgba("#e6f4ff", 230))
    if sparks:
        for spx, spy, dx, dy in ((76, 44, 5, -4), (80, 54, 6, 1), (74, 62, 4, 4)):
            frame.line(spx, spy, spx + dx, spy + dy, GOLD_RAMP[4])

    return frame


def render_knight_front(step: int = 0, sway: float = 0.0, breath_dy: float = 0.0) -> Layer:
    """Front-facing (`DOWN`) Knight: symmetrical greathelm, cloak, sword right, shield left."""
    frame = Layer(CELL, CELL)
    cx = 64.0

    # 1. Back cloak framing silhouette
    cloak = Layer(CELL, CELL)
    cloak.poly(
        [
            (cx - 13, 44),
            (cx + 13, 44),
            (cx + 18 + sway, 101),
            (cx + 10 + sway * 0.5, 103),
            (cx, 99),
            (cx - 11 + sway * 0.5, 103),
            (cx - 18 + sway, 100),
        ],
        CLOAK_RAMP[1],
    )
    cloak.shade_ramp(CLOAK_RAMP, light_dir=(-0.4, -0.8), dither=0.28)
    cloak.outline(OUT_CLOAK)
    cloak.blit_onto(frame)

    # 2. Front legs (`step`: 0=idle, 1=left step, 2=right step)
    l_dy = -3 if step == 1 else 0
    r_dy = -3 if step == 2 else 0
    for side, dy in ((-1, l_dy), (1, r_dy)):
        leg = Layer(CELL, CELL)
        lx = cx + side * 5.5
        leg.capsule(lx, 74, lx, 91 + dy * 0.5, 4.2, 3.6, STEEL_RAMP[2])
        leg.capsule(lx, 91 + dy * 0.5, lx, GROUND_Y - 3 + dy, 3.7, 3.4, STEEL_RAMP[2])
        leg.poly(
            [
                (lx - 4, GROUND_Y - 4 + dy),
                (lx + 4, GROUND_Y - 4 + dy),
                (lx + 4.5, GROUND_Y + dy),
                (lx - 4.5, GROUND_Y + dy),
            ],
            STEEL_RAMP[2],
        )
        leg.shade_ramp(STEEL_RAMP, light_dir=(-0.5, -0.8), dither=0.2)
        leg.disc(lx, 90 + dy * 0.5, 2.8, STEEL_RAMP[4])
        leg.outline(OUT_KNIGHT, skip_bottom_y=GROUND_Y)
        leg.blit_onto(frame)

    # 3. Breastplate, tassets & belt
    tor = Layer(CELL, CELL)
    by = breath_dy * 0.6
    tor.poly(
        [(cx - 10, 46 + by), (cx + 10, 46 + by), (cx + 8.5, 64 + by), (cx - 8.5, 64 + by)],
        STEEL_RAMP[2],
    )
    tor.poly([(cx - 9.5, 64 + by), (cx + 9.5, 64 + by), (cx + 11, 75), (cx - 11, 75)], DARK_STEEL_RAMP[2])
    # Dual fluted pauldrons
    tor.ellipse(cx - 11.5, 49 + by, 5.5, 4.8, STEEL_RAMP[3], angle_deg=20)
    tor.ellipse(cx + 11.5, 49 + by, 5.5, 4.8, STEEL_RAMP[3], angle_deg=-20)
    tor.shade_ramp(STEEL_RAMP, light_dir=(-0.45, -0.8), dither=0.24)
    tor.line(cx, 47 + by, cx, 63 + by, STEEL_RAMP[4])
    tor.line(cx - 9, 64 + by, cx + 9, 64 + by, LEATHER_RAMP[2], r=1.0)
    tor.disc(cx, 64 + by, 1.8, GOLD_RAMP[3])
    tor.outline(OUT_KNIGHT)
    tor.blit_onto(frame)

    # 4. Scarf + Front Symmetrical V-Slit Greathelm
    sc = Layer(CELL, CELL)
    sc.ellipse(cx, 44 + by * 0.5, 10.5, 4.0, SCARF_RAMP[2])
    sc.shade_ramp(SCARF_RAMP, light_dir=(-0.4, -0.8))
    sc.outline(OUT_CLOAK)
    sc.blit_onto(frame)

    helm = Layer(CELL, CELL)
    helm.poly(
        [
            (cx - 8, 29),
            (cx, 24),
            (cx + 8, 29),
            (cx + 8.5, 38),
            (cx + 5, 43),
            (cx, 44.5),
            (cx - 5, 43),
            (cx - 8.5, 38),
        ],
        STEEL_RAMP[2],
    )
    helm.shade_ramp(STEEL_RAMP, light_dir=(-0.45, -0.8), dither=0.22)
    helm.line(cx, 24, cx, 43, STEEL_RAMP[4])
    # Iconic dark Y/T visor slit + subtle cold eyes
    helm.line(cx - 5, 34, cx + 5, 34, OUT_KNIGHT)
    helm.line(cx - 5, 35, cx + 5, 35, OUT_KNIGHT)
    helm.line(cx, 35, cx, 42, OUT_KNIGHT)
    helm.pset(int(cx - 3), 34, hex_rgba("#a8d2fa"))
    helm.pset(int(cx + 3), 34, hex_rgba("#a8d2fa"))
    helm.outline(OUT_KNIGHT)
    helm.blit_onto(frame)

    # 5. Right hand (viewer-left) holding Greatsword angled down-left + Left arm holding Heater Shield
    draw_greatsword(frame, cx - 14, 63 + by, 112.0, blade_len=34.0)
    gaunt = Layer(CELL, CELL)
    gaunt.capsule(cx - 12, 52 + by, cx - 14, 63 + by, 3.0, 2.8, STEEL_RAMP[2])
    gaunt.shade_ramp(STEEL_RAMP)
    gaunt.outline(OUT_KNIGHT)
    gaunt.blit_onto(frame)

    draw_heater_shield(frame, cx + 12.5, 62 + by, profile_scale=0.92)
    return frame


def render_knight_back(step: int = 0, sway: float = 0.0, breath_dy: float = 0.0) -> Layer:
    """Back-facing (`UP`) Knight: full tattered midnight cloak, helm back, sword & shield edges."""
    frame = Layer(CELL, CELL)
    cx = 64.0
    by = breath_dy * 0.6

    # Peek of shield on left & greatsword tip on right behind cloak
    draw_heater_shield(frame, cx - 12.5, 61 + by, profile_scale=0.72)
    draw_greatsword(frame, cx + 13.5, 63 + by, 68.0, blade_len=34.0)

    # Boots peeking beneath cloak at GROUND_Y = 108
    l_dy = -3 if step == 1 else 0
    r_dy = -3 if step == 2 else 0
    for side, dy in ((-1, l_dy), (1, r_dy)):
        leg = Layer(CELL, CELL)
        lx = cx + side * 5.5
        leg.capsule(lx, 88, lx, GROUND_Y - 2 + dy, 3.8, 3.5, DARK_STEEL_RAMP[2])
        leg.poly(
            [(lx - 4, GROUND_Y - 3 + dy), (lx + 4, GROUND_Y - 3 + dy), (lx + 4, GROUND_Y + dy), (lx - 4, GROUND_Y + dy)],
            DARK_STEEL_RAMP[1],
        )
        leg.shade_ramp(DARK_STEEL_RAMP)
        leg.outline(OUT_KNIGHT, skip_bottom_y=GROUND_Y)
        leg.blit_onto(frame)

    # Pauldrons & Helm Back
    top = Layer(CELL, CELL)
    top.ellipse(cx - 11.5, 49 + by, 5.5, 4.8, STEEL_RAMP[2])
    top.ellipse(cx + 11.5, 49 + by, 5.5, 4.8, STEEL_RAMP[2])
    top.poly(
        [(cx - 8, 29), (cx, 24), (cx + 8, 29), (cx + 8.5, 40), (cx - 8.5, 40)],
        STEEL_RAMP[2],
    )
    top.shade_ramp(STEEL_RAMP, light_dir=(-0.45, -0.8), dither=0.22)
    top.line(cx, 24, cx, 40, STEEL_RAMP[4])
    top.outline(OUT_KNIGHT)
    top.blit_onto(frame)

    # Full-back multi-pleated tattered midnight cloak cascading from scarf to calves!
    cloak = Layer(CELL, CELL)
    cloak.poly(
        [
            (cx - 11.5, 47 + by * 0.5),
            (cx + 11.5, 47 + by * 0.5),
            (cx + 17 + sway, 98),
            (cx + 11 + sway * 0.7, 103),
            (cx + 5 + sway * 0.4, 97),
            (cx + sway * 0.3, 103),
            (cx - 6 + sway * 0.4, 98),
            (cx - 12 + sway * 0.7, 103),
            (cx - 17 + sway, 97),
        ],
        CLOAK_RAMP[2],
    )
    cloak.shade_ramp(CLOAK_RAMP, light_dir=(-0.45, -0.75), dither=0.30)
    for fx in (-8, -2, 4, 9):
        cloak.line(cx + fx * 0.6, 50, cx + fx + sway * 0.5, 98, CLOAK_RAMP[0])
    cloak.ellipse(cx, 45.5 + by * 0.5, 10.5, 3.4, SCARF_RAMP[2])
    cloak.outline(OUT_CLOAK)
    cloak.blit_onto(frame)

    # Re-blit full crested Greathelm back ABOVE cloak collar so head silhouette is crisp!
    helm_back = Layer(CELL, CELL)
    helm_back.poly(
        [
            (cx - 8, 29),
            (cx, 24),
            (cx + 8, 29),
            (cx + 8.5, 39),
            (cx + 5.5, 43.5),
            (cx - 5.5, 43.5),
            (cx - 8.5, 39),
        ],
        STEEL_RAMP[2],
    )
    helm_back.shade_ramp(STEEL_RAMP, light_dir=(-0.45, -0.8), dither=0.22)
    helm_back.line(cx, 24, cx, 42, STEEL_RAMP[4])
    helm_back.line(cx - 6, 40, cx + 6, 40, STEEL_RAMP[0])
    helm_back.outline(OUT_KNIGHT)
    helm_back.blit_onto(frame)
    return frame


def render_knight_kneel_death() -> Layer:
    """Frame 22 (`die_kneel`): Drops onto one armored knee, planting Greatsword into stone floor."""
    frame = Layer(CELL, CELL)
    cx = 60.0
    # Cloak draped low to floor
    draw_tattered_cloak_side(frame, cx - 4, 60, sway_px=-2.0, flare=-0.2)
    # Kneeling legs on GROUND_Y = 108
    draw_armored_leg_side(frame, cx - 2, 86, cx - 8, 104, cx - 14, GROUND_Y, is_back=True)
    draw_armored_leg_side(frame, cx + 3, 86, cx + 10, 96, cx + 9, GROUND_Y, is_back=False)
    draw_heater_shield(frame, cx - 6, 76, profile_scale=0.68)
    draw_knight_torso_side(frame, cx + 1, 71, lean_x=3.0)
    draw_scarf_collar_side(frame, cx + 2, 57, sway_px=-1.0)
    # Bowed greathelm
    draw_greathelm_side(frame, cx + 4, 50, blink=True, tilt_y=3.5)
    # Vertical Greatsword planted tip-down at GROUND_Y = 108!
    draw_greatsword(frame, cx + 18, 70, 90.0, blade_len=35.0)
    draw_arm_pauldron_side(frame, cx + 2, 63, cx + 11, 68, cx + 18, 70)
    return frame


def render_knight_fallen_death() -> Layer:
    """Frame 23 (`die_fallen`): Collapsed prone on stone floor at `GROUND_Y = 108`."""
    frame = Layer(CELL, CELL)
    # Greatsword lying flat along stone floor
    draw_greatsword(frame, 66, GROUND_Y - 3, 4.0, blade_len=36.0)
    # Fallen armored legs & torso resting along y = 94..108
    body = Layer(CELL, CELL)
    body.capsule(28, GROUND_Y - 5, 48, GROUND_Y - 6, 4.2, 4.6, DARK_STEEL_RAMP[2])
    body.capsule(48, GROUND_Y - 7, 70, GROUND_Y - 7, 6.2, 5.8, STEEL_RAMP[2])
    body.shade_ramp(STEEL_RAMP, light_dir=(-0.3, -0.9), dither=0.25)
    body.outline(OUT_KNIGHT, skip_bottom_y=GROUND_Y)
    body.blit_onto(frame)
    # Tattered midnight cloak draped across fallen back
    cloak = Layer(CELL, CELL)
    cloak.poly([(32, GROUND_Y - 6), (54, GROUND_Y - 15), (74, GROUND_Y - 13), (68, GROUND_Y - 2), (28, GROUND_Y - 2)], CLOAK_RAMP[2])
    cloak.shade_ramp(CLOAK_RAMP, light_dir=(-0.3, -0.9), dither=0.3)
    cloak.outline(OUT_CLOAK, skip_bottom_y=GROUND_Y)
    cloak.blit_onto(frame)
    # Fallen Greathelm & Heater Shield resting on ground
    draw_greathelm_side(frame, 79, GROUND_Y - 8, blink=True, tilt_y=4.0)
    draw_heater_shield(frame, 56, GROUND_Y - 9, profile_scale=0.65)
    return frame


def generate() -> None:
    sheet = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    labels = [
        # Row 0: Calm 4-frame Side Idle + 4-frame Grounded Side Walk
        "0:idle_0",
        "1:idle_1",
        "2:idle_2",
        "3:idle_blink",
        "4:walk_0",
        "5:walk_1",
        "6:walk_2",
        "7:walk_3",
        # Row 1: Front (DOWN) & Back (UP) Calm Idles + Walks
        "8:down_idle_0",
        "9:down_idle_1",
        "10:down_walk_0",
        "11:down_walk_1",
        "12:up_idle_0",
        "13:up_idle_1",
        "14:up_walk_0",
        "15:up_walk_1",
        # Row 2: Combat, Guard, Charge, Hurt, & Collapse Death
        "16:atk_windup",
        "17:atk_slash",
        "18:atk_spin",
        "19:guard",
        "20:charge",
        "21:hurt",
        "22:die_kneel",
        "23:die_fallen",
    ]

    frames: list[Layer] = [
        # --- ROW 0: CALM SIDE IDLE (4 frames — feet 100% planted, subtle 1px breath & cloak!) ---
        render_knight_side_pose(breath_dy=0.0, cloak_sway=0.0),
        render_knight_side_pose(breath_dy=-1.0, cloak_sway=1.0),
        render_knight_side_pose(breath_dy=-0.5, cloak_sway=1.6),
        render_knight_side_pose(breath_dy=0.0, cloak_sway=0.5, blink=True),
        # --- ROW 0: 4-FRAME GROUNDED UPRIGHT SIDE WALK ---
        render_knight_side_pose(
            cloak_sway=1.5,
            l_leg=(-8, 91, -12, GROUND_Y),
            r_leg=(8, 91, 11, GROUND_Y),
            arm_pose=(-2, 50, 2, 59, 10, 63),
            sword_angle=-36.0,
        ),
        render_knight_side_pose(
            cloak_sway=2.0,
            l_leg=(-2, 89, -3, GROUND_Y - 3),
            r_leg=(3, 91, 4, GROUND_Y),
            arm_pose=(-2, 50, 3, 59, 12, 62),
            sword_angle=-40.0,
        ),
        render_knight_side_pose(
            cloak_sway=1.5,
            l_leg=(8, 91, 11, GROUND_Y),
            r_leg=(-8, 91, -12, GROUND_Y),
            arm_pose=(-2, 50, 6, 58, 15, 61),
            sword_angle=-46.0,
        ),
        render_knight_side_pose(
            cloak_sway=1.0,
            l_leg=(3, 91, 4, GROUND_Y),
            r_leg=(-2, 89, -3, GROUND_Y - 3),
            arm_pose=(-2, 50, 4, 59, 13, 62),
            sword_angle=-42.0,
        ),
        # --- ROW 1: FRONT (DOWN) & BACK (UP) CALM IDLES + WALKS ---
        render_knight_front(step=0, sway=0.0, breath_dy=0.0),
        render_knight_front(step=0, sway=1.0, breath_dy=-1.0),
        render_knight_front(step=1, sway=1.2, breath_dy=-0.5),
        render_knight_front(step=2, sway=-1.2, breath_dy=-0.5),
        render_knight_back(step=0, sway=0.0, breath_dy=0.0),
        render_knight_back(step=0, sway=1.2, breath_dy=-1.0),
        render_knight_back(step=1, sway=1.5, breath_dy=-0.5),
        render_knight_back(step=2, sway=-1.5, breath_dy=-0.5),
        # --- ROW 2: COMBAT, SHIELD GUARD, SHIELD RAM, HURT, & DEATH ---
        # 16: Greatsword overhead/shoulder coil
        render_knight_side_pose(
            cloak_flare=0.25,
            lean_x=-1.5,
            l_leg=(-7, 91, -10, GROUND_Y),
            r_leg=(6, 91, 8, GROUND_Y),
            shield_pos=(8, 60, 0.72),
            shield_front=True,
            arm_pose=(-4, 48, -9, 40, -5, 34),
            sword_angle=-142.0,
            sword_len=39.0,
        ),
        # 17: Sweeping forward Greatsword cleave + crisp Moonlit-Steel Crescent Arc!
        render_knight_side_pose(
            cloak_flare=0.55,
            lean_x=3.0,
            l_leg=(-9, 92, -13, GROUND_Y),
            r_leg=(9, 91, 13, GROUND_Y),
            shield_pos=(-7, 61, 0.58),
            arm_pose=(2, 50, 12, 56, 19, 60),
            sword_angle=24.0,
            sword_len=40.0,
            slash_arc=(67, 58, 46, 38, -76, 26),
        ),
        # 18: Follow-through low 360 cleave spin!
        render_knight_side_pose(
            cloak_flare=0.70,
            lean_x=2.0,
            l_leg=(-8, 92, -11, GROUND_Y),
            r_leg=(8, 91, 12, GROUND_Y),
            shield_pos=(-8, 61, 0.55),
            arm_pose=(1, 51, 9, 62, 14, 70),
            sword_angle=58.0,
            sword_len=38.0,
            slash_arc=(65, 65, 46, 35, -18, 72),
        ),
        # 19: Tower/Heater Shield Guard braced firmly in front!
        render_knight_side_pose(
            cloak_sway=0.5,
            lean_x=-1.0,
            l_leg=(-7, 91, -9, GROUND_Y),
            r_leg=(7, 91, 9, GROUND_Y),
            shield_pos=(12, 57, 0.90),
            shield_front=True,
            guard_glow=True,
            arm_pose=(-4, 51, -8, 57, -5, 62),
            sword_angle=-118.0,
            sword_len=37.0,
        ),
        # 20: Shield-Bash Ram Charge!
        render_knight_side_pose(
            cloak_flare=0.95,
            lean_x=4.5,
            l_leg=(-11, 92, -16, GROUND_Y),
            r_leg=(10, 91, 14, GROUND_Y),
            shield_pos=(15, 57, 0.88),
            shield_front=True,
            guard_glow=True,
            arm_pose=(-4, 51, -9, 58, -12, 63),
            sword_angle=-138.0,
            sword_len=37.0,
            wind_lines=True,
        ),
        # 21: Hurt recoil + steel sparks
        render_knight_side_pose(
            cloak_flare=0.35,
            lean_x=-3.5,
            blink=True,
            l_leg=(-6, 91, -9, GROUND_Y),
            r_leg=(5, 91, 8, GROUND_Y),
            shield_pos=(-8, 59, 0.65),
            arm_pose=(-2, 49, 5, 53, 12, 49),
            sword_angle=-25.0,
            sparks=True,
        ),
        # 22 & 23: Kneeling -> Fallen Collapse Death (`die`)
        render_knight_kneel_death(),
        render_knight_fallen_death(),
    ]

    for idx, layer in enumerate(frames):
        c_idx = idx % COLS
        r_idx = idx // COLS
        sheet.paste(layer.to_image(), (c_idx * CELL, r_idx * CELL))

    out_sheet = "assets/textures/player_bahman.png"
    os.makedirs(os.path.dirname(out_sheet), exist_ok=True)
    sheet.save(out_sheet)

    # Save crisp 2x labeled preview grid in docs/images/knight_preview.png
    scale = 2
    tile_w = CELL * scale
    tile_h = CELL * scale + 22
    prev = Image.new("RGBA", (COLS * tile_w + 16, ROWS * tile_h + 36), (14, 17, 26, 255))
    pdraw = ImageDraw.Draw(prev)
    pdraw.text((12, 8), "REDESIGNED DARK KNIGHT (SER BAHMAN) - 24 frames (8x3 @ 128x128)", fill=(215, 228, 248, 255))
    for idx, layer in enumerate(frames):
        c_idx = idx % COLS
        r_idx = idx // COLS
        ox = 8 + c_idx * tile_w
        oy = 30 + r_idx * tile_h
        pdraw.rectangle([ox + 2, oy + 2, ox + tile_w - 3, oy + CELL * scale - 2], fill=(22, 27, 40, 255), outline=(45, 56, 80, 255))
        # Ground reference line
        gy = oy + GROUND_Y * scale
        pdraw.line([(ox + 6, gy), (ox + tile_w - 6, gy)], fill=(60, 78, 110, 140))
        up = layer.to_image().resize((CELL * scale, CELL * scale), Image.Resampling.NEAREST)
        prev.alpha_composite(up, (ox, oy))
        pdraw.text((ox + 6, oy + CELL * scale + 3), labels[idx], fill=(175, 192, 220, 255))

    os.makedirs("docs/images", exist_ok=True)
    prev.save("docs/images/knight_preview.png")
    print(f"Generated {out_sheet} ({sheet.size}) and docs/images/knight_preview.png")


if __name__ == "__main__":
    generate()
