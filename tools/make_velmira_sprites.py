#!/usr/bin/env python3
"""
tools/make_velmira_sprites.py

Slices and aligns the canonical Royal Crimson Vampire reference sheet
(`assets/sprites/vampire/velmira_reference.png`, 1536x1024 RGBA) into:
  1. `assets/textures/player_shabnam.png` (`1792 x 1120` = 8 cols x 5 rows of `224x224`, 40 frames):
       - `0..2`   : `idle` (side/3-4 regal stance, boots locked at `GROUND_Y = 200`)
       - `3..8`   : `walk` (6-frame grounded side walk/run, ZERO vertical floating!)
       - `9..10`  : `idle_down` (front-facing idle, looking down)
       - `11..14` : `walk_down` (4-frame front-facing walk, looking down)
       - `15..16` : `idle_up` (back-facing silver-hair idle, looking up)
       - `17..20` : `walk_up` (4-frame back-facing walk, looking up)
       - `21..25` : `attack` (5-frame Sweeping Crimson Crescent Blood-Splash Slash!)
       - `26..29` : `attack_splash` (4-frame Radial Crimson Blood-Splash Eruption!)
       - `30..31` : `hurt` (2-frame stagger recoil)
       - `32..39` : `die` (8-frame Kneel -> Collapse -> Dissolve into Swirling Blood Pool!)
  2. `assets/textures/portrait_shabnam.png` (`960 x 192` = 5 frames of `192x192`):
       - `idle_a`, `idle_b`, `blink`, `low_hp`, `hurt`
  3. `assets/textures/velmira_fx.png` (`896 x 224` = 4 frames of `224x224`):
       - `0`: Pure Crimson Crescent Blood-Splash Wave (directional slash FX)
       - `1`: Pure Twin Crimson Blood-Splash Burst
       - `2`: Ground Crimson Blood Fountain Peak
       - `3`: Ground Crimson Blood Fountain Settle
  4. `assets/textures/crimson_bat.png` (`72 x 24` = 3 frames of `24x24` classic pixel-art Vampire Bats)
  5. `docs/images/velmira_preview.png` (visual verification sheet)
"""

from __future__ import annotations
from collections import deque
from pathlib import Path
import sys

for extra in ("/tmp/pydeps",):
    if Path(extra).exists() and extra not in sys.path:
        sys.path.insert(0, extra)

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
REF_PATH = ROOT / "assets/sprites/vampire/velmira_reference.png"
OUT_HERO = ROOT / "assets/textures/player_shabnam.png"
OUT_PORTRAIT = ROOT / "assets/textures/portrait_shabnam.png"
OUT_FX = ROOT / "assets/textures/velmira_fx.png"
OUT_BAT = ROOT / "assets/textures/crimson_bat.png"
OUT_PREVIEW = ROOT / "docs/images/velmira_preview.png"

CELL = 224
COLS = 8
ROWS = 5
GROUND_Y = 200  # Exact boot ground row across ALL standing/walking frames!


def trim_alpha(im: Image.Image, min_a: int = 12) -> Image.Image:
    w, h = im.size
    px = im.load()
    minx, miny, maxx, maxy = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > min_a:
                if x < minx: minx = x
                if x > maxx: maxx = x
                if y < miny: miny = y
                if y > maxy: maxy = y
    if maxx < minx:
        return Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    return im.crop((minx, miny, maxx + 1, maxy + 1))


def isolate_largest_component(im: Image.Image, min_a: int = 12) -> Image.Image:
    """Keeps the main connected body plus any nearby crimson magic droplets."""
    return trim_alpha(im, min_a)


def scale_sprite(im: Image.Image, factor: float) -> Image.Image:
    nw = max(1, int(round(im.width * factor)))
    nh = max(1, int(round(im.height * factor)))
    return im.resize((nw, nh), Image.LANCZOS)


def fit_within(im: Image.Image, max_w: int, max_h: int) -> Image.Image:
    if im.width <= max_w and im.height <= max_h:
        return im
    factor = min(max_w / float(im.width), max_h / float(im.height))
    return scale_sprite(im, factor)


