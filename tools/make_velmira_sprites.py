#!/usr/bin/env python
"""Generate Velmira's 6-frame hero sheet (player_shabnam.png) - SECOND redesign.

WHY A GENERATOR (project rule: the .py is the source of truth, never the PNG)
  * Six frames that must not drift apart (idle / step A / step B / cast A /
    cast B / idle blink) are built from one body function, so a change to her
    waist or her hem moves in all six at once.
  * Every part is an ASCII block of a fixed width, so a paste can never shift
    by a pixel. check_widths() fails the build on a ragged row.

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

THE HOUSE STYLE (read player_pari / player_borzo / player_bahman first!)
  * Flat 2-tone materials, one hard outline (18,16,24) on every silhouette
    edge, bright saturated cloth - no near-black garments, no gradients.
  * Chibi proportion: head about as wide as the shoulders, ~27-29 px tall
    (y2..y29 here), boots landing on row 29 like every other hero.
  * Eyes are ONE row: a white sclera pixel next to a coloured iris pixel.
    A 2-row eye reads as a visor at this size (learned the hard way).
  * Face is 7 of the head's 13 px, with a blush row and a 1 px mouth.

WHY SHE LOOKS LIKE THIS  (docs/VELMIRA_REDESIGN.md)
  * The first redesign was all dark: navy hair, navy coat, a cool grey face.
    At 2x zoom she was a dark blob with a pale mask.
  * This one is built the other way round - the HAIR is the lightest, biggest
    thing on the sprite (long lilac, past the waist) and the dress is the dark
    thing. Value contrast does the read; detail only decorates it.
      1. LONG hair: two 2 px strands from the temples to the hem, plus the
         mass that frames the face;
      2. a warm pale face: white sclera + crimson iris, blush, 1 px mouth;
      3. a fitted violet gown: 13 px shoulders -> 9 px waist -> 13 px hem,
         crimson corset panel, gold belt;
      4. crimson opera gloves as the accent at her hands;
      5. fangs and blood only in the cast pose.
"""

from typing import Dict, Tuple

from PIL import Image, ImageDraw, ImageFont

FRAME = 32
FRAMES = 6

# ---------------------------------------------------------------------------
# Palette - bright lilac, warm skin, violet + crimson. Values are pulled
# together with the other heroes: same outline, same kind of flat shading.
# ---------------------------------------------------------------------------
PAL = {
    "outline": (18, 16, 24, 255),        # the house outline
    # hair: LILAC, three tones, light on top
    "hair_hi": (226, 196, 248, 255),
    "hair": (176, 128, 222, 255),
    "hair_lo": (126, 80, 168, 255),
    # skin: pale but WARM (a cool grey face was the last version's mistake)
    "skin": (242, 202, 186, 255),
    "skin_hi": (253, 232, 224, 255),
    "skin_lo": (208, 160, 158, 255),
    "blush": (238, 130, 148, 255),
    # face details
    "sclera": (250, 250, 255, 255),
    "iris": (214, 32, 62, 255),
    "lash": (46, 22, 52, 255),
    "lip": (178, 38, 70, 255),
    # cloth
    "dress": (84, 46, 120, 255),
    "dress_hi": (110, 64, 152, 255),
    "dress_lo": (60, 32, 88, 255),
    "crimson": (168, 28, 56, 255),
    "crimson_hi": (206, 52, 80, 255),
    "gold": (240, 198, 96, 255),
    "gold_lo": (186, 146, 58, 255),
    "glove": (58, 32, 72, 255),
    "boot": (64, 38, 80, 255),
    "tights": (88, 58, 108, 255),
    # blood
    "blood": (204, 26, 52, 255),
    "blood_hi": (255, 104, 118, 255),
    "white": (255, 255, 255, 255),
}

SYMBOLS: Dict[str, Tuple[int, int, int, int]] = {
    ".": None,
    "#": PAL["outline"],
    "H": PAL["hair_hi"],
    "h": PAL["hair"],
    "j": PAL["hair_lo"],
    "s": PAL["skin"],
    "S": PAL["skin_hi"],
    "u": PAL["skin_lo"],
    "b": PAL["blush"],
    "W": PAL["sclera"],
    "e": PAL["iris"],
    "L": PAL["lash"],
    "l": PAL["lip"],
    "c": PAL["dress"],
    "C": PAL["dress_hi"],
    "d": PAL["dress_lo"],
    "r": PAL["crimson"],
    "R": PAL["crimson_hi"],
    "g": PAL["gold"],
    "G": PAL["gold_lo"],
    "v": PAL["glove"],
    "o": PAL["boot"],
    "t": PAL["tights"],
    "x": PAL["blood"],
    "X": PAL["blood_hi"],
    "w": PAL["white"],
}

