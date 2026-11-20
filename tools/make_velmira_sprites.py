#!/usr/bin/env python
"""Generate Velmira's 6-frame hero sheet (player_shabnam.png) - FEMALE redesign.

WHY A GENERATOR (project rule: the .py is the source of truth, never the PNG)
  * Six frames that must not drift apart (idle / step A / step B / cast A /
    cast B / idle blink) are built from one body function, so a change to her
    waist or her coat hem moves in all six at once.
  * Everything is ASCII blocks of a fixed width (a paste can never shift by a
    pixel), plus two drawing helpers for the round bits (blood orb, droplets).
    check_widths() fails the build if any part has a ragged row.

        python tools/make_velmira_sprites.py

    Writes:
        assets/textures/player_shabnam.png   192 x 32 (6 frames of 32x32)
        docs/images/velmira_preview.png      review sheet

SHEET LAYOUT  (matches scenes/player/Shabnam.tscn - do not reorder!)
    frame 0 : idle            (the animation rests here)
    frame 1 : walk A          (0.00 - 0.08 s)
    frame 2 : walk B          (0.08 - 0.16 s)
    frame 3 : attack A        (0.00 - 0.08 s, wind-up)
    frame 4 : attack B        (0.08 - 0.24 s, the blood splash)
    frame 5 : idle breath     (2.20 - 2.40 s, a blink)

WHY SHE LOOKS LIKE THIS  (docs/VELMIRA_REDESIGN.md)
  * The old sprite read as a male count: one white blob of face under a black
    hood of hair, a straight coat, no waist. Nothing in it said "woman".
  * The fix is silhouette, in this order:
      1. a BOB - straight bangs, hair stopping at the jaw, side locks;
      2. a SMALL FACE inside that hair (5 px of skin in a 13 px head):
         lashed red eyes, blush, a two-pixel mouth;
      3. a WAIST - the coat is 15 px at the shoulders, 13 at the waist and
         15 again at the hem, and the corset pinches with it;
      4. skin at the throat - choker with a gold gem, and a sweetheart V over
         the corset;
      5. red gloves and a crimson hem lining - the only saturated colour, so
         the eye goes to her hands and her waist instead of to a dark blob.
  * Reference: the anime-style vampire portrait (blue-black bob, red eyes,
    fang, blood drip, choker + red gem, red gloves over a dark coat). Kept
    from the old Velmira: pale skin, crimson magic, a little gold.
"""

from typing import Dict, List, Tuple

from PIL import Image, ImageDraw, ImageFont

FRAME = 32
FRAMES = 6

# ---------------------------------------------------------------------------
# Palette - "cold moonlight, warm blood"
# ---------------------------------------------------------------------------
PAL = {
    "outline": (18, 13, 24, 255),
    # hair: blue-black with a cold sheen (the reference's bob)
    "hair": (38, 40, 72, 255),
    "hair_hi": (66, 72, 122, 255),
    "hair_lo": (24, 25, 46, 255),
    # skin: vampire pale with a COOL shadow (not pink, not grey)
    "skin": (226, 205, 217, 255),
    "skin_hi": (250, 238, 244, 255),
    "skin_lo": (186, 152, 172, 255),
    "blush": (214, 138, 160, 255),
    # eyes: the only place the red is pure
    "eye": (226, 34, 58, 255),
    "eye_hi": (255, 156, 168, 255),
    "lip": (146, 22, 44, 255),
    # clothes
    "coat": (50, 52, 82, 255),
    "coat_hi": (74, 80, 120, 255),
    "coat_lo": (30, 31, 52, 255),
    "corset": (124, 18, 36, 255),
    "corset_hi": (176, 34, 54, 255),
    "choker": (24, 20, 34, 255),
    "gold": (208, 170, 86, 255),
    "glove": (150, 24, 44, 255),
    "glove_hi": (204, 48, 66, 255),
    "boot": (30, 26, 42, 255),
    "tights": (44, 38, 58, 255),
    # blood
    "blood": (188, 20, 42, 255),
    "blood_hi": (255, 86, 100, 255),
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
    "e": PAL["eye"],
    "E": PAL["eye_hi"],
    "L": PAL["choker"],       # lashes: same near-black as the choker
    "l": PAL["lip"],
    "c": PAL["coat"],
    "C": PAL["coat_hi"],
    "d": PAL["coat_lo"],
    "r": PAL["corset"],
    "R": PAL["corset_hi"],
    "k": PAL["choker"],
    "g": PAL["gold"],
    "v": PAL["glove"],
    "V": PAL["glove_hi"],
    "o": PAL["boot"],
    "t": PAL["tights"],
    "x": PAL["blood"],
    "X": PAL["blood_hi"],
    "W": PAL["white"],
}

