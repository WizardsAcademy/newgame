#!/usr/bin/env python
"""Generate every skeleton-archer texture (the 12-pose rig + flash row).

WHY A GENERATOR, NOT A HAND-DRAWN PNG
  * The archer is a rig: pelvis -> spine -> shoulders -> arms, plus a bow whose
    string pull is a NUMBER. Twelve poses are twelve rows in `POSES` below, not
    twelve drawings that can drift apart.
  * The head, ribcage, pelvis and quiver are tiny ASCII parts (`HEAD`, `RIBS`,
    ...), so the face can be tuned pixel by pixel without touching the rig.
  * Re-running this file is the single source of truth:

        python tools/make_archer_sprites.py

    Writes:
        assets/textures/archer_skeleton.png   384 x 64 (12 poses x 2 rows)
        docs/images/archer_preview.png        review sheet

SHEET LAYOUT  (mirrored in scripts/enemies/archer_visuals.gd)
    row 0 : the 12 coloured poses
    row 1 : the same 12 poses as pure-white silhouettes (hit flash)
    frame index = pose + (flashing ? 12 : 0)

WHY IT LOOKS LIKE THIS  (see docs/ARCHER_REDESIGN.md)
  * Gaunt, not chibi: a 7 px head on long thin bones. A big round head reads as
    cute - the first blockouts proved it.
  * The face is a black void with two ember eyes and the shadow of teeth,
    under a torn hood. The eyes are the only saturated colour on the sprite.
  * Bow, string and nocked arrow are all drawn from the rig, so "aiming" is a
    silhouette change (string pulled back, jaw open), never just a tint.
"""

import math
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

from PIL import Image, ImageDraw, ImageFont

FRAME = 32
GROUND = 30.0
CENTRE = 15.0
COLS = 12
WHITE = (255, 255, 255, 255)

BG = (24, 28, 32, 255)

# ---------------------------------------------------------------------------
# Palette: aged bone, torn hood, burning embers, old bow wood
# ---------------------------------------------------------------------------
PAL = {
    "outline": (16, 14, 20, 255),
    "bone": (206, 198, 172, 255),
    "bone_hi": (240, 234, 212, 255),
    "bone_lo": (150, 142, 118, 255),
    "void": (40, 32, 50, 255),
    "ember": (255, 138, 48, 255),
    "ember_hi": (255, 224, 150, 255),
    "cloak": (56, 44, 74, 255),
    "cloak_hi": (84, 66, 108, 255),
    "cloak_lo": (30, 22, 42, 255),
    "wood": (96, 62, 34, 255),
    "wood_hi": (146, 100, 58, 255),
    "string": (186, 178, 158, 255),
    "fletch": (188, 58, 54, 255),
    "shaft": (168, 132, 84, 255),
}

SYMBOLS = {
    ".": None,
    "#": PAL["outline"],
    "B": PAL["bone"],
    "W": PAL["bone_hi"],
    "b": PAL["bone_lo"],
    "X": PAL["void"],
    "e": PAL["ember"],
    "E": PAL["ember_hi"],
    "H": PAL["cloak"],
    "h": PAL["cloak_hi"],
    "d": PAL["cloak_lo"],
    "o": PAL["wood"],
    "O": PAL["wood_hi"],
    "s": PAL["string"],
    "f": PAL["fletch"],
    "S": PAL["shaft"],
}

# ---------------------------------------------------------------------------
# Parts
# ---------------------------------------------------------------------------
# The head is the character read: torn hood, black void, two embers, teeth.
HEAD = [
    "..###..",
    ".#HHH#.",
    "#HhhHH#",
    "#HXXXH#",
    "#XeXeX#",
    "#XeXeX#",
    "#HbXbH#",
    ".#XXX#.",
    "..#H#..",
]

# Same head, jaw dropped: the "rattle" / full-draw beat.
HEAD_OPEN = [
    "..###..",
    ".#HHH#.",
    "#HhhHH#",
    "#HXXXH#",
    "#XeXeX#",
    "#XeXeX#",
    "#X###X#",
    "#XbXbX#",
    "..#X#..",
]

