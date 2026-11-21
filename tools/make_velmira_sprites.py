#!/usr/bin/env python3
"""Build Velmira's sprite sheet, close-up portrait strip, crimson bats, and blood FX
directly from the canonical reference sheet `assets/sprites/vampire/velmira_reference.png`.

Outputs:
  - assets/textures/player_shabnam.png   (3800 x 200: 19 frames of 200x200 native pixels)
      0..2   : idle   (3 frames — regal breathing & silver hair sway)
      3..6   : walk   (4 frames — dynamic forward-leaning Vampire Run!)
      7..9   : attack (3 frames — Blood Magic Cast 1)
      10..11 : attack_lance (2 frames — Blood Whip / Lance Thrust)
      12..14 : charge (3 frames — High-speed Mist Dash -> Shadow-Bat Silhouette!)
      15..16 : hurt   (2 frames — Recoil & Stagger)
      17..18 : die    (2 frames — Kneel -> Fallen Collapse)
  - assets/textures/portrait_shabnam.png (960 x 192: 5 frames of 192x192 close-up face)
      0: idle_a, 1: idle_b, 2: blink, 3: low_hp, 4: hurt
  - assets/textures/velmira_fx.png       (640 x 160: 4 frames of 160x160 Blood Magic FX)
      0: Crimson Crest, 1: Blood Whip Swirl, 2: 2-Fang Flame Circle, 3: 30% Blood Eruption
  - assets/textures/crimson_bat.png      (192 x 64: 3 frames of 64x64 flapping reference bats)
  - docs/images/velmira_preview.png      (Visual verification sheet on Arena slate floor)
"""
import os
import sys
from collections import deque

sys.path.insert(0, "/tmp/pydeps")
from PIL import Image, ImageDraw, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF_PATH = os.path.join(ROOT, "assets", "sprites", "vampire", "velmira_reference.png")
OUT_SHEET = os.path.join(ROOT, "assets", "textures", "player_shabnam.png")
OUT_PORTRAIT = os.path.join(ROOT, "assets", "textures", "portrait_shabnam.png")
OUT_FX = os.path.join(ROOT, "assets", "textures", "velmira_fx.png")
OUT_BAT = os.path.join(ROOT, "assets", "textures", "crimson_bat.png")
OUT_PREVIEW = os.path.join(ROOT, "docs", "images", "velmira_preview.png")

CELL = 200
GROUND_Y = 186