# ---------------------------------------------------------------------------
# THE VERTICAL BUDGET (32 px, boots on the bottom row)
#   y 1..12   head + bob (13 wide, face 5 of those 13)
#   y 13..24  neck, choker, corset, coat skirt, crimson hem
#   y 25..31  tights and boots (boots land on row 31)
# The first draft overflowed by three rows and the boots were simply cut off.
# ---------------------------------------------------------------------------
CX = 16
HEAD_X = 10
HEAD_Y = 1
TORSO_X = 9
TORSO_Y = 13
LEGS_X_OFFSET = 1
LEGS_Y = 25

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def new_frame() -> Image.Image:
    return Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))


def paste(img: Image.Image, art: List[str], ox: int, oy: int) -> None:
    for y, row in enumerate(art):
        for x, ch in enumerate(row):
            colour = SYMBOLS.get(ch)
            if colour is None:
                continue
            px(img, ox + x, oy + y, colour)


def px(img: Image.Image, x: int, y: int, colour) -> None:
    """Bounds-checked putpixel: parts are pasted right up to the frame edge."""
    if 0 <= x < FRAME and 0 <= y < FRAME:
        img.putpixel((x, y), colour)


def blood_orb(img: Image.Image, at, radius: int = 3) -> None:
    """A floating bead of blood magic (wind-up frame)."""
    x, y = at
    d = ImageDraw.Draw(img)
    d.ellipse([x - radius - 1, y - radius - 1, x + radius + 1, y + radius + 1],
              fill=PAL["outline"])
    d.ellipse([x - radius, y - radius, x + radius, y + radius], fill=PAL["blood"])
    d.ellipse([x - radius + 1, y - radius + 1, x, y - 1], fill=PAL["blood_hi"])
    px(img, x - 1, y - 2, PAL["white"])


def blood_spray(img: Image.Image, origin) -> None:
    """A fan of droplets in front of the thrust glove (cast B).

    A READ, not the hitbox: the real 92 px damage cone is drawn by the FX
    node, never by this sprite - so this only has to say "blood, that way".
    Written as separate pixels because a filled polygon at 32 px reads as a
    flag, not as magic.
    """
    x, y = origin
    for dx, dy, colour in ((0, 0, PAL["blood"]), (1, 0, PAL["blood"]),
                           (0, 1, PAL["blood_hi"]),
                           (2, -3, PAL["blood"]), (3, 1, PAL["blood"]),
                           (2, 3, PAL["blood_hi"]), (4, -1, PAL["blood"]),
                           (4, 2, PAL["blood_hi"])):
        px(img, x + dx, y + dy, colour)


# ---------------------------------------------------------------------------
# The head: hair mass, then the face on top of it
#
# 13 px wide, and the face inside it is only 7 px. That ratio is the whole
# trick: a small face framed by a big haircut reads as a girl at 32 px, while
# a face that fills the head reads as a mask.
# ---------------------------------------------------------------------------
HAIR_FACE = [
    "....#####....",
    "..##hhhhh##..",
    ".#hhhHHHhhh#.",
    "#hhhHHHhhhhh#",
    "#hhhhhhhhhhh#",
    "#hh#######hh#",
    "#hh#sssss#hh#",
    "#hh#sLsLs#hh#",
    "#hh#seses#hh#",
    "#hh#bsssb#hh#",
    "#hh#sslss#hh#",
    ".#hh#sss#hh#.",
]

# Idle blink (the 2.2 s beat of the idle animation): both lids shut.
HEAD_BLINK = [
    "....#####....",
    "..##hhhhh##..",
    ".#hhhHHHhhh#.",
    "#hhhHHHhhhhh#",
    "#hhhhhhhhhhh#",
    "#hh#######hh#",
    "#hh#sssss#hh#",
    "#hh#sLsLs#hh#",
    "#hh#sLsLs#hh#",
    "#hh#bsssb#hh#",
    "#hh#sslss#hh#",
    ".#hh#sss#hh#.",
]

# Cast pose: mouth open with both fangs out, and a drip of blood on the chin.
HEAD_OPEN = [
    "....#####....",
    "..##hhhhh##..",
    ".#hhhHHHhhh#.",
    "#hhhHHHhhhhh#",
    "#hhhhhhhhhhh#",
    "#hh#######hh#",
    "#hh#sssss#hh#",
    "#hh#sLsLs#hh#",
    "#hh#seses#hh#",
    "#hh#bsssb#hh#",
    "#hh#WxlxW#hh#",
    ".#hh#xss#hh#.",
]

# Torso: 15 px wide, 12 rows (y 13..24), drawn on a 13-11-9 taper and then
# flared back out to 15 at the hem. That hourglass is the female read - more
# than hair or eyes. Choker + gem at the throat, sweetheart neckline over a
# cinched corset, coat skirt with a crimson lining.
TORSO = [
    ".....#sss#.....",
    "...##kkgkk##...",
    ".#Cc#sssss#cC#.",
    ".#Cc#sssss#cC#.",
    "..#c#rrrrr#c#..",
    "..#c#rrrrr#c#..",
    "...#c#rrr#c#...",
    "...#c#rrr#c#...",
    "..#ccccccccc#..",
    ".#CcccccccccC#.",
    "#CCcccccccccCC#",
    "#ddRRRRRRRRRdd#",
]