RIBS = [
    ".###.",
    "#BWB#",
    "#...#",
    "#BWB#",
    "#...#",
    ".###.",
]

PELVIS = [
    ".###.",
    "#BBB#",
    ".#.#.",
]

QUIVER = [
    "f.f...",
    "f#f...",
    ".#....",
    ".#S...",
    ".#S...",
    ".##...",
]

# The final frame: a heap of bones where the archer stood.
BONES = [
    "....#....#....",
    "...#B#..#B#...",
    "..#BB#.#BB#...",
    ".#B#B###B#B#..",
    "#B##BBB#B##B#.",
    ".###.#####.#..",
    "..#B#..#BB#...",
    ".###########..",
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


def limb(img: Image.Image, p0, p1, shade: bool = False) -> None:
    """A 2 px bone with a 1 px dark rim - reads at 2x game zoom.

    `shade` draws the FAR limb (the leg or arm behind the body) one band
    darker, so two bones crossing each other never melt into one bright
    blob. That single trick is what makes the pose readable at 2x.

    Widths: 3 px of outline + a 2 px core. The first draft used 4 + 3 + 2
    (three bands) and the legs fused into a pair of trousers - a skeleton
    has to be THIN before it can read as a skeleton.
    """
    line(img, p0, p1, PAL["outline"], width=3)
    line(img, p0, p1, PAL["bone_lo"] if shade else PAL["bone"], width=2)


def foot(img: Image.Image, at) -> None:
    line(img, (at[0] - 1, at[1] + 1), (at[0] + 2, at[1] + 1), PAL["outline"], 3)
    line(img, (at[0] - 1, at[1] + 1), (at[0] + 2, at[1] + 1), PAL["bone"], 1)


# ---------------------------------------------------------------------------
# Poses
# ---------------------------------------------------------------------------
@dataclass
class Pose:
    name: str
    hips: Tuple[float, float] = (CENTRE - 1, 21)
    shoulder: Tuple[float, float] = (CENTRE - 1, 14)
    bow_hand: Tuple[float, float] = (CENTRE + 5, 17)
    draw_hand: Tuple[float, float] = (CENTRE + 1, 19)
    foot_a: Tuple[float, float] = (CENTRE - 4, GROUND)
    foot_b: Tuple[float, float] = (CENTRE + 4, GROUND)
    head_dy: float = 0.0
    lean: float = 0.0
    pull: float = 0.0
    aim: float = 0.0
    jaw: bool = False
    hem: float = 0.0
    heap: bool = False


POSES: List[Pose] = [
    # 0 idle_a: standing, bow low, embers dim.
    Pose("idle_a"),
    # 1 idle_b: 1 px sway, hem shifts.
    Pose("idle_b", hips=(CENTRE - 1, 21), head_dy=1.0, hem=1.0,
         bow_hand=(CENTRE + 5, 17)),
    # 2 rattle: the tell. Jaw open, shoulders up, bones shake.
    Pose("rattle", shoulder=(CENTRE - 1, 13), head_dy=-1.0,
         bow_hand=(CENTRE + 5, 16), draw_hand=(CENTRE + 2, 18), jaw=True),
    # 3/4 walk: stepping away, bow still low.
    Pose("walk_a", hips=(CENTRE - 1, 20), foot_a=(CENTRE - 7, GROUND),
         foot_b=(CENTRE + 5, GROUND - 2), head_dy=0.0, hem=1.0,
         shoulder=(CENTRE - 1, 13), bow_hand=(CENTRE + 5, 18),
         draw_hand=(CENTRE + 1, 20)),
    Pose("walk_b", hips=(CENTRE - 1, 20), foot_a=(CENTRE - 3, GROUND - 2),
         foot_b=(CENTRE + 8, GROUND), head_dy=0.0, hem=-1.0,
         shoulder=(CENTRE - 1, 13), bow_hand=(CENTRE + 4, 17),
         draw_hand=(CENTRE, 19)),
    # 5 draw: bow up, string half pulled.
    Pose("draw", shoulder=(CENTRE - 1, 14), bow_hand=(CENTRE + 6, 14),
         draw_hand=(CENTRE + 2, 14), pull=0.45, aim=1.0),
    # 6 full_draw: string at the cheek, jaw open, eyes flared.
    Pose("full_draw", shoulder=(CENTRE - 1, 14), bow_hand=(CENTRE + 6, 14),
         draw_hand=(CENTRE - 1, 13), pull=1.0, aim=1.0, jaw=True),
    # 7 release: string snapped forward, arms flung.
    Pose("release", shoulder=(CENTRE - 1, 14), bow_hand=(CENTRE + 6, 14),
         draw_hand=(CENTRE + 2, 13), pull=0.12),
    # 8 mock: head tilted, jaw open, bow lowered - "missed again".
    Pose("mock", head_dy=1.0, jaw=True, bow_hand=(CENTRE + 5, 19),
         draw_hand=(CENTRE + 2, 20), hem=1.0),
    # 9 hurt: knocked back, hood snapped.
    Pose("hurt", shoulder=(CENTRE - 2, 14), head_dy=1.0, lean=-2.0,
         bow_hand=(CENTRE + 4, 18), draw_hand=(CENTRE, 17),
         foot_a=(CENTRE - 6, GROUND), foot_b=(CENTRE + 5, GROUND), jaw=True),
    # 10 collapse: knees fold, bow dropping.
    Pose("collapse", hips=(CENTRE - 1, 26), shoulder=(CENTRE - 1, 21),
         bow_hand=(CENTRE + 4, 28), draw_hand=(CENTRE - 2, 28),
         foot_a=(CENTRE - 6, GROUND), foot_b=(CENTRE + 2, GROUND),
         head_dy=5.0, jaw=True),
    # 11 bones: the heap left behind.
    Pose("bones", heap=True),
]


def draw_bow(img: Image.Image, hand, pull: float, aim: float) -> None:
    """Recurve bow: two limbs, a string pulled by `pull` (0-1), nocked arrow."""
    gx, gy = hand
    top = (gx + 1, gy - 8)
    bot = (gx + 1, gy + 8)
    upper_knee = (gx + 5, gy - 3.5)
    lower_knee = (gx + 5, gy + 3.5)
    for a, b in ((top, upper_knee), (upper_knee, (gx + 1, gy)),
                 ((gx + 1, gy), lower_knee), (lower_knee, bot)):
        line(img, a, b, PAL["outline"], width=2)
        line(img, a, b, PAL["wood"], width=1)
    img.putpixel((int(gx + 2), int(gy)), PAL["wood_hi"])

    nock = (gx + 1 - 8.0 * pull, gy)
    line(img, top, nock, PAL["string"], width=1)
    line(img, nock, bot, PAL["string"], width=1)

    if aim > 0.05:
        tip = (nock[0] + 12.0 * aim, gy)
        line(img, nock, tip, PAL["outline"], width=2)
        line(img, nock, tip, PAL["shaft"], width=1)
        img.putpixel((int(tip[0]), int(tip[1])), PAL["bone_hi"])


def render(pose: Pose) -> Image.Image:
    img = new_frame()

    if pose.heap:
        paste(img, BONES, int(CENTRE - 7), int(GROUND - 8))
        return img

    hips = pose.hips
    neck = pose.shoulder
    lean = pose.lean

    # 1) Cloak behind everything: from the shoulders to a ragged hem.
    hem_y = hips[1] + 7 + pose.hem
    cloak = [
        (neck[0] - 3 + lean, neck[1] - 1),
        (neck[0] + 3 + lean, neck[1] - 1),
        (hips[0] + 5, hem_y),
        (hips[0] + 2, hem_y - 2),
        (hips[0], hem_y),
        (hips[0] - 2, hem_y - 1),
        (hips[0] - 5, hem_y - 2),
    ]
    ImageDraw.Draw(img).polygon(cloak, fill=PAL["cloak"], outline=PAL["outline"])
    line(img, (neck[0] - 1 + lean, neck[1] + 1), (hips[0] - 2, hem_y - 3),
         PAL["cloak_hi"])
    line(img, (hips[0] - 4, hem_y - 1), (hips[0] + 4, hem_y - 1),
         PAL["cloak_lo"])

    # 2) Quiver over the back shoulder, tucked so it overlaps the cloak:
    #    an arrow bundle that floats next to the body reads as debris.
    paste(img, QUIVER, int(neck[0] - 4 + lean), int(neck[1] - 3))

    # 3) Legs with knees + 2 px feet. The second (far) leg is a shade
    #    darker so a wide stance does not become one pair of trousers.
    for index, foot_pos in enumerate((pose.foot_a, pose.foot_b)):
        far: bool = index == 1
        knee = ((hips[0] + foot_pos[0]) / 2 + 1, (hips[1] + foot_pos[1]) / 2)
        limb(img, hips, knee, shade=far)
        limb(img, knee, foot_pos, shade=far)
        foot(img, foot_pos)

    # 4) Arms first, ribcage ON TOP: the chest must read even when an arm
    #    crosses it (the first draft's biggest bug).
    limb(img, pose.shoulder, pose.bow_hand)
    limb(img, (pose.shoulder[0] - 1, pose.shoulder[1] + 1), pose.draw_hand,
         shade=True)

    # 5) Spine + ribcage + pelvis.
    limb(img, hips, neck)
    paste(img, RIBS, int(neck[0] - 2 + lean), int(neck[1] + 1))
    paste(img, PELVIS, int(hips[0] - 2), int(hips[1] - 1))

    # 6) Bow, string, nocked arrow.
    draw_bow(img, pose.bow_hand, pose.pull, pose.aim)

    # 7) The head last, so nothing covers the face.
    head_top = int(neck[1] - 11 + pose.head_dy)
    paste(img, HEAD_OPEN if pose.jaw else HEAD, int(neck[0] - 1 + lean), head_top)
    return img


def silhouette(img: Image.Image) -> Image.Image:
    """Pure-white copy: the hit flash, exactly like the slime's flash row."""
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    src = img.load()
    dst = out.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            if src[x, y][3] > 0:
                dst[x, y] = WHITE
    return out


def build_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (FRAME * COLS, FRAME * 2), (0, 0, 0, 0))
    for i, pose in enumerate(POSES):
        art = render(pose)
        sheet.paste(art, (i * FRAME, 0))
        sheet.paste(silhouette(art), (i * FRAME, FRAME))
    return sheet