def extract_components(im: Image.Image, alpha_thresh: int = 38, min_pixels: int = 800):
    """Extract exact 8-connected pixel islands so neighboring sprites never bleed together."""
    w, h = im.size
    px = im.load()
    visited = bytearray(w * h)
    comps = []

    for y in range(h):
        row_off = y * w
        for x in range(w):
            idx = row_off + x
            if not visited[idx] and px[x, y][3] > alpha_thresh:
                q = deque([(x, y)])
                visited[idx] = 1
                coords = []
                minx = maxx = x
                miny = maxy = y
                while q:
                    cx, cy = q.popleft()
                    coords.append((cx, cy))
                    if cx < minx:
                        minx = cx
                    if cx > maxx:
                        maxx = cx
                    if cy < miny:
                        miny = cy
                    if cy > maxy:
                        maxy = cy
                    for dy in (-1, 0, 1):
                        ny = cy + dy
                        if 0 <= ny < h:
                            n_off = ny * w
                            for dx in (-1, 0, 1):
                                nx = cx + dx
                                if 0 <= nx < w:
                                    nidx = n_off + nx
                                    if not visited[nidx] and px[nx, ny][3] > alpha_thresh:
                                        visited[nidx] = 1
                                        q.append((nx, ny))
                if len(coords) >= min_pixels:
                    # Build isolated sprite with 1px soft-alpha fringe ring preserved
                    pad = 2
                    bx0 = max(0, minx - pad)
                    by0 = max(0, miny - pad)
                    bx1 = min(w, maxx + 1 + pad)
                    by1 = min(h, maxy + 1 + pad)
                    sub = Image.new("RGBA", (bx1 - bx0, by1 - by0), (0, 0, 0, 0))
                    spx = sub.load()
                    mask_set = set(coords)
                    for sy in range(by0, by1):
                        for sx in range(bx0, bx1):
                            if (sx, sy) in mask_set:
                                spx[sx - bx0, sy - by0] = px[sx, sy]
                            elif px[sx, sy][3] > 10:
                                # Keep anti-aliased edge pixel if adjacent to this island
                                near = any(
                                    (sx + ox, sy + oy) in mask_set
                                    for ox in (-1, 0, 1)
                                    for oy in (-1, 0, 1)
                                )
                                if near:
                                    spx[sx - bx0, sy - by0] = px[sx, sy]
                    comps.append((bx0, by0, bx1, by1, sub))

    comps.sort(key=lambda c: (c[1] // 140, c[0]))
    return comps


def find_comp_near(comps, target_cx: int, target_cy: int, max_dist: float = 95.0) -> Image.Image:
    best = None
    best_d = 1e9
    for x0, y0, x1, y1, sub in comps:
        cx = 0.5 * (x0 + x1)
        cy = 0.5 * (y0 + y1)
        d = ((cx - target_cx) ** 2 + (cy - target_cy) ** 2) ** 0.5
        if d < best_d and d <= max_dist:
            best_d = d
            best = sub
    if best is None:
        raise RuntimeError(f"No component found near ({target_cx}, {target_cy})")
    return best


def compute_body_anchor(sp: Image.Image):
    """Return (anchor_x, bottom_y) anchored to the lower-body/torso mass so trailing capes
    or outstretched magic hands do not shift the character's spine."""
    w, h = sp.size
    px = sp.load()
    bottom_y = h - 1
    for y in range(h - 1, -1, -1):
        if any(px[x, y][3] > 60 for x in range(w)):
            bottom_y = y
            break

    # Weight X centroid across the central-lower body band (35%..88% height) using high-alpha pixels
    y_start = int(h * 0.30)
    y_end = max(y_start + 4, int(bottom_y * 0.90))
    xs = []
    for y in range(y_start, min(h, y_end)):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 150:
                xs.append(x)
    if not xs:
        anchor_x = w // 2
    else:
        xs.sort()
        # Median X is ultra-robust against long trailing capes or forward blood lances!
        anchor_x = xs[len(xs) // 2]
    return anchor_x, bottom_y


def place_in_cell(sp: Image.Image, scale: float = 1.0, y_offset: int = 0, x_nudge: int = 0) -> Image.Image:
    if abs(scale - 1.0) > 1e-3:
        nw = max(1, int(round(sp.width * scale)))
        nh = max(1, int(round(sp.height * scale)))
        sp = sp.resize((nw, nh), Image.LANCZOS)

    # Fit safely if wider than CELL - 8
    if sp.width > CELL - 6:
        fit = (CELL - 6) / float(sp.width)
        sp = sp.resize((CELL - 6, max(1, int(round(sp.height * fit)))), Image.LANCZOS)

    ax, by = compute_body_anchor(sp)
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    dx = (CELL // 2) - ax + x_nudge
    dy = GROUND_Y - by + y_offset
    dx = max(2, min(CELL - sp.width - 2, dx))
    dy = max(2, min(CELL - sp.height - 2, dy))
    cell.alpha_composite(sp, (dx, dy))
    return cell


def build_portrait_strip(ref: Image.Image) -> Image.Image:
    """Build 5-frame 192x192 close-up face strip (idle_a, idle_b, blink, low_hp, hurt)
    from the top-left reference portrait."""
    P = 192
    # Crop square directly around Velmira's crown, pointed ear, crimson eyes, and collar
    face_box = ref.crop((18, 8, 306, 296))  # 288 x 288 square!
    base = face_box.resize((P, P), Image.LANCZOS)

    strip = Image.new("RGBA", (P * 5, P), (0, 0, 0, 0))

    # 0: idle_a — exact reference portrait
    f0 = base.copy()
    strip.alpha_composite(f0, (0, 0))

    # 1: idle_b — subtle 1px breathing rise + brighter ruby gem & crimson eye gleam
    f1 = Image.new("RGBA", (P, P), (0, 0, 0, 0))
    f1.alpha_composite(base, (0, -1))
    f1_bright = ImageEnhance.Brightness(f1).enhance(1.04)
    strip.alpha_composite(f1_bright, (P, 0))

    # Helper: true crimson iris test (excludes warm peach skin/eyelid shadows!)
    def is_iris(x: int, y: int, r: int, g: int, b: int) -> bool:
        in_left = (92 <= x <= 122 and 92 <= y <= 110)
        in_right = (135 <= x <= 156 and 103 <= y <= 120)
        return (in_left or in_right) and r > 105 and g < 78 and r > g + 42

    # 2: blink — gentle closed silver-lashed eyelids over BOTH crimson irises
    f2 = base.copy()
    px2 = f2.load()
    for y in range(90, 122):
        for x in range(90, 158):
            r, g, b, a = px2[x, y]
            if a > 180 and is_iris(x, y, r, g, b):
                px2[x, y] = (232, 202, 214, a)
    draw2 = ImageDraw.Draw(f2)
    draw2.line([(94, 104), (105, 106), (118, 105)], fill=(52, 24, 40, 245), width=2)
    draw2.line([(137, 113), (145, 115), (153, 114)], fill=(52, 24, 40, 245), width=2)
    strip.alpha_composite(f2, (P * 2, 0))

    # 3: low_hp — blood-starved vampire aura, radiant crimson irises & tiny lip blood drop
    f3 = base.copy()
    px3 = f3.load()
    for y in range(P):
        for x in range(P):
            r, g, b, a = px3[x, y]
            if a < 20:
                continue
            if is_iris(x, y, r, g, b):
                px3[x, y] = (min(255, int(r * 1.32 + 34)), max(0, int(g * 0.45)), max(0, int(b * 0.55)), a)
            else:
                dist = (((x - P * 0.54) / (P * 0.5)) ** 2 + ((y - P * 0.50) / (P * 0.5)) ** 2) ** 0.5
                vign = min(0.42, max(0.0, (dist - 0.34) * 0.60))
                nr = int(r * (1.0 - vign * 0.30) + 135 * vign * 0.30)
                ng = int(g * (1.0 - vign * 0.62))
                nb = int(b * (1.0 - vign * 0.48) + 45 * vign * 0.22)
                px3[x, y] = (min(255, nr), max(0, ng), max(0, nb), a)
    # Subtle crimson blood bead at the corner of her lips (around x=126, y=136)
    draw3 = ImageDraw.Draw(f3)
    draw3.ellipse((125, 136, 128, 141), fill=(196, 18, 48, 235))
    strip.alpha_composite(f3, (P * 3, 0))

    # 4: hurt — clean recoil tilt, closed wincing lashes, & subtle crimson impact flash
    f4_rot = f2.rotate(-4.5, resample=Image.BICUBIC, expand=False)
    f4 = Image.new("RGBA", (P, P), (0, 0, 0, 0))
    f4.alpha_composite(f4_rot, (3, 2))
    px4 = f4.load()
    for y in range(P):
        for x in range(P):
            r, g, b, a = px4[x, y]
            if a < 20:
                continue
            px4[x, y] = (min(255, int(r * 1.08 + 20)), int(g * 0.86), int(b * 0.90), a)
    strip.alpha_composite(f4, (P * 4, 0))

    return strip


def build_fx_and_bats(ref: Image.Image, comps):
    """Extract Row-6 Blood Magic Effects & Crimson Bats directly from the reference sheet."""
    FX_S = 160
    fx_strip = Image.new("RGBA", (FX_S * 4, FX_S), (0, 0, 0, 0))

    # 0: Crimson Vampire Crest (near 110, 1116)
    crest = find_comp_near(comps, 110, 1116)
    # 1: Swirling Liquid Blood Whip (near 290, 1132)
    whip = find_comp_near(comps, 290, 1132)
    # 2: Circular Jagged 2-Fang Crimson Ring (near 578, 1125)
    ring = find_comp_near(comps, 578, 1125)
    # 3: Crimson Blood Spire Eruption (near 851, 1132)
    erupt = find_comp_near(comps, 851, 1132)

    for idx, art in enumerate([crest, whip, ring, erupt]):
        scale = min((FX_S - 10) / float(art.width), (FX_S - 10) / float(art.height))
        nw = max(1, int(round(art.width * scale)))
        nh = max(1, int(round(art.height * scale)))
        rs = art.resize((nw, nh), Image.LANCZOS)
        fx_strip.alpha_composite(rs, (idx * FX_S + (FX_S - nw) // 2, (FX_S - nh) // 2))

    # Extract flapping Crimson Bats (64x64 x 3 frames = 192x64) from Row 6 (x=412..490, y=1078..1122)
    bat_hi = find_comp_near(comps, 450, 1100)  # Clean single reference bat with wings raised!
    bat_mid = bat_hi.resize((bat_hi.width, max(1, int(bat_hi.height * 0.62))), Image.LANCZOS)
    bat_lo = bat_hi.transpose(Image.FLIP_TOP_BOTTOM)

    BAT_S = 64
    bat_strip = Image.new("RGBA", (BAT_S * 3, BAT_S), (0, 0, 0, 0))
    for i, b_src in enumerate([bat_hi, bat_mid, bat_lo]):
        sc = min((BAT_S - 8) / float(b_src.width), (BAT_S - 8) / float(b_src.height))
        bw = max(1, int(round(b_src.width * sc)))
        bh = max(1, int(round(b_src.height * sc)))
        br = b_src.resize((bw, bh), Image.LANCZOS)
        # Boost bat crimson glow so they pop vividly during Shift Bat-Swarm!
        br = ImageEnhance.Brightness(br).enhance(1.22)
        bat_strip.alpha_composite(br, (i * BAT_S + (BAT_S - bw) // 2, (BAT_S - bh) // 2))

    return fx_strip, bat_strip


def main() -> None:
    ref = Image.open(REF_PATH).convert("RGBA")
    comps = extract_components(ref, alpha_thresh=38, min_pixels=800)

    # --- Locate all 19 exact animation frames from the reference sheet ---
    # Row 1 Idle (3/4 right regal poses, scaled 0.805x to match Row 2..5 gameplay height!)
    idle_0 = find_comp_near(comps, 585, 113)
    idle_1 = find_comp_near(comps, 748, 113)
    idle_2 = find_comp_near(comps, 913, 113)

    # Row 2 Right: 4-frame Vampire Run (dynamic forward lean, streaming hair & crimson-lined mantle)
    run_0 = find_comp_near(comps, 851, 330)
    run_1 = find_comp_near(comps, 952, 333)
    run_2 = find_comp_near(comps, 1061, 334)
    run_3 = find_comp_near(comps, 1175, 340)

    # Row 4: Attack 1 (Blood Magic Cast, 3 frames) + Attack 2 (Blood Whip/Lance Thrust, 2 frames)
    atk_0 = find_comp_near(comps, 119, 729)
    atk_1 = find_comp_near(comps, 281, 730)
    atk_2 = find_comp_near(comps, 431, 731)

    # Clean C27's left edge where C26's red crescent tip touched x=576..632
    atk2_raw = ref.crop((634, 664, 799, 814))
    atk_3 = atk2_raw
    atk_4 = find_comp_near(comps, 864, 738)

    # Row 3 Left: Dash -> Shadow-Bat Mist Form!
    dash_0 = find_comp_near(comps, 121, 521)
    dash_1 = find_comp_near(comps, 540, 529)
    dash_2 = find_comp_near(comps, 691, 531)  # Dark purple-black shadow-bat form!

    # Row 5 Left: Hurt Stagger (2 expressive frames)
    hurt_0 = find_comp_near(comps, 83, 927)
    hurt_1 = find_comp_near(comps, 368, 933)

    # Row 5 Right: Die Collapse (Kneel -> Fallen)
    die_0 = find_comp_near(comps, 786, 942)
    die_1 = find_comp_near(comps, 1144, 972)

    frames = [
        place_in_cell(idle_0, scale=0.805),              # 0: idle_0
        place_in_cell(idle_1, scale=0.805),              # 1: idle_1
        place_in_cell(idle_2, scale=0.805),              # 2: idle_2
        place_in_cell(run_0, scale=1.0),                 # 3: run_0
        place_in_cell(run_1, scale=1.0),                 # 4: run_1
        place_in_cell(run_2, scale=1.0),                 # 5: run_2
        place_in_cell(run_3, scale=1.0),                 # 6: run_3
        place_in_cell(atk_0, scale=1.0),                 # 7: atk_0
        place_in_cell(atk_1, scale=1.0),                 # 8: atk_1
        place_in_cell(atk_2, scale=1.0),                 # 9: atk_2
        place_in_cell(atk_3, scale=1.0, x_nudge=-6),     # 10: atk_lance_0
        place_in_cell(atk_4, scale=1.0, x_nudge=-4),     # 11: atk_lance_1
        place_in_cell(dash_0, scale=1.0, y_offset=-6),   # 12: dash_0
        place_in_cell(dash_1, scale=1.0, y_offset=-6),   # 13: dash_1
        place_in_cell(dash_2, scale=1.0, y_offset=-8),   # 14: dash_shadow_bat!
        place_in_cell(hurt_0, scale=1.0),                # 15: hurt_0
        place_in_cell(hurt_1, scale=1.0),                # 16: hurt_1
        place_in_cell(die_0, scale=1.0),                 # 17: die_0 (kneel)
        place_in_cell(die_1, scale=1.0),                 # 18: die_1 (fallen)
    ]

    sheet = Image.new("RGBA", (CELL * len(frames), CELL), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.alpha_composite(fr, (i * CELL, 0))
    sheet.save(OUT_SHEET)

    portrait_strip = build_portrait_strip(ref)
    portrait_strip.save(OUT_PORTRAIT)

    fx_strip, bat_strip = build_fx_and_bats(ref, comps)
    fx_strip.save(OUT_FX)
    bat_strip.save(OUT_BAT)

    # --- Build Visual Verification Preview on Arena Slate Floor ---
    pw, ph = 1260, 760
    prev = Image.new("RGBA", (pw, ph), (40, 40, 50, 255))
    draw = ImageDraw.Draw(prev)

    # Row A: 5 Portrait States (110x110) + 4 FX Icons
    for i in range(5):
        p_cell = portrait_strip.crop((i * 192, 0, (i + 1) * 192, 192)).resize((112, 112), Image.LANCZOS)
        prev.alpha_composite(p_cell, (20 + i * 124, 18))
        draw.ellipse((18 + i * 124, 16, 134 + i * 124, 132), outline=(224, 184, 86, 255), width=3)

    for i in range(4):
        f_cell = fx_strip.crop((i * 160, 0, (i + 1) * 160, 160)).resize((112, 112), Image.LANCZOS)
        prev.alpha_composite(f_cell, (660 + i * 140, 18))

    # Row B & C: All 19 Aligned 200x200 Character Frames with ground line!
    for i, fr in enumerate(frames):
        row = i // 10
        col = i % 10
        ox = 16 + col * 122
        oy = 160 + row * 220
        disp = fr.resize((118, 118), Image.LANCZOS)
        gy = oy + int(round(GROUND_Y * 118 / float(CELL)))
        draw.line((ox + 12, gy, ox + 106, gy), fill=(90, 96, 116, 180), width=1)
        prev.alpha_composite(disp, (ox, oy))

    # Row D: Crimson Bats (3 flapping frames)
    for i in range(3):
        b_cell = bat_strip.crop((i * 64, 0, (i + 1) * 64, 64))
        prev.alpha_composite(b_cell, (28 + i * 84, 630))

    prev.save(OUT_PREVIEW)
    print("Generated:", OUT_SHEET, sheet.size)
    print("Generated:", OUT_PORTRAIT, portrait_strip.size)
    print("Generated:", OUT_FX, fx_strip.size)
    print("Generated:", OUT_BAT, bat_strip.size)
    print("Generated:", OUT_PREVIEW, prev.size)


if __name__ == "__main__":
    main()