# ---------------------------------------------------------------------------
# THE VERTICAL BUDGET (32 px, boots on the bottom row - same as the others)
#   y 2..12   head: hair mass + a 9 px face
#   y 13..24  neck, choker, bodice, sash, skirt, hem
#   y 25..29  tights and boots (soles on row 29)
# ---------------------------------------------------------------------------
CX = 16
HEAD_X = 9            # head block is 15 px wide (hair counts)
HEAD_Y = 2
TORSO_X = 8
TORSO_Y = 13
LEGS_X = 10
LEGS_Y = 25
HAIR_L = (11, 10)     # left fall: inner column, outer column
HAIR_R = (21, 22)     # right fall, mirrored
HAIR_Y = 14           # the falls start under the chin...
HAIR_END = 19         # ...and tuck in at the waist


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


def hair_falls(img: Image.Image, sway: int = 0) -> None:
    """Two long lilac falls, hanging from the head's hair to the hips.

    They are drawn AFTER the dress, so they read as hair in front of the
    shoulders - the whole point of long hair. `sway` drifts the tips by a
    pixel between frames; still frames read, motion sells.
    """
    for y in range(HAIR_Y, HAIR_END + 1):
        tip = y == HAIR_END
        ox = sway if tip else 0
        # left fall: light on the outside (x10), shadow against the dress
        px(img, HAIR_L[1] + ox, y, PAL["hair"])
        if not tip:
            px(img, HAIR_L[0], y, PAL["hair_lo"])
        # right fall, mirrored
        px(img, HAIR_R[1] + ox, y, PAL["hair"])
        if not tip:
            px(img, HAIR_R[0], y, PAL["hair_lo"])


def blood_orb(img: Image.Image, at, radius: int = 3) -> None:
    """A floating bead of blood magic (cast A)."""
    x, y = at
    d = ImageDraw.Draw(img)
    d.ellipse([x - radius - 1, y - radius - 1, x + radius + 1, y + radius + 1],
              fill=PAL["outline"])
    d.ellipse([x - radius, y - radius, x + radius, y + radius],
              fill=PAL["blood"])
    d.ellipse([x - radius + 1, y - radius + 1, x, y - 1], fill=PAL["blood_hi"])
    px(img, x - 1, y - 2, PAL["white"])


def blood_spray(img: Image.Image, origin) -> None:
    """A fan of droplets in front of the thrust glove (cast B).

    A READ, not the hitbox: the real 92 px damage cone is drawn by the FX
    node, never by this sprite - it only has to say "blood, that way".
    """
    x, y = origin
    for dx, dy, colour in ((0, 0, PAL["blood"]), (1, 0, PAL["blood"]),
                           (0, 1, PAL["blood_hi"]),
                           (2, -3, PAL["blood"]), (3, 1, PAL["blood"]),
                           (2, 3, PAL["blood_hi"]), (4, -1, PAL["blood"]),
                           (4, 2, PAL["blood_hi"])):
        px(img, x + dx, y + dy, colour)


# ---------------------------------------------------------------------------
# The head: 13 px wide, 12 rows, a 7 px face inside it
# ---------------------------------------------------------------------------
def _face(middle: str) -> str:
    """One head row: 2 px of hair, the 9 px face, 2 px of hair.

    Writing the rows as (hair + face + hair) keeps them a rectangle without
    counting characters in the editor - check_widths() still guards it.
    """
    return "#hj" + middle + "jh#"


HEAD = [
    ".....#####.....",
    "...#hhhhhhh#...",
    "..#hhhhhhhh#...",
    ".#hhhhhhhhhhh#.",
    "#hhhhhhhhhhhhh#",
    _face("jjjjjjjjj"),      # bangs: dark lilac across the brow
    _face("sssssssss"),      # forehead
    _face("sWeessWes"),      # eyes: white sclera outside, crimson iris in
    _face("ssbsssbss"),      # blush
    _face("sssllssss"),      # mouth
    ".#hj#usssu#jh#.",       # chin
]

# Idle blink (the 2.2 s beat of the idle animation): lids shut, no sclera.
HEAD_BLINK = [
    ".....#####.....",
    "...#hhhhhhh#...",
    "..#hhhhhhhh#...",
    ".#hhhhhhhhhhh#.",
    "#hhhhhhhhhhhhh#",
    _face("jjjjjjjjj"),
    _face("sssssssss"),
    _face("sLLsssLLs"),
    _face("ssbsssbss"),
    _face("sssllssss"),
    ".#hj#usssu#jh#.",
]

# Cast pose: mouth open, both fangs out.
HEAD_OPEN = [
    ".....#####.....",
    "...#hhhhhhh#...",
    "..#hhhhhhhh#...",
    ".#hhhhhhhhhhh#.",
    "#hhhhhhhhhhhhh#",
    _face("jjjjjjjjj"),
    _face("sssssssss"),
    _face("sWeessWes"),
    _face("ssbsssbss"),
    _face("sssWxlWss"),
    ".#hj#usssu#jh#.",
]

