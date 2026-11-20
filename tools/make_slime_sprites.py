#!/usr/bin/env python
"""Generate every slime texture in one go (sprite sheet + goo puddle + shadow).

Why a generator instead of a hand-drawn PNG?
  * The slime is a 26-frame sheet (12 poses x coloured + white hit-flash
    silhouette). Editing 26 frames by hand invites drift between poses;
    here every pose is *the same dome* with different radii, so the slime
    can never look like a different creature between frames.
  * Re-running this file is the single source of truth:
        python tools/make_slime_sprites.py
    Writes:
        assets/textures/slime.png             384x64  (12 cols x 2 rows)
        assets/textures/slime_goo_puddle.png   32x10  (ground goo / death splat)
        assets/textures/slime_shadow.png       32x10  (soft ground shadow)
        docs/images/slime_preview.png                 (8x contact sheet for docs)

SHEET LAYOUT (this is mirrored in scripts/enemies/slime_visuals.gd):
    row 0, columns 0-11 : the 12 coloured poses
    row 1, columns 0-11 : the SAME poses as pure-white silhouettes
                          (swapping row 0 -> row 1 for 0.1 s IS the hit flash;
                           no shader, no extra overlay node)

ART RULES
  * 32x32 frame, ground line at y = 29.5 so the feet sit on the node origin.
  * Light comes from the top-left: one bright band, one base band, one shade
    band, plus a specular blob and a translucent "bounce" glow at the base.
  * 1 px dark outline closes the silhouette (same trick the colossus uses).
  * The body is a filled dome (superellipse), never a box: the top is broad
    and the bottom edge rolls under, which is what makes it read as jelly.
"""

import math
from dataclasses import dataclass, field
from typing import Dict, List, Tuple, Optional

from PIL import Image, ImageDraw

# ---------------------------------------------------------------------------
# Sheet geometry
# ---------------------------------------------------------------------------
FRAME = 32
GROUND_Y = 29.5          # y of the ground line inside the frame
CX = 16.0                # horizontal centre of the dome
COLS = 12                # poses per row
ROWS = 2                 # row 0 = art, row 1 = white flash silhouette

# ---------------------------------------------------------------------------
# Palette (matches the old body_color #6EC866 so the game's greens stay home)
# ---------------------------------------------------------------------------
OUTLINE = (26, 40, 30, 255)
DEEP    = (58, 122, 70, 255)     # darkest body band (bottom-right rim)
SHADE   = (82, 168, 86, 255)
BASE    = (108, 200, 100, 255)   # ~ #6CC864, the slime's "skin"
LIGHT   = (146, 224, 124, 255)
BOUNCE  = (126, 208, 118, 255)   # light bounced back up at the base
SPEC    = (206, 248, 186, 255)   # specular blob
EYE     = (22, 38, 30, 255)
GLINT   = (250, 255, 245, 255)
MOUTH   = (30, 52, 36, 255)
TONGUE  = (245, 118, 128, 255)
BLUSH   = (255, 146, 158, 150)
SWEAT   = (188, 240, 255, 235)
WHITE   = (255, 255, 255, 255)


# ---------------------------------------------------------------------------
# Face pieces -- tiny pixel patterns, one character per pixel.
#   '.' transparent   '#' dark    '1' glint (white)
# ---------------------------------------------------------------------------
EYE_OPEN = [".###.",
            "#1###",
            "#####",
            "#####",
            ".###."]

EYE_WIDE = [".###.",
            "#1###",
            "#####",
            "#####",
            "#####",
            ".###."]

EYE_HALF = [".###.",
            "#####"]

EYE_HAPPY = [".###.",
             "#...#"]

EYE_HURT_L = ["..#",
              ".#.",
              "..#"]

EYE_HURT_R = ["#..",
              ".#.",
              "#.."]

BROW_L = ["###.",
          "..##"]

BROW_R = ["..##",
          "###."]

MOUTH_SMILE = ["#..#",
               ".##."]

MOUTH_GRIN = ["#...#",
              ".###."]

MOUTH_FLAT = ["###"]

MOUTH_O = [".#.",
           "#.#",
           ".#."]

MOUTH_WIDE = ["#####",
              "#111#",
              "#####"]

MOUTH_GRIT = ["#####",
              "#.#.#"]


# ---------------------------------------------------------------------------
# Poses
# ---------------------------------------------------------------------------
@dataclass
class Pose:
    name: str
    rx: float                 # half width in px (at the widest point)
    ry: float                 # height in px (ground -> crown)
    exponent: float = 3.2     # dome fullness: higher = flatter crown
    shoulder: float = 0.42
    lean: float = 0.0         # top-of-body horizontal shift (px, + = right)
    eyes: str = "open"        # open / wide / half / happy / hurt
    eye_gap: float = 4.4      # distance from the face centre to each eye
    brow: bool = False
    mouth: str = "smile"      # smile / grin / flat / o / wide / grit / none
    blush: bool = False
    sweat: bool = False
    speed_lines: bool = False
    eye_dy: float = 0.0
    tint: Optional[Tuple[int, int, int]] = None


