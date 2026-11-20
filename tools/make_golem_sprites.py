#!/usr/bin/env python
"""Generate every stone-golem texture (the 12-pose rig + flash row).

WHY A GENERATOR, NOT A HAND-DRAWN PNG
  * The golem is a BRUTE: it is all silhouette. Shoulders, fists and the
    width of the chest are numbers here (`Pose`), so "heavier" is a slider,
    not a redraw.
  * The stone plates, the head and the rubble pile are tiny ASCII parts
    (`HEAD`, `PLATES`, `RUBBLE`, ...), so they can be tuned pixel by pixel.
  * Re-running is the single source of truth:

        python tools/make_golem_sprites.py

    Writes:
        assets/textures/golem_stone.png   480 x 80 (12 poses x 2 rows)
        docs/images/golem_preview.png     review sheet

SHEET LAYOUT  (mirrored in scripts/enemies/golem_visuals.gd)
    row 0 : the 12 coloured poses
    row 1 : the same 12 poses as pure-white silhouettes (hit flash)
    frame index = pose + (flashing ? 12 : 0)

WHY IT LOOKS LIKE THIS  (see docs/GOLEM_REDESIGN.md)
  * Heavy is a SHAPE, not a colour: tiny head sunk between boulder
    shoulders, arms that reach the knees, a chest wider than the hips, and
    legs so short they look like an afterthought. Every proportion says
    "this thing is made of rock and it does not hurry".
  * The chest is cracked open and burning: amber light pours out of the
    seams. That single bright channel is the only saturated colour on the
    sprite, exactly like the archer's embers.
  * Poses are RIG outputs, so the slam really lowers the shoulders and the
    telegraph really raises both fists above the head.
"""

import math
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

from PIL import Image, ImageDraw, ImageFont

FRAME = 40
GROUND = 37.0
CX = 19
COLS = 12
WHITE = (255, 255, 255, 255)

# ---------------------------------------------------------------------------
# Palette: cold basalt, hot seams
# ---------------------------------------------------------------------------
PAL = {
    "outline": (14, 12, 18, 255),
    "stone_hi": (140, 139, 154, 255),
    "stone": (107, 106, 120, 255),
    "stone_lo": (74, 73, 86, 255),
    "stone_dark": (46, 44, 56, 255),
    "amber": (255, 148, 38, 255),
    "amber_hi": (255, 217, 137, 255),
    "ember_deep": (176, 68, 22, 255),
    "dust": (120, 118, 130, 255),
}

SYMBOLS = {
    ".": None,
    "#": PAL["outline"],
    "L": PAL["stone_hi"],
    "S": PAL["stone"],
    "s": PAL["stone_lo"],
    "d": PAL["stone_dark"],
    "A": PAL["amber"],
    "a": PAL["amber_hi"],
    "E": PAL["ember_deep"],
    "u": PAL["dust"],
}

# ---------------------------------------------------------------------------
# Parts
# ---------------------------------------------------------------------------
# The head is deliberately SMALL and low: a big head reads as a person, a
# small head between two boulders reads as a monster.
HEAD = [
    "..####..",
    ".#LLLL#.",
    "#LSLLSL#",
    "#SssssS#",
    "#Sa##aS#",
    "#SSSSSS#",
    ".#SDDS#.",
]

# Roar / telegraph face: jaw dropped, furnace inside.
HEAD_OPEN = [
    "..####..",
    ".#LLLL#.",
    "#LSLLSL#",
    "#SssssS#",
    "#Sa##aS#",
    "#SEaaES#",
    "##EEEE##",
]

# A chest plate seam, pasted over the torso.
PLATE = [
    ".#....#.",
    "#s#..#s#",
    "#s#..#s#",
    ".#....#.",
]

# A fist: rounded knuckle block with three finger grooves and one ember
# seam. Drawn as ASCII (not as a rectangle) because a plain grey square at
# this size reads as a bucket, not as a hand.
FIST = [
    ".#####.",
    "#LLSSL#",
    "#S#S#S#",
    "#S#S#S#",
    "#sssSS#",
    ".#####.",
]
FIST_DARK = [
    ".#####.",
    "#ssSSs#",
    "#s#s#s#",
    "#s#s#s#",
    "#sssss#",
    ".#####.",
]

