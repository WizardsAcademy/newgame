#!/usr/bin/env python3
"""Hand-craft the redesigned 24-frame (8x3, 128x128) Behemoth Brawler spritesheet.

Inspired by feral dark-fantasy pit-champion barbarians (reference-only — 100%
original procedural pixel art built from scratch with `tools/pixel_art_kit.py`):
  - Towering bare-chested muscular warrior with diagonal chest battle-scar
  - Wild flowing dark-umber mane & thick full beard + fierce amber eyes
  - Shaggy dark wolf/beast-pelt mantle draped over shoulders & cascading down back
  - Heavy brass/iron champion medallion belt + tattered blood-crimson loincloth
  - Spiked iron-and-leather cestus gauntlets & fur-trimmed war-boots
  - Calm, subtle 4-frame side idle (`idle_0..3`), 2-frame front/back idles,
    4-frame grounded 4-dir walks, 3-hit Cestus Combo (`jab`, `cross`, `uppercut`),
    Shoulder Charge, Hurt, and 2-stage Kneel -> Fallen collapse death (`die`)!

Outputs:
  - assets/textures/player_borzo.png    (1024 x 384 RGBA, 8 cols x 3 rows of 128x128)
  - docs/images/brawler_preview.png     (2x crisp nearest-neighbor labeled contact sheet)
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

OUT_DARK = hex_rgba("#140b0a")
OUT_PELT = hex_rgba("#0c090c")
OUT_IRON = hex_rgba("#0d1017")

SKIN_RAMP = [
    hex_rgba("#5e362a"),
    hex_rgba("#844f3e"),
    hex_rgba("#ac6c56"),
    hex_rgba("#d18c72"),
    hex_rgba("#ebb299"),
]

BACK_SKIN_RAMP = [
    hex_rgba("#4a2a21"),
    hex_rgba("#6c3f31"),
    hex_rgba("#8e5745"),
    hex_rgba("#b0725c"),
]

HAIR_RAMP = [
    hex_rgba("#110b0c"),
    hex_rgba("#201516"),
    hex_rgba("#352323"),
    hex_rgba("#4e3533"),
    hex_rgba("#6c4c48"),
]

PELT_RAMP = [
    hex_rgba("#151014"),
    hex_rgba("#251d23"),
    hex_rgba("#3a2e36"),
    hex_rgba("#55444e"),
    hex_rgba("#76616c"),
]

CRIMSON_RAMP = [
    hex_rgba("#3d0b14"),
    hex_rgba("#691422"),
    hex_rgba("#9c2033"),
    hex_rgba("#cc364b"),
]

LEATHER_RAMP = [
    hex_rgba("#1b120e"),
    hex_rgba("#2f2019"),
    hex_rgba("#4a3328"),
    hex_rgba("#694a3a"),
]

IRON_RAMP = [
    hex_rgba("#1c212c"),
    hex_rgba("#30384a"),
    hex_rgba("#4b566e"),
    hex_rgba("#73829e"),
    hex_rgba("#b4c3de"),
]

GOLD_RAMP = [
    hex_rgba("#4d391b"),
    hex_rgba("#7d5e2f"),
    hex_rgba("#b58c49"),
    hex_rgba("#e3bd74"),
    hex_rgba("#fff0be"),
]


def draw_beast_pelt_side(
    dst: Layer, sx: float, sy: float, sway_px: float = 0.0, flare: float = 0.0
) -> None:
    """Draw shaggy dark wolf/beast-pelt mantle cascading down Behemoth's back."""
    p = Layer(CELL, CELL)
    tufts = [
        (-3, -2, -16 - flare * 13 - sway_px * 0.9, 86 - flare * 8, 7.2, 1.8),
        (0, 0, -12 - flare * 10 - sway_px * 1.0, 94 - flare * 6, 7.5, 2.0),
        (3, 2, -6 - flare * 7 - sway_px * 0.7, 90 - flare * 4, 6.5, 1.8),
        (-5, 6, -19 - flare * 11 - sway_px * 0.8, 72 - flare * 5, 5.2, 1.2),
    ]
    for ox, oy, tx, ty, r0, r1 in tufts:
        x0, y0 = sx + ox, sy + oy
        mx = x0 + tx * 0.52
        my = y0 + (ty - y0) * 0.48
        p.ribbon([(x0, y0), (mx, my), (sx + tx, ty)], r0, r1, PELT_RAMP[2], steps=24)
    p.shade_ramp(PELT_RAMP, light_dir=(-0.55, -0.75), dither=0.36)
    # Crisp fur-lock shadow grooves
    for k in range(3):
        p.line(sx - 3 - k * 2, sy + 10 + k * 4, sx - 10 - k * 3 - sway_px * 0.6 - flare * 5, 82 + k * 3 - flare * 4, PELT_RAMP[0])
    p.outline(OUT_PELT)
    p.blit_onto(dst)


