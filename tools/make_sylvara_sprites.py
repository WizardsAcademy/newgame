#!/usr/bin/env python3
"""Hand-craft the redesigned 24-frame (8x3, 128x128) Sylvara High-Elf Archer sheet.

Inspired by dark-fantasy woodland high-elf rangers (reference-only — 100%
original procedural pixel art built from scratch with `tools/pixel_art_kit.py`):
  - Long cascading platinum-champagne blonde hair, side braids & pointed elf ears
  - Forest-emerald & antique-gold mantle/cloak over ivory-and-emerald corset tunic
  - Diagonal feathered quiver on back + tall gold-trimmed leather ranger boots
  - Ornate double-curved Golden-Wood Elven Recurve Bow held in hand
  - Calm, subtle 4-frame side idle (`idle_0..3`), 2-frame front/back idles,
    4-frame grounded 4-dir walks, Bow Draw / Charge / Release / Quick-Follow,
    Sylvan Gale Vault (`charge`), Hurt, and 2-stage Kneel -> Fallen death (`die`)!

Outputs:
  - assets/textures/player_pari.png     (1024 x 384 RGBA, 8 cols x 3 rows of 128x128)
  - docs/images/sylvara_preview.png     (2x crisp nearest-neighbor labeled contact sheet)
"""
from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
from pixel_art_kit import Layer, hex_rgba

CELL = 128
COLS = 8
ROWS = 3
GROUND_Y = 108

OUT_ELF = hex_rgba("#1c1110")
OUT_CLOAK = hex_rgba("#091410")
OUT_BOW = hex_rgba("#1e1409")

SKIN_RAMP = [
    hex_rgba("#8e5b50"),
    hex_rgba("#b87c6e"),
    hex_rgba("#de9f8e"),
    hex_rgba("#f4c2b1"),
    hex_rgba("#ffe3d6"),
]

HAIR_RAMP = [
    hex_rgba("#6e5536"),
    hex_rgba("#9c7b50"),
    hex_rgba("#cca976"),
    hex_rgba("#ecd2a6"),
    hex_rgba("#fff3db"),
]

EMERALD_RAMP = [
    hex_rgba("#0e2018"),
    hex_rgba("#193829"),
    hex_rgba("#285740"),
    hex_rgba("#3e7c5d"),
    hex_rgba("#62a884"),
]

IVORY_RAMP = [
    hex_rgba("#786f64"),
    hex_rgba("#a3988b"),
    hex_rgba("#cfc5b7"),
    hex_rgba("#f2ebe0"),
]

BOOT_RAMP = [
    hex_rgba("#171110"),
    hex_rgba("#291f1c"),
    hex_rgba("#42312c"),
    hex_rgba("#614941"),
]

GOLD_RAMP = [
    hex_rgba("#4f3b1b"),
    hex_rgba("#806230"),
    hex_rgba("#ba914c"),
    hex_rgba("#e8c379"),
    hex_rgba("#fff2c2"),
]


def draw_quiver_and_cloak_side(
    dst: Layer, sx: float, sy: float, sway_px: float = 0.0, flare: float = 0.0
) -> None:
    """Draw diagonal feathered arrow quiver + forest-emerald gold-trimmed ranger cloak."""
    # 1. Arrow Quiver + emerald-white fletched arrow tails peeking above back shoulder
    qv = Layer(CELL, CELL)
    qv.capsule(sx - 5, sy - 6, sx - 1, sy + 12, 3.0, 2.6, BOOT_RAMP[2])
    qv.shade_ramp(BOOT_RAMP)
    # 3 fletched arrow shafts peeking out top-left
    for k, ox in enumerate((-3, -1, 1)):
        ax0, ay0 = sx - 6 + ox, sy - 7 - k
        ax1, ay1 = ax0 - 4, ay0 - 5
        qv.line(ax0, ay0, ax1, ay1, GOLD_RAMP[2])
        qv.line(ax1, ay1, ax1 - 2, ay1 - 1, hex_rgba("#7bf0b5"))
        qv.line(ax1, ay1, ax1, ay1 - 2, IVORY_RAMP[3])
    qv.outline(OUT_ELF)
    qv.blit_onto(dst)

    # 2. Flowing Forest-Emerald Cloak with gold hem embroidery
    c = Layer(CELL, CELL)
    strips = [
        (-3, 0, -15 - flare * 13 - sway_px * 0.9, 96 - flare * 8, 5.8, 2.0),
        (0, 1, -10 - flare * 9 - sway_px * 1.0, 99 - flare * 6, 6.0, 2.0),
        (3, 2, -4 - flare * 5 - sway_px * 0.6, 95 - flare * 4, 5.0, 1.6),
    ]
    for ox, oy, tx, ty, r0, r1 in strips:
        x0, y0 = sx + ox, sy + oy
        c.ribbon(
            [(x0, y0), (x0 + tx * 0.48, y0 + (ty - y0) * 0.52), (sx + tx, ty)],
            r0,
            r1,
            EMERALD_RAMP[2],
            steps=26,
        )
    c.shade_ramp(EMERALD_RAMP, light_dir=(-0.55, -0.75), dither=0.26)
    # Antique gold border along bottom cloak hem
    c.line(
        sx - 15 - flare * 13 - sway_px * 0.9,
        96 - flare * 8,
        sx - 4 - flare * 5 - sway_px * 0.6,
        95 - flare * 4,
        GOLD_RAMP[3],
    )
    c.outline(OUT_CLOAK)
    c.blit_onto(dst)