def _font(size: int):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def build_preview(sheet: Image.Image) -> Image.Image:
    zoom = 6
    pad = 12
    label_h = 18
    tile = FRAME * zoom
    width = pad + COLS * (tile + pad)
    height = pad * 2 + 30 + (tile + label_h) * 2
    img = Image.new("RGBA", (width, height), BG)
    draw = ImageDraw.Draw(img)
    title, label = _font(18), _font(13)

    draw.text((pad, 8), "SKELETON ARCHER  -  12 poses + white flash row",
              font=title, fill=(235, 242, 235, 255))

    for row in range(2):
        for col in range(COLS):
            x = pad + col * (tile + pad)
            y = pad + 26 + row * (tile + label_h)
            frame = sheet.crop((col * FRAME, row * FRAME,
                                (col + 1) * FRAME, (row + 1) * FRAME))
            img.alpha_composite(frame.resize((tile, tile), Image.NEAREST), (x, y))
            if row == 0:
                draw.text((x + 2, y + tile + 1), POSES[col].name, font=label,
                          fill=(150, 200, 160, 255))
            else:
                draw.text((x + 2, y + tile + 1), "flash", font=label,
                          fill=(150, 150, 150, 255))
    return img


def main() -> None:
    sheet = build_sheet()
    sheet.save("assets/textures/archer_skeleton.png")

    import os
    os.makedirs("docs/images", exist_ok=True)
    build_preview(sheet).save("docs/images/archer_preview.png")

    print("wrote assets/textures/archer_skeleton.png", sheet.size,
          "-> hframes", COLS, "vframes 2")
    print("wrote docs/images/archer_preview.png")
    print("frame index = pose + (flashing ? %d : 0)" % COLS)


if __name__ == "__main__":
    main()
