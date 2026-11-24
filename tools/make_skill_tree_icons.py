#!/usr/bin/env python3
"""Generate crisp 32x32 pixel-art RPG Skill Tree icons (`assets/textures/skill_tree_icons.png`):
  576 x 32 strip (18 icons of 32x32, luminous grayscale/white-core so UI tinting
  cleanly themes them into Knight Blue+Black, Behemoth Orange+Red, Sylvara Green+Gold,
  and Noa Red+White!):
    0: Root Awakening Lotus Flame
    1: Slashing Crescent Strike (Offense Branch)
    2: Meditating Spirit Aura   (Spirit Branch)
    3: Blazing Arcane Flame     (Signature Branch)
    4: Broadsword               (Attack DMG)
    5: Winged Swift Boot        (Move & Dash SPD)
    6: Vitality Heart           (Max HP)
    7: Bastion Heater Shield    (Armor / Toughness)
    8: Eight-Pointed Burst Star (Special / Crit DMG)
    9: Execution Skull          (Drain / Stun / Execute)
   10: Twin Crossed Blades      (Tier-4 Mastery 0)
   11: Lightning Step Bolt      (Tier-4 Mastery 1)
   12: Overflowing Chalice      (Tier-4 Mastery 2)
   13: Iron Fortress Crown      (Tier-4 Mastery 3)
   14: Arcane Supernova         (Tier-4 Mastery 4)
   15: Reaper Crescent Scythe   (Tier-4 Mastery 5)
   16: Padlock                  (Locked Tier-4 indicator)
   17: Faceted Skill Gem        (Top-left counter & Upgrade cost gem)
"""

from __future__ import annotations

import hashlib
from pathlib import Path
from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
TEX_DIR = REPO_ROOT / "assets" / "textures"

OUT = (18, 16, 26, 255)
SHAD = (118, 122, 146, 255)
MID = (186, 192, 218, 255)
LIT = (232, 236, 250, 255)
PURE = (255, 255, 255, 255)
GLOW = (200, 206, 235, 110)


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