def draw_elf_leg_side(
    dst: Layer,
    hip_x: float,
    hip_y: float,
    knee_x: float,
    knee_y: float,
    foot_x: float,
    foot_y: float,
    is_back: bool = False,
    ground_skip: int | None = GROUND_Y,
) -> None:
    """Draw slender elven thigh + tall thigh-high gold-trimmed dark ranger boot."""
    leg = Layer(CELL, CELL)
    leg.capsule(hip_x, hip_y, knee_x, knee_y, 3.6, 3.0, IVORY_RAMP[2 if not is_back else 1])
    leg.shade_ramp(IVORY_RAMP)
    leg.outline(OUT_ELF)
    leg.blit_onto(dst)

    boot = Layer(CELL, CELL)
    boot.capsule(knee_x, knee_y - 2, foot_x, foot_y - 3.5, 3.3, 2.8, BOOT_RAMP[2 if not is_back else 1])
    boot.poly(
        [
            (foot_x - 3.8, foot_y - 4.2),
            (foot_x + 4.0, foot_y - 3.8),
            (foot_x + 7.5, foot_y - 1.2),
            (foot_x + 7.0, foot_y),
            (foot_x - 4.2, foot_y),
        ],
        BOOT_RAMP[1],
    )
    boot.shade_ramp(BOOT_RAMP, light_dir=(-0.5, -0.8), dither=0.2)
    # Gold knee-cuff V-trim on thigh-high boot!
    boot.line(knee_x - 3, knee_y - 2, knee_x + 3, knee_y - 1, GOLD_RAMP[3])
    boot.pset(int(round(knee_x + 1)), int(round(knee_y - 2)), GOLD_RAMP[4])
    boot.outline(OUT_ELF, skip_bottom_y=ground_skip)
    boot.blit_onto(dst)


def draw_elf_torso_side(
    dst: Layer, cx: float, cy: float, lean_x: float = 0.0, sway_px: float = 0.0
) -> None:
    """Draw ivory-and-emerald elven corset bodice, gold belt, split ranger tunic & shoulder mantle."""
    tor = Layer(CELL, CELL)
    # Lithe hourglass elven corset & tunic skirt
    pts = [
        (cx - 6.5 + lean_x, cy - 10),
        (cx + 7.5 + lean_x, cy - 10),
        (cx + 8.0 + lean_x * 0.7, cy - 3),
        (cx + 5.8 + lean_x * 0.4, cy + 5),
        (cx + 9.0 - sway_px * 0.3, cy + 18),
        (cx - 8.5 - sway_px * 0.3, cy + 18),
        (cx - 6.0 + lean_x * 0.4, cy + 5),
    ]
    tor.poly(pts, EMERALD_RAMP[2])
    tor.shade_ramp(EMERALD_RAMP, light_dir=(-0.5, -0.8), dither=0.22, rim_right=True)

    # Ivory front panel & gold corset lacing + emerald waist gem
    tor.poly(
        [
            (cx + 2.0 + lean_x * 0.6, cy - 8),
            (cx + 7.0 + lean_x * 0.6, cy - 8),
            (cx + 5.5, cy + 4),
            (cx + 2.0, cy + 4),
        ],
        IVORY_RAMP[3],
    )
    tor.line(cx - 6, cy + 5, cx + 6, cy + 5, GOLD_RAMP[3], r=0.9)
    tor.line(cx - 8 - sway_px * 0.3, cy + 17, cx + 8 - sway_px * 0.3, cy + 17, GOLD_RAMP[3])
    tor.disc(cx + 4.0, cy + 5.0, 1.5, hex_rgba("#5bf0a8"))
    # Gold-trimmed emerald shoulder mantle + brooch
    tor.ellipse(cx + 0.5 + lean_x * 0.8, cy - 9.0, 7.8, 3.4, EMERALD_RAMP[3], angle_deg=-6)
    tor.line(cx - 6 + lean_x * 0.8, cy - 7, cx + 7 + lean_x * 0.8, cy - 7, GOLD_RAMP[3])
    tor.disc(cx + 4.5 + lean_x * 0.8, cy - 8.5, 1.5, GOLD_RAMP[4])
    tor.outline(OUT_ELF)
    tor.blit_onto(dst)


