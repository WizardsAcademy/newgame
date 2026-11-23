#!/usr/bin/env python3
"""Generate clean 96x96 house-style pixel-art assets for the Witch's Cottage Lobby:
  - assets/textures/lobby_witch.png    (384x96 = 4 frames of 96x96: idle, wink, magic, potion_offer)
  - assets/textures/lobby_cauldron.png (384x64 = 6 frames of 64x64: 3 green bubbling -> 3 sudden purple flash/swirl)
  - assets/textures/witch_potion.png   (64x32  = 2 frames of 32x32: emerald & amethyst potion vials)
  - assets/textures/cottage_floor.png  (64x64  tileable warm aged oak planks)
"""

from __future__ import annotations

import hashlib
from pathlib import Path
from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
TEX_DIR = REPO_ROOT / "assets" / "textures"

# Clean house-style pixel palette (matches Knight / Behemoth / Sylvara / Noa)
OUTLINE = (24, 16, 34, 255)
HAT_DARK = (32, 20, 48, 255)
HAT_MID = (54, 34, 82, 255)
HAT_LIGHT = (82, 54, 122, 255)

HAIR_DARK = (38, 22, 56, 255)
HAIR_MID = (66, 38, 96, 255)
HAIR_HI = (104, 62, 148, 255)

SKIN_SHAD = (224, 172, 164, 255)
SKIN_BASE = (248, 208, 198, 255)
SKIN_HI = (255, 230, 224, 255)
BLUSH = (244, 134, 158, 255)
LIP_BERRY = (188, 42, 92, 255)
EYE_VIOLET = (196, 68, 255, 255)
EYE_GLOW = (244, 148, 255, 255)
WHITE_SPEC = (252, 248, 255, 255)

DRESS_DARK = (28, 18, 42, 255)
DRESS_MID = (52, 30, 74, 255)
DRESS_TRIM = (146, 52, 196, 255)
GOLD_DARK = (168, 116, 38, 255)
GOLD_HI = (246, 204, 88, 255)

GREEN_DEEP = (20, 108, 56, 255)
GREEN_MID = (46, 204, 112, 255)
GREEN_HI = (146, 255, 186, 255)

PURP_DEEP = (88, 24, 158, 255)
PURP_MID = (168, 56, 255, 255)
PURP_HI = (238, 148, 255, 255)