# Legs: tights then boots, 7 rows (y 25..31). The 3 px gap between the legs is
# what stops the lower body from reading as one dark stump.
LEGS_STAND = [
    "..#t#...#t#..",
    "..#t#...#t#..",
    "..#t#...#t#..",
    "..#t#...#t#..",
    "..#o#...#o#..",
    ".#ooo#.#ooo#.",
    ".#####.#####.",
]

LEGS_STEP_A = [
    "..#t#...#t#..",
    "..#t#...#t#..",
    "..#t#...#t#..",
    "..#t#..#t#...",
    ".#o#...#o#...",
    "###o#.#ooo#..",
    "####..#####..",
]

LEGS_STEP_B = [
    "..#t#...#t#..",
    "..#t#...#t#..",
    "..#t#...#t#..",
    "...#t#..#t#..",
    "...#o#..#o#..",
    "..###o#.#ooo#",
    "..####..#####",
]

# Sleeves + gloved hands. Both arms step one pixel inward below the elbow: the
# shoulders measure 15 px across and the waist 13, and that taper is what makes
# the hourglass read at 2x zoom instead of the arms filling out a rectangle.
ARM_HANG = [
    "#c#.",
    "#c#.",
    "#c#.",
    "#c#.",
    ".#c#",
    ".#c#",
    ".#v#",
    ".#v#",
    ".###",
]

ARM_HANG_MIRROR = [
    ".#c#",
    ".#c#",
    ".#c#",
    ".#c#",
    "#c#.",
    "#c#.",
    "#v#.",
    "#v#.",
    "###.",
]

# Casting arm: elbow out, glove up beside the head (the reference's pose).
ARM_UP = [
    "#v##",
    "#vc#",
    ".#c#",
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
    "#ccccvv#",
    "#ccccvv#",
    "########",
]


# ---------------------------------------------------------------------------
# Body - one function, six sets of limbs
# ---------------------------------------------------------------------------
def draw_head(img: Image.Image, head: List[str]) -> None:
    paste(img, head, HEAD_X, HEAD_Y)


def draw_body(img: Image.Image, legs: List[str]) -> None:
    paste(img, TORSO, TORSO_X, TORSO_Y)
    paste(img, legs, TORSO_X + LEGS_X_OFFSET, LEGS_Y)


# ---------------------------------------------------------------------------
# Frames
# ---------------------------------------------------------------------------
def frame_idle(blink: bool = False) -> Image.Image:
    img = new_frame()
    draw_head(img, HEAD_BLINK if blink else HAIR_FACE)
    draw_body(img, LEGS_STAND)
    paste(img, ARM_HANG, TORSO_X, TORSO_Y + 2)
    paste(img, ARM_HANG_MIRROR, TORSO_X + 11, TORSO_Y + 2)
    return img


def frame_walk(step: int) -> Image.Image:
    img = new_frame()
    draw_head(img, HAIR_FACE)
    draw_body(img, LEGS_STEP_A if step == 1 else LEGS_STEP_B)
    paste(img, ARM_HANG, TORSO_X, TORSO_Y + 2)
    paste(img, ARM_HANG_MIRROR, TORSO_X + 11, TORSO_Y + (2 if step == 1 else 3))
    return img


def frame_cast(kind: int) -> Image.Image:
    img = new_frame()
    draw_head(img, HEAD_OPEN)
    draw_body(img, LEGS_STAND)
    paste(img, ARM_HANG, TORSO_X, TORSO_Y + 2)
    if kind == 0:
        paste(img, ARM_UP, TORSO_X + 11, TORSO_Y - 5)
        blood_orb(img, (TORSO_X + 16, TORSO_Y - 8), 3)
    else:
        paste(img, ARM_OUT, TORSO_X + 10, TORSO_Y + 3)
        blood_spray(img, (TORSO_X + 18, TORSO_Y + 5))
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
    img = Image.new("RGBA", (width, height), (28, 26, 34, 255))
    draw = ImageDraw.Draw(img)
    font = ImageFont.load_default()
    draw.text((pad, 10), "VELMIRA - 6 frames, 32x32 (female redesign)",
              font=font, fill=(240, 226, 236, 255))
    for index in range(FRAMES):
        frame = sheet.crop((index * FRAME, 0, index * FRAME + FRAME, FRAME))
        frame = frame.resize((FRAME * zoom, FRAME * zoom), Image.NEAREST)
        x = pad + index * (FRAME * zoom + pad)
        img.alpha_composite(frame, (x, 34))
        draw.text((x, 34 + FRAME * zoom + 4), labels[index],
                  font=font, fill=(196, 186, 200, 255))
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
