#!/usr/bin/env python
"""Generate every slime texture in one go (sprite sheet + goo puddle + shadow).

WHY A GENERATOR, NOT HAND-DRAWN PNGS
  * The slime is one parametric dome. Every pose is that dome with different
    radii / lean, so no two poses can drift into looking like another creature.
  * Every VARIANT is that same sheet with a different palette + one silhouette
    feature. Adding a slime variant is 15 lines in `VARIANTS` below, and all
    12 poses (plus the 12 white hit-flash silhouettes) come for free.
  * Re-running this file is the single source of truth:
        python tools/make_slime_sprites.py
    Writes:
        assets/textures/slime.png              384 x (64 * variants)
        assets/textures/slime_goo_puddle.png    32 x 10
        assets/textures/slime_shadow.png        32 x 10
        docs/images/slime_preview.png                   (grass, all 12 poses)
        docs/images/slime_variants_preview.png          (family contact sheet)

SHEET LAYOUT  (mirrored in scripts/enemies/slime_visuals.gd)
    Each variant owns 24 consecutive frames = 2 rows of 12:
        row 2i     : the 12 coloured poses of variant i
        row 2i + 1 : the SAME poses as pure-white silhouettes (hit flash)
    Global frame index = variant_row * 24 + (flash ? 12 : 0) + pose
    Variant order (row pairs): 0 grass, 1 acid, 2 ember, 3 basalt
    (`SlimeVariant` in scripts/enemies/slime_variant.gd uses the same order.)

ART RULES
  * 32x32 frame, ground line at y = 29.5 so the feet sit on the node origin.
  * Light from the top-left: one bright band, one base band, one shade band,
    a specular blob, and a translucent "bounce" glow along the base.
  * 1 px dark outline closes the silhouette (same trick as the colossus).
  * The body is a filled dome (superellipse), never a box.
  * VARIANT IDENTITY IS NOT COLOUR ALONE: each variant adds a shape feature
    (spikes / shards / crest / crown / horns / drips) so it stays readable for
    colour-blind players and against the dark arena floor.
"""

import math
from dataclasses import dataclass, field
from typing import Callable, Dict, List, Optional, Tuple

from PIL import Image, ImageDraw, ImageFont

# ---------------------------------------------------------------------------
# Sheet geometry
# ---------------------------------------------------------------------------
FRAME = 32
GROUND_Y = 29.5          # y of the ground line inside the frame
CX = 16.0                # horizontal centre of the dome
COLS = 12                # poses per row
ROW_FRAMES = 12          # frames per row
VARIANT_FRAMES = 24      # one art row + one flash row

WHITE = (255, 255, 255, 255)
SWEAT = (188, 240, 255, 235)

# ---------------------------------------------------------------------------
# Palettes. One dict per variant: the SAME keys, so the shading code is shared.
#   outline / deep / shade / base / light / bounce / spec  -> body shading
#   eye / glint / mouth / tongue / blush                  -> face
# "grass" is the shipped slime (#6CC864 skin) - do not drift from it.
# ---------------------------------------------------------------------------
GRASS = {
    "outline": (26, 40, 30, 255),
    "deep": (58, 122, 70, 255),
    "shade": (82, 168, 86, 255),
    "base": (108, 200, 100, 255),
    "light": (146, 224, 124, 255),
    "bounce": (126, 208, 118, 255),
    "spec": (206, 248, 186, 255),
    "eye": (22, 38, 30, 255),
    "glint": (250, 255, 245, 255),
    "mouth": (30, 52, 36, 255),
    "tongue": (245, 118, 128, 255),
    "blush": (255, 146, 158, 150),
    "spark": (238, 255, 222, 255),
    "cheek": (240, 150, 160, 210),
}

ACID = {
    "outline": (30, 20, 44, 255),
    "deep": (76, 42, 112, 255),
    "shade": (112, 62, 152, 255),
    "base": (150, 92, 198, 255),
    "light": (188, 132, 228, 255),
    "bounce": (163, 110, 208, 255),
    "spec": (234, 202, 255, 255),
    "eye": (24, 16, 36, 255),
    "glint": (245, 255, 235, 255),
    "mouth": (38, 24, 50, 255),
    "tongue": (186, 255, 120, 255),   # acid-lime mouth: "this one is poison"
    "blush": (150, 240, 130, 200),
    "spark": (240, 255, 210, 255),
    "cheek": (170, 240, 150, 200),
}

