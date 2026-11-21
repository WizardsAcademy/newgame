#!/usr/bin/env python
"""Generate Medieval Lobby Props + Training Dummy + Crimson Bat sprites!

Writes:
    assets/textures/lobby_wardrobe.png   128 x 80 (2 frames of 64x80: closed / open glow)
    assets/textures/training_dummy.png   256 x 64 (4 frames of 64x64: idle, hit_l, hit_r, spin)
    assets/textures/lobby_door.png       160 x 80 (2 frames of 80x80: 0=STAGES gate, 1=SANDBOX portal)
    assets/textures/crimson_bat.png       72 x 24 (3 frames of 24x24: flapping crimson bat)
"""

import math
from PIL import Image, ImageDraw

OUT = (12, 10, 14, 255)


def build_wardrobe_sheet() -> Image.Image:
    w, h = 64, 80
    sheet = Image.new("RGBA", (w * 2, h), (0, 0, 0, 0))
    for i, opened in enumerate((False, True)):
        fr = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(fr)
        # Shadow
        d.ellipse([6, 68, 58, 78], fill=(0, 0, 0, 95))
        # Carved Medieval Oak Armory Cabinet
        d.rounded_rectangle([10, 10, 54, 72], radius=3, fill=(82, 48, 28, 255), outline=OUT)
        # Crown pediment top + gold crest
        d.polygon([(7, 12), (32, 3), (57, 12)], fill=(112, 68, 38, 255), outline=OUT)
        d.ellipse([28, 5, 36, 13], fill=(238, 192, 72, 255), outline=OUT)

        if opened:
            # Doors ajar revealing glowing golden hero cloaks & armor inside!
            d.rectangle([15, 16, 49, 67], fill=(28, 20, 34, 255), outline=OUT)
            # Hanging crimson vampire cloak, emerald ranger hood & steel breastplate
            d.polygon([(18, 20), (25, 20), (27, 62), (16, 62)], fill=(168, 28, 56, 255), outline=OUT)
            d.polygon([(28, 20), (36, 20), (37, 56), (27, 56)], fill=(96, 114, 148, 255), outline=OUT)
            d.polygon([(38, 20), (46, 20), (48, 62), (37, 62)], fill=(48, 152, 96, 255), outline=OUT)
            # Swung outer doors
            d.polygon([(10, 14), (4, 18), (4, 70), (14, 68)], fill=(104, 62, 36, 255), outline=OUT)
            d.polygon([(54, 14), (60, 18), (60, 70), (50, 68)], fill=(104, 62, 36, 255), outline=OUT)
        else:
            # Twin panelled oak doors with iron hinges & brass rings
            d.rectangle([14, 16, 31, 67], fill=(108, 66, 38, 255), outline=OUT)
            d.rectangle([33, 16, 50, 67], fill=(108, 66, 38, 255), outline=OUT)
            d.rectangle([17, 20, 28, 40], fill=(86, 50, 28, 255), outline=OUT)
            d.rectangle([36, 20, 47, 40], fill=(86, 50, 28, 255), outline=OUT)
            d.rectangle([17, 44, 28, 63], fill=(86, 50, 28, 255), outline=OUT)
            d.rectangle([36, 44, 47, 63], fill=(86, 50, 28, 255), outline=OUT)
            # Iron strap hinges + brass handles
            for hy in (22, 58):
                d.rectangle([11, hy, 18, hy + 3], fill=(74, 82, 98, 255), outline=OUT)
                d.rectangle([46, hy, 53, hy + 3], fill=(74, 82, 98, 255), outline=OUT)
            d.ellipse([27, 39, 30, 43], fill=(242, 196, 76, 255), outline=OUT)
            d.ellipse([34, 39, 37, 43], fill=(242, 196, 76, 255), outline=OUT)
        sheet.alpha_composite(fr, (i * w, 0))
    return sheet