POSES: List[Pose] = [
    # 0 - idle "out breath": the resting dome
    Pose("idle_a", rx=11.6, ry=17.6, eyes="open", mouth="smile", blush=True),
    # 1 - idle "in breath": a hair taller, the loop is a 2-frame breath
    Pose("idle_b", rx=11.2, ry=19.0, eyes="open", mouth="smile", blush=True),
    # 2 - blink: same shape as idle_a, eyes closed happy
    Pose("blink", rx=11.6, ry=17.6, eyes="happy", mouth="smile", blush=True),
    # 3 - hop anticipation: squashed, half-lidded, mouth flat
    Pose("crouch", rx=13.2, ry=12.6, eyes="happy", mouth="flat"),
    # 4 - rising: stretched tall, eyes wide, small "o" of effort
    Pose("air_up", rx=10.2, ry=21.0, eyes="wide", mouth="o"),
    # 5 - falling: a touch wider than rising, mouth open
    Pose("air_down", rx=10.8, ry=19.2, eyes="wide", mouth="o"),
    # 6 - landing splat: widest + shortest pose in the set
    Pose("land", rx=14.0, ry=10.0, exponent=4.2, eyes="hurt", mouth="wide"),
    # 7 - attack telegraph: gathered low, leaning back, angry brows, teeth
    Pose("telegraph", rx=12.8, ry=13.2, eyes="half", brow=True,
         mouth="grit", lean=-0.8),
    # 8 - lunge: long and thin, leaning into the jump, shouting
    Pose("lunge", rx=10.2, ry=20.4, eyes="wide", brow=True,
         mouth="wide", lean=2.2, eye_gap=3.6),
    # 9 - hurt: a bitten-in flinch, >< eyes, sweat drop
    Pose("hurt", rx=12.4, ry=14.2, eyes="hurt", mouth="flat", sweat=True,
         lean=-0.6),
    # 10 - settle: small rebound after a landing
    Pose("settle", rx=12.4, ry=15.4, eyes="open", mouth="smile", blush=True),
    # 11 - death puddle: flattened goo, eyes closed, tiny smile
    Pose("puddle", rx=14.6, ry=7.8, exponent=4.0, shoulder=0.5,
         eyes="happy", mouth="smile", eye_gap=3.8),
]


# ---------------------------------------------------------------------------
# Shape + shading
# ---------------------------------------------------------------------------
def profile(v: float, exponent: float, shoulder: float) -> float:
    """Half-width of the dome at height fraction v (0 = ground, 1 = crown).

    (1 - v**e)**s keeps the body broad over most of its height and then
    rounds it off quickly near the crown - the classic slime silhouette.
    The extra taper in the first rows rolls the bottom edge under so the
    blob does not look like it was cut with a knife.
    """
    if v <= 0.0 or v >= 1.0:
        return 0.0
    width = (1.0 - v ** exponent) ** shoulder
    if v < 0.16:
        width *= 1.0 + 0.06 * (1.0 - v / 0.16)
    return width


def light_band(u: float, v: float) -> Tuple[int, int, int, int]:
    """Band-shaded body colour for a point at (u, v) inside the dome.

    A single scalar "how much light lands here" value is built from the
    height (v) and the horizontal position (u), then cut into flat bands.
    Flat bands - not a gradient - are what make pixel art read as pixel art.
    """
    lum = 0.62 * v - 0.34 * u - 0.14

    if lum > 0.40:
        colour = LIGHT
    elif lum > 0.09:
        colour = BASE
    elif lum > -0.13:
        colour = SHADE
    else:
        colour = DEEP

    # Translucent jelly: light that entered the body bounces back up at the
    # base, so the very bottom row stays bright instead of going black.
    if v < 0.11:
        colour = BOUNCE
    return colour


def build_mask(pose: Pose) -> Dict[Tuple[int, int], Tuple[float, float]]:
    """Map every inside pixel -> (u, v) normalised body coordinates."""
    mask: Dict[Tuple[int, int], Tuple[float, float]] = {}
    for y in range(FRAME):
        v = (GROUND_Y - (y + 0.5)) / pose.ry
        if v <= 0.0 or v >= 1.0:
            continue
        centre = CX + pose.lean * (v ** 1.7)
        half = pose.rx * profile(v, pose.exponent, pose.shoulder)
        if half <= 0.0:
            continue
        for x in range(FRAME):
            u = (x + 0.5 - centre) / half
            if abs(u) <= 1.0:
                mask[(x, y)] = (u, v)
    return mask