def draw_elf_head_side(
    dst: Layer, cx: float, hy: float, sway_px: float = 0.0, blink: bool = False
) -> None:
    """Draw graceful elven face, emerald eye, pointed elf ear, and long platinum-blonde hair."""
    # 1. Long cascading back platinum-blonde hair flowing down to waist!
    hair_back = Layer(CELL, CELL)
    for ox, oy, tx, ty, r0 in (
        (-5, -3, -15 - sway_px * 1.0, 32, 5.4),
        (-3, 0, -11 - sway_px * 0.8, 36, 5.0),
        (-6, -6, -17 - sway_px * 0.9, 24, 4.4),
    ):
        hair_back.ribbon(
            [(cx + ox, hy + oy), (cx + (ox + tx) * 0.52, hy + (oy + ty) * 0.5), (cx + tx, hy + ty)],
            r0,
            1.4,
            HAIR_RAMP[3],
            steps=22,
        )
    hair_back.shade_ramp(HAIR_RAMP, light_dir=(-0.5, -0.8), dither=0.24)
    hair_back.outline(OUT_ELF)
    hair_back.blit_onto(dst)

    # 2. Delicate elven face profile
    face = Layer(CELL, CELL)
    face.poly(
        [
            (cx - 5.0, hy - 6.5),
            (cx + 6.0, hy - 6.0),
            (cx + 7.5, hy - 0.5),
            (cx + 5.8, hy + 5.5),
            (cx + 1.0, hy + 7.0),
            (cx - 5.0, hy + 5.5),
        ],
        SKIN_RAMP[3],
    )
    face.shade_ramp(SKIN_RAMP, light_dir=(-0.45, -0.8), dither=0.16, rim_right=True)
    face.outline(OUT_ELF)
    face.blit_onto(dst)

    # 3. Expressive Emerald-Jade Eye & Soft Blush
    ex, ey = int(round(cx + 3.5)), int(round(hy - 0.5))
    if blink:
        dst.line(ex - 1, ey, ex + 2, ey, OUT_ELF)
    else:
        dst.line(ex - 1, ey - 1, ex + 2, ey - 1, OUT_ELF)  # upper lash
        dst.pset(ex, ey, hex_rgba("#16593e"))
        dst.pset(ex + 1, ey, hex_rgba("#4be39d"))
        dst.pset(ex, ey + 1, hex_rgba("#2aa871"))
        dst.pset(ex + 1, ey - 1, hex_rgba("#ffffff"))  # catchlight
    dst.pset(ex - 1, ey + 2, SKIN_RAMP[1])  # soft cheek blush

    # 4. Platinum-Blonde Crown Bangs, Side-Lock & Sweeping Pointed Elven Ear!
    hair_top = Layer(CELL, CELL)
    hair_top.poly(
        [
            (cx - 7.5, hy - 2),
            (cx - 5.5, hy - 9.0),
            (cx + 1.5, hy - 9.5),
            (cx + 7.0, hy - 6.5),
            (cx + 7.8, hy - 2.5),
            (cx + 4.5, hy - 3.5),
            (cx - 1.5, hy - 3.0),
            (cx - 4.5, hy + 2.0),
        ],
        HAIR_RAMP[3],
    )
    # Delicate side-lock framing cheek
    hair_top.ribbon(
        [(cx - 1.5, hy - 2.0), (cx - 1.0, hy + 6.0), (cx - 2.5 - sway_px * 0.4, hy + 14.0)],
        2.1,
        0.9,
        HAIR_RAMP[4],
        steps=14,
    )
    hair_top.shade_ramp(HAIR_RAMP, light_dir=(-0.45, -0.85), dither=0.2)
    # Emerald-gold elven circlet gem on brow
    hair_top.disc(cx + 5.0, hy - 5.5, 1.4, GOLD_RAMP[3])
    hair_top.pset(int(round(cx + 5)), int(round(hy - 6)), hex_rgba("#6bf7b5"))
    hair_top.outline(OUT_ELF)
    hair_top.blit_onto(dst)

    # Long sweeping pointed high-elf ear poking sharply back through hair!
    ear = Layer(CELL, CELL)
    ear.poly(
        [
            (cx - 1.5, hy - 1.0),
            (cx - 9.5, hy - 3.5),
            (cx - 3.0, hy + 2.2),
        ],
        SKIN_RAMP[3],
    )
    ear.shade_ramp(SKIN_RAMP, light_dir=(-0.4, -0.8))
    ear.outline(OUT_ELF)
    ear.blit_onto(dst)


def draw_recurve_bow(
    dst: Layer,
    bx: float,
    by: float,
    angle_deg: float = 12.0,
    pull_px: float = 0.0,
    arrow_state: str = "none",  # "none" | "draw" | "charge" | "release"
) -> None:
    """Draw ornate double-curved Golden-Wood Elven Recurve Bow + enchanted arrow."""
    bow = Layer(CELL, CELL)
    ang = math.radians(angle_deg)
    ca, sa = math.cos(ang), math.sin(ang)

    def rot(lx: float, ly: float) -> tuple[float, float]:
        return (bx + lx * ca - ly * sa, by + lx * sa + ly * ca)

    # Upper & lower graceful recurve limbs
    u0, u1, u2, u3 = rot(0, 0), rot(4, -10), rot(-1, -18), rot(-5, -22)
    l0, l1, l2, l3 = rot(0, 0), rot(4, 10), rot(-1, 18), rot(-5, 22)
    bow.ribbon([u0, u1, u2, u3], 1.9, 1.0, GOLD_RAMP[3], steps=22)
    bow.ribbon([l0, l1, l2, l3], 1.9, 1.0, GOLD_RAMP[3], steps=22)
    bow.shade_ramp(GOLD_RAMP, light_dir=(-0.5, -0.8), dither=0.18)
    # Emerald grip gem
    bow.disc(bx, by, 1.8, hex_rgba("#52eba0"))
    bow.outline(OUT_BOW)

    # Bowstring (pulled back by `pull_px` when drawing/charging!)
    str_mid = rot(-5.0 - pull_px, 0.0)
    s_col = hex_rgba("#dce8e2", 225)
    bow.line(u3[0], u3[1], str_mid[0], str_mid[1], s_col)
    bow.line(l3[0], l3[1], str_mid[0], str_mid[1], s_col)

    # Enchanted arrow / release streak
    if arrow_state in ("draw", "charge"):
        tail = str_mid
        tip = rot(12.0, 0.0)
        bow.line(tail[0], tail[1], tip[0], tip[1], GOLD_RAMP[4])
        bow.disc(tip[0], tip[1], 1.8 if arrow_state == "draw" else 3.0, hex_rgba("#4be89e"))
        if arrow_state == "charge":
            # Radiant golden-emerald starlight aura around charged arrowhead!
            bow.disc(tip[0], tip[1], 4.6, hex_rgba("#38c982", 140))
            bow.line(tip[0] - 7, tip[1], tip[0] + 7, tip[1], hex_rgba("#e8fff2"))
            bow.line(tip[0], tip[1] - 7, tip[0], tip[1] + 7, hex_rgba("#e8fff2"))
    elif arrow_state == "release":
        p0, p1 = rot(4.0, 0.0), rot(24.0, 0.0)
        bow.line(p0[0], p0[1], p1[0], p1[1], hex_rgba("#7ef7be"), r=0.9)
        bow.line(p0[0] + 4, p0[1], p1[0], p1[1], hex_rgba("#ffffff"))

    bow.blit_onto(dst)


