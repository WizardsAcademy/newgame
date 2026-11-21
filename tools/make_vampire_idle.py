#!/usr/bin/env python
"""Draw the gothic vampire girl's idle sprite, pixel by pixel, on a 32x32 canvas.

THE SOURCE OF TRUTH IS THIS FILE, NOT THE PNG.

    python tools/make_vampire_idle.py

    writes
        assets/sprites/vampire/vampire_idle.png        32 x 32, RGBA, transparent
        assets/sprites/vampire/vampire_idle.aseprite   1 frame, 1 layer, palette
        assets/sprites/vampire/palette.png             swatches + hex codes
        assets/sprites/vampire/vampire.gpl             Aseprite / GIMP palette
        docs/images/vampire_idle_preview.png           review sheet (nearest-neighbour only)
        docs/images/vampire_idle_x16.png               16x, transparent
        docs/images/vampire_idle_x32.png               32x, transparent

WHY AN ASCII GRID
  Every pixel is one character, so the drawing can be diffed, reviewed and
  corrected one character at a time - which is the whole point at 32x32.
  Nothing is ever scaled here: the grid *is* the sprite. The only scaling in
  this file happens in build_preview(), with Image.NEAREST, on a copy.

  The grid is validated before anything is written:
    * exactly 32 rows of exactly 32 characters (a ragged row silently shifts
      art, so it is a hard error);
    * every character must be PALETTE or '.', so a typo cannot become a stray
      colour;
    * every opaque pixel must be 4-connected to the body - the drafts grew
      smudges floating beside the cloak and on the hair, so this is a hard
      error too;
    * the .aseprite is decoded again and compared with the PNG.

HOW TO READ A ROW
  main() prints the grid with a column ruler under it (see RULER). Her
  centreline is between x15 and x16. Left/right below are *the viewer's* - the
  rose is on the image-left temple, as in the reference sheet.

VERTICAL BUDGET (soles land on row 29, same as every other hero)
  y2 ..y8    hair crown, rose on the left temple
  y9 ..y10   ears + fringe shadow teeth
  y11..y15   face: forehead, lash line, iris, under-eye, lips, fang, chin
  y16        shoulders + neck
  y17        high crimson collar
  y18..y20   bodice + brooch (y18-19), belt + buckle (y20)
  y21..y25   flared skirt between the cloak panels, hem at y25
  y26        bare thigh, cloak tails
  y27..y29   boot band, boot shaft, soles
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

CANVAS = 32

# ---------------------------------------------------------------------------
# Palette - the brief's ten colours, plus one (r) split off #A52C46 so the
# iris reads as a different red from the rose and the accents.
# "hex" is what ships; "role" is what it is allowed to be used for.
# ---------------------------------------------------------------------------
PALETTE = {
    "K": ("#100D14", "outline"),
    "p": ("#211827", "hair shadow / cloak"),
    "P": ("#392A40", "hair base"),
    "L": ("#59415F", "hair highlight"),
    "d": ("#65152B", "cloak crimson / lining / lips"),
    "R": ("#A52C46", "rose / crimson accents"),
    "s": ("#F2D4D9", "skin"),
    "q": ("#C994A5", "skin shadow"),
    "w": ("#F8EAF0", "highlight"),
    "g": ("#302B38", "clothing"),
    "r": ("#B32044", "iris (crimson, split from #A52C46)"),
}

TRANSPARENT = "."

# ---------------------------------------------------------------------------
# The sprite. One character = one pixel. 32 rows x 32 columns.
# ---------------------------------------------------------------------------
ROWS = [
    # 0         1         2         3
    # 0123456789012345678901234567890123
    "................................",  # 0
    "................................",  # 1  hair crown starts at y2
    ".............KPLLPK.............",  # 2  pointed centre parting
    "...........KLLPPPPLLK...........",  # 3
    ".........KLLPPPPPPPPLLK.........",  # 4
    "........KLLPPPPPPPPPPLLK........",  # 5
    ".......KLdRRdPPPPPPPPPLLK.......",  # 6  rose (top row)
    ".......KLRdwRPPPPPPPPPLLK.......",  # 7  rose (spiral + highlight)
    ".......KLdRRdPPPPPPPPPLLK.......",  # 8  rose (base)
    ".......KKsPppPPPPPppPPsKK.......",  # 9  ear tips + fringe shadow teeth
    ".......KLsqPPPPppPPPPqsLK.......",  # 10 ears + fringe
    ".......KLPPssssssssssPPLK.......",  # 11 forehead
    ".......KLPPqKKKssKKKqPPLK.......",  # 12 lash line, both eyes
    ".......KLPPqrwrqqrwrqPPLK.......",  # 13 crimson iris + white catchlight
    ".......KLPPqsssdddssqPPLK.......",  # 14 mouth, weighted to her left
    ".......KLPP.qsssswsq.PPLK.......",  # 15 chin + fang
    ".......KppppP.qssq.PppppK.......",  # 16 shoulders + neck
    ".......KppddddddddddddppK.......",  # 17 high crimson collar
    ".......KppdggggwRggggdppK.......",  # 18 black bodice + crimson brooch
    "......KLppdggggRRggggdppLK......",  # 19 arms close to the body
    ".....KLpppdKKKKRRKKKKdpppLK.....",  # 20 belt + crimson buckle
    "......KLpdKggggggggggKdpLK......",  # 21 flared skirt between the cloak
    "......KLpdKggggggggggKdpLK......",  # 22
    ".....KLpdKggggggggggggKdpLK.....",  # 23
    ".....KLpdKgppppppppppgKdpLK.....",  # 24 skirt shade
    "......KLdKKKKKKKKKKKKKKdLK......",  # 25 hem + crimson lining tips
    "........KLdKssqKKqssKdLK........",  # 26 bare thigh, cloak tails
    "........KLdKRRRKKRRRKdLK........",  # 27 crimson boot band
    "...........KggpKKpggK...........",  # 28 boot shaft
    "...........KKKKKKKKKK...........",  # 29 soles
    "................................",  # 30
    "................................",  # 31
]

RULER = "    " + "".join(str(i % 10) for i in range(CANVAS))


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
def validate() -> None:
    """Fail loudly before a single byte is written."""
    if len(ROWS) != CANVAS:
        raise SystemExit("grid has %d rows, need %d" % (len(ROWS), CANVAS))
    for y, row in enumerate(ROWS):
        if len(row) != CANVAS:
            raise SystemExit("row %d is %d wide, need %d: %r"
                             % (y, len(row), CANVAS, row))
        for x, ch in enumerate(row):
            if ch not in PALETTE and ch != TRANSPARENT:
                raise SystemExit("row %d col %d: unknown symbol %r" % (y, x, ch))

    # No floating confetti: every opaque pixel must reach the body centre.
    filled = {(x, y) for y, row in enumerate(ROWS)
              for x, ch in enumerate(row) if ch != TRANSPARENT}
    seed = (15, 20)                                    # centre of the bodice
    if seed not in filled:
        raise SystemExit("seed pixel %r is empty" % (seed,))
    seen, stack = {seed}, [seed]
    while stack:
        x, y = stack.pop()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) in filled and (nx, ny) not in seen:
                seen.add((nx, ny))
                stack.append((nx, ny))
    floating = sorted(filled - seen)
    if floating:
        raise SystemExit("%d floating pixel(s): %s"
                         % (len(floating), floating[:12]))


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
def render() -> Image.Image:
    """The one and only place the PNG pixels come from."""
    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    for y, row in enumerate(ROWS):
        for x, ch in enumerate(row):
            if ch != TRANSPARENT:
                img.putpixel((x, y), hex_to_rgba(PALETTE[ch][0]))
    return img


def hex_to_rgba(value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    return (int(value[1:3], 16), int(value[3:5], 16), int(value[5:7], 16), alpha)


# ---------------------------------------------------------------------------
# Aseprite file (.aseprite) - so the sprite opens as real, editable pixel art
# (one layer, full palette) instead of as a flattened PNG.
# ---------------------------------------------------------------------------
def chunk(kind: int, data: bytes) -> bytes:
    """A chunk header is 6 bytes: DWORD size (header included) + WORD type."""
    return struct.pack("<IH", 6 + len(data), kind) + data


def write_aseprite(img: Image.Image, path: Path, name: str = "vampire idle") -> None:
    """One frame, one normal layer, one cel, plus the sprite's palette.

    Layout follows the published .aseprite spec; verify_aseprite() reads it
    straight back so a wrong byte cannot ship unnoticed.
    """
    # --- header (128 bytes)
    header = struct.pack("<I", 0)                 # file size, patched at the end
    header += struct.pack("<H", 0xA5E0)           # magic
    header += struct.pack("<H", 1)                # frame count
    header += struct.pack("<HH", CANVAS, CANVAS)  # canvas width / height
    header += struct.pack("<H", 32)               # colour depth: 32 = RGBA
    header += struct.pack("<I", 1)                # flags: layer opacity valid
    header += struct.pack("<H", 100)              # speed, ms per frame
    header += struct.pack("<II", 0, 0)            # 0, 0
    header += b"\x00" * 4                         # transparent index + reserved
    header += struct.pack("<H", len(PALETTE))     # colours on the palette
    header += struct.pack("<BB", 1, 1)            # pixel ratio width / height
    header += struct.pack("<hh", 0, 0)            # grid x, grid y
    header += struct.pack("<HH", 16, 16)          # grid width / height
    header += b"\x00" * 84                        # reserved for future
    assert len(header) == 128, "header is %d bytes" % len(header)

    # --- frame header (16 bytes)
    frame = struct.pack("<I", 16)                 # bytes in this frame
    frame += struct.pack("<H", 0xF1FA)            # magic
    frame += struct.pack("<H", 3)                 # old field: chunk count
    frame += struct.pack("<H", 100)               # frame duration, ms
    frame += b"\x00" * 2                          # for future
    frame += struct.pack("<I", 3)                 # new field: chunk count
    assert len(frame) == 16, "frame header is %d bytes" % len(frame)

    # --- layer chunk (0x2004): one visible normal layer holding the sprite
    layer_name = name.encode("utf-8")
    layer = struct.pack("<HHH", 1, 0, 0)          # flags(visible), type, child level
    layer += struct.pack("<HH", 0, 0)             # default cel w/h (ignored)
    layer += struct.pack("<H", 0)                 # blend mode: normal
    layer += struct.pack("<B", 255)               # opacity
    layer += b"\x00" * 3                          # reserved
    layer += struct.pack("<H", len(layer_name)) + layer_name

    # --- palette chunk (0x2019): 11 named swatches
    entries = b""
    for key, (hex_value, _role) in PALETTE.items():
        r, g, b, a = hex_to_rgba(hex_value)
        entry_name = key.encode("utf-8")
        entries += struct.pack("<H", 1)           # flags: 1 = entry has a name
        entries += struct.pack("<BBBB", r, g, b, a)
        entries += struct.pack("<H", len(entry_name)) + entry_name
    palette = struct.pack("<III", len(PALETTE), 0, len(PALETTE) - 1)
    palette += b"\x00" * 8                        # reserved
    palette += entries

    # --- cel chunk (0x2005), type 2 = zlib-compressed image
    cel = struct.pack("<Hhh", 0, 0, 0)            # layer index, x, y
    cel += struct.pack("<BH", 255, 2)             # opacity, cel type 2
    cel += struct.pack("<h", 0)                   # z-index
    cel += b"\x00" * 5                           # reserved
    cel += struct.pack("<HH", CANVAS, CANVAS)     # cel width, height
    cel += zlib.compress(img.tobytes(), 9)

    body = header + frame + chunk(0x2004, layer) + chunk(0x2019, palette) \
        + chunk(0x2005, cel)
    path.write_bytes(struct.pack("<I", len(body)) + body[4:])


def verify_aseprite(path: Path, sprite: Image.Image) -> None:
    """Read the file back and rebuild the image from it. No trust, no drift."""
    data = path.read_bytes()
    if struct.unpack_from("<I", data, 0)[0] != len(data):
        raise SystemExit("aseprite: header file size does not match file length")
    if struct.unpack_from("<H", data, 4)[0] != 0xA5E0:
        raise SystemExit("aseprite: bad magic")
    frames = struct.unpack_from("<H", data, 6)[0]
    width, height = struct.unpack_from("<HH", data, 8)
    depth = struct.unpack_from("<H", data, 12)[0]
    if (frames, width, height, depth) != (1, CANVAS, CANVAS, 32):
        raise SystemExit("aseprite: header says %r" % ((frames, width, height, depth),))

    pos = 128
    frame_size, frame_magic, old_chunks = struct.unpack_from("<IHH", data, pos)
    new_chunks = struct.unpack_from("<I", data, pos + 12)[0]
    if frame_size != 16 or frame_magic != 0xF1FA or old_chunks != 3 or new_chunks != 3:
        raise SystemExit("aseprite: bad frame header")
    pos += frame_size

    pixels, layer_name = None, None
    seen = 0
    for _ in range(new_chunks):
        size, kind = struct.unpack_from("<IH", data, pos)
        if size < 6:
            raise SystemExit("aseprite: chunk size %d" % size)
        body = data[pos + 6:pos + size]
        if kind == 0x2004:
            name_len = struct.unpack_from("<H", body, 16)[0]
            layer_name = body[18:18 + name_len].decode("utf-8")
        elif kind == 0x2019:
            count = struct.unpack_from("<I", body, 0)[0]
            if count != len(PALETTE):
                raise SystemExit("aseprite: palette count %d" % count)
        elif kind == 0x2005:
            cel_w, cel_h = struct.unpack_from("<HH", body, 16)
            pixels = zlib.decompress(body[20:])
            if len(pixels) != cel_w * cel_h * 4:
                raise SystemExit("aseprite: cel payload is %d bytes" % len(pixels))
        else:
            raise SystemExit("aseprite: unexpected chunk 0x%04X" % kind)
        pos += size
        seen += 1
    if seen != new_chunks or pos != len(data):
        raise SystemExit("aseprite: chunk sizes do not add up")
    if Image.frombytes("RGBA", (CANVAS, CANVAS), pixels).tobytes() != sprite.tobytes():
        raise SystemExit("aseprite: decoded pixels differ from the sprite")
    print("verified .aseprite: %d x %d, 1 frame, 1 layer %r, %d palette entries"
          % (width, height, layer_name, len(PALETTE)))


# ---------------------------------------------------------------------------
# Palette deliverables
# ---------------------------------------------------------------------------
def build_palette_png() -> Image.Image:
    cell, pad, cells = 46, 8, len(PALETTE)
    width = 16 + cells * (cell + pad)
    img = Image.new("RGBA", (width, 150), (24, 20, 28, 255))
    draw = ImageDraw.Draw(img)
    font = ImageFont.load_default()
    draw.text((16, 10), "GOTHIC VAMPIRE - %d-colour palette" % cells, font=font,
              fill=(238, 222, 232, 255))
    for i, (key, (hex_value, role)) in enumerate(PALETTE.items()):
        x = 16 + i * (cell + pad)
        img.paste(Image.new("RGBA", (cell, cell), hex_to_rgba(hex_value)), (x, 30))
        draw.rectangle([x, 30, x + cell - 1, 30 + cell - 1], outline=(84, 72, 90, 255))
        draw.text((x, 82), hex_value.upper(), font=font, fill=(232, 216, 226, 255))
        # role, wrapped one word per line, keeps the sheet legible
        for line, word in enumerate(role.split(" ")[:3]):
            draw.text((x, 96 + line * 11), word, font=font, fill=(168, 140, 158, 255))
    draw.text((16, 136), "nearest-neighbour only - no anti-aliasing, no gradients, "
              "no subpixel placement", font=font, fill=(122, 102, 118, 255))
    return img


def write_gpl(path: Path) -> None:
    lines = ["GIMP Palette", "Name: gothic vampire 32x32",
             "Columns: 11", "#"]
    for key, (hex_value, role) in PALETTE.items():
        r, g, b, _a = hex_to_rgba(hex_value)
        lines.append("%3d %3d %3d\t%s (%s)" % (r, g, b, role, key))
    path.write_text("\n".join(lines) + "\n")


# ---------------------------------------------------------------------------
# Previews - the ONLY place scaling happens, always Image.NEAREST
# ---------------------------------------------------------------------------
FLOOR = (34, 28, 38, 255)          # the arena floor tone the heroes are seen on


def zoomed(img: Image.Image, factor: int) -> Image.Image:
    return img.resize((CANVAS * factor, CANVAS * factor), Image.NEAREST)


def silhouette(sprite: Image.Image) -> Image.Image:
    """Flat mask: if the silhouette does not read on its own, the sprite fails."""
    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    for y in range(CANVAS):
        for x in range(CANVAS):
            if sprite.getpixel((x, y))[3]:
                out.putpixel((x, y), (238, 234, 242, 255))
    return out


def build_preview(sprite: Image.Image) -> Image.Image:
    font = ImageFont.load_default()
    big = zoomed(sprite, 14)                      # 448 x 448
    small = zoomed(sprite, 4)                     # 128 x 128
    pad, top = 20, 52
    strip_h = CANVAS + 18
    width = pad + big.width + pad + small.width + pad
    height = top + big.height + pad + strip_h + pad + 8
    img = Image.new("RGBA", (width, height), (20, 17, 23, 255))
    draw = ImageDraw.Draw(img)

    draw.text((pad, 12), "GOTHIC VAMPIRE GIRL - idle sprite", font=font,
              fill=(244, 228, 236, 255))
    draw.text((pad, 28), "exactly 32 x 32 px  |  transparent background  |  "
              "drawn at native size, never downscaled", font=font,
              fill=(158, 130, 148, 255))
    draw.text((pad, 40), "preview scaling: nearest-neighbour only",
              font=font, fill=(110, 92, 106, 255))

    # --- left: 14x on the arena floor tone
    floor = Image.new("RGBA", big.size, FLOOR)
    img.paste(floor, (pad, top))
    img.alpha_composite(big, (pad, top))

    # --- right column: 4x on white, silhouette, 1x tiles
    x = pad + big.width + pad
    light = Image.new("RGBA", small.size, (226, 222, 232, 255))
    img.paste(light, (x, top))
    img.alpha_composite(small, (x, top))
    draw.text((x, top + small.height + 4), "4x on white", font=font,
              fill=(150, 124, 140, 255))

    y = top + small.height + 22
    mask = zoomed(silhouette(sprite), 2)          # 64 x 64
    img.alpha_composite(mask, (x, y))
    draw.text((x + mask.width + 8, y + 24), "silhouette", font=font,
              fill=(150, 124, 140, 255))

    y = top + small.height + 22 + 64 + 12
    draw.text((x, y), "1x - actual size", font=font, fill=(150, 124, 140, 255))
    for shade, dx in ((FLOOR, 0), ((226, 222, 232, 255), 40)):
        box = Image.new("RGBA", (CANVAS, CANVAS), shade)
        img.paste(box, (x + dx, y + 11))
        img.alpha_composite(sprite, (x + dx, y + 11))
    return img


# ---------------------------------------------------------------------------
def main() -> None:
    validate()

    root = Path(__file__).resolve().parent.parent
    src = root / "assets" / "sprites" / "vampire"
    previews = root / "docs" / "images"
    src.mkdir(parents=True, exist_ok=True)
    previews.mkdir(parents=True, exist_ok=True)

    sprite = render()
    sprite.save(src / "vampire_idle.png")
    print("wrote", (src / "vampire_idle.png").relative_to(root), sprite.size,
          "RGBA")

    ase = src / "vampire_idle.aseprite"
    write_aseprite(sprite, ase)
    print("wrote", ase.relative_to(root), ase.stat().st_size, "bytes")
    verify_aseprite(ase, sprite)

    build_palette_png().save(src / "palette.png")
    print("wrote", (src / "palette.png").relative_to(root))

    write_gpl(src / "vampire.gpl")
    print("wrote", (src / "vampire.gpl").relative_to(root))

    zoomed(sprite, 16).save(previews / "vampire_idle_x16.png")
    zoomed(sprite, 32).save(previews / "vampire_idle_x32.png")
    build_preview(sprite).save(previews / "vampire_idle_preview.png")
    print("wrote", (previews / "vampire_idle_preview.png").relative_to(root))

    print("\n" + RULER)
    for y, row in enumerate(ROWS):
        print("%2d  %s" % (y, row))
    print(RULER)

    colours = sorted({ch for row in ROWS for ch in row} - {TRANSPARENT})
    print("colours used: %d/%d %s" % (len(colours), len(PALETTE),
                                      "".join(sorted(colours))))
    rows_used = [y for y, row in enumerate(ROWS) if row.strip(".")]
    print("vertical extent: y%d..y%d" % (rows_used[0], rows_used[-1]))


if __name__ == "__main__":
    main()