def build_dummy_sheet() -> Image.Image:
    sz = 64
    sheet = Image.new("RGBA", (sz * 4, sz), (0, 0, 0, 0))
    tilts = [0, -4, 4, 1]
    for i, tilt in enumerate(tilts):
        fr = Image.new("RGBA", (sz, sz), (0, 0, 0, 0))
        d = ImageDraw.Draw(fr)
        cx = 32 + tilt
        # Wooden stand base + post
        d.ellipse([18, 52, 46, 60], fill=(0, 0, 0, 90))
        d.rounded_rectangle([22, 52, 42, 57], radius=2, fill=(92, 56, 32, 255), outline=OUT)
        d.rectangle([29, 36, 35, 55], fill=(116, 72, 42, 255), outline=OUT)
        # Wooden crossbar arms
        d.rounded_rectangle([cx - 21, 25, cx + 21, 31], radius=2, fill=(124, 78, 46, 255), outline=OUT)
        # Straw-stuffed burlap torso + painted red bullseye target!
        d.rounded_rectangle([cx - 10, 19, cx + 10, 41], radius=4, fill=(214, 178, 108, 255), outline=OUT)
        d.line([(cx - 9, 35), (cx + 9, 35)], fill=(86, 94, 112, 255), width=2)  # iron belt band
        # Bullseye rings on chest
        d.ellipse([cx - 6, 24, cx + 6, 36], fill=(248, 238, 214, 255), outline=(188, 38, 46, 255))
        d.ellipse([cx - 3, 27, cx + 3, 33], fill=(188, 38, 46, 255))
        # Burlap sack head with stitched X eyes + straw tufts!
        hx = cx + (tilt // 2)
        d.ellipse([hx - 8, 6, hx + 8, 21], fill=(226, 192, 122, 255), outline=OUT)
        # Straw tufts poking out top
        for sx in (-3, 0, 3):
            d.line([(hx + sx, 6), (hx + sx * 2, 2)], fill=(248, 218, 112, 255), width=1)
        # Stitched X eyes
        for ex in (hx - 4, hx + 2):
            d.line([(ex, 11), (ex + 2, 13)], fill=OUT)
            d.line([(ex + 2, 11), (ex, 13)], fill=OUT)
        d.line([(hx - 3, 16), (hx + 3, 16)], fill=OUT)
        if i in (1, 2):
            # Flying straw wisps on impact!
            for px, py in ((cx + 15, 16), (cx - 16, 20), (cx + 14, 34)):
                d.line([(px, py), (px + (3 if i == 2 else -3), py - 2)], fill=(252, 224, 120, 255), width=2)
        sheet.alpha_composite(fr, (i * sz, 0))
    return sheet


def build_doors_sheet() -> Image.Image:
    sz = 80
    sheet = Image.new("RGBA", (sz * 2, sz), (0, 0, 0, 0))
    for i in range(2):
        fr = Image.new("RGBA", (sz, sz), (0, 0, 0, 0))
        d = ImageDraw.Draw(fr)
        # Massive medieval stone archway
        d.rounded_rectangle([8, 8, 72, 76], radius=24, fill=(76, 82, 96, 255), outline=OUT)
        d.rounded_rectangle([13, 13, 67, 76], radius=20, fill=(54, 58, 70, 255), outline=OUT)
        if i == 0:
            # Frame 0: STAGES Dungeon Gate (iron portcullis + warm torchlit stairs descending!)
            d.rounded_rectangle([18, 18, 62, 76], radius=16, fill=(22, 16, 26, 255), outline=OUT)
            # Glowing dungeon amber light inside doorway
            d.ellipse([24, 28, 56, 70], fill=(238, 132, 48, 95))
            # Iron portcullis bars raised halfway
            for bx in (26, 35, 45, 54):
                d.line([(bx, 19), (bx, 42)], fill=(116, 126, 148, 255), width=2)
            d.line([(20, 34), (60, 34)], fill=(116, 126, 148, 255), width=2)
            # Twin wall torches on arch pillars!
            for tx in (11, 69):
                d.rectangle([tx - 2, 36, tx + 2, 46], fill=(92, 56, 32, 255), outline=OUT)
                d.ellipse([tx - 4, 28, tx + 4, 37], fill=(255, 148, 42, 255), outline=OUT)
                d.ellipse([tx - 2, 30, tx + 2, 35], fill=(255, 236, 132, 255))
        else:
            # Frame 1: SANDBOX Portal Doorway (emerald-cyan arcane stone archway!)
            d.rounded_rectangle([18, 18, 62, 76], radius=16, fill=(14, 32, 42, 255), outline=OUT)
            d.ellipse([22, 24, 58, 72], fill=(56, 214, 188, 145))
            d.ellipse([28, 32, 52, 66], fill=(168, 255, 236, 195))
            # Glowing keystone runes around arch
            for rx, ry in ((40, 12), (20, 24), (60, 24), (15, 48), (65, 48)):
                d.ellipse([rx - 2, ry - 2, rx + 2, ry + 2], fill=(92, 248, 214, 255))
        sheet.alpha_composite(fr, (i * sz, 0))
    return sheet


def build_bat_sheet() -> Image.Image:
    sz = 24
    sheet = Image.new("RGBA", (sz * 3, sz), (0, 0, 0, 0))
    wing_dy = [-4, 0, 4]
    for i, wdy in enumerate(wing_dy):
        fr = Image.new("RGBA", (sz, sz), (0, 0, 0, 0))
        d = ImageDraw.Draw(fr)
        cx, cy = 12, 12
        # Left & right scalloped vampire bat wings
        d.polygon([(cx - 2, cy - 1), (cx - 10, cy + wdy - 2), (cx - 8, cy + wdy + 3), (cx - 2, cy + 2)],
                  fill=(168, 18, 52, 255), outline=OUT)
        d.polygon([(cx + 2, cy - 1), (cx + 10, cy + wdy - 2), (cx + 8, cy + wdy + 3), (cx + 2, cy + 2)],
                  fill=(168, 18, 52, 255), outline=OUT)
        # Bat body + pointed ears + glowing ruby eyes!
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(42, 14, 28, 255), outline=OUT)
        fr.putpixel((cx - 2, cy - 4), OUT)
        fr.putpixel((cx + 2, cy - 4), OUT)
        fr.putpixel((cx - 1, cy - 1), (255, 92, 122, 255))
        fr.putpixel((cx + 1, cy - 1), (255, 92, 122, 255))
        sheet.alpha_composite(fr, (i * sz, 0))
    return sheet


def main() -> None:
    build_wardrobe_sheet().save("assets/textures/lobby_wardrobe.png")
    build_dummy_sheet().save("assets/textures/training_dummy.png")
    build_doors_sheet().save("assets/textures/lobby_door.png")
    build_bat_sheet().save("assets/textures/crimson_bat.png")
    print("wrote lobby_wardrobe.png, training_dummy.png, lobby_door.png, crimson_bat.png")


if __name__ == "__main__":
    main()
