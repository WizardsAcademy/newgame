#!/usr/bin/env python3
"""Generate crisp 64x64 / small pixel-art assets for the Witch's Cottage + Outdoor Yard:
  - assets/textures/lobby_witch.png          (256x64 = 4 frames of 64x64: idle, wink, magic, potion_offer)
  - assets/textures/lobby_cauldron.png       (288x48 = 6 frames of 48x48: 3 green bubbling -> 3 sudden purple flash!)
  - assets/textures/witch_potion.png         ( 64x32 = 2 frames of 32x32: emerald & amethyst potion vials)
  - assets/textures/lobby_door.png           (128x64 = 2 frames of 64x64: 0=Stages oak door, 1=Sandbox wooden fence gate)
  - assets/textures/lobby_wardrobe.png       (128x64 = 2 frames of 64x64: compact corner oak hero wardrobe)
  - assets/textures/lobby_fireplace_sofa.png (192x64 = 3 frames of 64x64: stone hearth fire A/B + plush cottage sofa)
  - assets/textures/cottage_floor.png        ( 32x32 moody aged dark-oak plank tile)
  - assets/textures/cottage_rugs.png         (128x64 = 2 frames of 64x64: spawn medallion rug + witch corner rug)
  - assets/textures/cottage_grass.png        ( 64x64 moody nocturnal woodland grass tile for outdoor yard)
  - assets/textures/cottage_trees.png        (128x96 = 2x 64x96 pixel-art dark pine & ancient oak trees)
  - assets/textures/cottage_fence_gate.png   (128x48 = 2x 64x48: 0=wooden fence gate for Sandbox, 1=wooden rail fence)
  - assets/textures/training_dummy.png       (256x64 = 4x 64x64 upgraded detailed medieval quintain training dummy)
"""

from __future__ import annotations

import hashlib
from pathlib import Path
from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
TEX_DIR = REPO_ROOT / "assets" / "textures"

OUTLINE = (20, 14, 28, 255)

HAT_DARK = (30, 18, 46, 255)
HAT_MID = (52, 32, 80, 255)
HAT_LIGHT = (82, 52, 122, 255)
HAT_SPEC = (116, 78, 164, 255)

HAIR_DARK = (36, 20, 54, 255)
HAIR_MID = (64, 36, 94, 255)
HAIR_HI = (102, 60, 146, 255)

SKIN_SHAD = (220, 168, 160, 255)
SKIN_BASE = (248, 208, 198, 255)
SKIN_HI = (255, 230, 224, 255)
BLUSH = (240, 136, 160, 255)
LIP_BERRY = (186, 40, 90, 255)
EYE_VIOLET = (196, 68, 255, 255)
EYE_GLOW = (244, 148, 255, 255)
WHITE_SPEC = (252, 248, 255, 255)

DRESS_DARK = (26, 16, 40, 255)
DRESS_MID = (48, 28, 70, 255)
DRESS_TRIM = (146, 52, 196, 255)
GOLD_DARK = (158, 108, 34, 255)
GOLD_HI = (244, 200, 84, 255)

GREEN_DEEP = (18, 104, 54, 255)
GREEN_MID = (44, 202, 110, 255)
GREEN_HI = (144, 255, 184, 255)

PURP_DEEP = (86, 22, 154, 255)
PURP_MID = (166, 54, 255, 255)
PURP_HI = (238, 148, 255, 255)

WOOD_DEEP = (38, 24, 18, 255)
WOOD_DARK = (58, 36, 25, 255)
WOOD_MID = (86, 53, 35, 255)
WOOD_LIT = (116, 74, 48, 255)
WOOD_HI = (146, 96, 62, 255)

STONE_DARK = (40, 36, 48, 255)
STONE_MID = (62, 56, 74, 255)
STONE_LIT = (88, 82, 104, 255)

IRON_DARK = (36, 40, 52, 255)
IRON_MID = (66, 74, 92, 255)
IRON_HI = (114, 126, 152, 255)


def put(im: Image.Image, x: int, y: int, col: tuple[int, int, int, int]) -> None:
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), col)


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
    imp_path = png_path.with_name(png_path.name + ".import")
    if not imp_path.exists():
        imp_path.write_text(content, encoding="utf-8")


def draw_potion_bottle(
    im: Image.Image, cx: int, cy: int, purple: bool, tiny: bool = False
) -> None:
    d = ImageDraw.Draw(im)
    c_deep = PURP_DEEP if purple else GREEN_DEEP
    c_mid = PURP_MID if purple else GREEN_MID
    c_hi = PURP_HI if purple else GREEN_HI

    if tiny:
        d.rectangle([cx - 1, cy - 5, cx + 1, cy - 3], fill=(176, 128, 76, 255), outline=OUTLINE)
        d.ellipse([cx - 4, cy - 3, cx + 4, cy + 5], fill=c_mid, outline=OUTLINE)
        d.line([(cx - 3, cy - 1), (cx + 3, cy - 1)], fill=c_hi)
        d.line([(cx - 2, cy + 3), (cx + 2, cy + 3)], fill=c_deep)
        put(im, cx - 2, cy, WHITE_SPEC)
    else:
        d.rectangle([cx - 3, cy - 11, cx + 3, cy - 7], fill=(182, 132, 78, 255), outline=OUTLINE)
        d.rectangle([cx - 4, cy - 7, cx + 4, cy - 4], fill=(196, 224, 244, 255), outline=OUTLINE)
        d.ellipse([cx - 9, cy - 5, cx + 9, cy + 11], fill=(174, 206, 232, 255), outline=OUTLINE)
        d.pieslice([cx - 8, cy - 3, cx + 8, cy + 10], start=0, end=180, fill=c_mid)
        d.ellipse([cx - 7, cy + 1, cx + 7, cy + 5], fill=c_hi)
        d.arc([cx - 8, cy - 3, cx + 8, cy + 10], start=20, end=160, fill=c_deep, width=2)
        d.line([(cx - 5, cy - 2), (cx - 4, cy + 4)], fill=WHITE_SPEC, width=1)