RUBBLE = [
    "......###..###......",
    "....##LLL##LLL##....",
    "..##LSSLL#LSSLL##...",
    ".#LSSsS##SSSsSSL#...",
    ".#SssSS#LSssSSsS#...",
    "#LSsdS#LSssdSSsSS#..",
    "#SssSS#LSsSSSSsSS#..",
    ".#####.##########...",
]


def new_frame() -> Image.Image:
    return Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))


def paste(img: Image.Image, art: List[str], ox: int, oy: int) -> None:
    for y, row in enumerate(art):
        for x, ch in enumerate(row):
            colour = SYMBOLS.get(ch)
            if colour is None:
                continue
            px, py = ox + x, oy + y
            if 0 <= px < FRAME and 0 <= py < FRAME:
                img.putpixel((px, py), colour)


def line(img: Image.Image, p0, p1, colour, width: int = 1) -> None:
    ImageDraw.Draw(img).line([p0, p1], fill=colour, width=width)


def stone_limb(img: Image.Image, p0, p1, thick: int, shade: bool = False) -> None:
    """A stone limb: dark rim, mid stone, one lit edge.

    `thick` is the FULL width in pixels. A brute needs 5-8 px limbs: at 40 px
    a thin limb reads as a stick figure wearing a rock costume.
    """
    line(img, p0, p1, PAL["outline"], width=thick + 2)
    line(img, p0, p1, PAL["stone_lo"] if shade else PAL["stone"], width=thick)
    # The lit edge: a single highlight line offset "up-left" of the limb.
    off = -1 if p0[0] <= p1[0] else 1
    line(img, (p0[0] + off, p0[1] - 1), (p1[0] + off, p1[1] - 1),
         PAL["stone_lo"] if shade else PAL["stone_hi"], width=1)


def boulder(img: Image.Image, at, radius: int, shade: bool = False) -> None:
    """A rounded chunk of rock - the shoulders are made of these."""
    x, y = at
    d = ImageDraw.Draw(img)
    d.ellipse([x - radius - 1, y - radius - 1, x + radius + 1, y + radius + 1],
              fill=PAL["outline"])
    d.ellipse([x - radius, y - radius, x + radius, y + radius],
              fill=PAL["stone_lo"] if shade else PAL["stone"])
    # lit cap
    d.ellipse([x - radius + 1, y - radius + 1, x + radius - 2, y - 1],
              fill=PAL["stone_lo"] if shade else PAL["stone_hi"])


def fist(img: Image.Image, at, shade: bool = False, mirror: bool = False) -> None:
    """A knuckled fist (see FIST above)."""
    art = FIST_DARK if shade else FIST
    rows = [row[::-1] if mirror else row for row in art]
    paste(img, rows, int(at[0] - 3), int(at[1] - 3))


def cracks(img: Image.Image, points: List[Tuple[float, float]], power: float,
           width: int = 1) -> None:
    """A burning seam. `power` 0..1 picks dim ember -> white-hot core.

    One pixel wide on purpose: a 2 px seam down the chest stops looking like
    a crack and starts looking like a harness strap.
    """
    if power <= 0.02:
        return
    hot = PAL["amber_hi"] if power > 0.75 else PAL["amber"]
    for i in range(len(points) - 1):
        line(img, points[i], points[i + 1],
             PAL["ember_deep"] if power < 0.35 else hot, width=width)


# ---------------------------------------------------------------------------
# Poses
# ---------------------------------------------------------------------------
@dataclass
class Pose:
    name: str
    neck_y: float = 13.0          # shoulder line
    waist_y: float = 25.0
    head_dy: float = 0.0
    lean: float = 0.0             # whole upper body shift, px
    half_top: float = 9.5         # shoulder half-width (the brute dial)
    half_bot: float = 5.0         # waist half-width
    fist_l: Optional[Tuple[float, float]] = None
    fist_r: Optional[Tuple[float, float]] = None
    foot_l_x: float = -6.0
    foot_r_x: float = 6.0
    knee_y: float = 31.0
    power: float = 0.45           # how bright the chest seams burn
    jaw: bool = False
    squat: float = 0.0            # hips drop
    rubble: bool = False
    ground_crack: bool = False