def paint_body(img: Image.Image, pose: Pose, mask: Dict[Tuple[int, int], Tuple[float, float]],
               solid: Optional[Tuple[int, int, int, int]] = None) -> None:
    """Fill the dome, add the specular blob, then close it with an outline."""
    px = img.load()

    for (x, y), (u, v) in mask.items():
        if solid is not None:
            px[x, y] = solid
            continue
        px[x, y] = light_band(u, v)

    if solid is None and pose.ry >= 12.0:
        # Specular blob: one soft highlight high on the light side.
        # (Skipped on the very flat poses - a "wet spot" in the middle of a
        # pancake reads as a blemish, not as gloss.)
        hx = CX + pose.lean * 0.9 - pose.rx * 0.40
        hy = GROUND_Y - pose.ry * 0.74
        rw, rh = max(1.4, pose.rx * 0.22), max(0.9, pose.ry * 0.07)
        for y in range(FRAME):
            for x in range(FRAME):
                if (x, y) not in mask:
                    continue
                dx = (x + 0.5 - hx) / rw
                dy = (y + 0.5 - hy) / rh
                if dx * dx + dy * dy <= 1.0:
                    px[x, y] = SPEC

        # Second, smaller sparkle just below it: reads as wet, not flat.
        sx, sy = int(hx + rw * 1.9), int(hy + rh * 2.1)
        if (sx, sy) in mask:
            px[sx, sy] = (238, 255, 222, 255)

    # Outline: any body pixel that sees the outside world in one of the 4
    # cardinal directions becomes the dark rim.
    rim = []
    for (x, y) in mask:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in mask:
                rim.append((x, y))
                break
    for (x, y) in rim:
        px[x, y] = OUTLINE if solid is None else solid


def draw_pattern(px, pattern: List[str], ox: int, oy: int,
                 palette: Dict[str, Tuple[int, int, int, int]],
                 mask: Optional[Dict] = None) -> None:
    for row, line in enumerate(pattern):
        for col, ch in enumerate(line):
            if ch == ".":
                continue
            colour = palette.get(ch)
            if colour is None:
                continue
            x, y = ox + col, oy + row
            if not (0 <= x < FRAME and 0 <= y < FRAME):
                continue
            if mask is not None and (x, y) not in mask:
                continue
            px[x, y] = colour


def eye_origin(pose: Pose, side: int) -> Tuple[int, int]:
    """Top-left pixel of the 5x5 eye box. side = -1 (left) / +1 (right)."""
    centre = CX + pose.lean * 0.7
    offset = pose.eye_gap * side
    eye_y = GROUND_Y - pose.ry * 0.58 + pose.eye_dy
    return int(round(centre + offset - 2.0)), int(round(eye_y - 2.0))


def paint_face(img: Image.Image, pose: Pose, mask) -> None:
    px = img.load()
    ink = {"#": EYE, "1": GLINT}

    for side in (-1, 1):
        ex, ey = eye_origin(pose, side)
        eye_pattern = {
            "open": (EYE_OPEN, 0, 0),
            "wide": (EYE_WIDE, 0, -1),
            "half": (EYE_HALF, 0, 2),
            "happy": (EYE_HAPPY, 0, 2),
            "hurt": (EYE_HURT_L if side < 0 else EYE_HURT_R, 1, 1),
        }.get(pose.eyes)
        if pose.eyes == "open":
            draw_pattern(px, EYE_OPEN, ex, ey, ink, mask)
        elif pose.eyes == "wide":
            draw_pattern(px, EYE_WIDE, ex, ey - 1, ink, mask)
        elif pose.eyes == "half":
            draw_pattern(px, EYE_HALF, ex, ey + 2, ink, mask)
        elif pose.eyes == "happy":
            draw_pattern(px, EYE_HAPPY, ex, ey + 2, ink, mask)
        elif pose.eyes == "hurt":
            draw_pattern(px, EYE_HURT_L if side < 0 else EYE_HURT_R,
                         ex + 1, ey + 1, ink, mask)
        if pose.brow:
            draw_pattern(px, BROW_L if side < 0 else BROW_R,
                         ex, ey - 2, {"#": MOUTH}, mask)

        if pose.blush:
            bx = int(round(CX + pose.lean * 0.7 + side * (pose.eye_gap + 2.2) - 1.0))
            draw_pattern(px, ["##"], bx, ey + 3,
                         {"#": (240, 150, 160, 210)}, mask)

    # Mouth sits on the centre line, just under the eyes.
    mx = int(round(CX + pose.lean * 0.7))
    my = int(round(GROUND_Y - pose.ry * 0.31))
    palette = {"#": MOUTH, "1": TONGUE}
    if pose.mouth == "smile":
        draw_pattern(px, MOUTH_SMILE, mx - 2, my, {"#": DEEP}, mask)
    elif pose.mouth == "grin":
        draw_pattern(px, MOUTH_GRIN, mx - 2, my, {"#": DEEP}, mask)
    elif pose.mouth == "flat":
        draw_pattern(px, MOUTH_FLAT, mx - 1, my, {"#": DEEP}, mask)
    elif pose.mouth == "o":
        draw_pattern(px, MOUTH_O, mx - 1, my - 1, palette, mask)
    elif pose.mouth == "wide":
        draw_pattern(px, MOUTH_WIDE, mx - 2, my - 1, palette, mask)
    elif pose.mouth == "grit":
        draw_pattern(px, MOUTH_GRIT, mx - 2, my, palette, mask)

    if pose.sweat:
        sx = int(round(CX + pose.rx * 0.62))
        draw_pattern(px, [".#.",
                          "###",
                          ".#."], sx, int(round(GROUND_Y - pose.ry * 0.92)),
                     {"#": SWEAT}, mask)