def compute_torso_x(im: Image.Image, body_only: bool = False) -> float:
    """Finds horizontal center of Velmira's silver hair/crown/dress (`body_only` ignores wide red splashes)."""
    w, h = im.size
    px = im.load()
    xs = []
    y0 = int(h * 0.12)
    y1 = max(y0 + 1, int(h * 0.65))
    for y in range(y0, y1):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 100:
                continue
            if body_only and r > g + 65 and g < 60:
                continue  # Ignore wide crimson blood splash when centering her body!
            xs.append(x)
    if not xs:
        return w * 0.5
    xs.sort()
    return float(xs[len(xs) // 2])


def compute_boot_bottom_y(im: Image.Image, body_only: bool = False) -> int:
    """Finds exact lowest boot/hem pixel of Velmira's body so her feet plant firmly on GROUND_Y."""
    w, h = im.size
    px = im.load()
    best_y = h - 1
    for y in range(h - 1, -1, -1):
        row_hits = 0
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 90:
                continue
            if body_only and r > g + 55 and g < 55:
                continue
            row_hits += 1
        if row_hits >= 2:
            best_y = y
            break
    return best_y


def place_grounded(
    im: Image.Image,
    dx: int = 0,
    dy: int = 0,
    body_only: bool = False,
    center_x_box: bool = False,
) -> Image.Image:
    im = fit_within(im, CELL - 6, CELL - 8)
    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    cx = (im.width * 0.5) if center_x_box else compute_torso_x(im, body_only=body_only)
    boot_y = compute_boot_bottom_y(im, body_only=body_only)
    px_x = int(round(CELL * 0.5 - cx)) + dx
    px_y = (GROUND_Y - boot_y) + dy
    px_x = max(2, min(CELL - im.width - 2, px_x))
    px_y = max(2, min(CELL - im.height - 2, px_y))
    canvas.alpha_composite(im, (px_x, px_y))
    return canvas


def extract_pure_crimson_splash(im: Image.Image) -> Image.Image:
    """Extracts ONLY the glowing crimson blood-splash pixels (removes character body) for directional VFX!"""
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    src = im.load()
    dst = out.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if a < 18:
                continue
            # Rich scarlet/crimson splash: high red dominance over green & blue
            red_dom = r - max(g, int(b * 0.88))
            if red_dom >= 36 and r >= 68:
                alpha_boost = min(255, int(a * min(1.0, red_dom / 55.0)))
                dst[x, y] = (r, g, b, alpha_boost)
    return trim_alpha(out, 15)


def build_classic_crimson_bats() -> Image.Image:
    """Builds the crisp 3-frame (72x24) classic pixel-art Vampire Bat strip for Bat-Swarm Shift!"""
    strip = Image.new("RGBA", (72, 24), (0, 0, 0, 0))
    OUTLINE = (24, 6, 14, 255)
    BODY = (62, 12, 28, 255)
    WING_DARK = (118, 16, 42, 255)
    WING_LIT = (212, 32, 68, 255)
    EYE = (255, 72, 96, 255)

    for idx, mode in enumerate(("up", "mid", "down")):
        cell = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
        d = ImageDraw.Draw(cell)
        cx, cy = 12, 12
        if mode == "up":
            # Swept-high gothic bat wings
            l_wing = [(cx - 2, cy), (cx - 6, cy - 6), (cx - 10, cy - 8), (cx - 9, cy - 2), (cx - 5, cy + 1)]
            r_wing = [(cx + 2, cy), (cx + 6, cy - 6), (cx + 10, cy - 8), (cx + 9, cy - 2), (cx + 5, cy + 1)]
        elif mode == "mid":
            # Wide gliding scalloped bat wings
            l_wing = [(cx - 2, cy - 1), (cx - 7, cy - 3), (cx - 11, cy - 1), (cx - 8, cy + 3), (cx - 4, cy + 2)]
            r_wing = [(cx + 2, cy - 1), (cx + 7, cy - 3), (cx + 11, cy - 1), (cx + 8, cy + 3), (cx + 4, cy + 2)]
        else:
            # Downstroke bat wings
            l_wing = [(cx - 2, cy - 1), (cx - 7, cy + 1), (cx - 10, cy + 7), (cx - 6, cy + 5), (cx - 3, cy + 2)]
            r_wing = [(cx + 2, cy - 1), (cx + 7, cy + 1), (cx + 10, cy + 7), (cx + 6, cy + 5), (cx + 3, cy + 2)]

        d.polygon(l_wing, fill=WING_DARK, outline=OUTLINE)
        d.polygon(r_wing, fill=WING_DARK, outline=OUTLINE)
        # Crimson membrane highlight along leading wing edge
        d.line([l_wing[0], l_wing[1], l_wing[2]], fill=WING_LIT, width=1)
        d.line([r_wing[0], r_wing[1], r_wing[2]], fill=WING_LIT, width=1)
        # Bat body + pointed vampire ears + glowing scarlet eyes
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=BODY, outline=OUTLINE)
        cell.putpixel((cx - 2, cy - 4), OUTLINE)
        cell.putpixel((cx + 2, cy - 4), OUTLINE)
        cell.putpixel((cx - 1, cy - 1), EYE)
        cell.putpixel((cx + 1, cy - 1), EYE)
        strip.alpha_composite(cell, (idx * 24, 0))
    return strip


def build_portrait_strip(ref: Image.Image) -> Image.Image:
    P = 192
    base = ref.crop((28, 12, 308, 292)).resize((P, P), Image.LANCZOS)
    strip = Image.new("RGBA", (P * 5, P), (0, 0, 0, 0))

    def is_iris(x: int, y: int, r: int, g: int, b: int) -> bool:
        in_left = (88 <= x <= 116 and 96 <= y <= 111)
        in_right = (129 <= x <= 147 and 100 <= y <= 118)
        return (in_left or in_right) and r > 105 and g < 78 and r > g + 42

    # 0: idle_a
    strip.alpha_composite(base, (0, 0))

    # 1: idle_b (gentle living breath)
    b1 = base.crop((2, 3, P - 2, P - 1)).resize((P, P), Image.LANCZOS)
    strip.alpha_composite(b1, (P, 0))

    # 2: blink (closed porcelain eyelids + dark lashes over both crimson irises; rose untouched!)
    f2 = base.copy()
    px2 = f2.load()
    for y in range(94, 120):
        for x in range(86, 150):
            r, g, b, a = px2[x, y]
            if a > 180 and is_iris(x, y, r, g, b):
                px2[x, y] = (232, 204, 212, a)
    d2 = ImageDraw.Draw(f2)
    d2.line([(90, 105), (102, 107), (114, 106)], fill=(48, 20, 34, 245), width=2)
    d2.line([(131, 110), (138, 112), (145, 111)], fill=(48, 20, 34, 245), width=2)
    strip.alpha_composite(f2, (P * 2, 0))

    # 3: low_hp (radiant scarlet vampire eyes + crimson aura + tiny ruby droplet at lip)
    f3 = base.copy()
    px3 = f3.load()
    for y in range(P):
        for x in range(P):
            r, g, b, a = px3[x, y]
            if a < 20:
                continue
            if is_iris(x, y, r, g, b):
                px3[x, y] = (min(255, int(r * 1.34 + 36)), max(0, int(g * 0.42)), max(0, int(b * 0.50)), a)
            else:
                dist = (((x - P * 0.54) / (P * 0.5)) ** 2 + ((y - P * 0.50) / (P * 0.5)) ** 2) ** 0.5
                vign = min(0.42, max(0.0, (dist - 0.34) * 0.60))
                nr = int(r * (1.0 - vign * 0.30) + 145 * vign * 0.30)
                ng = int(g * (1.0 - vign * 0.62))
                nb = int(b * (1.0 - vign * 0.48) + 42 * vign * 0.20)
                px3[x, y] = (min(255, nr), max(0, ng), max(0, nb), a)
    d3 = ImageDraw.Draw(f3)
    d3.ellipse((118, 134, 121, 139), fill=(205, 16, 46, 238))
    strip.alpha_composite(f3, (P * 3, 0))

    # 4: hurt (clean recoil tilt + wincing closed lashes + crimson flash)
    f4_rot = f2.rotate(-4.5, resample=Image.BICUBIC, expand=False)
    f4 = Image.new("RGBA", (P, P), (0, 0, 0, 0))
    f4.alpha_composite(f4_rot, (3, 2))
    px4 = f4.load()
    for y in range(P):
        for x in range(P):
            r, g, b, a = px4[x, y]
            if a < 20:
                continue
            px4[x, y] = (min(255, int(r * 1.10 + 22)), int(g * 0.85), int(b * 0.88), a)
    strip.alpha_composite(f4, (P * 4, 0))

    return strip


def main() -> None:
    assert REF_PATH.exists(), f"Missing reference sheet: {REF_PATH}"
    ref = Image.open(REF_PATH).convert("RGBA")

    # Helper to crop & trim a clean rectangular slice from `image-2.png`
    def c(x0: int, y0: int, x1: int, y1: int, scale: float = 1.0) -> Image.Image:
        im = trim_alpha(ref.crop((x0, y0, x1, y1)), 12)
        if abs(scale - 1.0) > 0.005:
            im = scale_sprite(im, scale)
        return im

    # Row 1 turnaround (`~178h`, scaled `0.91x` -> `~162h` to match Rows 2-4 exact standing height!)
    r1_front_0 = c(345, 9, 483, 196, 0.91)    # Front idle (looking DOWN)
    r1_front_step = c(497, 13, 639, 196, 0.91) # Front right-leg step
    r1_side_a = c(652, 14, 792, 196, 0.92)     # 3/4-right regal idle
    r1_back_a = c(954, 14, 1094, 196, 0.91)    # Back-facing idle (looking UP!)
    r1_side_blink = c(1099, 15, 1239, 196, 0.92)
    r1_back_b = c(1250, 10, 1402, 196, 0.90)   # Back-facing flowing silver hair

    # Row 2 grounded side walk/run (`~164h` native!)
    r2_idle = c(343, 212, 482, 383)
    r2_w0 = c(491, 214, 635, 383)
    r2_w1 = c(645, 216, 798, 384)
    r2_w2 = c(815, 216, 958, 384)
    r2_w3 = c(968, 216, 1120, 384)
    r2_w4 = c(1127, 217, 1285, 384)
    r2_w5 = c(1286, 234, 1525, 383)            # Separated cleanly above Row-3 crescent!

    # Row 3 & Row 4 directional front (DOWN) & back (UP) walks (`~158h` native, scaled `1.03x` -> `~163h`)
    r3_front_b = c(6, 394, 131, 558, 1.02)
    r3_up_0 = c(140, 397, 270, 560, 1.03)
    r3_up_1 = c(277, 397, 411, 560, 1.03)
    r3_up_2 = c(421, 398, 539, 560, 1.03)
    r4_front_stride = c(141, 586, 274, 741, 1.07)
    r4_up_3 = c(290, 590, 410, 741, 1.08)

    # Row 3 right: Sweeping Crimson Crescent Blood-Splash Attack!
    atk1_0 = c(545, 403, 660, 559, 1.06)
    atk1_1 = c(666, 401, 833, 557, 1.06)
    atk1_2 = c(974, 406, 1163, 559, 1.06)
    atk1_crescent_raw = trim_alpha(ref.crop((1288, 380, 1534, 565)), 12)
    atk1_3 = atk1_crescent_raw
    atk1_4 = c(1169, 396, 1308, 565, 1.0)

    # Row 4 right: Explosive Radial Crimson Blood-Splash Eruption!
    atk2_0 = c(546, 588, 700, 738, 1.08)
    atk2_1 = c(722, 583, 910, 739, 1.08)
    atk2_2_raw = trim_alpha(ref.crop((891, 580, 1147, 779)), 12)
    atk2_3_body = c(1235, 625, 1425, 808, 1.0)
    atk2_3_full = trim_alpha(ref.crop((1118, 571, 1530, 814)), 12)

    # Row 5 left: Hurt recoil
    hurt_0 = c(138, 769, 245, 892, 1.32)
    hurt_1 = c(251, 767, 360, 892, 1.32)

    # Rows 5 & 6: 8-frame Full Vampire Collapse & Blood-Pool Dissolution Death!
    die_0 = c(369, 791, 518, 888, 1.24)         # Drop to knees
    die_1 = c(677, 794, 832, 885, 1.22)         # Collapse onto chest
    die_2 = c(1013, 816, 1177, 883, 1.20)       # Fallen flat on stone
    die_3 = c(4, 899, 193, 1018, 1.08)          # Crimson tendrils rising around fallen body
    die_4 = c(202, 940, 381, 1015, 1.12)        # Sinking into dark crimson blood pool
    die_5 = c(382, 902, 605, 1016, 1.0)         # Swirling crimson wave submerging hair
    die_6 = c(864, 922, 1132, 1013, 0.82)       # Dissolved crimson puddle
    die_7 = c(1106, 889, 1363, 1018, 0.84)      # Final upward crimson blood splash & pool

    frames: list[Image.Image] = [
        # 0..2: Side Idle (grounded!)
        place_grounded(r2_idle),
        place_grounded(r1_side_a),
        place_grounded(r1_side_blink),
        # 3..8: Side 6-frame Grounded Walk/Run (every boot sole at exact GROUND_Y = 200!)
        place_grounded(r2_w0),
        place_grounded(r2_w1),
        place_grounded(r2_w2),
        place_grounded(r2_w3),
        place_grounded(r2_w4),
        place_grounded(r2_w5),
        # 9..10: Front/Down Idle (`idle_down`)
        place_grounded(r1_front_0, center_x_box=True),
        place_grounded(r3_front_b, center_x_box=True),
        # 11..14: Front/Down Walk (`walk_down`)
        place_grounded(r1_front_step, center_x_box=True),
        place_grounded(r1_front_0, center_x_box=True),
        place_grounded(r3_front_b, center_x_box=True),
        place_grounded(r4_front_stride, center_x_box=True),
        # 15..16: Back/Up Idle (`idle_up` — silver hair from behind!)
        place_grounded(r1_back_a, center_x_box=True),
        place_grounded(r1_back_b, center_x_box=True),
        # 17..20: Back/Up Walk (`walk_up` — walking upward looking away!)
        place_grounded(r3_up_0, center_x_box=True),
        place_grounded(r3_up_1, center_x_box=True),
        place_grounded(r3_up_2, center_x_box=True),
        place_grounded(r4_up_3, center_x_box=True),
        # 21..25: Attack 1 — Sweeping Crimson Crescent Blood-Splash Slash!
        place_grounded(atk1_0, body_only=True),
        place_grounded(atk1_1, body_only=True),
        place_grounded(atk1_2, body_only=True),
        place_grounded(atk1_3, dx=16, dy=4, center_x_box=True),
        place_grounded(atk1_4, body_only=True),
        # 26..29: Attack 2 — Radial Crimson Blood-Splash Eruption!
        place_grounded(atk2_0, body_only=True),
        place_grounded(atk2_1, body_only=True),
        place_grounded(atk2_2_raw, center_x_box=True, dy=4),
        place_grounded(atk2_3_body, center_x_box=True),
        # 30..31: Hurt
        place_grounded(hurt_0, dx=-3),
        place_grounded(hurt_1, dx=-5),
        # 32..39: 8-frame Vampire Collapse & Blood-Pool Dissolution Death!
        place_grounded(die_0, center_x_box=True, dy=2),
        place_grounded(die_1, center_x_box=True, dy=3),
        place_grounded(die_2, center_x_box=True, dy=4),
        place_grounded(die_3, center_x_box=True, dy=4),
        place_grounded(die_4, center_x_box=True, dy=5),
        place_grounded(die_5, center_x_box=True, dy=5),
        place_grounded(die_6, center_x_box=True, dy=5),
        place_grounded(die_7, center_x_box=True, dy=5),
    ]
    assert len(frames) == COLS * ROWS == 40

    sheet = Image.new("RGBA", (COLS * CELL, ROWS * CELL), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        col = i % COLS
        row = i // COLS
        sheet.alpha_composite(fr, (col * CELL, row * CELL))
    OUT_HERO.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT_HERO)

    portrait_strip = build_portrait_strip(ref)
    portrait_strip.save(OUT_PORTRAIT)

    # Pure Blood-Splash FX strip (`896 x 224` = 4 x `224x224`)
    fx_strip = Image.new("RGBA", (CELL * 4, CELL), (0, 0, 0, 0))
    fx_items = [
        extract_pure_crimson_splash(atk1_crescent_raw),                     # 0: Crescent Blood Slash Wave!
        extract_pure_crimson_splash(atk2_2_raw),                            # 1: Twin Crimson Splash Burst!
        trim_alpha(ref.crop((1106, 889, 1363, 1018)), 12),                  # 2: Ground Blood Fountain Peak!
        trim_alpha(ref.crop((1367, 889, 1531, 1015)), 12),                  # 3: Ground Blood Fountain Settle!
    ]
    for i, fxim in enumerate(fx_items):
        fitted = fit_within(fxim, CELL - 12, CELL - 12)
        fx_strip.alpha_composite(fitted, (i * CELL + (CELL - fitted.width) // 2, (CELL - fitted.height) // 2))
    fx_strip.save(OUT_FX)

    bat_strip = build_classic_crimson_bats()
    bat_strip.save(OUT_BAT)

    # Build comprehensive verification preview (`docs/images/velmira_preview.png`)
    prev_w, prev_h = 1320, 920
    prev = Image.new("RGBA", (prev_w, prev_h), (28, 28, 36, 255))
    draw = ImageDraw.Draw(prev)

    # Top row: Circular-clipped 5 HUD Portraits + 4 Blood Splash FX + 3 Classic Crimson Bats
    for i in range(5):
        pcell = portrait_strip.crop((i * 192, 0, (i + 1) * 192, 192)).resize((104, 104), Image.LANCZOS)
        # Apply circular mask exactly matching HeroHUD's circular shader!
        mask = Image.new("L", (104, 104), 0)
        ImageDraw.Draw(mask).ellipse((4, 4, 99, 99), fill=255)
        clipped = Image.new("RGBA", (104, 104), (0, 0, 0, 0))
        clipped.paste(pcell, (0, 0), mask)
        px_x = 18 + i * 116
        draw.ellipse((px_x + 2, 14, px_x + 102, 114), fill=(18, 12, 18, 255), outline=(228, 184, 88, 255), width=3)
        prev.alpha_composite(clipped, (px_x, 12))

    for i in range(4):
        fxcell = fx_strip.crop((i * CELL, 0, (i + 1) * CELL, CELL)).resize((112, 112), Image.LANCZOS)
        prev.alpha_composite(fxcell, (620 + i * 124, 10))

    for i in range(3):
        bcell = bat_strip.crop((i * 24, 0, (i + 1) * 24, 24)).resize((72, 72), Image.NEAREST)
        prev.alpha_composite(bcell, (1120 + i * 62, 32))

    # Draw all 40 frames in 4 rows of 10 with crisp ground alignment lines!
    labels = [
        "idle0", "idle1", "idle2", "walk0", "walk1", "walk2", "walk3", "walk4", "walk5", "down_i0",
        "down_i1", "down_w0", "down_w1", "down_w2", "down_w3", "up_i0", "up_i1", "up_w0", "up_w1", "up_w2",
        "up_w3", "atk1_0", "atk1_1", "atk1_2", "CRESCENT", "atk1_4", "atk2_0", "atk2_1", "SPLASH", "NOVA",
        "hurt0", "hurt1", "die0", "die1", "die2", "die3", "die4", "die5", "die6", "die7",
    ]
    disp = 124
    for i, fr in enumerate(frames):
        r = i // 10
        col = i % 10
        ox = 14 + col * 129
        oy = 140 + r * 190
        scaled = fr.resize((disp, disp), Image.LANCZOS)
        gy = oy + int(GROUND_Y * (disp / float(CELL)))
        draw.line([(ox + 12, gy), (ox + disp - 12, gy)], fill=(90, 210, 140, 120), width=1)
        prev.alpha_composite(scaled, (ox, oy))
        draw.text((ox + 28, oy + disp + 4), f"{i}:{labels[i]}", fill=(220, 215, 232, 255))

    OUT_PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    prev.save(OUT_PREVIEW)
    print(f"Generated {OUT_HERO} {sheet.size}")
    print(f"Generated {OUT_PORTRAIT} {portrait_strip.size}")
    print(f"Generated {OUT_FX} {fx_strip.size}")
    print(f"Generated {OUT_BAT} {bat_strip.size}")
    print(f"Generated {OUT_PREVIEW} {prev.size}")


if __name__ == "__main__":
    main()