def draw_elf_arm_side(
    dst: Layer, sx: float, sy: float, ex: float, ey: float, hx: float, hy: float
) -> None:
    """Draw ivory sleeve + forest-emerald bracer + slender elven hand."""
    sleeve = Layer(CELL, CELL)
    sleeve.capsule(sx, sy, ex, ey, 2.7, 2.3, IVORY_RAMP[3])
    sleeve.shade_ramp(IVORY_RAMP, light_dir=(-0.5, -0.8))
    sleeve.outline(OUT_ELF)
    sleeve.blit_onto(dst)

    bracer = Layer(CELL, CELL)
    mx = ex + (hx - ex) * 0.72
    my = ey + (hy - ey) * 0.72
    bracer.capsule(ex, ey, mx, my, 2.3, 1.9, EMERALD_RAMP[2])
    bracer.shade_ramp(EMERALD_RAMP, light_dir=(-0.5, -0.8))
    bracer.pset(int(round(ex)), int(round(ey)), GOLD_RAMP[3])
    bracer.outline(OUT_ELF)
    bracer.blit_onto(dst)

    hand = Layer(CELL, CELL)
    hand.disc(hx, hy, 2.0, SKIN_RAMP[3])
    hand.shade_ramp(SKIN_RAMP)
    hand.outline(OUT_ELF)
    hand.blit_onto(dst)


def render_sylvara_side(
    breath_dy: float = 0.0,
    sway_px: float = 0.0,
    flare: float = 0.0,
    blink: bool = False,
    lean_x: float = 0.0,
    lift_y: float = 0.0,
    l_leg: tuple = (-4, 92, -5, GROUND_Y),
    r_leg: tuple = (4, 92, 5, GROUND_Y),
    bow_pos: tuple = (14, 62, 16.0, 0.0, "none"),
    front_arm: tuple = (-2, 51, 5, 59, 13, 62),
    draw_back_bow_arm: tuple | None = None,
    wind_leaves: bool = False,
) -> Layer:
    """Compose a complete side-facing Sylvara frame with locked `GROUND_Y = 108`."""
    frame = Layer(CELL, CELL)
    cx = 62.0 + lean_x
    by = breath_dy * 0.6 + lift_y

    # 1. Quiver + Forest-Emerald gold-trimmed cloak
    draw_quiver_and_cloak_side(frame, cx - 3, 47 + by, sway_px=sway_px, flare=flare)

    # 2. Optional extended bow-holding off-arm (during bow draw/charge/release)
    if draw_back_bow_arm is not None:
        bsx, bsy, bex, bey, bhx, bhy = draw_back_bow_arm
        draw_elf_arm_side(frame, cx + bsx, bsy + by, cx + bex, bey + by, cx + bhx, bhy + by)

    # 3. Slender legs & gold-cuffed ranger boots
    g_skip = GROUND_Y if lift_y == 0.0 else None
    draw_elf_leg_side(
        frame, cx - 2, 74 + lift_y, cx + l_leg[0], l_leg[1] + lift_y, cx + l_leg[2], l_leg[3] + lift_y, is_back=True, ground_skip=g_skip
    )
    draw_elf_leg_side(
        frame, cx + 2, 74 + lift_y, cx + r_leg[0], r_leg[1] + lift_y, cx + r_leg[2], r_leg[3] + lift_y, is_back=False, ground_skip=g_skip
    )

    # 4. Emerald-and-ivory corset tunic & gold mantle
    draw_elf_torso_side(frame, cx, 58 + by, lean_x=lean_x * 0.4, sway_px=sway_px)

    # 5. Platinum-blonde elven head, emerald eye & pointed elf ear (steady in calm idle!)
    draw_elf_head_side(frame, cx + 1.0, 35 + lift_y, sway_px=sway_px, blink=blink)

    # 6. Ornate Golden-Wood Elven Recurve Bow + Front Arm
    bx_off, by_pos, b_ang, b_pull, a_state = bow_pos
    if draw_back_bow_arm is not None:
        # Bow in extended off-hand, front arm pulling bowstring!
        draw_recurve_bow(frame, cx + bx_off, by_pos + by, angle_deg=b_ang, pull_px=b_pull, arrow_state=a_state)
        sx, sy, ex, ey, hx, hy = front_arm
        draw_elf_arm_side(frame, cx + sx, sy + by, cx + ex, ey + by, cx + hx, hy + by)
    else:
        # Calm carry: bow held gracefully in front hand
        sx, sy, ex, ey, hx, hy = front_arm
        draw_recurve_bow(frame, cx + bx_off, by_pos + by, angle_deg=b_ang, pull_px=b_pull, arrow_state=a_state)
        draw_elf_arm_side(frame, cx + sx, sy + by, cx + ex, ey + by, cx + hx, hy + by)

    if wind_leaves:
        for lx, ly in ((22, 54), (16, 72), (28, 88), (36, 98)):
            frame.ellipse(lx, ly, 3.2, 1.4, hex_rgba("#6bf7b2", 230), angle_deg=-22)
            frame.line(lx - 6, ly + 2, lx + 2, ly, hex_rgba("#d8fff0", 200))
    return frame