def draw_brawler_leg_side(
    dst: Layer,
    hip_x: float,
    hip_y: float,
    knee_x: float,
    knee_y: float,
    foot_x: float,
    foot_y: float,
    is_back: bool = False,
) -> None:
    """Draw muscular bare/breeches thigh + fur-trimmed heavy leather war-boot."""
    leg = Layer(CELL, CELL)
    skin = BACK_SKIN_RAMP if is_back else SKIN_RAMP
    # Muscular thigh
    leg.capsule(hip_x, hip_y, knee_x, knee_y, 5.0, 4.1, skin[2])
    leg.shade_ramp(skin, light_dir=(-0.5, -0.8), dither=0.22)
    leg.outline(OUT_DARK)
    leg.blit_onto(dst)

    # Fur-trimmed war-boot + leather shin greave planted flat on GROUND_Y
    boot = Layer(CELL, CELL)
    boot.capsule(knee_x, knee_y + 1, foot_x, foot_y - 4, 4.1, 3.7, LEATHER_RAMP[2])
    boot.poly(
        [
            (foot_x - 5.0, foot_y - 5.0),
            (foot_x + 5.0, foot_y - 4.5),
            (foot_x + 9.0, foot_y - 1.5),
            (foot_x + 8.5, foot_y),
            (foot_x - 5.5, foot_y),
        ],
        LEATHER_RAMP[1],
    )
    boot.shade_ramp(LEATHER_RAMP, light_dir=(-0.5, -0.8), dither=0.24)
    # Shaggy fur boot-cuff + iron shin stud
    boot.ellipse(knee_x + 0.5, knee_y + 1.5, 4.8, 2.2, PELT_RAMP[3])
    boot.line(foot_x - 5, foot_y - 1, foot_x + 8, foot_y - 1, LEATHER_RAMP[0])
    boot.disc(foot_x + 1.5, (knee_y + foot_y) * 0.5, 1.2, IRON_RAMP[3])
    boot.outline(OUT_DARK, skip_bottom_y=GROUND_Y)
    boot.blit_onto(dst)


def draw_brawler_torso_side(
    dst: Layer, cx: float, cy: float, lean_x: float = 0.0, sway_px: float = 0.0
) -> None:
    """Draw broad sculpted bare chest, abs, diagonal scar, medallion belt & crimson loincloth."""
    tor = Layer(CELL, CELL)
    # Heroic broad V-tapered muscular torso
    pts = [
        (cx - 10.0 + lean_x, cy - 12),
        (cx + 10.5 + lean_x, cy - 12),
        (cx + 11.5 + lean_x * 0.7, cy - 3),
        (cx + 8.5 + lean_x * 0.4, cy + 8),
        (cx - 8.5 + lean_x * 0.4, cy + 8),
        (cx - 10.5 + lean_x * 0.7, cy - 2),
    ]
    tor.poly(pts, SKIN_RAMP[2])
    tor.shade_ramp(SKIN_RAMP, light_dir=(-0.5, -0.8), dither=0.24, rim_right=True)

    # Pectoral definition, abdominal ridges & diagonal battle-scar!
    tor.line(cx - 2 + lean_x * 0.7, cy - 3, cx + 8 + lean_x * 0.7, cy - 3, SKIN_RAMP[0])
    tor.line(cx + 5 + lean_x * 0.6, cy - 9, cx + 5, cy + 5, SKIN_RAMP[1])
    tor.line(cx + 1, cy + 1, cx + 7, cy + 1, SKIN_RAMP[1])
    # Battle-scar across chest
    tor.line(cx - 1 + lean_x * 0.6, cy - 9, cx + 7 + lean_x * 0.5, cy - 2, hex_rgba("#6e2724"))
    tor.line(cx + lean_x * 0.6, cy - 9, cx + 8 + lean_x * 0.5, cy - 2, SKIN_RAMP[4])
    tor.outline(OUT_DARK)
    tor.blit_onto(dst)

    # Tattered Crimson Loincloth + Heavy Iron-Brass Champion Belt
    kilt = Layer(CELL, CELL)
    kilt.poly(
        [
            (cx - 9.0, cy + 8),
            (cx + 9.0, cy + 8),
            (cx + 10.0, cy + 16),
            (cx - 9.5, cy + 16),
        ],
        LEATHER_RAMP[1],
    )
    # Hanging tattered crimson front & side loincloth sash
    kilt.poly(
        [
            (cx - 1.0, cy + 9),
            (cx + 7.5, cy + 9),
            (cx + 8.5 - sway_px * 0.4, cy + 25),
            (cx + 4.0 - sway_px * 0.3, cy + 22),
            (cx + 0.5 - sway_px * 0.4, cy + 26),
        ],
        CRIMSON_RAMP[2],
    )
    kilt.shade_ramp(CRIMSON_RAMP, light_dir=(-0.5, -0.7), dither=0.22)
    # Studded leather belt + brass champion buckle medallion
    kilt.line(cx - 9, cy + 7, cx + 9, cy + 7, LEATHER_RAMP[1], r=1.4)
    kilt.line(cx - 8, cy + 6, cx + 8, cy + 6, LEATHER_RAMP[3])
    kilt.disc(cx + 4.0, cy + 7.5, 2.8, GOLD_RAMP[2])
    kilt.disc(cx + 4.0, cy + 7.5, 1.6, GOLD_RAMP[4])
    kilt.outline(OUT_DARK)
    kilt.blit_onto(dst)

    # Asymmetric Wolf-Pelt Shoulder Collar draped across upper shoulders
    fur = Layer(CELL, CELL)
    fur.ellipse(cx - 3.5 + lean_x * 0.8, cy - 11.5, 9.5, 4.2, PELT_RAMP[3], angle_deg=-8)
    fur.shade_ramp(PELT_RAMP, light_dir=(-0.5, -0.8), dither=0.32)
    fur.outline(OUT_PELT)
    fur.blit_onto(dst)


