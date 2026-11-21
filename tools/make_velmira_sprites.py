#!/usr/bin/env python
"""Generate Velmira's 6-frame hero sheet (player_shabnam.png).

THIRD design - drawn from the player's reference sheet (dark crimson gothic
vampire: huge black-purple hair with a rose, pointed ears, red eyes, high
collar, black dress with a belt, thigh-high boots with crimson bands).

WHY A GENERATOR (project rule: the .py is the source of truth, never the PNG)
  * Six frames that must not drift apart (idle / step A / step B / cast A /
    cast B / idle blink) come from one body function, so a change to her hair
    or her hem moves in all six at once.
  * Rows are BUILT from absolute-coordinate spans, not typed as strings of
    dots: nothing can be off by a pixel, and check_widths() still guards the
    result.

        python tools/make_velmira_sprites.py

    Writes:
        assets/textures/player_shabnam.png   192 x 32 (6 frames of 32x32)
        docs/images/velmira_preview.png      review sheet

SHEET LAYOUT  (matches scenes/player/Shabnam.tscn - do not reorder!)
    frame 0 : idle
    frame 1 : walk A
    frame 2 : walk B
    frame 3 : attack A  (wind-up)
    frame 4 : attack B  (the blood splash)
    frame 5 : idle blink

WHAT THE REFERENCE SAYS (in priority order, and where each one lives)
  1. a HUGE hair mass, with a crimson rose on her left temple
        -> the crown block + two 4 px falls from the temples to the ankles
  2. a small pale face with big red eyes, a pointed ear on each side
        -> 7 px face inside a 15 px head, ears drawn over the hair
  3. a high crimson collar and a cape with a dark lining
        -> crimson wings at the shoulders, cape panels down the sides
  4. a black dress, silver belt buckle, red gem at the throat
        -> the torso block, with the gem 1 px below the collar
  5. bare thighs over thigh-high boots with a red cross
        -> 1 row of skin between the skirt and the boots
  6. blood magic only when she is casting
        -> a bead in her cupped hands (frame 3), a droplet fan (frame 4)

THE HOUSE RULE STILL APPLIES: a hard near-black outline on every silhouette
edge, flat 2-tone shading, no gradients, boots on row 29 like every hero.
"""

from typing import Dict, Tuple

from PIL import Image, ImageDraw, ImageFont

FRAME = 32
FRAMES = 6

# ---------------------------------------------------------------------------
# Palette - sampled from the reference, values lifted a touch so she does not
# sink into the dark arena floor (the reference is nearly black on black).
# ---------------------------------------------------------------------------
PAL = {
    "outline": (12, 8, 18, 255),
    # hair: black-purple, three tones, the highlight is what reads at 2x
    "hair": (52, 38, 66, 255),
    "hair_hi": (88, 68, 110, 255),
    "hair_lo": (30, 22, 42, 255),
    # skin: the reference's pale pink, warm shadow
    "skin": (238, 204, 212, 255),
    "skin_hi": (250, 232, 238, 255),
    "skin_lo": (202, 148, 168, 255),
    "blush": (222, 128, 152, 255),
    # eyes
    "sclera": (250, 238, 244, 255),
    "iris": (176, 26, 58, 255),
    "iris_hi": (240, 96, 120, 255),
    "lash": (22, 12, 26, 255),
    "lip": (108, 16, 42, 255),
    # clothes
    "dress": (34, 26, 44, 255),
    "dress_hi": (56, 44, 70, 255),
    "cape": (108, 16, 42, 255),
    "cape_hi": (146, 30, 60, 255),
    "cape_lo": (66, 8, 26, 255),
    "rose": (126, 20, 48, 255),
    "rose_hi": (168, 40, 72, 255),
    "rose_lo": (72, 10, 28, 255),
    "boot": (26, 20, 36, 255),
    "boot_hi": (48, 40, 62, 255),
    "silver": (150, 140, 164, 255),
    # fx
    "blood": (168, 16, 44, 255),
    "blood_hi": (230, 70, 96, 255),
    "white": (255, 255, 255, 255),
}

