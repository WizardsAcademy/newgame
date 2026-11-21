#!/usr/bin/env python3
"""Hand-craft lush 5-state 128x128 dark-fantasy circular HUD portraits (640x128).

100% original procedural dark-fantasy portrait illustration built from scratch
(reference-only — zero copied pixels from any external image).
Preserves `assets/textures/portrait_shabnam.png` (Velmira) and renders all 4
heroes together in `docs/images/portraits_preview.png`.

States per 640x128 strip (5 x 128x128 cells):
  0: idle_a   — calm heroic poise
  1: idle_b   — subtle hair/scarf/mane whisper
  2: blink    — natural blink / visor dim
  3: low_hp   — battle-worn grit / glowing visor ember / determined glare
  4: hurt     — expressive recoil + sparks
"""
from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
from pixel_art_kit import Layer, hex_rgba, lerp_col

CELL = 128
STATES = ["idle_a", "idle_b", "blink", "low_hp", "hurt"]


def mask_to_medallion(
    layer: Layer, bg_top: tuple, bg_mid: tuple, bg_edge: tuple
) -> Layer:
    """Place portrait inside a rich atmospheric dark-fantasy circular medallion (`r = 60.5`)."""
    out = Layer(CELL, CELL)
    cx = cy = (CELL - 1) * 0.5
    max_r = 60.5
    for y in range(CELL):
        for x in range(CELL):
            d = math.hypot(x - cx, y - cy)
            if d <= max_r:
                # Atmospheric vertical + radial vignette backdrop
                vy = y / (CELL - 1)
                base = (
                    bg_top[0] + (bg_mid[0] - bg_top[0]) * vy,
                    bg_top[1] + (bg_mid[1] - bg_top[1]) * vy,
                    bg_top[2] + (bg_mid[2] - bg_top[2]) * vy,
                )
                rt = min(1.0, (d / max_r) ** 1.65)
                bg = (
                    int(round(base[0] + (bg_edge[0] - base[0]) * rt)),
                    int(round(base[1] + (bg_edge[1] - base[1]) * rt)),
                    int(round(base[2] + (bg_edge[2] - base[2]) * rt)),
                    255,
                )
                out.pset(x, y, bg)
                p = layer.pget(x, y)
                if p[3] > 0:
                    out.pset(x, y, p)
    return out