def draw_witch_64(frame_idx: int) -> Image.Image:
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = 32
    by = -1 if frame_idx in (1, 2) else 0

    d.polygon(
        [
            (cx - 9, 18 + by),
            (cx + 9, 18 + by),
            (cx + 12, 41 + by),
            (cx + 8, 44 + by),
            (cx - 8, 44 + by),
            (cx - 12, 41 + by),
        ],
        fill=HAIR_DARK,
        outline=OUTLINE,
    )
    d.polygon(
        [(cx - 8, 20 + by), (cx + 8, 20 + by), (cx + 10, 40 + by), (cx - 10, 40 + by)],
        fill=HAIR_MID,
    )
    d.line([(cx - 8, 23 + by), (cx - 9, 36 + by)], fill=HAIR_HI)
    d.line([(cx + 8, 23 + by), (cx + 9, 36 + by)], fill=HAIR_HI)

    d.rectangle([cx - 5, 42, cx - 2, 48], fill=SKIN_BASE, outline=OUTLINE)
    put(im, cx - 4, 44, SKIN_HI)
    d.rectangle([cx + 2, 43, cx + 5, 48], fill=DRESS_DARK, outline=OUTLINE)
    d.rectangle([cx - 6, 48, cx - 2, 52], fill=HAT_DARK, outline=OUTLINE)
    d.rectangle([cx + 2, 48, cx + 6, 52], fill=HAT_DARK, outline=OUTLINE)
    put(im, cx - 4, 49, GOLD_HI)
    put(im, cx + 4, 49, GOLD_HI)

    d.polygon(
        [
            (cx - 6, 30 + by),
            (cx + 6, 30 + by),
            (cx + 5, 36 + by),
            (cx + 9, 47),
            (cx + 1, 47),
            (cx - 1, 40 + by),
            (cx - 5, 46),
            (cx - 8, 45),
            (cx - 5, 36 + by),
        ],
        fill=DRESS_MID,
        outline=OUTLINE,
    )
    d.polygon(
        [(cx + 2, 36 + by), (cx + 5, 36 + by), (cx + 8, 46), (cx + 2, 46)],
        fill=DRESS_DARK,
    )
    d.line([(cx + 1, 46), (cx + 8, 46)], fill=DRESS_TRIM)
    d.line([(cx - 7, 45), (cx - 5, 45)], fill=DRESS_TRIM)
    d.rectangle([cx - 6, 29 + by, cx + 6, 31 + by], fill=SKIN_BASE, outline=OUTLINE)
    put(im, cx, 31 + by, SKIN_SHAD)
    d.line([(cx - 5, 32 + by), (cx + 5, 32 + by)], fill=DRESS_TRIM)
    d.line([(cx - 4, 36 + by), (cx + 4, 36 + by)], fill=GOLD_HI)
    put(im, cx, 37 + by, GOLD_DARK)

    d.line([(cx + 6, 31 + by), (cx + 9, 34 + by), (cx + 6, 37 + by)], fill=DRESS_DARK, width=2)
    put(im, cx + 6, 37 + by, SKIN_BASE)

    if frame_idx == 3:
        d.line([(cx - 6, 31 + by), (cx - 13, 33 + by)], fill=DRESS_DARK, width=2)
        d.rectangle([cx - 15, 32 + by, cx - 13, 34 + by], fill=SKIN_BASE)
        draw_potion_bottle(im, cx - 17, 29 + by, purple=True, tiny=True)
        for sx, sy, col in ((-22, 25, GREEN_HI), (-13, 22, PURP_HI), (-21, 33, WHITE_SPEC)):
            put(im, cx + sx, sy + by, col)
    elif frame_idx == 2:
        d.line([(cx - 6, 31 + by), (cx - 12, 29 + by)], fill=DRESS_DARK, width=2)
        put(im, cx - 13, 29 + by, SKIN_BASE)
        for sx, sy, col in ((-13, 24, GREEN_HI), (-10, 22, PURP_HI), (-16, 26, PURP_MID), (-14, 27, WHITE_SPEC)):
            put(im, cx + sx, sy + by, col)
    else:
        d.line([(cx - 6, 31 + by), (cx - 10, 35 + by)], fill=DRESS_DARK, width=2)
        put(im, cx - 10, 36 + by, SKIN_BASE)
        d.line([(cx - 11, 36 + by), (cx - 16, 31 + by)], fill=GOLD_DARK)
        put(im, cx - 17, 30 + by, GREEN_HI if frame_idx == 0 else PURP_HI)

    d.rectangle([cx - 2, 27 + by, cx + 2, 29 + by], fill=SKIN_SHAD)
    d.line([(cx - 2, 28 + by), (cx + 2, 28 + by)], fill=OUTLINE)
    put(im, cx, 28 + by, GOLD_HI)

    d.polygon([(cx - 8, 21 + by), (cx - 11, 20 + by), (cx - 8, 24 + by)], fill=SKIN_BASE, outline=OUTLINE)
    d.polygon([(cx + 8, 21 + by), (cx + 11, 20 + by), (cx + 8, 24 + by)], fill=SKIN_BASE, outline=OUTLINE)
    put(im, cx - 10, 24 + by, GOLD_HI)
    put(im, cx + 10, 24 + by, GOLD_HI)

    d.rounded_rectangle([cx - 8, 15 + by, cx + 8, 27 + by], radius=3, fill=SKIN_BASE, outline=OUTLINE)
    d.line([(cx - 5, 16 + by), (cx + 5, 16 + by)], fill=SKIN_HI)

    if frame_idx == 1:
        d.line([(cx - 6, 22 + by), (cx - 2, 22 + by)], fill=OUTLINE)
        put(im, cx - 7, 21 + by, OUTLINE)
    else:
        d.rectangle([cx - 5, 20 + by, cx - 3, 23 + by], fill=EYE_VIOLET)
        d.line([(cx - 6, 20 + by), (cx - 2, 20 + by)], fill=OUTLINE)
        put(im, cx - 7, 19 + by, OUTLINE)
        put(im, cx - 5, 21 + by, WHITE_SPEC)
        put(im, cx - 3, 23 + by, EYE_GLOW)

    d.rectangle([cx + 3, 20 + by, cx + 5, 23 + by], fill=EYE_VIOLET)
    d.line([(cx + 2, 20 + by), (cx + 6, 20 + by)], fill=OUTLINE)
    put(im, cx + 7, 19 + by, OUTLINE)
    put(im, cx + 3, 21 + by, WHITE_SPEC)
    put(im, cx + 5, 23 + by, EYE_GLOW)

    put(im, cx - 6, 24 + by, BLUSH)
    put(im, cx + 6, 24 + by, BLUSH)
    put(im, cx + 5, 25 + by, OUTLINE)
    d.line([(cx - 2, 25 + by), (cx + 1, 25 + by)], fill=LIP_BERRY)
    put(im, cx + 2, 24 + by, LIP_BERRY)

    d.polygon([(cx - 8, 15 + by), (cx - 6, 15 + by), (cx - 7, 25 + by), (cx - 9, 24 + by)], fill=HAIR_MID, outline=OUTLINE)
    d.polygon([(cx + 6, 15 + by), (cx + 8, 15 + by), (cx + 9, 24 + by), (cx + 7, 25 + by)], fill=HAIR_MID, outline=OUTLINE)
    d.polygon([(cx - 7, 15 + by), (cx + 7, 15 + by), (cx + 2, 18 + by), (cx - 4, 18 + by)], fill=HAIR_DARK)

    d.polygon(
        [
            (cx - 8, 14 + by),
            (cx - 3, 5 + by),
            (cx + 6, 3 + by),
            (cx + 10, 6 + by),
            (cx + 5, 8 + by),
            (cx + 8, 14 + by),
        ],
        fill=HAT_MID,
        outline=OUTLINE,
    )
    d.polygon([(cx - 5, 13 + by), (cx - 2, 6 + by), (cx + 2, 6 + by), (cx - 1, 13 + by)], fill=HAT_LIGHT)
    put(im, cx - 1, 7 + by, HAT_SPEC)
    d.rectangle([cx - 7, 12 + by, cx + 7, 14 + by], fill=DRESS_TRIM, outline=OUTLINE)
    d.rectangle([cx - 2, 11 + by, cx + 2, 14 + by], fill=GOLD_HI, outline=OUTLINE)
    put(im, cx, 13 + by, HAT_DARK)
    d.ellipse([cx - 16, 13 + by, cx + 16, 18 + by], fill=HAT_DARK, outline=OUTLINE)
    d.arc([cx - 15, 13 + by, cx + 15, 17 + by], start=195, end=345, fill=HAT_LIGHT, width=1)

    return im