def render_sylvara_front(step: int = 0, sway: float = 0.0, breath_dy: float = 0.0) -> Layer:
    """Front-facing (`DOWN`) Sylvara: platinum locks, pointed ears, emerald-gold bodice & bow."""
    frame = Layer(CELL, CELL)
    cx = 64.0
    by = breath_dy * 0.6

    # 1. Back cloak + long blonde hair + quiver tip peeking over left shoulder
    back = Layer(CELL, CELL)
    back.line(cx - 10, 38, cx - 15, 31, GOLD_RAMP[2], r=1.0)
    back.line(cx - 15, 31, cx - 17, 29, hex_rgba("#7bf0b5"))
    back.poly(
        [
            (cx - 12, 46 + by * 0.5),
            (cx + 12, 46 + by * 0.5),
            (cx + 16 + sway, 98),
            (cx, 95),
            (cx - 16 + sway, 98),
        ],
        EMERALD_RAMP[1],
    )
    back.shade_ramp(EMERALD_RAMP, dither=0.25)
    back.outline(OUT_CLOAK)
    back.blit_onto(frame)

    # 2. Legs & tall gold-cuffed ranger boots
    l_dy = -3 if step == 1 else 0
    r_dy = -3 if step == 2 else 0
    for side, dy in ((-1, l_dy), (1, r_dy)):
        lx = cx + side * 4.8
        leg = Layer(CELL, CELL)
        leg.capsule(lx, 74, lx, 89 + dy * 0.5, 3.3, 2.9, IVORY_RAMP[2])
        leg.shade_ramp(IVORY_RAMP)
        leg.outline(OUT_ELF)
        leg.blit_onto(frame)

        boot = Layer(CELL, CELL)
        boot.capsule(lx, 88 + dy * 0.5, lx, GROUND_Y - 3 + dy, 3.2, 2.8, BOOT_RAMP[2])
        boot.poly([(lx - 3.5, GROUND_Y - 4 + dy), (lx + 3.5, GROUND_Y - 4 + dy), (lx + 4, GROUND_Y + dy), (lx - 4, GROUND_Y + dy)], BOOT_RAMP[1])
        boot.shade_ramp(BOOT_RAMP)
        boot.line(lx - 3, 88 + dy * 0.5, lx + 3, 88 + dy * 0.5, GOLD_RAMP[3])
        boot.outline(OUT_ELF, skip_bottom_y=GROUND_Y)
        boot.blit_onto(frame)

    # 3. Emerald-gold corset tunic & mantle
    tor = Layer(CELL, CELL)
    tor.poly(
        [
            (cx - 8.5, 47 + by),
            (cx + 8.5, 47 + by),
            (cx + 6.5, 62 + by),
            (cx + 10.5 + sway * 0.3, 77),
            (cx - 10.5 + sway * 0.3, 77),
            (cx - 6.5, 62 + by),
        ],
        EMERALD_RAMP[2],
    )
    tor.shade_ramp(EMERALD_RAMP, dither=0.22)
    tor.poly([(cx - 3.5, 48 + by), (cx + 3.5, 48 + by), (cx + 2.5, 61 + by), (cx - 2.5, 61 + by)], IVORY_RAMP[3])
    tor.line(cx - 6.5, 62 + by, cx + 6.5, 62 + by, GOLD_RAMP[3])
    tor.ellipse(cx, 48 + by, 10.0, 3.2, EMERALD_RAMP[3])
    tor.disc(cx, 49 + by, 1.6, GOLD_RAMP[4])
    tor.outline(OUT_ELF)
    tor.blit_onto(frame)

    # 4. Slender arms + Golden Recurve Bow held at side
    draw_elf_arm_side(frame, cx - 9.5, 50 + by, cx - 11.5, 58 + by, cx - 10.5, 64 + by)
    draw_recurve_bow(frame, cx + 13.5, 62 + by, angle_deg=24.0)
    draw_elf_arm_side(frame, cx + 9.5, 50 + by, cx + 11.5, 58 + by, cx + 12.0, 63 + by)

    # 5. Front elven face, pointed ears, emerald eyes & cascading platinum locks
    hair = Layer(CELL, CELL)
    hair.ellipse(cx, 35, 9.5, 9.5, HAIR_RAMP[3])
    hair.ribbon([(cx - 7.5, 34), (cx - 9.0, 46), (cx - 8.5 + sway * 0.4, 56)], 2.4, 1.0, HAIR_RAMP[3], steps=14)
    hair.ribbon([(cx + 7.5, 34), (cx + 9.0, 46), (cx + 8.5 + sway * 0.4, 56)], 2.4, 1.0, HAIR_RAMP[3], steps=14)
    hair.shade_ramp(HAIR_RAMP, dither=0.2)
    hair.outline(OUT_ELF)
    hair.blit_onto(frame)

    # Pointed elf ears left & right
    ears = Layer(CELL, CELL)
    ears.poly([(cx - 6, 34), (cx - 13, 32), (cx - 7, 37)], SKIN_RAMP[3])
    ears.poly([(cx + 6, 34), (cx + 13, 32), (cx + 7, 37)], SKIN_RAMP[3])
    ears.poly([(cx - 6.0, 29), (cx + 6.0, 29), (cx + 5.5, 40), (cx, 42), (cx - 5.5, 40)], SKIN_RAMP[3])
    ears.shade_ramp(SKIN_RAMP)
    ears.outline(OUT_ELF)
    ears.blit_onto(frame)

    bangs = Layer(CELL, CELL)
    bangs.poly([(cx - 7.5, 29), (cx, 26), (cx + 7.5, 29), (cx + 6.5, 33), (cx, 31.5), (cx - 6.5, 33)], HAIR_RAMP[4])
    bangs.shade_ramp(HAIR_RAMP)
    bangs.disc(cx, 29.5, 1.4, hex_rgba("#5bf0a8"))
    bangs.outline(OUT_ELF)
    bangs.blit_onto(frame)

    for sx in (-2.8, 2.8):
        ix = int(round(cx + sx))
        frame.pset(ix, 35, hex_rgba("#1b6b4a"))
        frame.pset(ix, 36, hex_rgba("#54eba2"))
    return frame