SYMBOLS: Dict[str, Tuple[int, int, int, int]] = {
    ".": None,
    "#": PAL["outline"],
    "h": PAL["hair"],
    "H": PAL["hair_hi"],
    "j": PAL["hair_lo"],
    "s": PAL["skin"],
    "S": PAL["skin_hi"],
    "u": PAL["skin_lo"],
    "b": PAL["blush"],
    "W": PAL["sclera"],
    "e": PAL["iris"],
    "E": PAL["iris_hi"],
    "L": PAL["lash"],
    "l": PAL["lip"],
    "c": PAL["dress"],
    "C": PAL["dress_hi"],
    "k": PAL["cape"],
    "K": PAL["cape_hi"],
    "m": PAL["cape_lo"],
    "r": PAL["rose"],
    "R": PAL["rose_hi"],
    "q": PAL["rose_lo"],
    "o": PAL["boot"],
    "O": PAL["boot_hi"],
    "v": PAL["silver"],
    "x": PAL["blood"],
    "X": PAL["blood_hi"],
    "w": PAL["white"],
}

# ---------------------------------------------------------------------------
# THE VERTICAL BUDGET (32 px, soles on row 29 like every other hero)
#   y 2..13   head: hair crown, 7 px face, ears
#   y 14..24  neck, collar, cape, dress, belt, skirt, bare thigh
#   y 25..29  thigh-high boots
# The hair falls run from y5 to y27 on both sides.
# ---------------------------------------------------------------------------
CX = 16
HEAD_X, HEAD_W = 9, 15
HEAD_Y = 2
TORSO_X, TORSO_W = 8, 17
TORSO_Y = 14
LEGS_X, LEGS_W = 8, 17
LEGS_Y = 25
HAIR_TOP = 5
HAIR_BOTTOM = 27


# ---------------------------------------------------------------------------
# Row builders - place art by ABSOLUTE x, so no row is ever counted by hand
# ---------------------------------------------------------------------------
def _row(origin: int, width: int, *spans) -> str:
    row = ["."] * width
    for x, art in spans:
        start = x - origin
        if start < 0 or start + len(art) > width:
            raise SystemExit("span out of block: x=%d art=%r" % (x, art))
        for i, ch in enumerate(art):
            row[start + i] = ch
    return "".join(row)


def h(*spans) -> str:
    """One head row (the block spans x9..23)."""
    return _row(HEAD_X, HEAD_W, *spans)


def b(*spans) -> str:
    """One torso row (the block spans x8..24)."""
    return _row(TORSO_X, TORSO_W, *spans)


def l(*spans) -> str:
    """One leg row (the block spans x8..24)."""
    return _row(LEGS_X, LEGS_W, *spans)


# ---------------------------------------------------------------------------
# Head: 15 wide, 12 rows (y2..13). Face 7 px at x13..19, ears at x11 / x21.
# ---------------------------------------------------------------------------
HEAD = [
    h((13, "#hhhhhhh#")),                            # crown
    h((11, "#hhhhhhhhhhh#")),
    h((9, "#hhhhhhhhhhhhh#")),                       # widest point of the mass
    h((9, "hhhhhhhhhhhhhhh")),                       # falls start here: no side outline
    h((9, "hhhjjjjjjjjjhhh")),                       # fringe over the brow
    h((9, "hhhh"), (13, "sssssss"), (20, "hhhh")),   # forehead
    h((9, "hh"), (11, "u"), (12, "h"), (13, "sLLsLLs"), (20, "h"), (21, "u"), (22, "hh")),
    h((9, "hh"), (11, "u"), (12, "h"), (13, "seesees"), (20, "h"), (21, "u"), (22, "hh")),
    h((9, "hhhh"), (13, "seesees"), (20, "hhhh")),   # crimson eyes, heavy lash above
    h((9, "hhhh"), (13, "sbsssbs"), (20, "hhhh")),   # blush
    h((9, "hhhh"), (13, "ssWlWss"), (20, "hhhh")),   # fanged smirk
    h((9, "hhhhh"), (14, "usssu"), (19, "hhhhh")),   # tapered jaw
]