def draw_cauldron_48(frame_idx: int) -> Image.Image:
    im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = 24
    is_purple = frame_idx >= 3

    ember_hi = (255, 184, 72, 255) if frame_idx % 2 == 0 else (255, 126, 44, 255)
    d.ellipse([cx - 8, 40, cx + 8, 44], fill=(168, 46, 26, 255), outline=OUTLINE)
    d.ellipse([cx - 5, 41, cx + 5, 43], fill=ember_hi)

    d.rectangle([cx - 11, 38, cx - 7, 44], fill=IRON_DARK, outline=OUTLINE)
    d.rectangle([cx + 7, 38, cx + 11, 44], fill=IRON_DARK, outline=OUTLINE)
    d.ellipse([cx - 18, 22, cx - 12, 30], fill=IRON_MID, outline=OUTLINE)
    d.ellipse([cx + 12, 22, cx + 18, 30], fill=IRON_MID, outline=OUTLINE)

    d.ellipse([cx - 15, 16, cx + 15, 42], fill=IRON_DARK, outline=OUTLINE)
    d.ellipse([cx - 12, 19, cx + 11, 39], fill=IRON_MID)
    d.arc([cx - 11, 21, cx + 4, 36], start=120, end=235, fill=IRON_HI, width=2)

    d.ellipse([cx - 14, 12, cx + 14, 21], fill=IRON_MID, outline=OUTLINE)
    d.arc([cx - 13, 12, cx + 13, 20], start=190, end=350, fill=IRON_HI, width=1)

    c_deep = PURP_DEEP if is_purple else GREEN_DEEP
    c_mid = PURP_MID if is_purple else GREEN_MID
    c_hi = PURP_HI if is_purple else GREEN_HI

    d.ellipse([cx - 11, 14, cx + 11, 19], fill=c_deep)
    d.ellipse([cx - 9, 15, cx + 9, 18], fill=c_mid)
    if frame_idx == 3:
        d.ellipse([cx - 6, 15, cx + 6, 18], fill=WHITE_SPEC)
    else:
        d.ellipse([cx - 5, 15, cx + 4, 17], fill=c_hi)

    drip_h = 22 + (frame_idx % 3)
    d.polygon([(cx - 6, 18), (cx - 3, 18), (cx - 4, drip_h), (cx - 6, drip_h - 1)], fill=c_mid)

    bubbles = {
        0: [(-5, 12, 2), (3, 10, 2), (0, 6, 1)],
        1: [(-4, 9, 2), (4, 12, 2), (-1, 4, 1)],
        2: [(-6, 6, 1), (2, 8, 2), (6, 11, 1)],
        3: [(-6, 10, 3), (0, 7, 3), (6, 10, 2), (-2, 3, 1)],
        4: [(-5, 7, 2), (2, 4, 2), (6, 8, 2), (-8, 5, 1)],
        5: [(-3, 5, 2), (4, 6, 2), (0, 10, 2)],
    }[frame_idx]
    for bx, by, r in bubbles:
        if r <= 1:
            put(im, cx + bx, by, WHITE_SPEC if frame_idx == 3 else c_hi)
        else:
            d.ellipse([cx + bx - r, by - r, cx + bx + r, by + r], fill=c_hi, outline=OUTLINE)
            put(im, cx + bx - 1, by - 1, WHITE_SPEC)

    return im