def render_sylvara_back(step: int = 0, sway: float = 0.0, breath_dy: float = 0.0) -> Layer:
    """Back-facing (`UP`) Sylvara: waist-length platinum-blonde hair, emerald cloak, quiver & bow."""
    frame = Layer(CELL, CELL)
    cx = 64.0
    by = breath_dy * 0.6

    draw_recurve_bow(frame, cx + 13.5, 62 + by, angle_deg=22.0)

    # Boots peeking beneath emerald cloak
    l_dy = -3 if step == 1 else 0
    r_dy = -3 if step == 2 else 0
    for side, dy in ((-1, l_dy), (1, r_dy)):
        lx = cx + side * 4.8
        boot = Layer(CELL, CELL)
        boot.capsule(lx, 88, lx, GROUND_Y - 3 + dy, 3.2, 2.8, BOOT_RAMP[1])
        boot.poly([(lx - 3.5, GROUND_Y - 4 + dy), (lx + 3.5, GROUND_Y - 4 + dy), (lx + 4, GROUND_Y + dy), (lx - 4, GROUND_Y + dy)], BOOT_RAMP[0])
        boot.shade_ramp(BOOT_RAMP)
        boot.outline(OUT_ELF, skip_bottom_y=GROUND_Y)
        boot.blit_onto(frame)

    # Full Forest-Emerald gold-bordered cloak!
    cloak = Layer(CELL, CELL)
    cloak.poly(
        [
            (cx - 11, 46 + by * 0.5),
            (cx + 11, 46 + by * 0.5),
            (cx + 16 + sway, 98),
            (cx + 7 + sway * 0.5, 101),
            (cx + sway * 0.3, 97),
            (cx - 7 + sway * 0.5, 101),
            (cx - 16 + sway, 98),
        ],
        EMERALD_RAMP[2],
    )
    cloak.shade_ramp(EMERALD_RAMP, light_dir=(-0.45, -0.75), dither=0.26)
    cloak.line(cx - 15 + sway, 97, cx + 15 + sway, 97, GOLD_RAMP[3])
    cloak.outline(OUT_CLOAK)
    cloak.blit_onto(frame)

    # Diagonal Leather Quiver + Fletched Arrows strapped over cloak back
    qv = Layer(CELL, CELL)
    qv.capsule(cx - 5, 48 + by, cx + 3, 68 + by, 3.2, 2.8, BOOT_RAMP[2])
    qv.shade_ramp(BOOT_RAMP)
    for k in (-2, 0, 2):
        qv.line(cx - 6 + k, 46 + by, cx - 10 + k, 39 + by, GOLD_RAMP[3])
        qv.pset(int(cx - 10 + k), int(38 + by), hex_rgba("#7bf0b5"))
    qv.outline(OUT_ELF)
    qv.blit_onto(frame)

    # Pointed elf ears peeking out + cascading waist-length platinum-blonde hair!
    ears = Layer(CELL, CELL)
    ears.poly([(cx - 6, 34), (cx - 13, 32), (cx - 7, 37)], SKIN_RAMP[2])
    ears.poly([(cx + 6, 34), (cx + 13, 32), (cx + 7, 37)], SKIN_RAMP[2])
    ears.outline(OUT_ELF)
    ears.blit_onto(frame)

    hair = Layer(CELL, CELL)
    hair.poly(
        [
            (cx - 8, 28),
            (cx, 26),
            (cx + 8, 28),
            (cx + 10.5 + sway * 0.5, 58),
            (cx + 6 + sway * 0.7, 68),
            (cx + sway * 0.8, 71),
            (cx - 6 + sway * 0.7, 68),
            (cx - 10.5 + sway * 0.5, 58),
        ],
        HAIR_RAMP[3],
    )
    hair.shade_ramp(HAIR_RAMP, light_dir=(-0.45, -0.8), dither=0.22)
    for hx in (-4, 0, 4):
        hair.line(cx + hx * 0.7, 32, cx + hx + sway * 0.6, 65, HAIR_RAMP[1])
    hair.outline(OUT_ELF)
    hair.blit_onto(frame)
    return frame


def render_sylvara_kneel_death() -> Layer:
    """Frame 22 (`die_kneel`): Sinks gracefully onto one knee bracing on her Recurve Bow."""
    frame = Layer(CELL, CELL)
    cx = 60.0
    draw_quiver_and_cloak_side(frame, cx - 3, 62, sway_px=-1.5, flare=-0.15)
    draw_elf_leg_side(frame, cx - 2, 87, cx - 8, 104, cx - 13, GROUND_Y, is_back=True)
    draw_elf_leg_side(frame, cx + 2, 87, cx + 9, 96, cx + 8, GROUND_Y, is_back=False)
    draw_elf_torso_side(frame, cx + 1, 72, lean_x=3.0)
    draw_elf_head_side(frame, cx + 4, 51, sway_px=-1.0, blink=True)
    draw_recurve_bow(frame, cx + 16, 86, angle_deg=8.0)
    draw_elf_arm_side(frame, cx, 65, cx + 8, 76, cx + 15, 85)
    return frame