EMBER = {
    "outline": (44, 18, 12, 255),
    "deep": (112, 34, 16, 255),
    "shade": (170, 62, 20, 255),
    "base": (212, 96, 32, 255),
    "light": (246, 150, 56, 255),
    "bounce": (235, 130, 46, 255),
    "spec": (255, 228, 150, 255),
    "eye": (36, 12, 8, 255),
    "glint": (255, 255, 225, 255),
    "mouth": (48, 16, 8, 255),
    "tongue": (255, 170, 66, 255),
    "blush": (255, 128, 80, 200),
    "spark": (255, 248, 214, 255),
    "cheek": (255, 150, 110, 200),
}

BASALT = {
    "outline": (16, 16, 20, 255),
    "deep": (44, 44, 50, 255),
    "shade": (72, 72, 80, 255),
    "base": (102, 102, 110, 255),
    "light": (140, 140, 148, 255),
    "bounce": (118, 118, 126, 255),
    "spec": (190, 190, 200, 255),
    "eye": (252, 138, 44, 255),       # amber eyes: glowing rock
    "glint": (255, 240, 190, 255),
    "mouth": (18, 18, 22, 255),
    "tongue": (255, 120, 36, 255),
    "blush": (96, 96, 104, 255),
    "spark": (226, 226, 236, 255),
    "cheek": (150, 150, 160, 200),
}

