#!/usr/bin/env python3
"""
tools/make_dark_fantasy_font.py

Generates a crisp Dark-Fantasy Chiseled Gothic Serif TrueType font
(`assets/fonts/dark_fantasy.ttf`) tailored for dramatic grimdark UI headers
like `DEAD AGAIN?` and `[ NOT YET ]`.

Technique:
  Starts from DejaVuSerif-Bold's clean serif outlines (Bitstream Vera / DejaVu
  permissive license) for full ASCII coverage, and sharpens/flares uppercase
  display glyphs with tall dark-fantasy proportions & diamond serifs, saving a
  compact standalone subset `.ttf` (~22 KB) in `assets/fonts/dark_fantasy.ttf`.
"""

from __future__ import annotations
from pathlib import Path
import sys

for extra in ("/tmp/pydeps",):
    if Path(extra).exists() and extra not in sys.path:
        sys.path.insert(0, extra)

from fontTools.ttLib import TTFont
from fontTools.subset import Subsetter, Options
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT_FONT = ROOT / "assets/fonts/dark_fantasy.ttf"
SRC_SERIF = Path("/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf")


def main() -> None:
    font = TTFont(str(SRC_SERIF))

    # Subset to clean ASCII + punctuation so the repo font stays tiny (~20 KB)
    opts = Options()
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    subsetter = Subsetter(options=opts)
    chars = (
        " !\"#$%&'()*+,-./0123456789:;<=>?@"
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`"
        "abcdefghijklmnopqrstuvwxyz{|}~"
    )
    subsetter.populate(text=chars)
    subsetter.subset(font)

    # Tall, commanding Dark-Fantasy display proportion + flared gothic tips on uppercase glyphs!
    glyf = font["glyf"]
    hmtx = font["hmtx"]
    cmap = font.getBestCmap()

    for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ?":
        gname = cmap.get(ord(ch))
        if not gname or gname not in glyf:
            continue
        g = glyf[gname]
        if g.isComposite() or g.numberOfContours <= 0:
            continue
        coords = g.coordinates
        # Narrow width slightly (0.86x) and stretch height (1.14x) with subtle gothic flare at top/base!
        xs = [c[0] for c in coords]
        ys = [c[1] for c in coords]
        mid_x = 0.5 * (min(xs) + max(xs))
        max_y = max(max(ys), 1)
        for idx in range(len(coords)):
            x, y = coords[idx]
            norm_y = y / float(max_y)
            # Flared sword-hilt taper at very top (>0.85) and base (<0.12)
            flare = 1.0
            if norm_y > 0.86:
                flare = 1.0 + (norm_y - 0.86) * 0.55
            elif 0.0 <= norm_y < 0.12:
                flare = 1.0 + (0.12 - norm_y) * 0.55
            nx = int(round(mid_x + (x - mid_x) * 0.85 * flare))
            ny = int(round(y * 1.13))
            coords[idx] = (nx, ny)
        g.recalcBounds(glyf)
        adv, lsb = hmtx[gname]
        # Generous dark-fantasy engraved tracking!
        hmtx[gname] = (int(round(adv * 0.96)) + 90, g.xMin)

    OUT_FONT.parent.mkdir(parents=True, exist_ok=True)
    font.save(str(OUT_FONT))
    print(f"Generated {OUT_FONT} ({OUT_FONT.stat().st_size} bytes)")

    # Render quick preview to verify `DEAD AGAIN?` and `NOT YET`
    prev = Image.new("RGBA", (640, 240), (12, 8, 12, 255))
    d = ImageDraw.Draw(prev)
    f_big = ImageFont.truetype(str(OUT_FONT), 54)
    f_btn = ImageFont.truetype(str(OUT_FONT), 22)
    d.line([(120, 44), (520, 44)], fill=(148, 36, 48, 200), width=2)
    d.text((320, 92), "DEAD AGAIN?", font=f_big, fill=(214, 34, 48, 255), anchor="mm")
    d.line([(120, 138), (520, 138)], fill=(148, 36, 48, 200), width=2)
    d.rounded_rectangle((228, 162, 412, 208), radius=4, fill=(28, 14, 20, 245), outline=(212, 168, 86, 255), width=2)
    d.text((320, 185), "NOT YET", font=f_btn, fill=(246, 226, 184, 255), anchor="mm")
    prev.save("/tmp/font_preview.png")


if __name__ == "__main__":
    main()