def render_sylvara_fallen_death() -> Layer:
    """Frame 23 (`die_fallen`): Collapsed gracefully on stone floor (`GROUND_Y = 108`)."""
    frame = Layer(CELL, CELL)
    draw_recurve_bow(frame, 92, GROUND_Y - 3, angle_deg=86.0)
    body = Layer(CELL, CELL)
    body.capsule(28, GROUND_Y - 4, 48, GROUND_Y - 5, 3.6, 4.0, BOOT_RAMP[2])
    body.capsule(48, GROUND_Y - 6, 72, GROUND_Y - 6, 5.2, 4.8, EMERALD_RAMP[2])
    body.shade_ramp(EMERALD_RAMP, light_dir=(-0.3, -0.9), dither=0.22)
    body.outline(OUT_ELF, skip_bottom_y=GROUND_Y)
    body.blit_onto(frame)

    cloak = Layer(CELL, CELL)
    cloak.poly([(34, GROUND_Y - 6), (54, GROUND_Y - 13), (72, GROUND_Y - 11), (68, GROUND_Y - 2), (32, GROUND_Y - 2)], EMERALD_RAMP[3])
    cloak.shade_ramp(EMERALD_RAMP, light_dir=(-0.3, -0.9))
    cloak.line(34, GROUND_Y - 3, 68, GROUND_Y - 3, GOLD_RAMP[3])
    cloak.outline(OUT_CLOAK, skip_bottom_y=GROUND_Y)
    cloak.blit_onto(frame)

    # Fallen elven head & platinum-blonde hair fanned horizontally along stone floor!
    head = Layer(CELL, CELL)
    head.ellipse(79, GROUND_Y - 7, 5.8, 5.2, SKIN_RAMP[3])
    head.shade_ramp(SKIN_RAMP, light_dir=(-0.3, -0.9))
    head.line(80, GROUND_Y - 7, 82, GROUND_Y - 7, OUT_ELF)
    head.outline(OUT_ELF, skip_bottom_y=GROUND_Y)
    head.blit_onto(frame)

    hair = Layer(CELL, CELL)
    hair.ribbon([(81, GROUND_Y - 11), (68, GROUND_Y - 11), (52, GROUND_Y - 6)], 4.2, 1.6, HAIR_RAMP[3], steps=20)
    hair.ribbon([(77, GROUND_Y - 9), (64, GROUND_Y - 7), (48, GROUND_Y - 3)], 3.6, 1.4, HAIR_RAMP[4], steps=20)
    hair.shade_ramp(HAIR_RAMP, light_dir=(-0.3, -0.9), dither=0.2)
    hair.poly([(75, GROUND_Y - 9), (69, GROUND_Y - 12), (74, GROUND_Y - 6)], SKIN_RAMP[3])  # pointed ear
    hair.outline(OUT_ELF, skip_bottom_y=GROUND_Y)
    hair.blit_onto(frame)
    return frame