# Idle blink: the lids close for one beat of the idle loop.
HEAD_BLINK = [
    h((13, "#hhhhhhh#")),
    h((11, "#hhhhhhhhhhh#")),
    h((9, "#hhhhhhhhhhhhh#")),
    h((9, "hhhhhhhhhhhhhhh")),
    h((9, "hhhjjjjjjjjjhhh")),
    h((9, "hhhh"), (13, "sssssss"), (20, "hhhh")),
    h((9, "hh"), (11, "u"), (12, "h"), (13, "sLLsLLs"), (20, "h"), (21, "u"), (22, "hh")),
    h((9, "hh"), (11, "u"), (12, "h"), (13, "sLLsLLs"), (20, "h"), (21, "u"), (22, "hh")),
    h((9, "hhhh"), (13, "sssssss"), (20, "hhhh")),
    h((9, "hhhh"), (13, "sbsssbs"), (20, "hhhh")),
    h((9, "hhhh"), (13, "ssWlWss"), (20, "hhhh")),
    h((9, "hhhhh"), (14, "usssu"), (19, "hhhhh")),
]

# Cast pose: fangs bared, eyes blazing.
HEAD_OPEN = [
    h((13, "#hhhhhhh#")),
    h((11, "#hhhhhhhhhhh#")),
    h((9, "#hhhhhhhhhhhhh#")),
    h((9, "hhhhhhhhhhhhhhh")),
    h((9, "hhhjjjjjjjjjhhh")),
    h((9, "hhhh"), (13, "sssssss"), (20, "hhhh")),
    h((9, "hh"), (11, "u"), (12, "h"), (13, "sLLsLLs"), (20, "h"), (21, "u"), (22, "hh")),
    h((9, "hh"), (11, "u"), (12, "h"), (13, "sEesEes"), (20, "h"), (21, "u"), (22, "hh")),
    h((9, "hhhh"), (13, "sEesEes"), (20, "hhhh")),
    h((9, "hhhh"), (13, "sbsssbs"), (20, "hhhh")),
    h((9, "hhhh"), (13, "sWlllWs"), (20, "hhhh")),
    h((9, "hhhh"), (13, "sxsssxs"), (20, "hhhh")),
]

# ---------------------------------------------------------------------------
# Torso: 15 wide (x9..23), 11 rows (y14..24). High crimson collar, cape panels
# falling behind the shoulders, black bodice with crimson brooch and silver
# belt, flared skirt, one row of bare thigh above the boots.
# ---------------------------------------------------------------------------
TORSO = [
    b((12, "#kk"), (15, "sss"), (18, "kk#")),            # collar tips + neck
    b((10, "#kkkk"), (15, "sss"), (18, "kkkk#")),        # collar opens
    b((9, "#kk"), (12, "ccccxcccc"), (21, "kk#")),       # shoulders + brooch
    b((9, "#kk"), (12, "Ccccccccc"), (21, "kk#")),       # lit edge of the bodice
    b((9, "#kk"), (12, "ccccccccc"), (21, "kk#")),
    b((9, "#kk"), (12, "ccccccccc"), (21, "kk#")),
    b((9, "#kk"), (12, "cccvvvccc"), (21, "kk#")),       # belt + silver buckle
    b((9, "#"), (10, "ccccccccccccc"), (23, "#")),       # skirt flares
    b((9, "#"), (10, "Ccccccccccccm"), (23, "#")),
    b((9, "#"), (10, "ccccccccccccm"), (23, "#")),       # hem
    b((9, "#"), (10, "cc"), (12, "sss"), (18, "sss"), (21, "cc"), (23, "#")),
]

# Legs: 15 wide (x9..23), 5 rows (y25..29). Thigh-high boots, crimson cross-band.
LEGS_STAND = [
    l((11, "#ooo#"), (17, "#ooo#")),   # cuff
    l((12, "#oo#"), (18, "#oo#")),     # shaft
    l((12, "#xx#"), (18, "#xx#")),     # crimson cross-band
    l((11, "#ooo#"), (17, "#ooo#")),   # foot
    l((11, "#####"), (17, "#####")),   # sole
]

LEGS_STEP_A = [
    l((10, "#ooo#"), (18, "#ooo#")),
    l((11, "#oo#"), (18, "#oo#")),
    l((11, "#xx#"), (18, "#xx#")),
    l((10, "#ooo#"), (17, "#ooo#")),
    l((10, "#####"), (17, "#####")),
]

LEGS_STEP_B = [
    l((12, "#ooo#"), (17, "#ooo#")),
    l((13, "#oo#"), (18, "#oo#")),
    l((13, "#xx#"), (18, "#xx#")),
    l((12, "#ooo#"), (18, "#ooo#")),
    l((12, "#####"), (18, "#####")),
]