# =============================================================================
# 1. BEHEMOTH PORTRAIT (128x128 x 5) — Fierce Barbarian, Exposed Cheeks & Mane
# =============================================================================
def draw_behemoth_portrait(state: str) -> Layer:
    L = Layer(CELL, CELL)
    dx = -2 if state == "hurt" else 0
    dy = 2 if state == "hurt" else 0
    sway = 1.6 if state == "idle_b" else 0.0
    cx = 64 + dx
    cy = 63 + dy

    OUT = hex_rgba("#120908")
    SKIN = [
        hex_rgba("#4f2b21"),
        hex_rgba("#734233"),
        hex_rgba("#9c5e49"),
        hex_rgba("#c27b62"),
        hex_rgba("#df9b80"),
        hex_rgba("#f5bfa6"),
    ]
    HAIR = [
        hex_rgba("#0f0a0b"),
        hex_rgba("#1d1314"),
        hex_rgba("#302020"),
        hex_rgba("#49312f"),
        hex_rgba("#694945"),
        hex_rgba("#87625c"),
    ]
    PELT = [
        hex_rgba("#141013"),
        hex_rgba("#241c22"),
        hex_rgba("#392d35"),
        hex_rgba("#54434d"),
        hex_rgba("#78626e"),
    ]

    # 1. Wild flowing dark-umber warrior mane locks behind head & shoulders
    mane = Layer(CELL, CELL)
    mane.ellipse(cx, cy + 4, 41, 44, HAIR[2])
    for side in (-1, 1):
        for k, (oy, rx, ty, r0) in enumerate(((-14, 38, 44, 9.5), (-2, 42, 52, 8.5), (10, 36, 56, 7.0))):
            mane.ribbon(
                [
                    (cx + side * 24, cy + oy),
                    (cx + side * rx + sway * 0.7, cy + oy + 22),
                    (cx + side * (rx - 5) + sway, cy + ty),
                ],
                r0,
                2.5,
                HAIR[2 + (k % 2)],
                steps=26,
            )
    mane.shade_ramp(HAIR, light_dir=(-0.45, -0.8), dither=0.30)
    # Crisp dark strand grooves inside mane
    for side in (-1, 1):
        for ox in (26, 32, 37):
            mane.line(cx + side * (ox - 4), cy - 8, cx + side * ox + sway * 0.6, cy + 36, HAIR[0])
    mane.outline(OUT)
    mane.blit_onto(L)

    # 2. Bare scarred shoulders/traps + shaggy wolf-pelt mantle collar!
    sh = Layer(CELL, CELL)
    sh.ellipse(cx, cy + 52, 46, 22, SKIN[2])
    sh.capsule(cx - 10, cy + 22, cx - 10, cy + 40, 8.0, 9.0, SKIN[2])
    sh.capsule(cx + 10, cy + 22, cx + 10, cy + 40, 8.0, 9.0, SKIN[2])
    sh.shade_ramp(SKIN, light_dir=(-0.42, -0.82), dither=0.24)
    sh.line(cx - 12, cy + 38, cx + 8, cy + 52, hex_rgba("#6b2220"), r=1.0)
    sh.line(cx - 11, cy + 37, cx + 9, cy + 51, SKIN[4])
    sh.outline(OUT)
    sh.blit_onto(L)

    pelt = Layer(CELL, CELL)
    for side in (-1, 1):
        pelt.ellipse(cx + side * 28, cy + 47, 21, 13, PELT[2], angle_deg=-side * 16)
        for tx in (14, 22, 30, 38):
            pelt.ribbon(
                [(cx + side * tx, cy + 39), (cx + side * (tx + 3), cy + 48), (cx + side * (tx + 1), cy + 57)],
                4.2,
                1.4,
                PELT[3],
                steps=12,
            )
    pelt.shade_ramp(PELT, light_dir=(-0.45, -0.8), dither=0.36)
    pelt.outline(OUT)
    pelt.blit_onto(L)

    # 3. Sculpted Rugged Warrior Face — EXPOSED BRONZED CHEEKBONES & NOSE!
    face = Layer(CELL, CELL)
    face.poly(
        [
            (cx - 23, cy - 24),
            (cx + 23, cy - 24),
            (cx + 24, cy + 2),
            (cx + 20, cy + 18),
            (cx, cy + 26),
            (cx - 20, cy + 18),
            (cx - 24, cy + 2),
        ],
        SKIN[3],
    )
    face.shade_ramp(SKIN, light_dir=(-0.42, -0.82), dither=0.22)
    # Deep eye-socket shadows under furrowed brow + strong cheekbone highlights
    face.ellipse(cx - 11, cy - 5, 7.0, 4.0, SKIN[1])
    face.ellipse(cx + 11, cy - 5, 7.0, 4.0, SKIN[1])
    face.ellipse(cx - 14, cy + 4, 5.0, 3.0, SKIN[4])
    face.ellipse(cx + 13, cy + 4, 4.5, 2.8, SKIN[3])
    # Sculpted warrior nose bridge, tip & nostrils
    face.capsule(cx, cy - 8, cx, cy + 6, 2.6, 3.6, SKIN[3])
    face.line(cx - 1, cy - 7, cx - 1, cy + 5, SKIN[5])
    face.disc(cx, cy + 6, 3.4, SKIN[3])
    face.pset(int(cx - 4), int(cy + 7), SKIN[0])
    face.pset(int(cx + 4), int(cy + 7), SKIN[0])
    # Iconic diagonal battle-scar across right brow & cheekbone!
    face.line(cx - 16, cy - 19, cx - 7, cy + 5, hex_rgba("#69201e"), r=0.8)
    face.line(cx - 15, cy - 19, cx - 6, cy + 5, SKIN[5])
    if state == "low_hp":
        face.line(cx + 15, cy - 17, cx + 16, cy - 1, hex_rgba("#c41828"), r=1.1)
        face.disc(cx + 16, cy + 1, 1.6, hex_rgba("#e02436"))
        face.line(cx - 14, cy + 6, cx - 8, cy + 9, hex_rgba("#b01826"), r=0.8)
    face.outline(OUT)
    face.blit_onto(L)

    # 4. Sculpted Jawline Full Beard + Separate Mustache (leaving cheeks & nose OPEN!)
    beard = Layer(CELL, CELL)
    # Jawline sideburns curving LOW (`cy + 14`) around open cheeks down into thick forked beard!
    beard.poly(
        [
            (cx - 23, cy + 2),
            (cx - 18, cy + 2),
            (cx - 15, cy + 13),
            (cx - 6, cy + 16),
            (cx, cy + 15),
            (cx + 6, cy + 16),
            (cx + 15, cy + 13),
            (cx + 18, cy + 2),
            (cx + 23, cy + 2),
            (cx + 21, cy + 23),
            (cx + 11, cy + 35),
            (cx + 4, cy + 38),
            (cx, cy + 34),
            (cx - 4, cy + 38),
            (cx - 11, cy + 35),
            (cx - 21, cy + 23),
        ],
        HAIR[2],
    )
    # Distinct swept warrior mustache under nose (`cy + 9..13`)
    beard.ribbon([(cx - 14, cy + 15), (cx - 7, cy + 9.5), (cx, cy + 10.5)], 3.0, 3.4, HAIR[3], steps=14)
    beard.ribbon([(cx, cy + 10.5), (cx + 7, cy + 9.5), (cx + 14, cy + 15)], 3.4, 3.0, HAIR[2], steps=14)
    # Soul-patch tuft under lower lip
    beard.poly([(cx - 3, cy + 16), (cx + 3, cy + 16), (cx, cy + 23)], HAIR[3])
    # Wild jagged swept-back forehead hair locks!
    beard.poly(
        [
            (cx - 27, cy - 10),
            (cx - 22, cy - 31),
            (cx - 7, cy - 37),
            (cx + 9, cy - 36),
            (cx + 23, cy - 29),
            (cx + 27, cy - 10),
            (cx + 20, cy - 19),
            (cx + 10, cy - 22),
            (cx + 3, cy - 17),
            (cx - 4, cy - 23),
            (cx - 13, cy - 19),
            (cx - 20, cy - 18),
        ],
        HAIR[2],
    )
    beard.shade_ramp(HAIR, light_dir=(-0.45, -0.8), dither=0.28)
    # Vertical beard hair-lock texture lines!
    for bx in (-12, -7, -2, 3, 8, 13):
        beard.line(cx + bx, cy + 18, cx + bx * 0.85, cy + 34, HAIR[0])
        beard.line(cx + bx - 1, cy + 18, cx + bx * 0.85 - 1, cy + 31, HAIR[4])
    beard.outline(OUT)
    beard.blit_onto(L)

    # 5. Mouth expression framed cleanly between mustache & lower beard!
    if state in ("idle_a", "idle_b", "blink"):
        L.line(cx - 5, cy + 14, cx + 5, cy + 14, OUT, r=0.8)
        L.line(cx - 3, cy + 15, cx + 3, cy + 15, SKIN[1])
    elif state == "low_hp":
        L.poly([(cx - 8, cy + 13), (cx + 8, cy + 13), (cx + 7, cy + 19), (cx - 7, cy + 19)], OUT)
        L.line(cx - 6, cy + 14, cx + 6, cy + 14, hex_rgba("#f7eedc"), r=1.0)
        L.line(cx - 5, cy + 17, cx + 5, cy + 17, hex_rgba("#e4d5bc"), r=0.8)
    elif state == "hurt":
        L.poly([(cx - 9, cy + 12), (cx + 9, cy + 12), (cx + 7, cy + 21), (cx - 7, cy + 21)], hex_rgba("#4d0d16"))
        L.line(cx - 7, cy + 13, cx + 7, cy + 13, hex_rgba("#fff5e0"), r=1.0)
        L.line(cx - 5, cy + 19, cx + 5, cy + 19, hex_rgba("#d95966"), r=1.0)

    # 6. Heavy furrowed brows & blazing amber warrior eyes!
    for side in (-1, 1):
        ex = cx + side * 10.5
        ey = cy - 5
        if state == "blink":
            L.line(ex - 5, ey - 3, ex + 5, ey - 2, HAIR[0], r=1.1)
            L.line(ex - 4, ey + 1, ex + 4, ey + 1, OUT, r=0.8)
        elif state == "hurt":
            L.line(ex - side * 5, ey - 3, ex + side * 3, ey + 1, OUT, r=1.1)
            L.line(ex - side * 5, ey + 4, ex + side * 3, ey + 1, OUT, r=1.1)
        else:
            L.line(ex - side * 5.5, ey - 5, ex + side * 5, ey - 8, HAIR[0], r=1.4)
            L.poly([(ex - 5, ey), (ex + 5, ey - 1), (ex + 4, ey + 3), (ex - 4, ey + 3)], hex_rgba("#1e100f"))
            L.ellipse(ex, ey + 1, 3.8, 2.0, hex_rgba("#e8ddd0"))
            gx = ex + (1.0 if state == "idle_b" else 0.0)
            L.disc(gx, ey + 0.8, 2.4, hex_rgba("#ff7b1c" if state == "low_hp" else "#e89a2c"))
            L.disc(gx, ey + 0.8, 1.2, hex_rgba("#2b1208"))
            L.pset(int(gx - 1), int(ey - 0.5), hex_rgba("#fff9de"))

    return mask_to_medallion(L, (58, 34, 28), (34, 20, 17), (14, 8, 8))