def default_fists(pose: Pose) -> Tuple[Tuple[float, float], Tuple[float, float]]:
    fl = pose.fist_l if pose.fist_l is not None else (CX - 11, 28)
    fr = pose.fist_r if pose.fist_r is not None else (CX + 11, 28)
    return fl, fr


POSES: List[Pose] = [
    # 0 idle_a: hunched, fists hanging by the knees.
    Pose("idle_a"),
    # 1 idle_b: breath in - chest up a pixel, seams glow a little more.
    Pose("idle_b", neck_y=12.0, power=0.55),
    # 2 roar: the testosterone beat. Head up, jaw open, arms flung wide.
    Pose("roar", neck_y=12.5, head_dy=-1.0, power=0.95, jaw=True,
         fist_l=(CX - 13, 22), fist_r=(CX + 13, 22), half_top=10.5),
    # 3/4 walk: a slow stomp. The whole body drops on the planted foot.
    Pose("walk_a", neck_y=13.0, head_dy=0.5, fist_l=(CX - 11, 29),
         fist_r=(CX + 11, 27), foot_l_x=-7.0, foot_r_x=4.0, knee_y=31.0),
    Pose("walk_b", neck_y=13.0, head_dy=0.5, fist_l=(CX - 11, 27),
         fist_r=(CX + 11, 29), foot_l_x=-4.0, foot_r_x=7.0, knee_y=31.0),
    # 5 telegraph: both fists overhead - the 0.8 s dodge window.
    Pose("telegraph", neck_y=12.0, head_dy=-1.0, power=0.8, jaw=True,
         fist_l=(CX - 9, 6), fist_r=(CX + 9, 6), half_top=10.0),
    # 6 slam: fists driven into the floor, body compressed, floor cracks.
    Pose("slam", neck_y=17.0, waist_y=27.0, head_dy=2.0, power=0.9, jaw=True,
         fist_l=(CX - 12, 34), fist_r=(CX + 12, 34), half_top=11.0,
         knee_y=32.0, squat=1.0, ground_crack=True),
    # 7 recover: stuck in the ground, slumped, seams almost out.
    Pose("recover", neck_y=16.5, waist_y=27.0, head_dy=3.0, power=0.12,
         fist_l=(CX - 12, 35), fist_r=(CX + 12, 35), half_top=10.5,
         knee_y=32.0, squat=1.0),
    # 8 hurt: knocked back a step, one arm up to guard.
    Pose("hurt", neck_y=13.5, head_dy=1.5, lean=-2.0, power=0.3, jaw=True,
         fist_l=(CX - 10, 24), fist_r=(CX + 12, 30),
         foot_l_x=-7.0, foot_r_x=5.0),
    # 9 rise: the elite's UPRISING - arms spread, seams blazing.
    Pose("rise", neck_y=12.0, head_dy=-1.0, power=1.0, jaw=True,
         fist_l=(CX - 14, 20), fist_r=(CX + 14, 20), half_top=10.5),
    # 10 crumble: knees gone, whole body folding sideways.
    Pose("crumble", neck_y=22.0, waist_y=30.0, head_dy=2.0, lean=-3.0,
         power=0.2, half_top=10.0, fist_l=(CX - 13, 36), fist_r=(CX + 6, 37),
         foot_l_x=-8.0, foot_r_x=2.0, knee_y=34.0, squat=1.0),
    # 11 rubble: the pile that is left behind.
    Pose("rubble", rubble=True),
]