def make_wooden_doors_sheet() -> Image.Image:
    """128x64 (2 frames of 64x64):
    Frame 0: North-Wall Arched Heavy Oak Cottage Door (`STAGES`)
    Frame 1: Rustic Wooden Picket/Ranch Fence Gate (`SANDBOX` — `shabih fence gate`)!
    """
    sheet = Image.new("RGBA", (128, 64), (0, 0, 0, 0))

    # --- Frame 0: North-Center Arched Oak Cottage Door ---
    f0 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d0 = ImageDraw.Draw(f0)
    d0.rounded_rectangle([12, 6, 52, 58], radius=14, fill=STONE_MID, outline=OUTLINE)
    d0.rounded_rectangle([15, 9, 49, 58], radius=12, fill=WOOD_DEEP, outline=OUTLINE)
    d0.rounded_rectangle([18, 12, 46, 56], radius=10, fill=WOOD_MID, outline=OUTLINE)
    for px in (24, 30, 36, 41):
        d0.line([(px, 14), (px, 55)], fill=WOOD_DARK, width=1)
        d0.line([(px + 1, 15), (px + 1, 54)], fill=WOOD_LIT, width=1)
    for hy in (24, 44):
        d0.rectangle([19, hy, 45, hy + 4], fill=WOOD_DARK, outline=OUTLINE)
        d0.rectangle([18, hy + 1, 28, hy + 3], fill=IRON_MID, outline=OUTLINE)
        put(f0, 21, hy + 2, IRON_HI)
        put(f0, 26, hy + 2, IRON_HI)
    d0.rectangle([28, 17, 36, 22], fill=WOOD_DEEP, outline=OUTLINE)
    d0.line([(32, 17), (32, 22)], fill=IRON_MID)
    d0.ellipse([39, 32, 44, 37], fill=GOLD_HI, outline=OUTLINE)
    put(f0, 41, 34, WOOD_DEEP)
    d0.rectangle([10, 55, 54, 60], fill=STONE_DARK, outline=OUTLINE)
    d0.line([(12, 56), (52, 56)], fill=STONE_LIT)
    sheet.alpha_composite(f0, (0, 0))

    # --- Frame 1: Rustic Wooden Fence Gate (`shabih fence gate` for SANDBOX!) ---
    f1 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d1 = ImageDraw.Draw(f1)
    # Dirt trail stones under the fence gate
    for sx, sy, sw, sh in ((18, 52, 9, 5), (30, 54, 10, 5), (41, 51, 8, 5), (24, 47, 8, 4)):
        d1.ellipse([sx, sy, sx + sw, sy + sh], fill=STONE_DARK, outline=OUTLINE)
    # Left & Right heavy square oak fence posts with pointed caps
    for px in (8, 50):
        d1.polygon([(px, 18), (px + 3, 14), (px + 6, 18)], fill=WOOD_HI, outline=OUTLINE)
        d1.rectangle([px, 18, px + 6, 54], fill=WOOD_DARK, outline=OUTLINE)
        d1.line([(px + 1, 19), (px + 1, 53)], fill=WOOD_LIT)
    # Horizontal top & bottom gate rails behind pickets
    d1.rectangle([14, 26, 50, 30], fill=WOOD_DARK, outline=OUTLINE)
    d1.rectangle([14, 42, 50, 46], fill=WOOD_DARK, outline=OUTLINE)
    # 5 vertical pointed wooden pickets with gaps showing outdoor grass through them!
    for gx in (16, 23, 30, 37, 44):
        d1.polygon([(gx, 22), (gx + 2, 19), (gx + 4, 22)], fill=WOOD_HI, outline=OUTLINE)
        d1.rectangle([gx, 22, gx + 4, 50], fill=WOOD_MID, outline=OUTLINE)
        d1.line([(gx + 1, 23), (gx + 1, 49)], fill=WOOD_LIT)
    # Diagonal wooden Z-brace across the fence gate + wrought-iron hinges & latch!
    d1.polygon([(16, 45), (20, 45), (46, 27), (42, 27)], fill=WOOD_LIT, outline=OUTLINE)
    for hy in (26, 42):
        d1.rectangle([13, hy + 1, 19, hy + 3], fill=IRON_MID, outline=OUTLINE)
        put(f1, 15, hy + 2, IRON_HI)
    d1.rectangle([45, 34, 51, 37], fill=IRON_HI, outline=OUTLINE)
    put(f1, 47, 35, GOLD_HI)
    sheet.alpha_composite(f1, (64, 0))

    return sheet


def make_fence_rail_sheet() -> Image.Image:
    """128x48 (2x 64x48):
    Frame 0: Horizontal rustic wooden rail-and-picket fence section
    Frame 1: Hanging wooden lantern post beside the fence gate!
    """
    sheet = Image.new("RGBA", (128, 48), (0, 0, 0, 0))
    # Frame 0: Fence section
    f0 = Image.new("RGBA", (64, 48), (0, 0, 0, 0))
    d0 = ImageDraw.Draw(f0)
    d0.rectangle([0, 20, 63, 24], fill=WOOD_DARK, outline=OUTLINE)
    d0.rectangle([0, 34, 63, 38], fill=WOOD_DARK, outline=OUTLINE)
    for px in (2, 18, 34, 50):
        d0.polygon([(px, 14), (px + 3, 10), (px + 6, 14)], fill=WOOD_HI, outline=OUTLINE)
        d0.rectangle([px, 14, px + 6, 43], fill=WOOD_MID, outline=OUTLINE)
        d0.line([(px + 1, 15), (px + 1, 42)], fill=WOOD_LIT)
    sheet.alpha_composite(f0, (0, 0))

    # Frame 1: Cozy wooden signpost / lantern post (no circular glow!)
    f1 = Image.new("RGBA", (64, 48), (0, 0, 0, 0))
    d1 = ImageDraw.Draw(f1)
    d1.rectangle([28, 8, 33, 44], fill=WOOD_DARK, outline=OUTLINE)
    d1.line([(29, 9), (29, 43)], fill=WOOD_LIT)
    d1.rectangle([28, 10, 44, 14], fill=WOOD_MID, outline=OUTLINE)
    d1.rectangle([39, 14, 45, 23], fill=IRON_DARK, outline=OUTLINE)
    d1.rectangle([40, 16, 44, 21], fill=(255, 196, 84, 255))
    put(f1, 42, 18, WHITE_SPEC)
    sheet.alpha_composite(f1, (64, 0))
    return sheet


def make_wardrobe_64_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    for i, opened in enumerate((False, True)):
        fr = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(fr)
        d.polygon([(10, 11), (32, 4), (54, 11)], fill=WOOD_LIT, outline=OUTLINE)
        d.rounded_rectangle([12, 10, 52, 56], radius=2, fill=WOOD_DARK, outline=OUTLINE)
        d.ellipse([29, 6, 35, 11], fill=GOLD_HI, outline=OUTLINE)
        d.rectangle([14, 55, 19, 59], fill=WOOD_DEEP, outline=OUTLINE)
        d.rectangle([45, 55, 50, 59], fill=WOOD_DEEP, outline=OUTLINE)

        if opened:
            d.rectangle([16, 14, 48, 52], fill=(24, 18, 32, 255), outline=OUTLINE)
            d.polygon([(18, 18), (25, 18), (26, 48), (17, 48)], fill=(168, 28, 56, 255), outline=OUTLINE)
            d.polygon([(27, 18), (36, 18), (37, 45), (27, 45)], fill=IRON_HI, outline=OUTLINE)
            d.polygon([(38, 18), (45, 18), (46, 48), (37, 48)], fill=(48, 152, 96, 255), outline=OUTLINE)
            d.polygon([(12, 12), (5, 16), (5, 54), (15, 52)], fill=WOOD_MID, outline=OUTLINE)
            d.polygon([(52, 12), (59, 16), (59, 54), (49, 52)], fill=WOOD_MID, outline=OUTLINE)
        else:
            d.rectangle([15, 14, 31, 52], fill=WOOD_MID, outline=OUTLINE)
            d.rectangle([33, 14, 49, 52], fill=WOOD_MID, outline=OUTLINE)
            d.rectangle([18, 18, 28, 32], fill=WOOD_DARK, outline=OUTLINE)
            d.rectangle([36, 18, 46, 32], fill=WOOD_DARK, outline=OUTLINE)
            d.rectangle([18, 35, 28, 49], fill=WOOD_DARK, outline=OUTLINE)
            d.rectangle([36, 35, 46, 49], fill=WOOD_DARK, outline=OUTLINE)
            put(fr, 29, 33, GOLD_HI)
            put(fr, 35, 33, GOLD_HI)
        sheet.alpha_composite(fr, (i * 64, 0))
    return sheet