# =============================================================================
# 2. DARK KNIGHT PORTRAIT (128x128 x 5) — Gothic Visor Greathelm, Scarf & Hilt
# =============================================================================
def draw_knight_portrait(state: str) -> Layer:
    L = Layer(CELL, CELL)
    dx = -2 if state == "hurt" else 0
    dy = 2 if state == "hurt" else 0
    sway = 1.6 if state == "idle_b" else 0.0
    cx = 64 + dx
    cy = 65 + dy

    OUT = hex_rgba("#070a11")
    STEEL = [
        hex_rgba("#161c29"),
        hex_rgba("#252e42"),
        hex_rgba("#3b4863"),
        hex_rgba("#5c6e91"),
        hex_rgba("#8fa3c7"),
        hex_rgba("#d7e5fa"),
    ]
    SCARF = [
        hex_rgba("#0c111f"),
        hex_rgba("#162036"),
        hex_rgba("#243352"),
        hex_rgba("#374b73"),
        hex_rgba("#516999"),
    ]
    GOLD = [hex_rgba("#4a391d"), hex_rgba("#7d6235"), hex_rgba("#ba9556"), hex_rgba("#ecd093"), hex_rgba("#fff2ca")]

    # 1. Greatsword Pommel & Crossguard peeking diagonally over back shoulder!
    hilt = Layer(CELL, CELL)
    hilt.line(cx + 22, cy + 16, cx + 38, cy - 10, hex_rgba("#3d2b22"), r=2.2)
    hilt.line(cx + 16, cy + 8, cx + 34, cy + 18, GOLD[2], r=1.8)
    hilt.disc(cx + 39, cy - 12, 4.2, GOLD[3])
    hilt.disc(cx + 39, cy - 12, 2.0, GOLD[4])
    hilt.outline(OUT)
    hilt.blit_onto(L)

    # 2. Fluted Gothic Pauldrons + Breastplate + Heraldic Shield Rim!
    armor = Layer(CELL, CELL)
    armor.ellipse(cx, cy + 46, 46, 20, STEEL[2])
    armor.ellipse(cx - 32, cy + 41, 19, 13, STEEL[3], angle_deg=18)
    armor.ellipse(cx + 32, cy + 41, 19, 13, STEEL[2], angle_deg=-18)
    armor.shade_ramp(STEEL, light_dir=(-0.5, -0.8), dither=0.24, rim_right=True)
    for k in (-28, -22, 22, 28):
        armor.line(cx + k, cy + 32, cx + k * 1.1, cy + 49, STEEL[0])
    armor.outline(OUT)
    armor.blit_onto(L)

    # 3. Layered Midnight-Navy Tattered Scarf & Cloak Hood Folds!
    sc = Layer(CELL, CELL)
    sc.ribbon([(cx - 16, cy + 23), (cx - 35 - sway * 0.6, cy + 15), (cx - 48 - sway, cy + 27)], 8.5, 3.0, SCARF[2], steps=22)
    sc.ellipse(cx, cy + 28, 28, 11.5, SCARF[2])
    sc.ellipse(cx, cy + 24, 24, 8.5, SCARF[3])
    sc.shade_ramp(SCARF, light_dir=(-0.45, -0.8), dither=0.26)
    sc.line(cx - 21, cy + 27, cx + 21, cy + 29, SCARF[0], r=0.8)
    sc.outline(OUT)
    sc.blit_onto(L)

    # 4. Pointed Crested Gothic V-Slit Greathelm (KEPT ON IN ALL STATES!)
    helm = Layer(CELL, CELL)
    helm.poly(
        [
            (cx - 24, cy - 20),
            (cx - 12, cy - 36),
            (cx, cy - 41),
            (cx + 12, cy - 36),
            (cx + 24, cy - 20),
            (cx + 26, cy + 3),
            (cx + 20, cy + 21),
            (cx, cy + 29),
            (cx - 20, cy + 21),
            (cx - 26, cy + 3),
        ],
        STEEL[2],
    )
    helm.shade_ramp(STEEL, light_dir=(-0.52, -0.78), dither=0.24, rim_right=True)

    # Central raised Gothic ridge + specular bevels
    helm.line(cx, cy - 40, cx, cy + 27, STEEL[4], r=1.1)
    helm.line(cx - 1, cy - 38, cx - 1, cy - 6, STEEL[5])
    helm.line(cx - 23, cy - 11, cx, cy - 5, STEEL[4], r=0.9)
    helm.line(cx + 23, cy - 11, cx, cy - 5, STEEL[3], r=0.9)
    helm.line(cx - 22, cy + 4, cx - 4, cy + 13, STEEL[1])
    helm.line(cx + 22, cy + 4, cx + 4, cy + 13, STEEL[1])

    # Deep V-angled Visor Slit + Vertical Nasal T-slot!
    helm.poly(
        [(cx - 19, cy - 7), (cx, cy - 2), (cx + 19, cy - 7), (cx + 18, cy - 1), (cx, cy + 3), (cx - 18, cy - 1)],
        OUT,
    )
    helm.poly([(cx - 2.5, cy + 1), (cx + 2.5, cy + 1), (cx + 2.0, cy + 22), (cx - 2.0, cy + 22)], OUT)

    # Forged ventilation breath-pores on lower cheek plates
    for side in (-1, 1):
        for r_y in (8, 13, 18):
            for c_x in (8, 13):
                helm.disc(cx + side * c_x, cy + r_y, 0.9, OUT)

    if state in ("low_hp", "hurt"):
        helm.line(cx - 17, cy - 27, cx - 6, cy - 10, OUT, r=0.9)
        helm.line(cx - 16, cy - 27, cx - 5, cy - 10, STEEL[5])

    helm.outline(OUT)
    helm.blit_onto(L)

    # 5. Visor eye gleams inside dark V-slit
    for side in (-1, 1):
        ex = cx + side * 9.5 + (1.0 if state == "idle_b" else 0.0)
        ey = cy - 3
        if state == "blink":
            L.line(ex - 3, ey, ex + 3, ey, hex_rgba("#2f4668"))
        elif state == "low_hp":
            L.disc(ex, ey, 3.0, hex_rgba("#c92a22", 190))
            L.disc(ex, ey, 1.9, hex_rgba("#ff6838"))
            L.pset(int(ex), int(ey), hex_rgba("#fff0b8"))
        elif state == "hurt":
            L.disc(ex, ey, 2.5, hex_rgba("#ffe48f"))
            L.pset(int(ex), int(ey), hex_rgba("#ffffff"))
        else:
            L.disc(ex, ey, 2.5, hex_rgba("#4c84c4", 185))
            L.disc(ex, ey, 1.5, hex_rgba("#9fd2ff"))
            L.pset(int(ex), int(ey), hex_rgba("#f2fbff"))

    if state == "hurt":
        for sx0, sy0, sdx, sdy in ((cx + 28, cy - 16, 9, -7), (cx + 30, cy + 3, 10, 3), (cx - 29, cy - 8, -9, -5)):
            L.line(sx0, sy0, sx0 + sdx, sy0 + sdy, GOLD[4], r=1.0)

    return mask_to_medallion(L, (32, 44, 68), (18, 25, 42), (8, 11, 20))