def render(pose: Pose) -> Image.Image:
    img = new_frame()

    if pose.rubble:
        paste(img, RUBBLE, int(CX - 8), int(GROUND - 6))
        return img

    hips_y = pose.waist_y + 2.0 + pose.squat
    neck = (CX + pose.lean, pose.neck_y)
    waist_y = pose.waist_y + pose.squat

    fl, fr = default_fists(pose)

    # 1) Legs: short, thick, wide stance. The far leg is one band darker.
    for x_off, shade in ((pose.foot_l_x, True), (pose.foot_r_x, False)):
        hip = (CX + x_off * 0.55, hips_y)
        knee = (CX + x_off * 0.9, pose.knee_y + pose.squat)
        foot = (CX + x_off, GROUND)
        stone_limb(img, hip, knee, 5, shade=shade)
        stone_limb(img, knee, foot, 4, shade=shade)
        # foot: a slab
        line(img, (foot[0] - 3, foot[1] + 1), (foot[0] + 3, foot[1] + 1),
             PAL["outline"], width=4)
        line(img, (foot[0] - 2, foot[1] + 1), (foot[0] + 2, foot[1] + 1),
             PAL["stone_lo"] if shade else PAL["stone"], width=2)

    # 2) Pelvis: a stone belt between the waist and the legs.
    d = ImageDraw.Draw(img)
    d.polygon([
        (CX - pose.half_bot - 1, waist_y),
        (CX + pose.half_bot + 1, waist_y),
        (CX + pose.half_bot, hips_y + 1),
        (CX - pose.half_bot, hips_y + 1),
    ], fill=PAL["stone_lo"], outline=PAL["outline"])
    d.line([CX - pose.half_bot + 1, hips_y, CX + pose.half_bot - 1, hips_y],
           fill=PAL["stone_dark"])
    d.line([CX - pose.half_bot, waist_y + 1, CX + pose.half_bot, waist_y + 1],
           fill=PAL["stone_dark"])
    for rivet in (-2, 2):
        img.putpixel((CX + rivet, int(waist_y) + 1),
                     PAL["amber"] if pose.power > 0.4 else PAL["ember_deep"])

    # 4) Torso: a chest wider than the hips. THE brute shape.
    torso = [
        (neck[0] - pose.half_top, neck[1]),
        (neck[0] + pose.half_top, neck[1]),
        (CX + pose.half_bot, waist_y),
        (CX - pose.half_bot, waist_y),
    ]
    d.polygon(torso, fill=PAL["stone"], outline=PAL["outline"])

    # Carved masonry: the chest is three courses of rock, each with a lit top
    # bevel and a dark joint under it, plus two offset vertical joints like a
    # brick wall. That pattern is what says "made of stone" and not "grey
    # jumper": a flat fill reads as cloth no matter how grey it is.
    chest_top = neck[1] + 1
    course_a = neck[1] + 5
    course_b = neck[1] + 9
    line(img, (neck[0] - pose.half_top + 2, chest_top),
         (neck[0] + pose.half_top - 2, chest_top), PAL["stone_hi"])
    for y, inset in ((course_a, 5.0), (course_b, 4.2)):
        line(img, (CX - (pose.half_top - inset), y),
             (CX + (pose.half_top - inset), y), PAL["stone_hi"])
        line(img, (CX - (pose.half_top - inset) + 1, y + 1),
             (CX + (pose.half_top - inset) - 1, y + 1), PAL["stone_dark"])
    # offset vertical joints (brick pattern)
    line(img, (CX - 5, course_a + 1), (CX - 5, course_b), PAL["stone_dark"])
    line(img, (CX + 5, course_a + 1), (CX + 5, course_b), PAL["stone_dark"])
    line(img, (CX - 1, course_b + 1), (CX - 1, waist_y - 1), PAL["stone_dark"])
    # underside shadow: the belly is always the darkest part of the slab, and
    # the last two rows of the chest go a full band darker so the mass has a
    # bottom edge instead of fading into the legs
    line(img, (CX - pose.half_bot + 1, waist_y - 1),
         (CX + pose.half_bot - 1, waist_y - 1), PAL["stone_dark"])
    line(img, (CX - pose.half_bot - 1, waist_y - 3),
         (CX + pose.half_bot + 1, waist_y - 3), PAL["stone_lo"])

    # 6) Arms AFTER the torso: they overlap the chest edge and keep their own
    #    dark rim, which is what makes them read as two slabs of rock in front
    #    of a third one instead of one wide grey blob.
    for fist_pos, shade, side in ((fl, True, -1), (fr, False, 1)):
        shoulder = (neck[0] + side * (pose.half_top + 1.0), neck[1] + 1.0)
        elbow = (shoulder[0] + side * 1.5, (shoulder[1] + fist_pos[1]) * 0.5)
        stone_limb(img, shoulder, elbow, 6, shade=shade)
        stone_limb(img, elbow, fist_pos, 7, shade=shade)
        # contact shadow where the arm meets the chest: without it the arm
        # melts back into the torso at gameplay zoom
        line(img, (shoulder[0] - side * 4, shoulder[1] + 1),
             (elbow[0] - side * 4, elbow[1]), PAL["stone_dark"])
        fist(img, fist_pos, shade=shade, mirror=side > 0)

    # 7) The burning core: a jagged seam from the throat to the belly, with
    #    two branches into the ribs and a hot cluster at the sternum.
    seam_top = (CX + pose.lean, neck[1] + 2)
    seam_mid = (CX - 1, neck[1] + 8)
    seam_bot = (CX, waist_y - 1)
    cracks(img, [seam_top, seam_mid], pose.power)
    cracks(img, [seam_mid, seam_bot], pose.power)
    if pose.power > 0.4:
        cracks(img, [(CX - 1, neck[1] + 5), (CX - 4, neck[1] + 4)], pose.power * 0.8)
        cracks(img, [(CX - 1, neck[1] + 6), (CX + 3, neck[1] + 8)], pose.power * 0.8)
    if pose.power > 0.6:
        # the heart: a 2x2 white-hot cluster, the brightest thing on screen
        for hx, hy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            img.putpixel((CX + hx, int(neck[1] + 6 + hy)), PAL["amber_hi"])
    if pose.ground_crack:
        cracks(img, [(CX - 13, GROUND + 1), (CX - 8, GROUND - 1)], 0.9)
        cracks(img, [(CX + 13, GROUND + 1), (CX + 8, GROUND - 1)], 0.9)

    # 8) Shoulder boulders outside the arm joints, like armour caps.
    boulder(img, (neck[0] - pose.half_top + 1, neck[1] + 2), 4)
    boulder(img, (neck[0] + pose.half_top - 1, neck[1] + 2), 4)

    # 9) Head: small, sunk between the boulders, drawn after everything.
    head_top = int(neck[1] - 5 + pose.head_dy)
    paste(img, HEAD_OPEN if pose.jaw else HEAD, int(CX + pose.lean - 4), head_top)
    return img