def make_fireplace_and_sofa_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (192, 64), (0, 0, 0, 0))
    for fi in range(2):
        fr = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(fr)
        d.rectangle([14, 4, 50, 18], fill=STONE_DARK, outline=OUTLINE)
        d.rounded_rectangle([8, 16, 56, 54], radius=3, fill=STONE_MID, outline=OUTLINE)
        for sx, sy, sw, sh in ((11, 20, 10, 6), (24, 19, 12, 6), (40, 20, 11, 6), (10, 30, 8, 8), (46, 30, 8, 8)):
            d.rectangle([sx, sy, sx + sw, sy + sh], fill=STONE_LIT, outline=OUTLINE)
        d.rectangle([6, 14, 58, 19], fill=WOOD_MID, outline=OUTLINE)
        d.line([(8, 15), (56, 15)], fill=WOOD_HI)
        d.rectangle([46, 8, 49, 14], fill=(238, 226, 202, 255), outline=OUTLINE)
        put(fr, 47, 6 + fi, (255, 204, 88, 255))
        d.rounded_rectangle([18, 26, 46, 52], radius=8, fill=(22, 14, 22, 255), outline=OUTLINE)
        d.line([(22, 49), (42, 45)], fill=WOOD_MID, width=3)
        d.line([(22, 45), (42, 49)], fill=WOOD_DARK, width=3)
        f_outer = (232, 82, 32, 255)
        f_mid = (255, 154, 44, 255)
        f_core = (255, 232, 118, 255)
        shift = -2 if fi == 0 else 2
        d.polygon([(23, 46), (28, 33 + (fi * 2)), (32 + shift, 28), (37, 34 - fi), (41, 46)], fill=f_outer)
        d.polygon([(26, 46), (30, 36), (32 - shift, 32), (36, 37), (38, 46)], fill=f_mid)
        d.polygon([(29, 46), (32, 38 + fi), (35, 46)], fill=f_core)
        put(fr, 29 - shift, 29, f_mid)
        put(fr, 35 + shift, 27, f_core)
        d.rectangle([6, 51, 58, 58], fill=STONE_DARK, outline=OUTLINE)
        d.line([(8, 52), (56, 52)], fill=STONE_LIT)
        sheet.alpha_composite(fr, (fi * 64, 0))

    sofa = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sofa)
    VEL_DARK = (74, 20, 44, 255)
    VEL_MID = (118, 32, 66, 255)
    VEL_HI = (158, 50, 88, 255)
    ds.rounded_rectangle([8, 16, 56, 48], radius=5, fill=WOOD_DARK, outline=OUTLINE)
    ds.rectangle([11, 47, 15, 53], fill=WOOD_DEEP, outline=OUTLINE)
    ds.rectangle([49, 47, 53, 53], fill=WOOD_DEEP, outline=OUTLINE)
    ds.rounded_rectangle([11, 19, 53, 37], radius=4, fill=VEL_MID, outline=OUTLINE)
    ds.line([(14, 21), (50, 21)], fill=VEL_HI)
    for tx in (22, 32, 42):
        put(sofa, tx, 26, VEL_DARK)
        put(sofa, tx, 27, GOLD_HI)
    ds.rounded_rectangle([12, 34, 32, 45], radius=3, fill=VEL_HI, outline=OUTLINE)
    ds.rounded_rectangle([32, 34, 52, 45], radius=3, fill=VEL_HI, outline=OUTLINE)
    ds.line([(14, 43), (50, 43)], fill=VEL_DARK)
    ds.rounded_rectangle([6, 28, 14, 47], radius=3, fill=VEL_DARK, outline=OUTLINE)
    ds.rounded_rectangle([50, 28, 58, 47], radius=3, fill=VEL_DARK, outline=OUTLINE)
    ds.rectangle([7, 30, 13, 33], fill=WOOD_LIT, outline=OUTLINE)
    ds.rectangle([51, 30, 57, 33], fill=WOOD_LIT, outline=OUTLINE)
    ds.polygon([(15, 31), (22, 29), (24, 37), (16, 38)], fill=HAT_LIGHT, outline=OUTLINE)
    put(sofa, 19, 33, GOLD_HI)
    sheet.alpha_composite(sofa, (128, 0))
    return sheet


def make_cottage_floor_32() -> Image.Image:
    im = Image.new("RGBA", (32, 32), (42, 27, 20, 255))
    d = ImageDraw.Draw(im)
    plank_tones = [
        (46, 30, 22, 255),
        (39, 25, 19, 255),
        (50, 33, 24, 255),
        (43, 28, 21, 255),
    ]
    for row in range(4):
        y0 = row * 8
        d.rectangle([0, y0, 31, y0 + 7], fill=plank_tones[row])
        d.line([(0, y0), (31, y0)], fill=(24, 15, 12, 255))
        d.line([(0, y0 + 1), (31, y0 + 1)], fill=(58, 39, 28, 255))
        seam_x = (row * 13 + 7) % 30
        d.line([(seam_x, y0), (seam_x, y0 + 7)], fill=(24, 15, 12, 255))
        for dy in (2, 5):
            put(im, (seam_x - 2) % 32, y0 + dy, (26, 17, 14, 255))
            put(im, (seam_x + 2) % 32, y0 + dy, (26, 17, 14, 255))
    return im