def draw_brawler_head_side(
    dst: Layer, cx: float, hy: float, sway_px: float = 0.0, blink: bool = False, roar: bool = False
) -> None:
    """Draw fierce bearded barbarian head + wild flowing dark-umber mane (facing right)."""
    # 1. Flowing back mane locks behind head/neck
    mane_back = Layer(CELL, CELL)
    for ox, oy, tx, ty, r0 in (
        (-5, -4, -15 - sway_px, 16, 5.2),
        (-3, 0, -12 - sway_px * 0.8, 20, 4.8),
        (-6, -7, -13 - sway_px * 0.6, 9, 4.4),
    ):
        mane_back.ribbon(
            [(cx + ox, hy + oy), (cx + (ox + tx) * 0.55, hy + (oy + ty) * 0.5), (cx + tx, hy + ty)],
            r0,
            1.4,
            HAIR_RAMP[2],
            steps=16,
        )
    mane_back.shade_ramp(HAIR_RAMP, light_dir=(-0.5, -0.8), dither=0.28)
    mane_back.outline(OUT_DARK)
    mane_back.blit_onto(dst)

    # 2. Rugged brow, nose & cheekbones (openly visible warrior face!)
    face = Layer(CELL, CELL)
    face.poly(
        [
            (cx - 4.5, hy - 7.5),
            (cx + 6.8, hy - 7.0),
            (cx + 8.8, hy - 0.5),
            (cx + 7.5, hy + 5.5),
            (cx - 4.0, hy + 5.5),
            (cx - 5.5, hy),
        ],
        SKIN_RAMP[2],
    )
    face.shade_ramp(SKIN_RAMP, light_dir=(-0.45, -0.8), dither=0.2, rim_right=True)
    # Prominent warrior nose & cheekbone highlight
    face.pset(int(round(cx + 8)), int(round(hy)), SKIN_RAMP[4])
    face.pset(int(round(cx + 4)), int(round(hy + 1)), SKIN_RAMP[3])
    face.outline(OUT_DARK)
    face.blit_onto(dst)

    # 3. Wild swept-back crown hair & sculpted lower jaw beard (leaving cheek & nose clear!)
    hair = Layer(CELL, CELL)
    hair.poly(
        [
            (cx - 8.5, hy - 4),
            (cx - 5.5, hy - 10.5),
            (cx + 2.5, hy - 10.8),
            (cx + 7.0, hy - 7.5),
            (cx + 2.0, hy - 6.2),
            (cx - 2.5, hy - 4.5),
            (cx - 4.5, hy + 1.0),
        ],
        HAIR_RAMP[2],
    )
    # Sculpted lower jaw beard + mustache framing mouth (does NOT cover cheek/nose!)
    hair.poly(
        [
            (cx - 2.5, hy + 2.5),
            (cx + 2.0, hy + 3.5),
            (cx + 8.0, hy + 2.8),
            (cx + 8.5, hy + 6.5),
            (cx + 5.0, hy + 10.2),
            (cx - 1.0, hy + 9.2),
            (cx - 3.5, hy + 5.5),
        ],
        HAIR_RAMP[2],
    )
    hair.shade_ramp(HAIR_RAMP, light_dir=(-0.5, -0.8), dither=0.26)
    if roar:
        hair.line(cx + 4, hy + 5, cx + 7, hy + 5, hex_rgba("#f5ead6"))
    hair.outline(OUT_DARK)
    hair.blit_onto(dst)

    # 4. Fierce furrowed brow + piercing amber warrior eye
    ey = int(round(hy - 2))
    ex = int(round(cx + 4))
    dst.line(ex - 2, ey - 2, ex + 2, ey - 1, OUT_DARK)
    if blink:
        dst.line(ex - 1, ey, ex + 2, ey, OUT_DARK)
    else:
        dst.pset(ex - 1, ey, OUT_DARK)
        dst.pset(ex, ey, hex_rgba("#ffcf66"))
        dst.pset(ex + 1, ey, hex_rgba("#fff4cc"))


def draw_cestus_arm_side(
    dst: Layer,
    sx: float,
    sy: float,
    ex: float,
    ey: float,
    hx: float,
    hy: float,
    is_back: bool = False,
) -> None:
    """Draw muscular bare deltoid/bicep/forearm + dark-leather bracer + iron-studded fist."""
    skin = BACK_SKIN_RAMP if is_back else SKIN_RAMP
    arm = Layer(CELL, CELL)
    arm.disc(sx, sy, 4.6, skin[2])
    arm.capsule(sx, sy, ex, ey, 4.1, 3.5, skin[2])
    # Upper half of forearm is muscular bare skin too!
    mx = ex + (hx - ex) * 0.38
    my = ey + (hy - ey) * 0.38
    arm.capsule(ex, ey, mx, my, 3.5, 3.3, skin[2])
    arm.shade_ramp(skin, light_dir=(-0.5, -0.8), dither=0.2, rim_right=not is_back)
    arm.outline(OUT_DARK)
    arm.blit_onto(dst)

    # Dark studded leather wrist-bracer
    bracer = Layer(CELL, CELL)
    wx = ex + (hx - ex) * 0.80
    wy = ey + (hy - ey) * 0.80
    bracer.capsule(mx, my, wx, wy, 3.4, 3.3, LEATHER_RAMP[2])
    bracer.shade_ramp(LEATHER_RAMP, light_dir=(-0.5, -0.8), dither=0.22)
    bracer.pset(int(round((mx + wx) * 0.5)), int(round((my + wy) * 0.5)), GOLD_RAMP[3])
    bracer.outline(OUT_DARK)
    bracer.blit_onto(dst)

    # Heavy iron-knuckled cestus fist!
    fist = Layer(CELL, CELL)
    fist.disc(hx, hy, 3.9, SKIN_RAMP[2])
    ang = math.atan2(hy - ey, hx - ex)
    dx, dy = math.cos(ang), math.sin(ang)
    px, py = -dy, dx
    fist.capsule(hx + dx * 1.2 - px * 2.2, hy + dy * 1.2 - py * 2.2, hx + dx * 1.2 + px * 2.2, hy + dy * 1.2 + py * 2.2, 2.2, 2.2, IRON_RAMP[2])
    fist.shade_ramp(IRON_RAMP, light_dir=(-0.5, -0.8))
    for k in (-2.0, 0.0, 2.0):
        kx = int(round(hx + dx * 3.5 + px * k))
        ky = int(round(hy + dy * 3.5 + py * k))
        fist.pset(kx, ky, IRON_RAMP[4])
    fist.outline(OUT_IRON)
    fist.blit_onto(dst)