PALETTES: Dict[str, Dict[str, Tuple[int, int, int, int]]] = {
    "grass": GRASS,
    "acid": ACID,
    "ember": EMBER,
    "basalt": BASALT,
}


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
    The extra flare in the first rows makes the blob sit in its own goo
    instead of looking like it was cut with a knife.
    """
    if v <= 0.0 or v >= 1.0:
        return 0.0
    width = (1.0 - v ** exponent) ** shoulder
    if v < 0.16:
        width *= 1.0 + 0.06 * (1.0 - v / 0.16)
    return width


def light_band(u: float, v: float, pal: Dict[str, Tuple[int, int, int, int]]
               ) -> Tuple[int, int, int, int]:
    """Band-shaded body colour for a point at (u, v) inside the dome.

    A single scalar "how much light lands here" value is built from the
    height (v) and the horizontal position (u), then cut into flat bands.
    Flat bands - not a gradient - are what make pixel art read as pixel art.
    """
    lum = 0.62 * v - 0.34 * u - 0.14

    if lum > 0.40:
        colour = pal["light"]
    elif lum > 0.09:
        colour = pal["base"]
    elif lum > -0.13:
        colour = pal["shade"]
    else:
        colour = pal["deep"]

    # Translucent jelly: light that entered the body bounces back up at the
    # base, so the very bottom row stays bright instead of going black.
    if v < 0.11:
        colour = pal["bounce"]
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


def paint_body(img: Image.Image, pose: Pose,
               mask: Dict[Tuple[int, int], Tuple[float, float]],
               pal: Dict[str, Tuple[int, int, int, int]],
               solid: Optional[Tuple[int, int, int, int]] = None) -> None:
    """Fill the dome, add the specular blob, then close it with an outline."""
    px = img.load()

    for (x, y), (u, v) in mask.items():
        px[x, y] = solid if solid is not None else light_band(u, v, pal)

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
                    px[x, y] = pal["spec"]

        # Second, smaller sparkle just below it: reads as wet, not flat.
        sx, sy = int(hx + rw * 1.9), int(hy + rh * 2.1)
        if (sx, sy) in mask:
            px[sx, sy] = pal["spark"]

    # Outline: any body pixel that sees the outside world in one of the 4
    # cardinal directions becomes the dark rim.
    rim = []
    for (x, y) in mask:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in mask:
                rim.append((x, y))
                break
    for (x, y) in rim:
        px[x, y] = pal["outline"] if solid is None else solid


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


def paint_face(img: Image.Image, pose: Pose, mask,
               pal: Dict[str, Tuple[int, int, int, int]]) -> None:
    px = img.load()
    ink = {"#": pal["eye"], "1": pal["glint"]}

    for side in (-1, 1):
        ex, ey = eye_origin(pose, side)
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
                         ex, ey - 2, {"#": pal["mouth"]}, mask)

        if pose.blush:
            bx = int(round(CX + pose.lean * 0.7 + side * (pose.eye_gap + 2.2) - 1.0))
            draw_pattern(px, ["##"], bx, ey + 3, {"#": pal["cheek"]}, mask)

    # Mouth sits on the centre line, just under the eyes.
    mx = int(round(CX + pose.lean * 0.7))
    my = int(round(GROUND_Y - pose.ry * 0.31))
    palette = {"#": pal["mouth"], "1": pal["tongue"]}
    if pose.mouth == "smile":
        draw_pattern(px, MOUTH_SMILE, mx - 2, my, {"#": pal["deep"]}, mask)
    elif pose.mouth == "grin":
        draw_pattern(px, MOUTH_GRIN, mx - 2, my, {"#": pal["deep"]}, mask)
    elif pose.mouth == "flat":
        draw_pattern(px, MOUTH_FLAT, mx - 1, my, {"#": pal["deep"]}, mask)
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


# ---------------------------------------------------------------------------
# Variant silhouette features
#   Every variant carries a SHAPE difference, not only a colour difference.
#   They are painted after the body + face, using the silhouette that the
#   current pose already drew - so a spike sits on the crown of EVERY pose
#   (including the squashed ones) without any per-pose bookkeeping.
# ---------------------------------------------------------------------------
@dataclass
class Variant:
    key: str                                     # id used by GDScript
    name: str                                    # human name for the docs
    pal: Dict[str, Tuple[int, int, int, int]]
    features: List[Callable] = field(default_factory=list)
    goo: Tuple[int, int, int] = (108, 200, 100)   # particle / decal tint
    # Features drawn BEFORE the body: they sink into the shell instead of
    # sitting on top of its outline (spikes read as "growing out of it").
    back_features: List[Callable] = field(default_factory=list)


def top_of(img: Image.Image, x: int) -> Optional[int]:
    for y in range(FRAME):
        if img.getpixel((x, y))[3] > 0:
            return y
    return None


def _triangle(d, x: int, base_y: int, h: int, half: int,
              fill, rim) -> None:
    """A small upward triangle: light face, dark rim on the outer columns."""
    for i in range(h):
        y = base_y - i
        w = max(0, half + 1 - int(i * (half + 1) / max(h - 1, 1)))
        if w <= 0:
            continue
        d.line([(x - w, y), (x + w, y)], fill=rim)
        if w > 1:
            d.line([(x - w + 1, y), (x + w - 1, y)], fill=fill)
    d.point((x, base_y - h + 1), fill=fill)


def feature_stone_crown(img, pal: Dict, mask=None) -> None:
    """BASALT: a jagged rock crown plastered onto the dome.

    This is a FOREGROUND feature, and it deliberately repaints the dome's own
    top row: that is the pixel that would otherwise draw a dark seam between
    the rock and the shell. The result is a band that is *attached* - the
    lesson from the first draft, where spikes painted behind the body read as
    floating gravel once the body's outline cut them off.
    """
    if mask is None:
        return
    tops: Dict[int, int] = {}
    for (x, y) in mask:
        if x not in tops or y < tops[x]:
            tops[x] = y

    face = (168, 164, 156, 255)
    rim = (22, 22, 26, 255)

    # Jagged heights: tall peaks, medium shoulders, a low lip elsewhere.
    heights: Dict[int, int] = {}
    for x in range(7, 26):
        if x not in tops:
            continue
        if 8 <= x <= 23:
            heights[x] = 1
        if x in (10, 11, 16, 21):
            heights[x] = 3
        elif x in (9, 12, 15, 17, 20, 22):
            heights[x] = 2

    for x, h in heights.items():
        for i in range(0, h + 1):              # 0 = break the dome's outline
            y = tops[x] - i
            if 0 <= y < FRAME:
                img.putpixel((x, y), face)
        cap = tops[x] - h - 1                  # dark cap on the peak
        if 0 <= cap < FRAME:
            img.putpixel((x, cap), rim)

    # Dark columns at the two ends so the band does not just stop in mid-air.
    for x in (min(heights), max(heights)):
        if x not in heights:
            continue
        for i in range(0, heights[x] + 1):
            y = tops[x] - i
            if 0 <= y < FRAME:
                img.putpixel((x, y), rim)


def feature_flame_crest(img, pal: Dict, mask=None) -> None:
    """EMBER: a flame licking off the top of the head."""
    y0 = top_of(img, int(CX))
    if y0 is None:
        return
    hot, warm, pale = (255, 150, 60, 255), (255, 208, 90, 255), (255, 246, 190, 255)
    cx = int(CX)
    # A 5-wide, 6-tall lick of flame, anchored on the crown.
    flame = [
        "..W..",
        ".WY..",
        ".YYY.",
        "YYYYY",
        ".YHY.",
        "..H..",
    ]
    palette = {"W": pale, "Y": warm, "H": hot}
    for row, line in enumerate(flame):
        for col, ch in enumerate(line):
            if ch == ".":
                continue
            x = cx - 2 + col
            y = y0 - len(flame) + row
            if 0 <= x < FRAME and 0 <= y < FRAME:
                img.putpixel((x, y), palette[ch])


def feature_hot_cracks(img, pal: Dict, mask=None) -> None:
    """EMBER / BASALT: glowing seams through the shell."""
    ember = (255, 176, 74, 255)
    for x, y in ((11, 24), (12, 24), (20, 24)):
        if 0 <= x < FRAME and 0 <= y < FRAME and img.getpixel((x, y))[3] > 0:
            img.putpixel((x, y), ember)


def feature_acid_splash(img, pal: Dict, mask=None) -> None:
    """ACID: a permanent sizzling splash at its feet.

    Painted on the GROUND line, not on the body, so it reads in every pose
    (the body lifts off the floor during hops, the splash stays down there).
    """
    ground = int(GROUND_Y - 0.5)
    for cx, half in ((7, 3), (25, 3), (16, 5)):
        for dx in range(-half, half + 1):
            x = cx + dx
            if not (0 <= x < FRAME):
                continue
            wet = pal["base"] if abs(dx) < half - 1 else pal["outline"]
            if abs(dx) == half:
                img.putpixel((x, ground), pal["outline"])
            else:
                img.putpixel((x, ground), wet)
            if abs(dx) < half - 1 and ground - 1 >= 0:
                img.putpixel((x, ground - 1), pal["light"])


# ---------------------------------------------------------------------------
# Render one pose of one variant
# ---------------------------------------------------------------------------
def render_pose(pose: Pose, variant: Variant) -> Image.Image:
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    mask = build_mask(pose)
    for feature in variant.back_features:
        feature(img, variant.pal, mask)
    paint_body(img, pose, mask, variant.pal)
    paint_face(img, pose, mask, variant.pal)
    for feature in variant.features:
        feature(img, variant.pal, mask)
    return img


def render_silhouette(pose: Pose, variant: Variant) -> Image.Image:
    """Pure white body, same pose, same silhouette features.

    This row IS the hit flash (frame + 12). Features keep their colours so
    spikes / a crown still read while the slime is flashing white.
    """
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    mask = build_mask(pose)
    for feature in variant.back_features:
        feature(img, variant.pal, mask)
    paint_body(img, pose, mask, variant.pal, solid=WHITE)
    for feature in variant.features:
        feature(img, variant.pal, mask)
    return img


# ---------------------------------------------------------------------------
# THE FAMILY - order = row pair on the sheet = `SlimeVariant` row index
# ---------------------------------------------------------------------------
VARIANTS: List[Variant] = [
    Variant("grass", "Grass Slime", GRASS, [], (108, 200, 100)),
    Variant("acid", "Acid Slime", ACID, [feature_acid_splash], (150, 92, 198)),
    Variant("ember", "Ember Slime", EMBER, [feature_flame_crest, feature_hot_cracks],
            (212, 96, 32)),
    Variant("basalt", "Basalt Slime", BASALT, [feature_stone_crown],
            (102, 102, 110)),
]

# Poses worth showing in the family contact sheet.
PREVIEW_POSES = ["idle_a", "blink", "crouch", "air_up", "land", "telegraph", "lunge", "hurt"]


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
    """One texture: every variant as an art row + a white flash row."""
    sheet = Image.new("RGBA", (FRAME * COLS, FRAME * 2 * len(VARIANTS)), (0, 0, 0, 0))
    for row, variant in enumerate(VARIANTS):
        for col, pose in enumerate(POSES):
            sheet.paste(render_pose(pose, variant), (col * FRAME, (row * 2) * FRAME))
            sheet.paste(render_silhouette(pose, variant),
                        (col * FRAME, (row * 2 + 1) * FRAME))
    return sheet


def _font(size: int):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:            # very old Pillow
        return ImageFont.load_default()


def build_pose_preview() -> Image.Image:
    """Contact sheet: the 12 poses of the grass slime + their flash rows."""
    zoom, pad, label_h = 8, 10, 16
    bg = (24, 30, 34, 255)
    cell_w, cell_h = FRAME * zoom + pad, FRAME * zoom + pad + label_h
    preview = Image.new("RGBA", (cell_w * 6 + pad, cell_h * 4 + pad * 2), bg)
    draw = ImageDraw.Draw(preview)

    cells: List[Tuple[Image.Image, str]] = []
    cells += [(render_pose(p, VARIANTS[0]), p.name) for p in POSES]
    cells += [(render_silhouette(p, VARIANTS[0]), "flash_" + p.name) for p in POSES]

    for i, (frame, name) in enumerate(cells):
        col, row = i % 6, i // 6
        x, y = pad + col * cell_w, pad + row * cell_h
        preview.alpha_composite(frame.resize((FRAME * zoom, FRAME * zoom), Image.NEAREST), (x, y))
        draw.text((x + 2, y + FRAME * zoom + 2), name, fill=(210, 235, 210, 255))
    return preview


def build_variants_preview() -> Image.Image:
    """Contact sheet: one row per variant across the key poses."""
    zoom, pad = 6, 12
    label_w = 190
    tile = FRAME * zoom
    row_h = tile + 18
    bg = (26, 30, 34, 255)
    cols = len(PREVIEW_POSES)
    width = label_w + cols * (tile + pad) + pad
    height = pad * 2 + len(VARIANTS) * (row_h + pad) + 30
    img = Image.new("RGBA", (width, height), bg)
    draw = ImageDraw.Draw(img)
    title_font, label_font, small_font = _font(18), _font(16), _font(13)

    draw.text((pad, 10), "SLIME FAMILY", font=title_font, fill=(235, 245, 235, 255))
    draw.text((pad + 150, 14),
              "same 12-pose rig - palette + one silhouette feature per variant",
              font=small_font, fill=(145, 170, 150, 255))

    for row, variant in enumerate(VARIANTS):
        y = pad + 28 + row * (row_h + pad)
        goo = "#%02X%02X%02X" % variant.goo
        draw.text((pad, y + 8), variant.name, font=label_font, fill=(225, 240, 225, 255))
        draw.text((pad, y + 30), "row %d  |  goo %s" % (row, goo),
                  font=small_font, fill=(140, 200, 145, 255))

        for col, pose_name in enumerate(PREVIEW_POSES):
            pose = next(p for p in POSES if p.name == pose_name)
            x = label_w + col * (tile + pad)
            draw.line([(x - 4, y + tile - 3), (x + tile + 4, y + tile - 3)],
                      fill=(58, 68, 60, 255))
            frame = render_pose(pose, variant).resize((tile, tile), Image.NEAREST)
            img.alpha_composite(frame, (x, y))

            if row == len(VARIANTS) - 1:
                draw.text((x + 2, y + tile + 2), pose_name, font=small_font,
                          fill=(150, 170, 160, 255))
    return img


def main() -> None:
    sheet = build_sheet()
    sheet.save("assets/textures/slime.png")
    make_puddle().save("assets/textures/slime_goo_puddle.png")
    make_shadow().save("assets/textures/slime_shadow.png")

    import os
    os.makedirs("docs/images", exist_ok=True)
    build_pose_preview().save("docs/images/slime_preview.png")
    build_variants_preview().save("docs/images/slime_variants_preview.png")

    print("wrote assets/textures/slime.png", sheet.size)
    print("wrote assets/textures/slime_goo_puddle.png", (32, 10))
    print("wrote assets/textures/slime_shadow.png", (32, 10))
    print("wrote docs/images/slime_preview.png")
    print("wrote docs/images/slime_variants_preview.png")
    print("")
    print("frame index = variant_row * %d + (flash ? %d : 0) + pose" %
          (VARIANT_FRAMES, ROW_FRAMES))
    for row, variant in enumerate(VARIANTS):
        print("  row %d = %-13s (poses %d-%d, flash %d-%d)" %
              (row, variant.key, row * VARIANT_FRAMES, row * VARIANT_FRAMES + ROW_FRAMES - 1,
               row * VARIANT_FRAMES + ROW_FRAMES, row * VARIANT_FRAMES + VARIANT_FRAMES - 1))


if __name__ == "__main__":
    main()