def make_cottage_rugs_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    r0 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d0 = ImageDraw.Draw(r0)
    d0.ellipse([8, 12, 56, 52], fill=(78, 18, 34, 255), outline=OUTLINE)
    d0.ellipse([12, 16, 52, 48], fill=(118, 26, 48, 255), outline=GOLD_DARK)
    d0.ellipse([20, 22, 44, 42], fill=(86, 20, 38, 255), outline=GOLD_HI)
    d0.polygon([(32, 25), (39, 32), (32, 39), (25, 32)], fill=(156, 36, 62, 255), outline=GOLD_HI)
    sheet.alpha_composite(r0, (0, 0))

    r1 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d1 = ImageDraw.Draw(r1)
    d1.pieslice([-42, -42, 58, 58], start=0, end=90, fill=(48, 22, 68, 255), outline=OUTLINE)
    d1.arc([-38, -38, 54, 54], start=4, end=86, fill=DRESS_TRIM, width=2)
    d1.arc([-32, -32, 48, 48], start=6, end=84, fill=GOLD_DARK, width=1)
    sheet.alpha_composite(r1, (64, 0))
    return sheet


def make_outdoor_grass_64() -> Image.Image:
    """64x64 seamless moody nocturnal woodland meadow turf (no polka-dot circles!)."""
    G_BASE = (21, 37, 28, 255)
    G_DEEP = (16, 29, 22, 255)
    G_SOFT = (25, 44, 33, 255)
    G_MID = (32, 58, 41, 255)
    G_LIT = (46, 80, 54, 255)
    im = Image.new("RGBA", (64, 64), G_BASE)

    # Organic pixel-dithered moss variation (tile-safe modulo 64!)
    for y in range(64):
        for x in range(64):
            h = ((x * 37 + y * 57) ^ ((x * 13) + (y * 29))) & 31
            if h < 4:
                put(im, x, y, G_DEEP)
            elif h < 9:
                put(im, x, y, G_SOFT)

    # Crisp pixel grass blade clusters & tiny clover patches
    tufts = [
        (7, 11), (22, 8), (41, 12), (56, 9),
        (13, 25), (31, 21), (49, 26), (3, 34),
        (20, 41), (37, 38), (54, 42),
        (9, 55), (27, 53), (45, 57), (60, 54),
    ]
    for tx, ty in tufts:
        put(im, tx % 64, ty % 64, G_DEEP)
        put(im, (tx - 1) % 64, (ty - 1) % 64, G_MID)
        put(im, tx % 64, (ty - 2) % 64, G_LIT)
        put(im, (tx + 1) % 64, (ty - 1) % 64, G_MID)
        put(im, (tx + 2) % 64, (ty - 2) % 64, G_LIT)

    # Tiny twilight wildflowers & mossy pebbles
    for fx, fy, col in (
        (17, 16, (128, 92, 174, 255)),
        (48, 33, (90, 148, 122, 255)),
        (33, 49, (116, 126, 102, 255)),
        (5, 48, (76, 124, 96, 255)),
    ):
        put(im, fx, fy, col)
    return im