# ---------------------------------------------------------------------------
# Torso: 13 px wide, 10 rows. 13 shoulders -> 9 waist -> 13 hem, crimson
# corset panel, gold belt, crimson hem lining. Symbols: c dress, r crimson.
# ---------------------------------------------------------------------------
def _seg(segment: str) -> str:
    """Centre a torso segment - outline included - in the 17 px body block.

    Writing the gown as centred segments means the waist and the hem can move
    without anyone recounting characters; only odd widths are allowed, so the
    segment always lands on the CX = 16 column.
    """
    pad = (17 - len(segment)) // 2
    if 17 - len(segment) != 2 * pad:
        raise SystemExit("torso segment is not centred: %r" % segment)
    return "." * pad + segment + "." * pad


TORSO = [
    _seg("#sss#"),              # neck
    _seg("##LLgLL##"),          # choker + gold gem
    _seg("#cccsssssccc#"),      # shoulders, sweetheart neckline
    _seg("#cccsssccc#"),        # ...narrowing to a point
    _seg("#ccccccccc#"),        # bodice
    _seg("#ccccccccc#"),
    _seg("#crrrrrc#"),          # crimson underbust band
    _seg("#crrrrrc#"),
    _seg("#Ccccccccc#"),        # skirt...
    _seg("#Ccccccccccc#"),
    _seg("#Ccccccccccccc#"),    # ...flaring
    _seg("#ddGGGGGGGGGGGdd#"),  # gold hem trim
]

# Legs: 13 px wide, 5 rows, soles on the last one (row 29, like every hero).
LEGS_STAND = [
    "..#t#...#t#..",
    "..#t#...#t#..",
    "..#o#...#o#..",
    ".#ooo#.#ooo#.",
    ".#####.#####.",
]

LEGS_STEP_A = [
    "..#t#...#t#..",
    "..#t#..#t#...",
    "..#o#..#o#...",
    "#ooo#.#ooo#..",
    "#####.######.",
]

LEGS_STEP_B = [
    "..#t#...#t#..",
    "...#t#..#t#..",
    "...#o#..#o#..",
    ".#ooo#.#ooo#.",
    "######.#####.",
]

# Casting arm: elbow out, glove up beside the head (5 px wide, 8 rows).
ARM_UP = [
    "..###",
    "..#r#",
    "..#r#",
    ".#C#.",
    ".#C#.",
    "#C#..",
    "#C#..",
    "##...",
]

# Thrust: the arm punches forward, glove at the end (7 px wide, 4 rows).
ARM_OUT = [
    "#ccc###",
    "#cccrr#",
    "#cccrr#",
    "#######",
]


# Casting arm: elbow out, glove up beside the head.
ARM_UP = [
    "#r##",
    "#rc#",
    ".#c#",
    ".#c#",
    ".#c#",
    "##c#",
    "#c##",
    "###.",
]

# Thrust: the arm punches forward, glove at the end.
ARM_OUT = [
    "#cc#####",
    "#ccccrr#",
    "#ccccrr#",
    "########",
]


# ---------------------------------------------------------------------------
# Body - one function, six sets of limbs
# ---------------------------------------------------------------------------
def draw_head(img: Image.Image, head) -> None:
    paste(img, head, HEAD_X, HEAD_Y)


def draw_body(img: Image.Image, legs) -> None:
    paste(img, TORSO, TORSO_X, TORSO_Y)
    paste(img, legs, LEGS_X, LEGS_Y)


# ---------------------------------------------------------------------------
# Frames
# ---------------------------------------------------------------------------
def frame_idle(blink: bool = False) -> Image.Image:
    img = new_frame()
    draw_body(img, LEGS_STAND)
    hair_falls(img)
    draw_head(img, HEAD_BLINK if blink else HEAD)
    return img


def frame_walk(step: int) -> Image.Image:
    img = new_frame()
    draw_body(img, LEGS_STEP_A if step == 1 else LEGS_STEP_B)
    hair_falls(img, sway=1 if step == 1 else -1)
    draw_head(img, HEAD)
    return img


def frame_cast(kind: int) -> Image.Image:
    img = new_frame()
    draw_body(img, LEGS_STAND)
    hair_falls(img, sway=1)
    if kind == 0:
        paste(img, ARM_UP, TORSO_X + 13, TORSO_Y - 5)
        blood_orb(img, (TORSO_X + 18, TORSO_Y - 7), 3)
    else:
        paste(img, ARM_OUT, TORSO_X + 11, TORSO_Y + 2)
        blood_spray(img, (TORSO_X + 18, TORSO_Y + 3))
    draw_head(img, HEAD_OPEN)
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
    img = Image.new("RGBA", (width, height), (30, 26, 40, 255))
    draw = ImageDraw.Draw(img)
    font = ImageFont.load_default()
    draw.text((pad, 10), "VELMIRA - 6 frames, 32x32 (lilac-haired redesign)",
              font=font, fill=(240, 226, 236, 255))
    for index in range(FRAMES):
        x = pad + index * (FRAME * zoom + pad)
        frame = sheet.crop((index * FRAME, 0, (index + 1) * FRAME, FRAME))
        img.alpha_composite(frame.resize((FRAME * zoom, FRAME * zoom),
                                         Image.NEAREST), (x, 34))
        draw.text((x, height - 14), labels[index], font=font,
                  fill=(206, 192, 210, 255))
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