# ---------------------------------------------------------------------------
# Decor: rose in her hair
# ---------------------------------------------------------------------------
ROSE = [
    ".rR.",
    "rRrr",
    "rrqr",
    ".rr.",
]

# Cast A: both hands cupped under the blood bead, sleeves rising to the elbow.
ARM_CUP = [
    "..##..",
    ".#kk#.",
    "#kkkk#",
    "#s##s#",
]

# Cast B: the arm punches forward, hand at the end, blood leaving it.
ARM_OUT = [
    "#kkkk#",
    "#kkss#",
    "######",
]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def new_frame() -> Image.Image:
    return Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))


def px(img: Image.Image, x: int, y: int, colour) -> None:
    """Bounds-checked putpixel: parts are pasted right up to the frame edge."""
    if 0 <= x < FRAME and 0 <= y < FRAME:
        img.putpixel((x, y), colour)


def paste(img: Image.Image, art, ox: int, oy: int) -> None:
    for y, row in enumerate(art):
        for x, ch in enumerate(row):
            colour = SYMBOLS.get(ch)
            if colour is None:
                continue
            px(img, ox + x, oy + y, colour)


# Outer edge of each fall per row (index = y - HAIR_TOP). A 2 px staircase over
# four-row steps reads as a wave of hair; a 1 px alternation reads as a dotted
# line, which is why this table moves in blocks. Inner edges sit at x8 / x24 so
# the mass always joins the head and never floats beside her.
FALL_EDGE_L = [6, 6, 4, 4, 4, 5, 5, 5, 6, 6, 4, 4, 4, 5, 5, 5, 6, 6, 5, 4, 4, 4, 5]
FALL_EDGE_R = [32 - e for e in FALL_EDGE_L]


def _fall_span(y: int, side: int, sway: int) -> tuple[int, int]:
    """(outer, inner) inclusive hair columns of the fall on row y."""
    i = y - HAIR_TOP
    outer = FALL_EDGE_L[i] if side < 0 else FALL_EDGE_R[i]
    if sway and 11 <= y <= 25:
        outer -= side * sway          # the mass swings with the walk
    if y >= HAIR_BOTTOM - 2:          # tapered tip
        outer += 1 if side < 0 else -1
    inner = 8 if side < 0 else 24
    return outer, inner


def hair_fall(img: Image.Image, side: int, sway: int = 0) -> None:
    """One long fall of hair: highlight on the outer edge, shadow inside."""
    for y in range(HAIR_TOP, HAIR_BOTTOM + 1):
        outer, inner = _fall_span(y, side, sway)
        lo, hi = (outer, inner) if side < 0 else (inner, outer)
        for col in range(lo, hi + 1):
            d = (col - lo) if side < 0 else (hi - col)      # 0 = outer edge
            sym = "H" if d == 0 else ("h" if d <= 2 else "j")
            img.putpixel((col, y), SYMBOLS[sym])
        edge_out = outer - 1 if side < 0 else outer + 1
        if 0 <= edge_out < 32:
            img.putpixel((edge_out, y), SYMBOLS["#"])


def blood_orb(img: Image.Image, at, radius: int = 3) -> None:
    """A bead of blood magic (cast A)."""
    x, y = at
    d = ImageDraw.Draw(img)
    d.ellipse([x - radius - 1, y - radius - 1, x + radius + 1, y + radius + 1],
              fill=PAL["outline"])
    d.ellipse([x - radius, y - radius, x + radius, y + radius],
              fill=PAL["blood"])
    d.ellipse([x - radius + 1, y - radius + 1, x, y - 1], fill=PAL["blood_hi"])
    px(img, x - 1, y - 2, PAL["white"])


def blood_spray(img: Image.Image, origin) -> None:
    """A fan of droplets in front of the thrust hand (cast B).

    A READ, not the hitbox: the real 92 px damage cone is drawn by the FX node,
    this only has to say "blood, that way".
    """
    x, y = origin
    for dx, dy, colour in ((0, 0, PAL["blood"]), (1, 0, PAL["blood"]),
                           (0, 1, PAL["blood_hi"]),
                           (2, -3, PAL["blood"]), (3, 1, PAL["blood"]),
                           (2, 3, PAL["blood_hi"]), (4, -1, PAL["blood"]),
                           (4, 2, PAL["blood_hi"])):
        px(img, x + dx, y + dy, colour)