def make_forest_trees_sheet() -> Image.Image:
    """128x96 (2x 64x96) lush pixel-art nocturnal forest trees (`ja divar derakht bezar`)!
    Tree 0 (0..64): Layered Dark-Forest Pine Conifer
    Tree 1 (64..128): Gnarled Ancient Mossy Witch-Wood Oak
    """
    sheet = Image.new("RGBA", (128, 96), (0, 0, 0, 0))
    LEAF_OUT = (12, 20, 22, 255)
    LEAF_DEEP = (18, 38, 34, 255)
    LEAF_MID = (28, 60, 48, 255)
    LEAF_LIT = (46, 92, 66, 255)
    LEAF_RIM = (74, 126, 90, 255)

    # --- Tree 0: Tall Layered Forest Pine ---
    t0 = Image.new("RGBA", (64, 96), (0, 0, 0, 0))
    d0 = ImageDraw.Draw(t0)
    # Ground root shadow
    d0.ellipse([14, 80, 50, 91], fill=(10, 14, 16, 150))
    # Bark trunk + roots
    d0.polygon([(26, 62), (38, 62), (42, 87), (35, 88), (32, 84), (29, 88), (22, 87)], fill=WOOD_DARK, outline=OUTLINE)
    d0.line([(29, 64), (28, 85)], fill=WOOD_LIT, width=2)
    # 4 tiered pine boughs (bottom to top)
    tiers = [
        (32, 34, 26, 68),
        (32, 22, 23, 54),
        (32, 12, 18, 40),
        (32, 4, 12, 26),
    ]
    for cx, top_y, half_w, bot_y in tiers:
        pts = [
            (cx, top_y),
            (cx + half_w, bot_y - 3),
            (cx + half_w - 6, bot_y),
            (cx, bot_y - 2),
            (cx - half_w + 6, bot_y),
            (cx - half_w, bot_y - 3),
        ]
        d0.polygon(pts, fill=LEAF_DEEP, outline=LEAF_OUT)
        inner = [
            (cx, top_y + 2),
            (cx + half_w - 4, bot_y - 5),
            (cx, bot_y - 5),
            (cx - half_w + 3, bot_y - 5),
        ]
        d0.polygon(inner, fill=LEAF_MID)
        # Top-left moonlit needle clusters
        d0.line([(cx - 1, top_y + 2), (cx - half_w + 5, bot_y - 6)], fill=LEAF_LIT, width=2)
        put(t0, cx - 2, top_y + 4, LEAF_RIM)
        put(t0, cx - half_w // 2, (top_y + bot_y) // 2, LEAF_RIM)
    sheet.alpha_composite(t0, (0, 0))

    # --- Tree 1: Ancient Gnarled Witch-Wood Oak ---
    t1 = Image.new("RGBA", (64, 96), (0, 0, 0, 0))
    d1 = ImageDraw.Draw(t1)
    d1.ellipse([12, 80, 52, 91], fill=(10, 14, 16, 150))
    # Twisted trunk + hollow knot
    d1.polygon([(24, 54), (40, 54), (44, 87), (36, 89), (32, 84), (27, 89), (20, 87)], fill=WOOD_DARK, outline=OUTLINE)
    d1.line([(27, 56), (25, 85)], fill=WOOD_MID, width=3)
    d1.ellipse([30, 67, 35, 74], fill=WOOD_DEEP, outline=OUTLINE)
    # Lush overlapping pixel foliage clumps
    blobs = [
        (18, 30, 44, 58, LEAF_DEEP),
        (24, 28, 54, 58, LEAF_DEEP),
        (10, 22, 38, 50, LEAF_MID),
        (26, 18, 54, 48, LEAF_DEEP),
        (16, 10, 48, 40, LEAF_MID),
        (20, 12, 40, 32, LEAF_LIT),
        (13, 24, 29, 40, LEAF_LIT),
    ]
    for x0, y0, x1, y1, col in blobs:
        d1.ellipse([x0, y0, x1, y1], fill=col, outline=LEAF_OUT if col == LEAF_DEEP else None)
    for rx, ry in ((22, 15), (26, 14), (16, 27), (33, 20), (41, 28)):
        put(t1, rx, ry, LEAF_RIM)
    sheet.alpha_composite(t1, (64, 0))

    return sheet


def make_upgraded_training_dummy_sheet() -> Image.Image:
    """256x64 (4 frames of 64x64) crisp upgraded pixel-art Medieval Quintain Dummy!
    Features:
      - Braced dark-oak cross stand + iron bolts,
      - Leather-padded sparring arm + mini hung wooden buckler shield on right arm,
      - Rope-laced stitched burlap torso with riveted iron belt & crisp bullseye,
      - Dented iron pot-helm tilted over burlap head + golden straw tufts!
    """
    BURLAP_DARK = (138, 104, 62, 255)
    BURLAP_MID = (184, 144, 88, 255)
    BURLAP_HI = (224, 184, 122, 255)
    STRAW_MID = (226, 182, 74, 255)
    STRAW_HI = (252, 224, 118, 255)
    TARGET_RED = (196, 36, 48, 255)

    sheet = Image.new("RGBA", (256, 64), (0, 0, 0, 0))
    tilts = [0, -4, 4, 1]
    for i, tilt in enumerate(tilts):
        fr = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(fr)
        cx = 32 + tilt

        # Ground shadow + X-braced timber base
        d.ellipse([16, 53, 48, 60], fill=(10, 12, 16, 130))
        d.polygon([(18, 56), (26, 51), (38, 51), (46, 56), (42, 58), (22, 58)], fill=WOOD_DARK, outline=OUTLINE)
        d.line([(21, 55), (43, 55)], fill=WOOD_LIT)
        # Center oak post + diagonal foot braces
        d.rectangle([29, 36, 35, 55], fill=WOOD_MID, outline=OUTLINE)
        d.line([(30, 38), (30, 54)], fill=WOOD_HI)
        d.polygon([(24, 54), (29, 46), (29, 50), (26, 55)], fill=WOOD_DARK, outline=OUTLINE)
        d.polygon([(40, 54), (35, 46), (35, 50), (38, 55)], fill=WOOD_DARK, outline=OUTLINE)

        # Horizontal wooden crossbar arms + rope shoulder lashings
        d.rounded_rectangle([cx - 21, 24, cx + 21, 29], radius=2, fill=WOOD_MID, outline=OUTLINE)
        d.line([(cx - 19, 25), (cx + 19, 25)], fill=WOOD_HI)
        # Left arm: upright wooden sparring sword + leather pad!
        d.polygon([(cx - 19, 12), (cx - 17, 10), (cx - 15, 12), (cx - 15, 29), (cx - 19, 29)], fill=WOOD_LIT, outline=OUTLINE)
        d.rectangle([cx - 21, 22, cx - 13, 25], fill=IRON_MID, outline=OUTLINE)
        d.rectangle([cx - 18, 25, cx - 16, 32], fill=(122, 52, 34, 255), outline=OUTLINE)
        put(fr, cx - 17, 14, WHITE_SPEC)
        # Right arm: mini hanging wooden practice buckler with iron boss!
        d.ellipse([cx + 13, 22, cx + 24, 35], fill=WOOD_DARK, outline=OUTLINE)
        d.ellipse([cx + 15, 24, cx + 22, 33], fill=WOOD_LIT, outline=IRON_MID)
        d.ellipse([cx + 17, 27, cx + 20, 30], fill=IRON_HI)

        # Straw tufts poking from shoulders & waist
        for sx, sy in ((cx - 11, 22), (cx + 10, 22), (cx - 6, 41), (cx + 6, 41)):
            d.line([(sx, sy), (sx + (-2 if sx < cx else 2), sy + 2)], fill=STRAW_HI)

        # Stitched burlap sack torso + riveted iron belt
        d.rounded_rectangle([cx - 10, 18, cx + 10, 41], radius=4, fill=BURLAP_MID, outline=OUTLINE)
        d.line([(cx - 8, 20), (cx - 8, 38)], fill=BURLAP_HI)
        d.line([(cx + 8, 20), (cx + 8, 38)], fill=BURLAP_DARK)
        d.rectangle([cx - 10, 35, cx + 10, 38], fill=IRON_MID, outline=OUTLINE)
        for rx in (cx - 7, cx, cx + 7):
            put(fr, rx, 36, IRON_HI)

        # Crisp painted bullseye target on chest + diagonal sword stitch scar!
        d.ellipse([cx - 6, 22, cx + 6, 34], fill=(244, 234, 210, 255), outline=TARGET_RED)
        d.ellipse([cx - 4, 24, cx + 4, 32], fill=TARGET_RED)
        d.ellipse([cx - 2, 26, cx + 2, 30], fill=(244, 234, 210, 255))
        put(fr, cx, 28, TARGET_RED)
        d.line([(cx - 7, 21), (cx - 3, 25)], fill=OUTLINE)

        # Burlap head + tilted dented iron pot-helm on top!
        hx = cx + (tilt // 2)
        d.ellipse([hx - 7, 7, hx + 7, 19], fill=BURLAP_HI, outline=OUTLINE)
        # Stitched X eyes & stitched mouth
        for ex in (hx - 4, hx + 2):
            d.line([(ex, 12), (ex + 2, 14)], fill=OUTLINE)
            d.line([(ex + 2, 12), (ex, 14)], fill=OUTLINE)
        d.line([(hx - 3, 16), (hx + 3, 16)], fill=BURLAP_DARK)
        for mx in (hx - 2, hx, hx + 2):
            put(fr, mx, 16, OUTLINE)

        # Tilted iron training bucket-helm cap + straw wisps!
        d.pieslice([hx - 8, 3, hx + 8, 15], start=180, end=360, fill=IRON_MID, outline=OUTLINE)
        d.line([(hx - 8, 9), (hx + 8, 9)], fill=IRON_DARK, width=2)
        d.line([(hx - 5, 5), (hx - 1, 5)], fill=IRON_HI)
        put(fr, hx + 5, 6, STRAW_HI)
        put(fr, hx - 6, 4, STRAW_MID)

        # Flying straw sparks on hit frames (1 & 2)
        if i in (1, 2):
            dir_s = 1 if i == 2 else -1
            for px, py in ((cx + 14 * dir_s, 15), (cx + 16 * dir_s, 21), (cx - 13 * dir_s, 18)):
                d.line([(px, py), (px + 3 * dir_s, py - 2)], fill=STRAW_HI, width=1)
                put(fr, px + 2 * dir_s, py + 2, STRAW_MID)

        sheet.alpha_composite(fr, (i * 64, 0))
    return sheet


def main() -> None:
    TEX_DIR.mkdir(parents=True, exist_ok=True)

    witch_strip = Image.new("RGBA", (64 * 4, 64), (0, 0, 0, 0))
    for i in range(4):
        witch_strip.alpha_composite(draw_witch_64(i), (i * 64, 0))
    witch_path = TEX_DIR / "lobby_witch.png"
    witch_strip.save(witch_path)
    write_godot_import(witch_path, "uid://bw7tchc0ttag1")

    cauldron_strip = Image.new("RGBA", (48 * 6, 48), (0, 0, 0, 0))
    for i in range(6):
        cauldron_strip.alpha_composite(draw_cauldron_48(i), (i * 48, 0))
    cauldron_path = TEX_DIR / "lobby_cauldron.png"
    cauldron_strip.save(cauldron_path)
    write_godot_import(cauldron_path, "uid://bca8dr0nc0tt2")

    potion_strip = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    for i, is_p in enumerate((False, True)):
        v = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        draw_potion_bottle(v, 16, 16, purple=is_p, tiny=False)
        potion_strip.alpha_composite(v, (i * 32, 0))
    potion_path = TEX_DIR / "witch_potion.png"
    potion_strip.save(potion_path)
    write_godot_import(potion_path, "uid://bw7tchp0t70n3")

    door_path = TEX_DIR / "lobby_door.png"
    make_wooden_doors_sheet().save(door_path)

    wardrobe_path = TEX_DIR / "lobby_wardrobe.png"
    make_wardrobe_64_sheet().save(wardrobe_path)

    fp_path = TEX_DIR / "lobby_fireplace_sofa.png"
    make_fireplace_and_sofa_sheet().save(fp_path)
    write_godot_import(fp_path, "uid://bf7rep8aces05")

    floor_path = TEX_DIR / "cottage_floor.png"
    make_cottage_floor_32().save(floor_path)
    write_godot_import(floor_path, "uid://bc0ttag3f8r04")

    rugs_path = TEX_DIR / "cottage_rugs.png"
    make_cottage_rugs_sheet().save(rugs_path)
    write_godot_import(rugs_path, "uid://bc0ttager8gs6")

    grass_path = TEX_DIR / "cottage_grass.png"
    make_outdoor_grass_64().save(grass_path)
    write_godot_import(grass_path, "uid://bc0ttagegrs07")

    trees_path = TEX_DIR / "cottage_trees.png"
    make_forest_trees_sheet().save(trees_path)
    write_godot_import(trees_path, "uid://bc0ttagetr308")

    fence_path = TEX_DIR / "cottage_fence_gate.png"
    make_fence_rail_sheet().save(fence_path)
    write_godot_import(fence_path, "uid://bc0ttagefnc05")

    dummy_path = TEX_DIR / "training_dummy.png"
    make_upgraded_training_dummy_sheet().save(dummy_path)

    reagents_strip = Image.new("RGBA", (96, 32), (0, 0, 0, 0))
    # Frame 0: Moonshade Alchemy Herb (+1 Reagent from monsters)
    r0 = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    dr0 = ImageDraw.Draw(r0)
    dr0.polygon([(16, 4), (24, 12), (20, 23), (16, 27), (12, 23), (8, 12)],
                fill=(42, 168, 96, 255), outline=OUTLINE)
    dr0.polygon([(16, 7), (21, 13), (18, 21), (16, 23), (14, 21), (11, 13)],
                fill=(108, 238, 152, 255))
    dr0.line([(16, 8), (16, 26)], fill=(238, 255, 224, 255), width=2)
    reagents_strip.alpha_composite(r0, (0, 0))

    # Frame 1: Crimson Monster Essence Drop (+2 Reagents from tough monsters)
    r1 = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    dr1 = ImageDraw.Draw(r1)
    dr1.polygon([(16, 4), (24, 15), (22, 24), (16, 28), (10, 24), (8, 15)],
                fill=(178, 32, 86, 255), outline=OUTLINE)
    dr1.polygon([(16, 8), (21, 16), (19, 23), (16, 25), (13, 23), (11, 16)],
                fill=(248, 78, 138, 255))
    put(r1, 14, 13, WHITE_SPEC)
    put(r1, 15, 12, WHITE_SPEC)
    reagents_strip.alpha_composite(r1, (32, 0))

    # Frame 2: Golden-Violet Wave Arcane Crystal (+3 Reagents on wave clear = 1 full Majon!)
    r2 = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    dr2 = ImageDraw.Draw(r2)
    dr2.polygon([(16, 3), (25, 11), (22, 27), (10, 27), (7, 11)],
                fill=(146, 72, 224, 255), outline=OUTLINE)
    dr2.polygon([(16, 6), (22, 12), (19, 25), (13, 25), (10, 12)],
                fill=(212, 142, 255, 255))
    dr2.polygon([(16, 8), (19, 14), (16, 22), (13, 14)], fill=GOLD_HI)
    reagents_strip.alpha_composite(r2, (64, 0))

    reagents_path = TEX_DIR / "witch_reagents.png"
    reagents_strip.save(reagents_path)
    write_godot_import(reagents_path, "uid://bw7tchr3agnt8")

    print("Generated Witch's Cottage + Outdoor Yard pixel-art assets:")
    for p in (
        witch_path, cauldron_path, potion_path, door_path, wardrobe_path,
        fp_path, floor_path, rugs_path, grass_path, trees_path, fence_path, dummy_path,
        reagents_path
    ):
        im = Image.open(p)
        print(f"  - {p.relative_to(REPO_ROOT)}: {im.size}")


if __name__ == "__main__":
    main()