def draw_punch_impact_fx(
    dst: Layer, fx_x: float, fx_y: float, style: str = "jab"
) -> None:
    """Hand-pixelled golden-amber Cestus shockwave / uppercut arc inside 128x128."""
    fx = Layer(CELL, CELL)
    c_deep = hex_rgba("#b85218", 220)
    c_mid = hex_rgba("#f5a638", 245)
    c_hot = hex_rgba("#fff6c4", 255)
    if style == "jab":
        for deg in (-28, 0, 28):
            r = math.radians(deg)
            fx.line(fx_x, fx_y, fx_x + math.cos(r) * 13, fx_y + math.sin(r) * 9, c_mid, r=0.8)
            fx.line(fx_x + 2, fx_y, fx_x + math.cos(r) * 9, fx_y + math.sin(r) * 6, c_hot)
        fx. ribbon([(fx_x - 3, fx_y - 10), (fx_x + 7, fx_y), (fx_x - 3, fx_y + 10)], 1.6, 1.2, c_hot, steps=18)
    elif style == "cross":
        # Heavy double shock-ring + kinetic streaks
        for i in range(36):
            t = i / 35
            ang = math.radians(-78 + 156 * t)
            w = 0.7 + 2.8 * math.sin(math.pi * t)
            x = fx_x + math.cos(ang) * 12
            y = fx_y + math.sin(ang) * 15
            fx.disc(x, y, w, c_deep)
            fx.disc(x + 1.2, y, w * 0.6, c_mid)
            fx.disc(x + 2.0, y, max(0.6, w * 0.3), c_hot)
        for wy in (-6, 0, 6):
            fx.line(fx_x - 16, fx_y + wy, fx_x + 4, fx_y + wy, c_hot)
    elif style == "uppercut":
        # Explosive rising golden fist arc from knees to overhead!
        steps = 56
        for i in range(steps + 1):
            t = i / steps
            ang = math.radians(68 - 148 * t)
            w = 0.6 + 4.4 * (t ** 0.7) * (math.sin(math.pi * min(1.0, t * 0.94 + 0.06)) ** 0.8)
            x = fx_x + math.cos(ang) * 28
            y = fx_y + math.sin(ang) * 34
            fx.disc(x, y, w, c_deep)
            fx.disc(x + 1.2, y - 0.8, w * 0.64, c_mid)
            if t > 0.2:
                fx.disc(x + 2.0, y - 1.4, max(0.6, w * 0.32), c_hot)
    fx.blit_onto(dst)


def render_brawler_side(
    breath_dy: float = 0.0,
    sway_px: float = 0.0,
    flare: float = 0.0,
    blink: bool = False,
    roar: bool = False,
    lean_x: float = 0.0,
    l_leg: tuple = (-5, 91, -7, GROUND_Y),
    r_leg: tuple = (6, 91, 6, GROUND_Y),
    back_arm: tuple = (4, 50, 12, 57, 19, 54),
    front_arm: tuple = (-4, 51, 3, 60, 13, 57),
    impact_fx: tuple | None = None,
    charge_streaks: bool = False,
) -> Layer:
    """Compose a complete side-facing Behemoth frame with locked `GROUND_Y = 108`."""
    frame = Layer(CELL, CELL)
    cx = 62.0 + lean_x

    # 1. Shaggy dark wolf-pelt mantle cascading behind shoulders
    draw_beast_pelt_side(frame, cx - 5, 44 + breath_dy * 0.5, sway_px=sway_px, flare=flare)

    # 2. Back arm (lead right-side off-hand)
    draw_cestus_arm_side(
        frame,
        cx + back_arm[0],
        back_arm[1] + breath_dy * 0.6,
        cx + back_arm[2],
        back_arm[3] + breath_dy * 0.5,
        cx + back_arm[4],
        back_arm[5] + breath_dy * 0.5,
        is_back=True,
    )

    # 3. Muscular legs & fur-trimmed war-boots planted on GROUND_Y = 108
    draw_brawler_leg_side(frame, cx - 3, 74, cx + l_leg[0], l_leg[1], cx + l_leg[2], l_leg[3], is_back=True)
    draw_brawler_leg_side(frame, cx + 3, 74, cx + r_leg[0], r_leg[1], cx + r_leg[2], r_leg[3], is_back=False)

    # 4. Broad scarred chest, champion belt & crimson loincloth
    draw_brawler_torso_side(frame, cx, 57 + breath_dy * 0.7, lean_x=lean_x * 0.4, sway_px=sway_px)

    # 5. Fierce bearded head & wild dark mane (steady head during calm idle!)
    draw_brawler_head_side(frame, cx + 1.5, 33, sway_px=sway_px, blink=blink, roar=roar)

    # 6. Front muscular arm & spiked iron cestus
    draw_cestus_arm_side(
        frame,
        cx + front_arm[0],
        front_arm[1] + breath_dy * 0.6,
        cx + front_arm[2],
        front_arm[3] + breath_dy * 0.5,
        cx + front_arm[4],
        front_arm[5] + breath_dy * 0.5,
        is_back=False,
    )

    if impact_fx is not None:
        draw_punch_impact_fx(frame, *impact_fx)
    if charge_streaks:
        for wy, wx0, wx1 in ((48, 14, 34), (64, 10, 30), (84, 18, 36)):
            frame.line(wx0, wy, wx1, wy, hex_rgba("#f5a638", 215))
            frame.line(wx0 + 4, wy + 1, wx1, wy + 1, hex_rgba("#fff4c2", 235))
    return frame