def render_pose(pose: Pose) -> Image.Image:
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    mask = build_mask(pose)
    paint_body(img, pose, mask)
    paint_face(img, pose, mask)
    return img


def render_silhouette(pose: Pose) -> Image.Image:
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    mask = build_mask(pose)
    paint_body(img, pose, mask, solid=WHITE)
    return img


# ---------------------------------------------------------------------------
# Companion textures
# ---------------------------------------------------------------------------
def make_puddle() -> Image.Image:
    """A flat goo puddle: used under the feet and as the death splat decal."""
    w, h = 32, 10
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            u = (x + 0.5 - w * 0.5) / (w * 0.5 - 1.0)
            v = (y + 0.5 - h * 0.5) / (h * 0.5)
            dist = u * u + v * v * 1.35
            if dist > 1.0:
                continue
            if dist > 0.74:
                px[x, y] = (46, 104, 60, 190)
            elif v < -0.35 and u < 0.1:
                px[x, y] = (168, 232, 150, 205)   # wet highlight
            else:
                px[x, y] = (84, 168, 88, 200)
            if v > 0.45 and dist > 0.5:
                px[x, y] = (40, 92, 54, 175)      # shaded front lip
    return img


def make_shadow() -> Image.Image:
    """Soft oval shadow with a feathered rim (much nicer than a scaled square)."""
    w, h = 32, 10
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            u = (x + 0.5 - w * 0.5) / (w * 0.5 - 1.0)
            v = (y + 0.5 - h * 0.5) / (h * 0.5)
            dist = math.sqrt(u * u + v * v)
            if dist > 1.0:
                continue
            alpha = int(120 * (1.0 - dist) ** 0.55)
            px[x, y] = (0, 0, 0, alpha)
    return img


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
def build_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (FRAME * COLS, FRAME * ROWS), (0, 0, 0, 0))
    for i, pose in enumerate(POSES):
        sheet.paste(render_pose(pose), (i * FRAME, 0))
        sheet.paste(render_silhouette(pose), (i * FRAME, FRAME))
    return sheet


def build_preview(sheet: Image.Image) -> Image.Image:
    """8x contact sheet with labels - what humans look at in the docs."""
    zoom = 8
    pad = 10
    label_h = 16
    bg = (24, 30, 34, 255)
    cell_w = FRAME * zoom + pad
    cell_h = FRAME * zoom + pad + label_h
    preview = Image.new("RGBA", (cell_w * 6 + pad, cell_h * 4 + pad * 2), bg)
    draw = ImageDraw.Draw(preview)

    frames: List[Tuple[Image.Image, str]] = []
    for pose in POSES:
        frames.append((render_pose(pose), pose.name))
    for pose in POSES:
        frames.append((render_silhouette(pose), "flash_" + pose.name))

    for i, (frame, name) in enumerate(frames):
        col, row = i % 6, i // 6
        x = pad + col * cell_w
        y = pad + row * cell_h
        scaled = frame.resize((FRAME * zoom, FRAME * zoom), Image.NEAREST)
        preview.alpha_composite(scaled, (x, y))
        draw.text((x + 2, y + FRAME * zoom + 2), name, fill=(210, 235, 210, 255))
    return preview


def main() -> None:
    sheet = build_sheet()
    sheet.save("assets/textures/slime.png")
    make_puddle().save("assets/textures/slime_goo_puddle.png")
    make_shadow().save("assets/textures/slime_shadow.png")

    import os
    os.makedirs("docs/images", exist_ok=True)
    build_preview(sheet).save("docs/images/slime_preview.png")

    print("wrote assets/textures/slime.png", sheet.size)
    print("wrote assets/textures/slime_goo_puddle.png", (32, 10))
    print("wrote assets/textures/slime_shadow.png", (32, 10))
    print("wrote docs/images/slime_preview.png")


if __name__ == "__main__":
    main()