# ---------------------------------------------------------------------------
# Body
# ---------------------------------------------------------------------------
def draw_head(img: Image.Image, head) -> None:
    paste(img, head, HEAD_X, HEAD_Y)


def draw_body(img: Image.Image, legs) -> None:
    paste(img, TORSO, TORSO_X, TORSO_Y)
    paste(img, legs, LEGS_X, LEGS_Y)


def draw_hair(img: Image.Image, sway: int = 0) -> None:
    hair_fall(img, -1, sway)
    hair_fall(img, +1, sway)


def draw_rose(img: Image.Image) -> None:
    """The crimson rose sits ON the hair, at her left temple."""
    paste(img, ROSE, 8, 5)


# ---------------------------------------------------------------------------
# Frames
# ---------------------------------------------------------------------------
def frame_idle(blink: bool = False) -> Image.Image:
    img = new_frame()
    draw_body(img, LEGS_STAND)
    draw_head(img, HEAD_BLINK if blink else HEAD)
    draw_hair(img)
    draw_rose(img)
    return img


def frame_walk(step: int) -> Image.Image:
    img = new_frame()
    draw_body(img, LEGS_STEP_A if step == 1 else LEGS_STEP_B)
    draw_head(img, HEAD)
    draw_hair(img, sway=1 if step == 1 else -1)
    draw_rose(img)
    return img


def frame_cast(kind: int) -> Image.Image:
    img = new_frame()
    draw_hair(img, sway=1 if kind == 0 else -1)
    draw_body(img, LEGS_STAND)
    if kind == 0:
        paste(img, ARM_CUP, 13, 20)
        blood_orb(img, (16, 19), 2)
    else:
        paste(img, ARM_OUT, 20, 16)
        blood_spray(img, (26, 17))
    draw_head(img, HEAD_OPEN)
    draw_rose(img)
    return img


def build_sheet() -> Image.Image:
    frames = [
        frame_idle(False),
        frame_walk(1),
        frame_walk(2),
        frame_cast(0),
        frame_cast(1),
        frame_idle(True),
    ]
    sheet = Image.new("RGBA", (FRAME * FRAMES, FRAME), (0, 0, 0, 0))
    for index, art in enumerate(frames):
        sheet.alpha_composite(art, (index * FRAME, 0))
    return sheet


def build_preview(sheet: Image.Image) -> Image.Image:
    zoom = 6
    pad = 16
    labels = ["idle", "walk A", "walk B", "cast A", "cast B", "idle blink"]
    width = pad + FRAMES * (FRAME * zoom + pad)
    height = 34 + FRAME * zoom + pad + 18
    img = Image.new("RGBA", (width, height), (22, 18, 26, 255))
    draw = ImageDraw.Draw(img)
    font = ImageFont.load_default()
    draw.text((pad, 10), "VELMIRA - 6 frames, 32x32 (gothic vampire, from the "
              "reference sheet)", font=font, fill=(238, 216, 226, 255))
    for index in range(FRAMES):
        x = pad + index * (FRAME * zoom + pad)
        frame = sheet.crop((index * FRAME, 0, (index + 1) * FRAME, FRAME))
        img.alpha_composite(frame.resize((FRAME * zoom, FRAME * zoom),
                                         Image.NEAREST), (x, 34))
        draw.text((x, height - 14), labels[index], font=font,
                  fill=(200, 168, 186, 255))
    return img


def check_widths() -> None:
    """Every ASCII part must be a rectangle, or the paste silently shifts."""
    for name, value in list(globals().items()):
        if isinstance(value, list) and value and isinstance(value[0], str):
            widths = {len(row) for row in value}
            if len(widths) != 1:
                raise SystemExit("part %s has ragged rows: %s" % (name, widths))


def main() -> None:
    check_widths()
    sheet = build_sheet()
    sheet.save("assets/textures/player_shabnam.png")
    print("wrote assets/textures/player_shabnam.png", sheet.size,
          "-> %d frames of %d" % (FRAMES, FRAME))
    build_preview(sheet).save("docs/images/velmira_preview.png")
    print("wrote docs/images/velmira_preview.png")


if __name__ == "__main__":
    main()