def generate() -> None:
    sheet = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    labels = [
        "0:idle_0",
        "1:idle_1",
        "2:idle_2",
        "3:idle_blink",
        "4:walk_0",
        "5:walk_1",
        "6:walk_2",
        "7:walk_3",
        "8:down_idle_0",
        "9:down_idle_1",
        "10:down_walk_0",
        "11:down_walk_1",
        "12:up_idle_0",
        "13:up_idle_1",
        "14:up_walk_0",
        "15:up_walk_1",
        "16:bow_draw",
        "17:bow_charge",
        "18:bow_release",
        "19:bow_alt",
        "20:vault_dash",
        "21:hurt",
        "22:die_kneel",
        "23:die_fallen",
    ]

    frames: list[Layer] = [
        # --- ROW 0: CALM SIDE IDLE (4 frames — feet 100% planted, subtle 1px breath & hair!) ---
        render_sylvara_side(breath_dy=0.0, sway_px=0.0),
        render_sylvara_side(breath_dy=-1.0, sway_px=1.0),
        render_sylvara_side(breath_dy=-0.5, sway_px=1.5),
        render_sylvara_side(breath_dy=0.0, sway_px=0.5, blink=True),
        # --- ROW 0: 4-FRAME GROUNDED UPRIGHT SIDE WALK ---
        render_sylvara_side(
            sway_px=1.5,
            l_leg=(-8, 92, -11, GROUND_Y),
            r_leg=(8, 92, 10, GROUND_Y),
            front_arm=(-2, 51, 3, 59, 11, 63),
            bow_pos=(12, 63, 20.0, 0.0, "none"),
        ),
        render_sylvara_side(
            sway_px=2.0,
            l_leg=(-2, 90, -2, GROUND_Y - 3),
            r_leg=(3, 92, 3, GROUND_Y),
            front_arm=(-2, 51, 4, 59, 12, 62),
            bow_pos=(13, 62, 18.0, 0.0, "none"),
        ),
        render_sylvara_side(
            sway_px=1.5,
            l_leg=(8, 92, 10, GROUND_Y),
            r_leg=(-8, 92, -11, GROUND_Y),
            front_arm=(-2, 51, 7, 58, 15, 61),
            bow_pos=(16, 61, 14.0, 0.0, "none"),
        ),
        render_sylvara_side(
            sway_px=1.0,
            l_leg=(3, 92, 3, GROUND_Y),
            r_leg=(-2, 90, -2, GROUND_Y - 3),
            front_arm=(-2, 51, 5, 59, 13, 62),
            bow_pos=(14, 62, 16.0, 0.0, "none"),
        ),
        # --- ROW 1: FRONT (DOWN) & BACK (UP) CALM IDLES + WALKS ---
        render_sylvara_front(step=0, sway=0.0, breath_dy=0.0),
        render_sylvara_front(step=0, sway=1.0, breath_dy=-1.0),
        render_sylvara_front(step=1, sway=1.2, breath_dy=-0.5),
        render_sylvara_front(step=2, sway=-1.2, breath_dy=-0.5),
        render_sylvara_back(step=0, sway=0.0, breath_dy=0.0),
        render_sylvara_back(step=0, sway=1.2, breath_dy=-1.0),
        render_sylvara_back(step=1, sway=1.5, breath_dy=-0.5),
        render_sylvara_back(step=2, sway=-1.5, breath_dy=-0.5),
        # --- ROW 2: RECURVE BOW DRAW / CHARGE / RELEASE, SYLVAN VAULT, HURT, & DEATH ---
        # 16: `bow_draw` — raises golden recurve bow, arrow nocked & half-drawn
        render_sylvara_side(
            sway_px=1.5,
            l_leg=(-6, 92, -8, GROUND_Y),
            r_leg=(6, 92, 8, GROUND_Y),
            draw_back_bow_arm=(3, 49, 12, 50, 20, 50),
            bow_pos=(22, 50, 0.0, 5.0, "draw"),
            front_arm=(-3, 50, 3, 51, 10, 50),
        ),
        # 17: `bow_charge` — full taut draw to cheek with blazing emerald-gold starlight arrow!
        render_sylvara_side(
            flare=0.35,
            sway_px=2.0,
            l_leg=(-7, 92, -10, GROUND_Y),
            r_leg=(7, 92, 9, GROUND_Y),
            draw_back_bow_arm=(3, 49, 13, 49, 21, 49),
            bow_pos=(23, 49, 0.0, 10.5, "charge"),
            front_arm=(-4, 49, -6, 48, 5, 49),
        ),
        # 18: `bow_release` — crisp bowstring snap & arrow release streak!
        render_sylvara_side(
            flare=0.45,
            sway_px=2.5,
            l_leg=(-7, 92, -10, GROUND_Y),
            r_leg=(7, 92, 9, GROUND_Y),
            draw_back_bow_arm=(3, 49, 13, 49, 21, 49),
            bow_pos=(23, 49, 0.0, 0.0, "release"),
            front_arm=(-4, 49, -9, 46, -4, 45),
        ),
        # 19: `bow_alt` — swift follow-through poise
        render_sylvara_side(
            flare=0.25,
            lean_x=1.5,
            l_leg=(-6, 92, -8, GROUND_Y),
            r_leg=(6, 92, 8, GROUND_Y),
            draw_back_bow_arm=(3, 50, 12, 53, 19, 55),
            bow_pos=(21, 55, 8.0, 3.0, "draw"),
            front_arm=(-3, 50, 2, 53, 9, 54),
        ),
        # 20: `vault` (`charge` / `Shift`) — graceful Sylvan Gale airborne vault!
        render_sylvara_side(
            flare=0.95,
            sway_px=3.0,
            lean_x=3.5,
            lift_y=-4.0,
            l_leg=(-9, 89, -15, GROUND_Y - 4),
            r_leg=(8, 88, 5, GROUND_Y - 6),
            bow_pos=(17, 56, -12.0, 0.0, "none"),
            front_arm=(0, 49, 9, 53, 16, 56),
            wind_leaves=True,
        ),
        # 21: `hurt` — graceful stagger recoil
        render_sylvara_side(
            flare=0.35,
            lean_x=-3.0,
            blink=True,
            l_leg=(-5, 92, -8, GROUND_Y),
            r_leg=(4, 92, 7, GROUND_Y),
            bow_pos=(12, 56, 28.0, 0.0, "none"),
            front_arm=(-3, 49, 4, 52, 11, 55),
        ),
        # 22 & 23: Kneeling -> Fallen Collapse Death (`die`)
        render_sylvara_kneel_death(),
        render_sylvara_fallen_death(),
    ]

    for idx, layer in enumerate(frames):
        c_idx = idx % COLS
        r_idx = idx // COLS
        sheet.paste(layer.to_image(), (c_idx * CELL, r_idx * CELL))

    out_sheet = "assets/textures/player_pari.png"
    os.makedirs(os.path.dirname(out_sheet), exist_ok=True)
    sheet.save(out_sheet)

    scale = 2
    tile_w = CELL * scale
    tile_h = CELL * scale + 22
    prev = Image.new("RGBA", (COLS * tile_w + 16, ROWS * tile_h + 36), (12, 22, 18, 255))
    pdraw = ImageDraw.Draw(prev)
    pdraw.text((12, 8), "REDESIGNED SYLVARA HIGH-ELF ARCHER (PARI) - 24 frames (8x3 @ 128x128)", fill=(222, 245, 232, 255))
    for idx, layer in enumerate(frames):
        c_idx = idx % COLS
        r_idx = idx // COLS
        ox = 8 + c_idx * tile_w
        oy = 30 + r_idx * tile_h
        pdraw.rectangle([ox + 2, oy + 2, ox + tile_w - 3, oy + CELL * scale - 2], fill=(20, 34, 28, 255), outline=(52, 86, 68, 255))
        gy = oy + GROUND_Y * scale
        pdraw.line([(ox + 6, gy), (ox + tile_w - 6, gy)], fill=(76, 128, 98, 140))
        up = layer.to_image().resize((CELL * scale, CELL * scale), Image.Resampling.NEAREST)
        prev.alpha_composite(up, (ox, oy))
        pdraw.text((ox + 6, oy + CELL * scale + 3), labels[idx], fill=(188, 226, 204, 255))

    os.makedirs("docs/images", exist_ok=True)
    prev.save("docs/images/sylvara_preview.png")
    print(f"Generated {out_sheet} ({sheet.size}) and docs/images/sylvara_preview.png")


if __name__ == "__main__":
    generate()