def draw_icon(idx: int) -> Image.Image:
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    if idx == 0:
        # Root Awakening Lotus Flame
        d.ellipse([6, 6, 26, 26], fill=GLOW)
        d.polygon([(16, 4), (23, 14), (20, 25), (16, 27), (12, 25), (9, 14)], fill=MID, outline=OUT)
        d.polygon([(6, 15), (12, 18), (13, 25), (8, 22)], fill=SHAD, outline=OUT)
        d.polygon([(26, 15), (20, 18), (19, 25), (24, 22)], fill=SHAD, outline=OUT)
        d.polygon([(16, 8), (20, 16), (16, 24), (12, 16)], fill=PURE)
    elif idx == 1:
        # Slashing Crescent Strike (matches image-17 Shadow Strike!)
        d.polygon([(5, 26), (13, 12), (26, 5), (22, 13), (12, 21)], fill=LIT, outline=OUT)
        d.polygon([(6, 26), (15, 15), (25, 6), (19, 16)], fill=PURE)
        d.polygon([(9, 27), (18, 19), (27, 13), (21, 21)], fill=MID, outline=OUT)
        d.polygon([(14, 27), (22, 23), (27, 20), (22, 26)], fill=SHAD)
    elif idx == 2:
        # Meditating Spirit Aura (matches image-17 Row 1 Center!)
        d.polygon([(16, 4), (24, 11), (26, 21), (6, 21), (8, 11)], fill=GLOW)
        d.polygon([(8, 16), (11, 10), (13, 16)], fill=MID)
        d.polygon([(24, 16), (21, 10), (19, 16)], fill=MID)
        d.ellipse([13, 7, 19, 13], fill=PURE, outline=OUT)
        d.polygon([(11, 14), (21, 14), (23, 22), (9, 22)], fill=LIT, outline=OUT)
        d.rounded_rectangle([7, 21, 25, 26], radius=2, fill=PURE, outline=OUT)
    elif idx == 3:
        # Blazing Arcane Flame (matches image-17 Row 1 Right!)
        d.polygon([(16, 4), (21, 11), (25, 9), (24, 21), (19, 27), (13, 27), (8, 21), (7, 9), (11, 11)], fill=MID, outline=OUT)
        d.polygon([(16, 8), (21, 16), (20, 24), (16, 26), (12, 24), (11, 16)], fill=LIT)
        d.polygon([(16, 13), (19, 19), (16, 25), (13, 19)], fill=PURE)
        d.ellipse([14, 19, 18, 24], fill=OUT)
    elif idx == 4:
        # Broadsword
        d.polygon([(23, 5), (27, 5), (27, 9), (14, 22), (10, 18)], fill=LIT, outline=OUT)
        d.line([(25, 7), (13, 19)], fill=PURE, width=1)
        d.line([(8, 16), (16, 24)], fill=MID, width=3)
        d.line([(6, 26), (11, 21)], fill=SHAD, width=3)
    elif idx == 5:
        # Winged Swift Boot
        d.polygon([(13, 8), (21, 8), (20, 19), (26, 21), (26, 26), (10, 26), (11, 18)], fill=LIT, outline=OUT)
        d.line([(5, 13), (10, 13)], fill=PURE, width=2)
        d.line([(4, 18), (9, 18)], fill=MID, width=2)
        d.line([(6, 22), (9, 22)], fill=SHAD, width=2)
    elif idx == 6:
        # Vitality Heart
        d.ellipse([6, 7, 17, 18], fill=LIT, outline=OUT)
        d.ellipse([15, 7, 26, 18], fill=LIT, outline=OUT)
        d.polygon([(7, 14), (25, 14), (16, 26)], fill=LIT, outline=OUT)
        d.ellipse([9, 10, 14, 14], fill=PURE)
    elif idx == 7:
        # Bastion Heater Shield
        d.polygon([(8, 6), (24, 6), (24, 16), (16, 27), (8, 16)], fill=MID, outline=OUT)
        d.polygon([(11, 9), (21, 9), (21, 15), (16, 23), (11, 15)], fill=LIT)
        d.line([(16, 9), (16, 23)], fill=PURE, width=2)
    elif idx == 8:
        # Eight-Pointed Burst Star (matches image-17 Row 2 Col 5!)
        d.polygon([(16, 3), (18, 13), (29, 16), (18, 19), (16, 29), (14, 19), (3, 16), (14, 13)], fill=PURE, outline=OUT)
        d.polygon([(7, 7), (15, 13), (25, 7), (19, 15), (25, 25), (17, 19), (7, 25), (13, 17)], fill=LIT)
        d.ellipse([13, 13, 19, 19], fill=PURE)
    elif idx == 9:
        # Execution Skull
        d.ellipse([8, 6, 24, 21], fill=LIT, outline=OUT)
        d.rectangle([11, 18, 21, 25], fill=MID, outline=OUT)
        d.ellipse([10, 12, 14, 16], fill=OUT)
        d.ellipse([18, 12, 22, 16], fill=OUT)
        d.polygon([(15, 16), (17, 16), (16, 19)], fill=OUT)
        for tx in (13, 16, 19):
            d.line([(tx, 21), (tx, 24)], fill=OUT)
    elif idx == 10:
        # Twin Crossed Blades
        d.polygon([(6, 24), (8, 26), (26, 8), (24, 6)], fill=PURE, outline=OUT)
        d.polygon([(24, 26), (26, 24), (8, 6), (6, 8)], fill=LIT, outline=OUT)
        d.ellipse([13, 13, 19, 19], fill=PURE, outline=OUT)
    elif idx == 11:
        # Lightning Step Bolt
        d.polygon([(18, 4), (9, 17), (16, 17), (13, 28), (23, 14), (16, 14)], fill=PURE, outline=OUT)
    elif idx == 12:
        # Overflowing Elixir Chalice
        d.polygon([(9, 7), (23, 7), (19, 18), (13, 18)], fill=LIT, outline=OUT)
        d.rectangle([15, 18, 17, 24], fill=MID, outline=OUT)
        d.rectangle([11, 24, 21, 27], fill=LIT, outline=OUT)
        d.ellipse([11, 6, 21, 10], fill=PURE)
    elif idx == 13:
        # Iron Fortress Crown
        d.polygon([(6, 23), (6, 11), (11, 16), (16, 8), (21, 16), (26, 11), (26, 23)], fill=LIT, outline=OUT)
        d.rectangle([6, 22, 26, 26], fill=MID, outline=OUT)
        d.ellipse([14, 15, 18, 19], fill=PURE)
    elif idx == 14:
        # Arcane Supernova Eye
        d.polygon([(4, 16), (12, 9), (20, 9), (28, 16), (20, 23), (12, 23)], fill=MID, outline=OUT)
        d.ellipse([11, 11, 21, 21], fill=PURE, outline=OUT)
        d.ellipse([14, 14, 18, 18], fill=OUT)
    elif idx == 15:
        # Reaper Crescent War-Scythe
        d.polygon([(7, 13), (15, 5), (26, 7), (22, 12), (14, 11), (9, 16)], fill=PURE, outline=OUT)
        d.polygon([(22, 7), (25, 8), (11, 27), (8, 26)], fill=MID, outline=OUT)
    elif idx == 16:
        # Padlock (Locked Node icon matching Row 3 of image-17!)
        d.arc([10, 5, 22, 18], start=180, end=360, fill=MID, width=3)
        d.rounded_rectangle([8, 13, 24, 26], radius=2, fill=SHAD, outline=OUT)
        d.line([(10, 15), (22, 15)], fill=LIT)
        d.ellipse([14, 17, 18, 21], fill=OUT)
        d.line([(16, 20), (16, 24)], fill=OUT, width=2)
    else:
        # 17: Faceted Skill Gem (`💎`)
        d.polygon([(16, 4), (25, 12), (22, 25), (16, 28), (10, 25), (7, 12)], fill=MID, outline=OUT)
        d.polygon([(16, 6), (22, 12), (16, 25), (10, 12)], fill=LIT)
        d.polygon([(16, 6), (19, 12), (16, 18), (13, 12)], fill=PURE)

    return im


def main() -> None:
    TEX_DIR.mkdir(parents=True, exist_ok=True)
    strip = Image.new("RGBA", (32 * 18, 32), (0, 0, 0, 0))
    for i in range(18):
        strip.alpha_composite(draw_icon(i), (i * 32, 0))
    out_path = TEX_DIR / "skill_tree_icons.png"
    strip.save(out_path)
    write_godot_import(out_path, "uid://bsk788tree7c0")
    print(f"wrote {out_path.relative_to(REPO_ROOT)} ({strip.size})")


if __name__ == "__main__":
    main()