def silhouette(img: Image.Image) -> Image.Image:
    """Pure-white copy: the hit flash, exactly like the slime's and archer's."""
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    src = img.load()
    dst = out.load()
    for y in range(img.height):
        for x in range(img.width):
            if src[x, y][3] > 0:
                dst[x, y] = WHITE
    return out


def build_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (FRAME * COLS, FRAME * 2), (0, 0, 0, 0))
    for index, pose in enumerate(POSES):
        art = render(pose)
        sheet.alpha_composite(art, (index * FRAME, 0))
        sheet.alpha_composite(silhouette(art), (index * FRAME, FRAME))
    return sheet


def build_preview(sheet: Image.Image) -> Image.Image:
    """A review sheet: every pose, labelled, plus the flash row."""
    zoom = 4
    pad = 18
    label_h = 16
    width = pad + COLS * (FRAME * zoom + pad)
    height = 30 + (FRAME * zoom + label_h) * 2 + pad
    img = Image.new("RGBA", (width, height), (24, 26, 32, 255))
    draw = ImageDraw.Draw(img)
    draw.text((pad, 8), "STONE GOLEM - 12 poses + white flash row (40x40)",
              font=ImageFont.load_default(), fill=(240, 234, 212, 255))
    for row in range(2):
        for index, pose in enumerate(POSES):
            frame = sheet.crop((index * FRAME, row * FRAME,
                                index * FRAME + FRAME, row * FRAME + FRAME))
            frame = frame.resize((FRAME * zoom, FRAME * zoom), Image.NEAREST)
            x = pad + index * (FRAME * zoom + pad)
            y = 30 + row * (FRAME * zoom + label_h)
            img.alpha_composite(frame, (x, y))
            text = pose.name if row == 0 else "flash"
            draw.text((x, y + FRAME * zoom + 2), text,
                      font=ImageFont.load_default(), fill=(190, 188, 198, 255))
    return img


def main() -> None:
    sheet = build_sheet()
    sheet.save("assets/textures/golem_stone.png")
    print("wrote assets/textures/golem_stone.png", sheet.size,
          "-> hframes %d vframes 2" % COLS)
    build_preview(sheet).save("docs/images/golem_preview.png")
    print("wrote docs/images/golem_preview.png")
    print("frame index = pose + (flashing ? 12 : 0)")


if __name__ == "__main__":
    main()