def render_brawler_front(step: int = 0, sway: float = 0.0, breath_dy: float = 0.0) -> Layer:
    """Front-facing (`DOWN`) Behemoth: pelt shoulders, scarred chest, crimson sash, twin cestus."""
    frame = Layer(CELL, CELL)
    cx = 64.0
    by = breath_dy * 0.7

    # 1. Back shaggy beast-pelt silhouette
    pelt = Layer(CELL, CELL)
    pelt.poly(
        [
            (cx - 16, 42 + by * 0.5),
            (cx + 16, 42 + by * 0.5),
            (cx + 18 + sway, 88),
            (cx + 10, 94),
            (cx, 89),
            (cx - 10, 94),
            (cx - 18 + sway, 88),
        ],
        PELT_RAMP[1],
    )
    pelt.shade_ramp(PELT_RAMP, light_dir=(-0.4, -0.8), dither=0.34)
    pelt.outline(OUT_PELT)
    pelt.blit_onto(frame)

    # 2. Front legs & fur-cuffed boots
    l_dy = -3 if step == 1 else 0
    r_dy = -3 if step == 2 else 0
    for side, dy in ((-1, l_dy), (1, r_dy)):
        lx = cx + side * 6.5
        leg = Layer(CELL, CELL)
        leg.capsule(lx, 74, lx, 90 + dy * 0.5, 4.8, 4.0, SKIN_RAMP[2])
        leg.shade_ramp(SKIN_RAMP)
        leg.outline(OUT_DARK)
        leg.blit_onto(frame)

        boot = Layer(CELL, CELL)
        boot.capsule(lx, 90 + dy * 0.5, lx, GROUND_Y - 3 + dy, 4.1, 3.8, LEATHER_RAMP[2])
        boot.poly([(lx - 4.5, GROUND_Y - 4 + dy), (lx + 4.5, GROUND_Y - 4 + dy), (lx + 5, GROUND_Y + dy), (lx - 5, GROUND_Y + dy)], LEATHER_RAMP[1])
        boot.shade_ramp(LEATHER_RAMP)
        boot.ellipse(lx, 90 + dy * 0.5, 4.6, 2.0, PELT_RAMP[3])
        boot.outline(OUT_DARK, skip_bottom_y=GROUND_Y)
        boot.blit_onto(frame)

    # 3. Broad bare chest + scar + medallion belt + tattered crimson loincloth
    tor = Layer(CELL, CELL)
    tor.poly([(cx - 12, 44 + by), (cx + 12, 44 + by), (cx + 9.5, 65 + by), (cx - 9.5, 65 + by)], SKIN_RAMP[2])
    tor.shade_ramp(SKIN_RAMP, light_dir=(-0.45, -0.8), dither=0.22)
    tor.line(cx, 46 + by, cx, 63 + by, SKIN_RAMP[1])
    tor.line(cx - 8, 53 + by, cx + 8, 53 + by, SKIN_RAMP[0])
    tor.line(cx - 6, 47 + by, cx + 5, 56 + by, hex_rgba("#6e2724"))
    tor.outline(OUT_DARK)
    tor.blit_onto(frame)

    kilt = Layer(CELL, CELL)
    kilt.poly([(cx - 10, 65), (cx + 10, 65), (cx + 11, 75), (cx - 11, 75)], LEATHER_RAMP[1])
    kilt.poly([(cx - 5.5, 66), (cx + 5.5, 66), (cx + 6.5 + sway * 0.5, 86), (cx, 82), (cx - 6.5 + sway * 0.5, 86)], CRIMSON_RAMP[2])
    kilt.shade_ramp(CRIMSON_RAMP)
    kilt.line(cx - 10, 65, cx + 10, 65, LEATHER_RAMP[2], r=1.4)
    kilt.disc(cx, 65.5, 2.8, GOLD_RAMP[3])
    kilt.disc(cx, 65.5, 1.4, GOLD_RAMP[4])
    kilt.outline(OUT_DARK)
    kilt.blit_onto(frame)

    # Pelt shoulder pads
    pads = Layer(CELL, CELL)
    pads.ellipse(cx - 11, 45 + by, 6.2, 4.0, PELT_RAMP[3], angle_deg=18)
    pads.ellipse(cx + 11, 45 + by, 6.2, 4.0, PELT_RAMP[3], angle_deg=-18)
    pads.shade_ramp(PELT_RAMP, dither=0.3)
    pads.outline(OUT_PELT)
    pads.blit_onto(frame)

    # 4. Twin muscular arms & iron cestus fists
    for side in (-1, 1):
        draw_cestus_arm_side(
            frame,
            cx + side * 12.5,
            49 + by,
            cx + side * 15.0,
            58 + by,
            cx + side * 12.5,
            65 + by,
        )

    # 5. Front bearded barbarian head & wild dark mane
    head = Layer(CELL, CELL)
    head.ellipse(cx, 33, 10.5, 10.0, HAIR_RAMP[2])
    head.shade_ramp(HAIR_RAMP, dither=0.28)
    head.outline(OUT_DARK)
    head.blit_onto(frame)

    face = Layer(CELL, CELL)
    face.poly([(cx - 6.5, 27), (cx + 6.5, 27), (cx + 6.8, 38), (cx - 6.8, 38)], SKIN_RAMP[2])
    face.shade_ramp(SKIN_RAMP)
    face.pset(int(cx), 34, SKIN_RAMP[4])  # nose bridge highlight
    face.outline(OUT_DARK)
    face.blit_onto(frame)

    beard = Layer(CELL, CELL)
    beard.poly([(cx - 7.0, 36.5), (cx, 35.5), (cx + 7.0, 36.5), (cx + 6.2, 42), (cx, 44.5), (cx - 6.2, 42)], HAIR_RAMP[2])
    beard.poly([(cx - 8, 24), (cx, 22), (cx + 8, 24), (cx + 7, 28), (cx - 7, 28)], HAIR_RAMP[2])
    beard.shade_ramp(HAIR_RAMP, dither=0.26)
    beard.outline(OUT_DARK)
    beard.blit_onto(frame)

    for sx in (-3, 3):
        frame.line(cx + sx - 1, 30, cx + sx + 1, 30, OUT_DARK)
        frame.pset(int(cx + sx), 31, hex_rgba("#ffcf66"))
        frame.pset(int(cx + sx), 32, SKIN_RAMP[3])
    return frame