def write_godot_import(png_path: Path, uid_str: str) -> None:
    res_path = f"res://assets/textures/{png_path.name}"
    md5 = hashlib.md5(res_path.encode("utf-8")).hexdigest()
    ctex = f"res://.godot/imported/{png_path.name}-{md5}.ctex"
    content = f"""[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid_str}"
path="{ctex}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{res_path}"
dest_files=["{ctex}"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""
    imp_path = png_path.with_suffix(".png.import")
    if not imp_path.exists():
        imp_path.write_text(content, encoding="utf-8")


def draw_potion_bottle(im: Image.Image, cx: int, cy: int, purple: bool = False, small: bool = False) -> None:
    d = ImageDraw.Draw(im)
    c_deep = PURP_DEEP if purple else GREEN_DEEP
    c_mid = PURP_MID if purple else GREEN_MID
    c_hi = PURP_HI if purple else GREEN_HI

    if small:
        # Cute 11x13 vial held in Witch's hand
        d.rectangle([cx - 2, cy - 6, cx + 2, cy - 4], fill=(168, 116, 68, 255), outline=OUTLINE)
        d.ellipse([cx - 5, cy - 4, cx + 5, cy + 6], fill=c_mid, outline=OUTLINE)
        d.chord([cx - 4, cy, cx + 4, cy + 5], 0, 180, fill=c_deep)
        im.putpixel((cx - 2, cy - 1), WHITE_SPEC)
        im.putpixel((cx - 1, cy - 2), c_hi)
        return

    # 32x32 standalone potion icon
    d.rectangle([cx - 3, cy - 11, cx + 3, cy - 7], fill=(176, 122, 72, 255), outline=OUTLINE)
    d.rectangle([cx - 4, cy - 7, cx + 4, cy - 5], fill=(190, 214, 236, 255), outline=OUTLINE)
    d.ellipse([cx - 9, cy - 5, cx + 9, cy + 11], fill=(56, 68, 92, 255), outline=OUTLINE)
    d.ellipse([cx - 7, cy - 2, cx + 7, cy + 9], fill=c_mid)
    d.chord([cx - 7, cy + 2, cx + 7, cy + 9], 0, 180, fill=c_deep)
    d.ellipse([cx - 5, cy - 1, cx + 5, cy + 2], fill=c_hi)
    d.line([(cx - 5, cy - 2), (cx - 4, cy + 3)], fill=WHITE_SPEC, width=1)


def draw_witch_frame(frame_idx: int) -> Image.Image:
    im = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    by = -1 if frame_idx in (1, 2) else 0
    cx = 48

    # 1. Back voluminous dark-violet hair cape cascading past hips
    hair_sway = 1 if frame_idx in (1, 3) else 0
    d.polygon(
        [
            (cx - 14, 30 + by),
            (cx + 14, 30 + by),
            (cx + 19 + hair_sway, 66 + by),
            (cx + 12 + hair_sway, 70 + by),
            (cx - 12 + hair_sway, 70 + by),
            (cx - 19 + hair_sway, 65 + by),
        ],
        fill=HAIR_DARK,
        outline=OUTLINE,
    )
    d.polygon(
        [
            (cx - 12, 33 + by),
            (cx + 12, 33 + by),
            (cx + 15 + hair_sway, 64 + by),
            (cx - 15 + hair_sway, 64 + by),
        ],
        fill=HAIR_MID,
    )

    # 2. Heeled dark boots & legs (high-slit baddie skirt!)
    # Left leg (visible slit leg) + right boot
    d.rectangle([cx - 8, 66, cx - 3, 75], fill=SKIN_SHAD, outline=OUTLINE)
    d.rectangle([cx - 8, 72, cx - 2, 79], fill=DRESS_DARK, outline=OUTLINE)
    d.rectangle([cx + 2, 71, cx + 8, 79], fill=DRESS_DARK, outline=OUTLINE)
    # Gold boot buckles
    im.putpixel((cx - 5, 74), GOLD_HI)
    im.putpixel((cx + 5, 74), GOLD_HI)

    # 3. Fitted corset-bodice & side-slit velvet skirt
    # Skirt (flared with confident left leg slit)
    d.polygon(
        [
            (cx - 9, 56 + by),
            (cx + 9, 56 + by),
            (cx + 14, 73),
            (cx - 1, 73),
            (cx - 3, 63 + by),
            (cx - 9, 71),
            (cx - 14, 70),
        ],
        fill=DRESS_DARK,
        outline=OUTLINE,
    )
    d.polygon(
        [(cx + 1, 58 + by), (cx + 8, 58 + by), (cx + 11, 71), (cx + 1, 71)],
        fill=DRESS_MID,
    )
    # Trim along skirt hem
    d.line([(cx + 1, 72), (cx + 12, 72)], fill=DRESS_TRIM)

    # Off-shoulder sweetheart neckline & hourglass corset waist
    d.rectangle([cx - 9, 44 + by, cx + 9, 51 + by], fill=SKIN_BASE, outline=OUTLINE)
    d.polygon(
        [
            (cx - 10, 47 + by),
            (cx - 4, 46 + by),
            (cx, 49 + by),
            (cx + 4, 46 + by),
            (cx + 10, 47 + by),
            (cx + 8, 57 + by),
            (cx - 8, 57 + by),
        ],
        fill=DRESS_MID,
        outline=OUTLINE,
    )
    # Gold waist chain + amethyst corset gem
    d.line([(cx - 7, 56 + by), (cx + 7, 56 + by)], fill=GOLD_HI)
    im.putpixel((cx, 57 + by), GOLD_DARK)
    im.putpixel((cx, 49 + by), PURP_MID)
    im.putpixel((cx, 48 + by), GOLD_HI)

    # 4. Arms & pose-specific gesture
    # Right arm (resting confidently on hip or channeling magic)
    d.polygon(
        [(cx + 9, 47 + by), (cx + 14, 52 + by), (cx + 10, 57 + by), (cx + 8, 54 + by)],
        fill=DRESS_DARK,
        outline=OUTLINE,
    )
    im.putpixel((cx + 10, 56 + by), SKIN_BASE)

    if frame_idx == 3:
        # OFFERING GLOWING POTION TO THE HERO! (left arm extended outward holding glowing potion)
        d.polygon(
            [(cx - 9, 47 + by), (cx - 21, 49 + by), (cx - 21, 53 + by), (cx - 9, 52 + by)],
            fill=DRESS_DARK,
            outline=OUTLINE,
        )
        d.rectangle([cx - 24, 49 + by, cx - 20, 53 + by], fill=SKIN_BASE, outline=OUTLINE)
        draw_potion_bottle(im, cx - 25, 46 + by, purple=True, small=True)
        # Sparkles around offered potion
        for sx, sy, col in ((-33, 41, GREEN_HI), (-19, 38, PURP_HI), (-32, 52, WHITE_SPEC)):
            im.putpixel((cx + sx, sy + by), col)
    elif frame_idx == 2:
        # Stirring / casting emerald-violet magic above palm!
        d.polygon(
            [(cx - 9, 47 + by), (cx - 17, 45 + by), (cx - 17, 50 + by), (cx - 9, 52 + by)],
            fill=DRESS_DARK,
            outline=OUTLINE,
        )
        d.rectangle([cx - 19, 45 + by, cx - 16, 49 + by], fill=SKIN_BASE, outline=OUTLINE)
        for sx, sy, col in ((-18, 39, GREEN_HI), (-15, 36, PURP_HI), (-21, 37, PURP_MID), (-17, 41, WHITE_SPEC)):
            im.putpixel((cx + sx, sy + by), col)
    else:
        # Relaxed baddie pose holding slender arcane wand tilted toward cauldron
        d.polygon(
            [(cx - 9, 47 + by), (cx - 15, 52 + by), (cx - 12, 56 + by), (cx - 8, 52 + by)],
            fill=DRESS_DARK,
            outline=OUTLINE,
        )
        im.putpixel((cx - 13, 55 + by), SKIN_BASE)
        d.line([(cx - 14, 55 + by), (cx - 22, 47 + by)], fill=GOLD_DARK, width=1)
        im.putpixel((cx - 23, 46 + by), GREEN_HI if frame_idx == 0 else PURP_HI)

    # 5. Cute / Baddie Head & Face (house 96x96 style with winged liner, sultry eyes, beauty mark!)
    # Neck + velvet choker
    d.rectangle([cx - 3, 41 + by, cx + 3, 45 + by], fill=SKIN_SHAD, outline=OUTLINE)
    d.line([(cx - 3, 43 + by), (cx + 3, 43 + by)], fill=OUTLINE)
    im.putpixel((cx, 43 + by), GOLD_HI)

    # Pointed cute ears + gold hoop earrings
    d.polygon([(cx - 11, 33 + by), (cx - 16, 31 + by), (cx - 11, 37 + by)], fill=SKIN_BASE, outline=OUTLINE)
    d.polygon([(cx + 11, 33 + by), (cx + 16, 31 + by), (cx + 11, 37 + by)], fill=SKIN_BASE, outline=OUTLINE)
    im.putpixel((cx - 13, 37 + by), GOLD_HI)
    im.putpixel((cx + 13, 37 + by), GOLD_HI)

    # Rounded face
    d.rounded_rectangle([cx - 11, 24 + by, cx + 11, 42 + by], radius=4, fill=SKIN_BASE, outline=OUTLINE)
    d.line([(cx - 8, 26 + by), (cx + 6, 26 + by)], fill=SKIN_HI)

    # Sultry baddie eyes (heavy winged dark lashes + glowing violet irises!)
    # Left eye
    if frame_idx == 1:
        # Playful wink on left eye!
        d.line([(cx - 8, 34 + by), (cx - 3, 34 + by)], fill=OUTLINE)
        im.putpixel((cx - 9, 33 + by), OUTLINE)
    else:
        d.rectangle([cx - 7, 32 + by, cx - 4, 36 + by], fill=EYE_VIOLET)
        d.line([(cx - 9, 31 + by), (cx - 3, 32 + by)], fill=OUTLINE)  # winged liner + half-lid!
        im.putpixel((cx - 8, 32 + by), OUTLINE)
        im.putpixel((cx - 6, 33 + by), WHITE_SPEC)
        im.putpixel((cx - 5, 35 + by), EYE_GLOW)

    # Right eye
    d.rectangle([cx + 4, 32 + by, cx + 7, 36 + by], fill=EYE_VIOLET)
    d.line([(cx + 3, 32 + by), (cx + 9, 31 + by)], fill=OUTLINE)  # winged liner!
    im.putpixel((cx + 8, 32 + by), OUTLINE)
    im.putpixel((cx + 5, 33 + by), WHITE_SPEC)
    im.putpixel((cx + 6, 35 + by), EYE_GLOW)

    # Rosy blush + signature beauty mark + glossy berry smirk!
    im.putpixel((cx - 8, 37 + by), BLUSH)
    im.putpixel((cx - 7, 37 + by), BLUSH)
    im.putpixel((cx + 7, 37 + by), BLUSH)
    im.putpixel((cx + 8, 37 + by), BLUSH)
    im.putpixel((cx + 6, 38 + by), OUTLINE)  # beauty mark!

    # Glossy berry lips (smirk)
    d.line([(cx - 2, 39 + by), (cx + 2, 39 + by)], fill=LIP_BERRY)
    im.putpixel((cx + 3, 38 + by), LIP_BERRY)

    # Side-swept bangs framing face
    d.polygon([(cx - 11, 24 + by), (cx + 11, 24 + by), (cx + 12, 30 + by), (cx + 3, 28 + by), (cx - 2, 31 + by), (cx - 12, 30 + by)], fill=HAIR_MID, outline=OUTLINE)
    d.line([(cx - 7, 26 + by), (cx + 5, 26 + by)], fill=HAIR_HI)
    # Cheek framing locks
    d.polygon([(cx - 12, 29 + by), (cx - 9, 29 + by), (cx - 10, 44 + by), (cx - 13, 42 + by)], fill=HAIR_MID, outline=OUTLINE)
    d.polygon([(cx + 9, 29 + by), (cx + 12, 29 + by), (cx + 13, 42 + by), (cx + 10, 44 + by)], fill=HAIR_MID, outline=OUTLINE)

    # 6. Wide-Brimmed Crooked Witch Hat with Gold Buckle!
    # Hat cone (tilted tip to the right!)
    d.polygon(
        [
            (cx - 11, 22 + by),
            (cx - 4, 10 + by),
            (cx + 8, 5 + by),
            (cx + 15, 9 + by),
            (cx + 7, 12 + by),
            (cx + 11, 22 + by),
        ],
        fill=HAT_MID,
        outline=OUTLINE,
    )
    d.polygon([(cx - 7, 20 + by), (cx - 2, 12 + by), (cx + 4, 10 + by), (cx + 1, 20 + by)], fill=HAT_LIGHT)
    # Ribbon band + Gold buckle
    d.rectangle([cx - 11, 19 + by, cx + 11, 23 + by], fill=DRESS_TRIM, outline=OUTLINE)
    d.rectangle([cx - 3, 18 + by, cx + 3, 23 + by], fill=GOLD_HI, outline=OUTLINE)
    d.rectangle([cx - 1, 19 + by, cx + 1, 22 + by], fill=HAT_DARK)
    # Wide sweeping curved hat brim
    d.ellipse([cx - 22, 21 + by, cx + 22, 28 + by], fill=HAT_DARK, outline=OUTLINE)
    d.arc([cx - 21, 21 + by, cx + 21, 27 + by], 190, 350, fill=HAT_LIGHT)

    return im


def draw_cauldron_frame(frame_idx: int) -> Image.Image:
    """64x64 cauldron: frames 0..2 green bubbling -> frames 3..5 sudden purple flash & swirl!"""
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = 32

    # Warm glowing firewood & embers under cauldron
    ember_hi = (255, 214, 92, 255) if frame_idx % 2 == 0 else (255, 162, 64, 255)
    d.polygon([(cx - 14, 57), (cx + 14, 57), (cx + 10, 60), (cx - 10, 60)], fill=(78, 42, 26, 255), outline=OUTLINE)
    d.ellipse([cx - 9, 54, cx + 9, 59], fill=(232, 92, 36, 255))
    d.ellipse([cx - 5, 55, cx + 5, 58], fill=ember_hi)

    # Iron cauldron feet
    d.rectangle([cx - 13, 52, cx - 8, 58], fill=(34, 38, 52, 255), outline=OUTLINE)
    d.rectangle([cx + 8, 52, cx + 13, 58], fill=(34, 38, 52, 255), outline=OUTLINE)

    # Side iron ring handles
    d.ellipse([cx - 23, 33, cx - 15, 43], outline=OUTLINE, width=2)
    d.ellipse([cx + 15, 33, cx + 23, 43], outline=OUTLINE, width=2)

    # Main heavy iron pot belly
    d.ellipse([cx - 19, 24, cx + 19, 56], fill=(42, 46, 64, 255), outline=OUTLINE)
    d.chord([cx - 18, 34, cx + 18, 55], 0, 180, fill=(28, 30, 44, 255))
    # Specular iron shine on left belly
    d.arc([cx - 15, 29, cx - 3, 50], 120, 235, fill=(92, 102, 134, 255), width=2)

    # Wide iron rim
    d.ellipse([cx - 18, 21, cx + 18, 31], fill=(64, 70, 94, 255), outline=OUTLINE)

    # Brew liquid colors: 0..2 = emerald green, 3 = SUDDEN BRIGHT PURPLE FLASH, 4 = deep purple swirl, 5 = purple->green
    is_purple = frame_idx in (3, 4, 5)
    if frame_idx in (0, 1, 2):
        c0, c1, c2 = GREEN_DEEP, GREEN_MID, GREEN_HI
    elif frame_idx == 3:
        # Sudden dramatic flash into electric violet!
        c0, c1, c2 = PURP_MID, PURP_HI, WHITE_SPEC
    elif frame_idx == 4:
        c0, c1, c2 = PURP_DEEP, PURP_MID, PURP_HI
    else:
        c0, c1, c2 = PURP_DEEP, (112, 148, 212, 255), GREEN_HI

    # Glowing brew surface inside rim
    d.ellipse([cx - 15, 23, cx + 15, 29], fill=c0, outline=OUTLINE)
    d.ellipse([cx - 12, 24, cx + 12, 28], fill=c1)
    d.ellipse([cx - 6 + (frame_idx % 3) - 1, 25, cx + 4 + (frame_idx % 3) - 1, 27], fill=c2)

    # Drip over front lip of cauldron!
    drip_col = PURP_MID if is_purple else GREEN_MID
    d.polygon([(cx - 6, 29), (cx - 3, 29), (cx - 4, 35), (cx - 6, 33)], fill=drip_col)

    # Animated rising bubbles & sudden purple burst sparks!
    bubble_sets = [
        [(-7, 21, 2), (4, 18, 2), (-2, 13, 1)],
        [(-5, 18, 2), (6, 21, 2), (1, 11, 2)],
        [(-8, 16, 1), (2, 19, 3), (-3, 9, 1)],
        # Frame 3: SUDDEN PURPLE ERUPTION!
        [(-9, 17, 3), (0, 14, 4), (8, 18, 3), (-4, 8, 2), (5, 9, 2)],
        [(-6, 14, 3), (4, 12, 3), (-1, 6, 2), (9, 15, 1)],
        [(-4, 16, 2), (3, 10, 2), (-7, 11, 1)],
    ]
    for bx, by_pos, rad in bubble_sets[frame_idx]:
        d.ellipse([cx + bx - rad, by_pos - rad, cx + bx + rad, by_pos + rad], fill=c1, outline=OUTLINE)
        if rad >= 2:
            im.putpixel((cx + bx - 1, by_pos - 1), c2)

    if frame_idx in (3, 4):
        # Extra magical purple rune sparks when brew turns purple!
        for sx, sy in ((-13, 12), (13, 11), (0, 4), (-10, 20), (12, 19)):
            if 0 <= cx + sx < 64 and 0 <= sy < 64:
                im.putpixel((cx + sx, sy), WHITE_SPEC if frame_idx == 3 else PURP_HI)

    return im


def make_cottage_floor() -> Image.Image:
    """64x64 seamless tileable warm aged-oak cottage planks."""
    im = Image.new("RGBA", (64, 64), (58, 38, 26, 255))
    d = ImageDraw.Draw(im)
    plank_h = 16
    tones = [
        (64, 42, 29, 255),
        (56, 36, 24, 255),
        (68, 45, 31, 255),
        (60, 39, 27, 255),
    ]
    joints = [18, 46, 10, 38]

    for row in range(4):
        y0 = row * plank_h
        d.rectangle([0, y0, 63, y0 + plank_h - 1], fill=tones[row])
        # Top warm bevel & bottom dark seam
        d.line([(0, y0), (63, y0)], fill=(78, 52, 36, 255))
        d.line([(0, y0 + plank_h - 1), (63, y0 + plank_h - 1)], fill=(36, 22, 15, 255))
        # Subtle woodgrain streaks
        gy = y0 + 6
        d.line([(4, gy), (26, gy)], fill=(50, 32, 21, 255))
        d.line([(34, gy + 4), (58, gy + 4)], fill=(74, 49, 34, 255))
        # Vertical plank joint + iron nail heads
        jx = joints[row]
        d.line([(jx, y0), (jx, y0 + plank_h - 1)], fill=(36, 22, 15, 255))
        for ny in (y0 + 3, y0 + plank_h - 4):
            im.putpixel(((jx - 3) % 64, ny), (30, 19, 13, 255))
            im.putpixel(((jx + 3) % 64, ny), (30, 19, 13, 255))

    return im


def main() -> None:
    TEX_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Witch sprite strip (384x96)
    witch_strip = Image.new("RGBA", (96 * 4, 96), (0, 0, 0, 0))
    for i in range(4):
        witch_strip.alpha_composite(draw_witch_frame(i), (i * 96, 0))
    witch_path = TEX_DIR / "lobby_witch.png"
    witch_strip.save(witch_path)
    write_godot_import(witch_path, "uid://bw7tchc0ttag1")

    # 2. Cauldron sprite strip (384x64)
    cauldron_strip = Image.new("RGBA", (64 * 6, 64), (0, 0, 0, 0))
    for i in range(6):
        cauldron_strip.alpha_composite(draw_cauldron_frame(i), (i * 64, 0))
    cauldron_path = TEX_DIR / "lobby_cauldron.png"
    cauldron_strip.save(cauldron_path)
    write_godot_import(cauldron_path, "uid://bca8dr0nc0tt2")

    # 3. Potion bottle strip (64x32)
    potion_strip = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    v0 = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw_potion_bottle(v0, 16, 16, purple=False, small=False)
    v1 = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw_potion_bottle(v1, 16, 16, purple=True, small=False)
    potion_strip.alpha_composite(v0, (0, 0))
    potion_strip.alpha_composite(v1, (32, 0))
    potion_path = TEX_DIR / "witch_potion.png"
    potion_strip.save(potion_path)
    write_godot_import(potion_path, "uid://bw7tchp0t70n3")

    # 4. Cottage floor tile (64x64)
    floor_im = make_cottage_floor()
    floor_path = TEX_DIR / "cottage_floor.png"
    floor_im.save(floor_path)
    write_godot_import(floor_path, "uid://bc0ttag3f8r04")

    print("Generated Witch's Cottage pixel-art assets:")
    for p in (witch_path, cauldron_path, potion_path, floor_path):
        im = Image.open(p)
        print(f"  - {p.relative_to(REPO_ROOT)}: {im.size}")


if __name__ == "__main__":
    main()