# =============================================================================
# 3. SYLVARA PORTRAIT (128x128 x 5) — Lush Platinum Locks, Elf Ears & Emerald Eyes
# =============================================================================
def draw_sylvara_portrait(state: str) -> Layer:
    L = Layer(CELL, CELL)
    dx = -2 if state == "hurt" else 0
    dy = 2 if state == "hurt" else 0
    sway = 1.6 if state == "idle_b" else 0.0
    cx = 64 + dx
    cy = 64 + dy

    OUT = hex_rgba("#1c1010")
    SKIN = [
        hex_rgba("#8c584d"),
        hex_rgba("#b5796b"),
        hex_rgba("#db9c8b"),
        hex_rgba("#f0bead"),
        hex_rgba("#fbd7c9"),
        hex_rgba("#ffece3"),
    ]
    HAIR = [
        hex_rgba("#6b5132"),
        hex_rgba("#99774c"),
        hex_rgba("#c7a370"),
        hex_rgba("#e6ca9c"),
        hex_rgba("#f7e4c3"),
        hex_rgba("#fff7e6"),
    ]
    EMERALD = [
        hex_rgba("#0d1f17"),
        hex_rgba("#183628"),
        hex_rgba("#27543e"),
        hex_rgba("#3d785a"),
        hex_rgba("#60a682"),
    ]
    GOLD = [hex_rgba("#4f3b1b"), hex_rgba("#826330"), hex_rgba("#bd934d"), hex_rgba("#eac57b"), hex_rgba("#fff3c7")]

    # 1. Curved Recurve Bow Tip peeking gracefully behind right shoulder + Lush Platinum Back Hair!
    back = Layer(CELL, CELL)
    back.ribbon([(cx + 22, cy + 34), (cx + 38, cy + 6), (cx + 33, cy - 22)], 3.0, 1.5, GOLD[3], steps=22)
    back.line(cx + 33, cy - 22, cx + 24, cy + 36, hex_rgba("#dce8e2", 180))
    back.ellipse(cx, cy + 4, 36, 42, HAIR[2])
    for side in (-1, 1):
        for oy, rx, ty, r0 in ((-10, 33, 46, 9.0), (2, 36, 54, 7.5)):
            back.ribbon(
                [(cx + side * 22, cy + oy), (cx + side * rx + sway * 0.6, cy + oy + 22), (cx + side * (rx - 4) + sway, cy + ty)],
                r0,
                2.8,
                HAIR[3],
                steps=24,
            )
    back.shade_ramp(HAIR, light_dir=(-0.45, -0.8), dither=0.22)
    for side in (-1, 1):
        back.line(cx + side * 25, cy - 4, cx + side * 29 + sway * 0.5, cy + 38, HAIR[1])
    back.outline(OUT)
    back.blit_onto(L)

    # 2. Forest-Emerald & Gold-Filigree Ranger Mantle + Slender Neck!
    garb = Layer(CELL, CELL)
    garb.ellipse(cx, cy + 50, 42, 20, EMERALD[2])
    garb.shade_ramp(EMERALD, light_dir=(-0.45, -0.8), dither=0.22)
    # Slender porcelain neck + collarbone shadow
    garb.capsule(cx, cy + 20, cx, cy + 37, 7.2, 8.0, SKIN[3])
    garb.poly([(cx - 10, cy + 35), (cx, cy + 43), (cx + 10, cy + 35), (cx + 14, cy + 46), (cx - 14, cy + 46)], hex_rgba("#ede4d5"))
    garb.line(cx - 24, cy + 39, cx, cy + 46, GOLD[3], r=1.2)
    garb.line(cx + 24, cy + 39, cx, cy + 46, GOLD[3], r=1.2)
    garb.disc(cx, cy + 45, 4.0, GOLD[3])
    garb.disc(cx, cy + 45, 2.3, hex_rgba("#55f2a6"))
    garb.pset(int(cx - 1), int(cy + 44), hex_rgba("#ffffff"))
    garb.outline(OUT)
    garb.blit_onto(L)

    # 3. Graceful Pointed High-Elf Ears + Delicate V-Chin Porcelain Face!
    face = Layer(CELL, CELL)
    # Long sweeping pointed elven ears left & right!
    face.poly([(cx - 19, cy - 5), (cx - 44, cy - 14), (cx - 32, cy + 4), (cx - 19, cy + 6)], SKIN[3])
    face.poly([(cx + 19, cy - 5), (cx + 44, cy - 14), (cx + 32, cy + 4), (cx + 19, cy + 6)], SKIN[3])
    # Delicate heart-shaped high-elf face tapering to graceful V-chin
    face.poly(
        [
            (cx - 21, cy - 22),
            (cx + 21, cy - 22),
            (cx + 21, cy + 3),
            (cx + 15, cy + 17),
            (cx, cy + 25),
            (cx - 15, cy + 17),
            (cx - 21, cy + 3),
        ],
        SKIN[4],
    )
    face.shade_ramp(SKIN, light_dir=(-0.42, -0.82), dither=0.16)
    # Inner ear fold detail + soft peach cheek blush + nose tip highlight
    face.line(cx - 38, cy - 11, cx - 23, cy - 1, SKIN[1])
    face.line(cx + 38, cy - 11, cx + 23, cy - 1, SKIN[1])
    face.ellipse(cx - 13, cy + 8, 4.2, 2.2, SKIN[2])
    face.ellipse(cx + 13, cy + 8, 4.2, 2.2, SKIN[2])
    face.pset(int(cx), int(cy + 6), SKIN[1])
    face.line(cx - 1, cy + 1, cx - 1, cy + 5, SKIN[5])
    if state == "low_hp":
        face.line(cx - 16, cy + 9, cx - 10, cy + 12, hex_rgba("#b54545"), r=0.8)
    face.outline(OUT)
    face.blit_onto(L)

    # 4. Large Luminous Emerald-Jade Elven Eyes, Long Eyelashes & Soft Lips!
    for side in (-1, 1):
        ex = cx + side * 10.0
        ey = cy - 1
        if state == "blink":
            L.ribbon([(ex - 5.5, ey + 1), (ex, ey + 3), (ex + 5.5, ey + 1)], 0.9, 0.9, OUT, steps=12)
            L.line(ex + side * 4, ey + 1, ex + side * 6, ey, OUT)
        elif state == "hurt":
            L.line(ex - side * 4.5, ey - 3, ex + side * 3, ey + 1, OUT, r=1.0)
            L.line(ex - side * 4.5, ey + 4, ex + side * 3, ey + 1, OUT, r=1.0)
        else:
            brow_dy = 1.5 if state == "low_hp" else 0.0
            L.line(
                ex - 5,
                ey - 8 + (brow_dy if side == 1 else -0.5),
                ex + 5,
                ey - 8 + (brow_dy if side == -1 else -0.5),
                HAIR[0],
                r=0.8,
            )
            # Crisp white sclera + multi-tone emerald-jade iris!
            L.ellipse(ex, ey + 1, 5.4, 4.6, hex_rgba("#ffffff"))
            gx = ex + (1.0 if state == "idle_b" else 0.0)
            L.disc(gx, ey + 1.2, 3.8, hex_rgba("#124f36"))
            L.disc(gx, ey + 1.8, 2.8, hex_rgba("#2ca872"))
            L.ellipse(gx, ey + 2.6, 2.2, 1.3, hex_rgba("#6bf7b5"))
            L.disc(gx, ey + 1.0, 1.4, hex_rgba("#09291b"))  # pupil
            # Twin starlight catchlights!
            L.disc(ex - 1.6, ey - 0.8, 1.3, hex_rgba("#ffffff"))
            L.pset(int(ex + 1.8), int(ey + 2.6), hex_rgba("#e8fff4"))
            # Sweeping dark upper lash arch + wing tip
            L.ribbon([(ex - 5.8, ey - 1), (ex, ey - 4.2), (ex + 5.8, ey - 1)], 1.1, 1.1, OUT, steps=14)
            L.pset(int(ex + side * 6), int(ey - 2), OUT)

    # Delicate elven lips
    if state in ("idle_a", "blink"):
        L.line(cx - 3, cy + 15, cx + 3, cy + 15, hex_rgba("#b86262"), r=0.7)
        L.pset(int(cx), int(cy + 16), hex_rgba("#e08b8b"))
    elif state == "idle_b":
        L.ribbon([(cx - 3.5, cy + 14.5), (cx, cy + 15.8), (cx + 3.5, cy + 14.2)], 0.8, 0.8, hex_rgba("#b86262"), steps=10)
    elif state == "low_hp":
        L.line(cx - 4, cy + 16, cx + 4, cy + 15, OUT, r=0.8)
    elif state == "hurt":
        L.ellipse(cx, cy + 16, 3.6, 3.0, hex_rgba("#6e222a"))
        L.line(cx - 2.5, cy + 14, cx + 2.5, cy + 14, hex_rgba("#fff5ec"))

    # 5. Voluminous Layered Platinum-Blonde Bangs, Gold Hair-Clasps & Filigree Tiara!
    bangs = Layer(CELL, CELL)
    bangs.poly(
        [
            (cx - 27, cy - 10),
            (cx - 20, cy - 31),
            (cx, cy - 37),
            (cx + 20, cy - 31),
            (cx + 27, cy - 10),
            (cx + 19, cy - 13),
            (cx + 12, cy - 7),
            (cx + 6, cy - 17),
            (cx, cy - 8),
            (cx - 6, cy - 17),
            (cx - 12, cy - 7),
            (cx - 19, cy - 13),
        ],
        HAIR[3],
    )
    # Long face-framing platinum side-locks with antique gold hair-rings!
    for side in (-1, 1):
        bangs.ribbon(
            [(cx + side * 20, cy - 14), (cx + side * 21, cy + 10), (cx + side * 18 + sway * 0.6, cy + 38)],
            4.8,
            1.6,
            HAIR[4],
            steps=24,
        )
    bangs.shade_ramp(HAIR, light_dir=(-0.45, -0.85), dither=0.18)
    # Specular champagne halo sheen across crown bangs + gold hair-clasps
    for side in (-1, 1):
        bangs.line(cx + side * 6, cy - 24, cx + side * 16, cy - 21, HAIR[5], r=0.9)
        bangs.line(cx + side * 18, cy + 12, cx + side * 23, cy + 12, GOLD[3], r=1.1)
    # Ornate Elven Gold V-Tiara & Luminous Emerald Tear-Gem on Forehead!
    bangs.line(cx - 19, cy - 23, cx, cy - 18, GOLD[3], r=1.1)
    bangs.line(cx + 19, cy - 23, cx, cy - 18, GOLD[3], r=1.1)
    bangs.disc(cx, cy - 18, 3.8, GOLD[3])
    bangs.disc(cx, cy - 18, 2.3, hex_rgba("#4df5a5"))
    bangs.pset(int(cx - 1), int(cy - 19), hex_rgba("#ffffff"))
    bangs.outline(OUT)
    bangs.blit_onto(L)

    return mask_to_medallion(L, (28, 62, 46), (16, 38, 28), (8, 18, 14))