def render_brawler_back(step: int = 0, sway: float = 0.0, breath_dy: float = 0.0) -> Layer:
    """Back-facing (`UP`) Behemoth: full shaggy beast-pelt mantle & wild dark mane."""
    frame = Layer(CELL, CELL)
    cx = 64.0
    by = breath_dy * 0.7

    # Legs & fur-cuffed boots
    l_dy = -3 if step == 1 else 0
    r_dy = -3 if step == 2 else 0
    for side, dy in ((-1, l_dy), (1, r_dy)):
        lx = cx + side * 6.5
        boot = Layer(CELL, CELL)
        boot.capsule(lx, 84, lx, GROUND_Y - 3 + dy, 4.2, 3.8, LEATHER_RAMP[1])
        boot.poly([(lx - 4.5, GROUND_Y - 4 + dy), (lx + 4.5, GROUND_Y - 4 + dy), (lx + 5, GROUND_Y + dy), (lx - 5, GROUND_Y + dy)], LEATHER_RAMP[0])
        boot.shade_ramp(LEATHER_RAMP)
        boot.ellipse(lx, 89 + dy * 0.5, 4.6, 2.0, PELT_RAMP[2])
        boot.outline(OUT_DARK, skip_bottom_y=GROUND_Y)
        boot.blit_onto(frame)

    # Muscular arms & iron cestus on sides
    for side in (-1, 1):
        draw_cestus_arm_side(
            frame,
            cx + side * 12.5,
            49 + by,
            cx + side * 15.0,
            58 + by,
            cx + side * 13.0,
            65 + by,
            is_back=True,
        )

    # Full shaggy dark beast-pelt mantle covering shoulders & back!
    pelt = Layer(CELL, CELL)
    pelt.poly(
        [
            (cx - 14, 43 + by * 0.5),
            (cx + 14, 43 + by * 0.5),
            (cx + 17 + sway, 82),
            (cx + 11 + sway * 0.7, 94),
            (cx + 5 + sway * 0.4, 88),
            (cx + sway * 0.3, 96),
            (cx - 6 + sway * 0.4, 88),
            (cx - 12 + sway * 0.7, 94),
            (cx - 17 + sway, 82),
        ],
        PELT_RAMP[2],
    )
    pelt.shade_ramp(PELT_RAMP, light_dir=(-0.45, -0.75), dither=0.38)
    for fx in (-8, -3, 3, 8):
        pelt.line(cx + fx * 0.7, 48, cx + fx + sway * 0.5, 88, PELT_RAMP[0])
    pelt.outline(OUT_PELT)
    pelt.blit_onto(frame)

    # Wild dark-umber warrior mane cascading over upper pelt!
    mane = Layer(CELL, CELL)
    mane.poly(
        [
            (cx - 9, 25),
            (cx, 22),
            (cx + 9, 25),
            (cx + 12 + sway * 0.4, 48),
            (cx + 6 + sway * 0.5, 55),
            (cx + sway * 0.5, 51),
            (cx - 6 + sway * 0.5, 56),
            (cx - 12 + sway * 0.4, 48),
        ],
        HAIR_RAMP[2],
    )
    mane.shade_ramp(HAIR_RAMP, light_dir=(-0.45, -0.8), dither=0.30)
    mane.outline(OUT_DARK)
    mane.blit_onto(frame)
    return frame


def render_brawler_kneel_death() -> Layer:
    """Frame 22 (`die_kneel`): Drops onto knees bracing one iron gauntlet against the stone floor."""
    frame = Layer(CELL, CELL)
    cx = 60.0
    draw_beast_pelt_side(frame, cx - 4, 62, sway_px=-2.0, flare=-0.15)
    draw_brawler_leg_side(frame, cx - 3, 86, cx - 9, 104, cx - 15, GROUND_Y, is_back=True)
    draw_brawler_leg_side(frame, cx + 3, 86, cx + 10, 96, cx + 9, GROUND_Y, is_back=False)
    draw_brawler_torso_side(frame, cx + 2, 72, lean_x=4.0)
    draw_brawler_head_side(frame, cx + 6, 52, sway_px=-1.0, blink=True)
    # Bracing right gauntlet on stone floor at GROUND_Y - 3
    draw_cestus_arm_side(frame, cx + 1, 64, cx + 9, 82, cx + 15, GROUND_Y - 3)
    return frame


def render_brawler_fallen_death() -> Layer:
    """Frame 23 (`die_fallen`): Collapsed face-down on stone floor (`GROUND_Y = 108`)."""
    frame = Layer(CELL, CELL)
    # Muscular legs & torso prone along GROUND_Y
    body = Layer(CELL, CELL)
    body.capsule(26, GROUND_Y - 5, 48, GROUND_Y - 6, 4.6, 5.0, LEATHER_RAMP[2])
    body.capsule(48, GROUND_Y - 7, 74, GROUND_Y - 7, 6.8, 6.2, SKIN_RAMP[2])
    body.shade_ramp(SKIN_RAMP, light_dir=(-0.3, -0.9), dither=0.24)
    body.outline(OUT_DARK, skip_bottom_y=GROUND_Y)
    body.blit_onto(frame)
    # Shaggy dark beast-pelt draped across fallen back
    pelt = Layer(CELL, CELL)
    pelt.poly([(36, GROUND_Y - 7), (56, GROUND_Y - 16), (76, GROUND_Y - 14), (72, GROUND_Y - 3), (34, GROUND_Y - 3)], PELT_RAMP[2])
    pelt.shade_ramp(PELT_RAMP, light_dir=(-0.3, -0.9), dither=0.35)
    pelt.outline(OUT_PELT, skip_bottom_y=GROUND_Y)
    pelt.blit_onto(frame)
    # Fallen bearded head & wild mane resting horizontally on stone floor
    head = Layer(CELL, CELL)
    head.ellipse(81, GROUND_Y - 7, 6.2, 5.5, SKIN_RAMP[2])
    head.shade_ramp(SKIN_RAMP, light_dir=(-0.3, -0.9))
    head.line(82, GROUND_Y - 7, 85, GROUND_Y - 7, OUT_DARK)
    head.outline(OUT_DARK, skip_bottom_y=GROUND_Y)
    head.blit_onto(frame)

    mane = Layer(CELL, CELL)
    mane.ribbon([(83, GROUND_Y - 11), (70, GROUND_Y - 12), (56, GROUND_Y - 7)], 4.5, 1.8, HAIR_RAMP[2], steps=18)
    mane.poly([(82, GROUND_Y - 6), (88, GROUND_Y - 5), (86, GROUND_Y - 1), (78, GROUND_Y - 2)], HAIR_RAMP[2])
    mane.shade_ramp(HAIR_RAMP, light_dir=(-0.3, -0.9), dither=0.25)
    mane.outline(OUT_DARK, skip_bottom_y=GROUND_Y)
    mane.blit_onto(frame)

    draw_cestus_arm_side(frame, 72, GROUND_Y - 6, 84, GROUND_Y - 4, 95, GROUND_Y - 3)
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
        "16:atk_windup",
        "17:atk_jab",
        "18:atk_cross",
        "19:atk_uppercut",
        "20:charge",
        "21:hurt",
        "22:die_kneel",
        "23:die_fallen",
    ]

    frames: list[Layer] = [
        # --- ROW 0: CALM SIDE IDLE (4 frames — feet 100% planted, subtle 1px breath & pelt!) ---
        render_brawler_side(breath_dy=0.0, sway_px=0.0),
        render_brawler_side(breath_dy=-1.0, sway_px=1.0),
        render_brawler_side(breath_dy=-0.5, sway_px=1.5),
        render_brawler_side(breath_dy=0.0, sway_px=0.5, blink=True),
        # --- ROW 0: 4-FRAME GROUNDED UPRIGHT SIDE WALK ---
        render_brawler_side(
            sway_px=1.5,
            l_leg=(-9, 91, -13, GROUND_Y),
            r_leg=(9, 91, 12, GROUND_Y),
            back_arm=(4, 50, 9, 58, 15, 56),
            front_arm=(-4, 51, 5, 59, 15, 55),
        ),
        render_brawler_side(
            sway_px=2.0,
            l_leg=(-2, 89, -3, GROUND_Y - 3),
            r_leg=(3, 91, 4, GROUND_Y),
            back_arm=(4, 50, 11, 57, 17, 55),
            front_arm=(-4, 51, 4, 60, 14, 56),
        ),
        render_brawler_side(
            sway_px=1.5,
            l_leg=(9, 91, 12, GROUND_Y),
            r_leg=(-9, 91, -13, GROUND_Y),
            back_arm=(4, 50, 14, 56, 21, 53),
            front_arm=(-4, 51, 1, 60, 10, 58),
        ),
        render_brawler_side(
            sway_px=1.0,
            l_leg=(3, 91, 4, GROUND_Y),
            r_leg=(-2, 89, -3, GROUND_Y - 3),
            back_arm=(4, 50, 12, 57, 19, 54),
            front_arm=(-4, 51, 3, 60, 13, 57),
        ),
        # --- ROW 1: FRONT (DOWN) & BACK (UP) CALM IDLES + WALKS ---
        render_brawler_front(step=0, sway=0.0, breath_dy=0.0),
        render_brawler_front(step=0, sway=1.0, breath_dy=-1.0),
        render_brawler_front(step=1, sway=1.2, breath_dy=-0.5),
        render_brawler_front(step=2, sway=-1.2, breath_dy=-0.5),
        render_brawler_back(step=0, sway=0.0, breath_dy=0.0),
        render_brawler_back(step=0, sway=1.2, breath_dy=-1.0),
        render_brawler_back(step=1, sway=1.5, breath_dy=-0.5),
        render_brawler_back(step=2, sway=-1.5, breath_dy=-0.5),
        # --- ROW 2: 3-HIT CESTUS COMBO, SHOULDER CHARGE, HURT, & DEATH ---
        # 16: Coiled pit-brawler windup
        render_brawler_side(
            flare=0.25,
            lean_x=-2.0,
            l_leg=(-8, 91, -11, GROUND_Y),
            r_leg=(7, 91, 9, GROUND_Y),
            back_arm=(5, 49, 13, 54, 19, 49),
            front_arm=(-6, 51, -12, 57, -7, 54),
        ),
        # 17: Hit 1 (`attack` / Jab) — snapping lead iron cestus straight forward!
        render_brawler_side(
            flare=0.45,
            lean_x=2.5,
            roar=True,
            l_leg=(-9, 91, -13, GROUND_Y),
            r_leg=(9, 91, 13, GROUND_Y),
            back_arm=(6, 49, 18, 50, 30, 50),
            front_arm=(-5, 52, -1, 59, 8, 57),
            impact_fx=(99, 50, "jab"),
        ),
        # 18: Hit 2 (`attack_cross` / Cross) — heavy rear cestus driving straight across!
        render_brawler_side(
            flare=0.65,
            lean_x=4.0,
            roar=True,
            l_leg=(-10, 92, -15, GROUND_Y),
            r_leg=(10, 91, 14, GROUND_Y),
            back_arm=(2, 51, -4, 57, 3, 56),
            front_arm=(3, 50, 16, 52, 30, 52),
            impact_fx=(98, 52, "cross"),
        ),
        # 19: Hit 3 (`attack_uppercut` / Uppercut) — skyward explosive uppercut finisher!
        render_brawler_side(
            flare=0.75,
            lean_x=2.5,
            roar=True,
            l_leg=(-8, 91, -12, GROUND_Y),
            r_leg=(9, 90, 13, GROUND_Y),
            back_arm=(2, 51, -4, 58, 4, 57),
            front_arm=(3, 48, 15, 41, 19, 25),
            impact_fx=(74, 54, "uppercut"),
        ),
        # 20: Shoulder-Smash Beast-Pelt Charge (`Shift`)!
        render_brawler_side(
            flare=0.95,
            lean_x=5.0,
            roar=True,
            l_leg=(-12, 92, -17, GROUND_Y),
            r_leg=(10, 91, 15, GROUND_Y),
            back_arm=(-2, 51, -9, 58, -13, 62),
            front_arm=(5, 49, 14, 54, 21, 53),
            charge_streaks=True,
        ),
        # 21: Hurt stagger recoil
        render_brawler_side(
            flare=0.35,
            lean_x=-3.5,
            blink=True,
            roar=True,
            l_leg=(-6, 91, -9, GROUND_Y),
            r_leg=(5, 91, 8, GROUND_Y),
            back_arm=(4, 48, 12, 43, 17, 39),
            front_arm=(-5, 49, -11, 44, -14, 39),
        ),
        # 22 & 23: Kneeling -> Fallen Collapse Death (`die`)
        render_brawler_kneel_death(),
        render_brawler_fallen_death(),
    ]

    for idx, layer in enumerate(frames):
        c_idx = idx % COLS
        r_idx = idx // COLS
        sheet.paste(layer.to_image(), (c_idx * CELL, r_idx * CELL))

    out_sheet = "assets/textures/player_borzo.png"
    os.makedirs(os.path.dirname(out_sheet), exist_ok=True)
    sheet.save(out_sheet)

    scale = 2
    tile_w = CELL * scale
    tile_h = CELL * scale + 22
    prev = Image.new("RGBA", (COLS * tile_w + 16, ROWS * tile_h + 36), (20, 15, 14, 255))
    pdraw = ImageDraw.Draw(prev)
    pdraw.text((12, 8), "REDESIGNED BEHEMOTH PIT-BRAWLER (BORZO) - 24 frames (8x3 @ 128x128)", fill=(242, 220, 198, 255))
    for idx, layer in enumerate(frames):
        c_idx = idx % COLS
        r_idx = idx // COLS
        ox = 8 + c_idx * tile_w
        oy = 30 + r_idx * tile_h
        pdraw.rectangle([ox + 2, oy + 2, ox + tile_w - 3, oy + CELL * scale - 2], fill=(32, 24, 22, 255), outline=(74, 54, 48, 255))
        gy = oy + GROUND_Y * scale
        pdraw.line([(ox + 6, gy), (ox + tile_w - 6, gy)], fill=(110, 78, 66, 140))
        up = layer.to_image().resize((CELL * scale, CELL * scale), Image.Resampling.NEAREST)
        prev.alpha_composite(up, (ox, oy))
        pdraw.text((ox + 6, oy + CELL * scale + 3), labels[idx], fill=(224, 196, 174, 255))

    os.makedirs("docs/images", exist_ok=True)
    prev.save("docs/images/brawler_preview.png")
    print(f"Generated {out_sheet} ({sheet.size}) and docs/images/brawler_preview.png")


if __name__ == "__main__":
    generate()