def build_strip(draw_fn, out_path: str) -> Image.Image:
    strip = Image.new("RGBA", (CELL * len(STATES), CELL), (0, 0, 0, 0))
    for i, st in enumerate(STATES):
        strip.paste(draw_fn(st).to_image(), (i * CELL, 0))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    strip.save(out_path)
    return strip


def main() -> None:
    strips = [
        ("BEHEMOTH (PIT-BRAWLER)", build_strip(draw_behemoth_portrait, "assets/textures/portrait_borzo.png")),
        ("DARK KNIGHT (HELM ON)", build_strip(draw_knight_portrait, "assets/textures/portrait_bahman.png")),
        ("SYLVARA (HIGH-ELF)", build_strip(draw_sylvara_portrait, "assets/textures/portrait_pari.png")),
    ]
    vel_path = "assets/textures/portrait_shabnam.png"
    if os.path.exists(vel_path):
        vel_im = Image.open(vel_path).convert("RGBA").resize((CELL * len(STATES), CELL), Image.Resampling.BILINEAR)
        strips.append(("VELMIRA (VAMPIRE)", vel_im))

    disp = 160
    pw = 200 + len(STATES) * (disp + 14) + 16
    ph = 36 + len(strips) * (disp + 16) + 12
    prev = Image.new("RGBA", (pw, ph), (14, 16, 22, 255))
    pd = ImageDraw.Draw(prev)
    for i, st in enumerate(STATES):
        pd.text((200 + i * (disp + 14) + 56, 10), st, fill=(205, 215, 235, 255))
    for r, (name, strip) in enumerate(strips):
        oy = 34 + r * (disp + 16)
        pd.text((14, oy + disp // 2 - 6), name, fill=(235, 240, 250, 255))
        for i in range(len(STATES)):
            cell_im = strip.crop((i * CELL, 0, (i + 1) * CELL, CELL))
            resamp = Image.Resampling.BILINEAR if "VELMIRA" in name else Image.Resampling.NEAREST
            up = cell_im.resize((disp, disp), resamp)
            prev.alpha_composite(up, (200 + i * (disp + 14), oy))

    os.makedirs("docs/images", exist_ok=True)
    prev.save("docs/images/portraits_preview.png")
    print("Generated 5-state 128x128 portraits (640x128) and docs/images/portraits_preview.png")


if __name__ == "__main__":
    main()
