#!/usr/bin/env python
"""Generate the pixel art for every painted shape on the arena floor.

WHY THIS FILE EXISTS
  `_draw()` circles are vectors: Godot rasterises them at the window
  resolution, so an acid pool drawn with `draw_circle()` looked like a smooth
  vector ring sitting *under* a pixel-art world - the one thing that broke the
  art direction of the slime family. These hazards now use hand-generated 1:1
  pixel art: one texture pixel == one game pixel, so the game's canvas_items
  stretch + nearest filter keeps them crisp and chunky.

  The elite aura is here for the same reason: it was a 24-segment Line2D,
  i.e. the last smooth vector circle drawn under a pixel-art enemy.

  Re-running this file is the single source of truth:

      python tools/make_fx_sprites.py

  Writes:
      assets/textures/fx_acid_pool.png     4 frames x 64x64   (bubble loop)
      assets/textures/fx_blast_ring.png    8 frames x 96x96   (ember fuse)
      assets/textures/fx_blast_burst.png   5 frames x 96x96   (detonation)
      assets/textures/fx_gold_ring.png     1 frame  x 32x32   (elite aura)
      docs/images/slime_hazards_preview.png (review sheet)

  Radius contract - keep in sync with scripts/fx/*.gd:
      acid pool   : 26 px radius (damage) == 26 px of art
      ember fuse  : 44 px radius (damage) == 44 px of art
  A telegraph that lies is worse than no telegraph, so the art is drawn at
  exactly the damaging radius and never scaled at runtime.
"""

import math

from PIL import Image, ImageDraw, ImageFont

# ---------------------------------------------------------------------------
# Palettes (mirror the slime variants: acid violet, ember orange)
# ---------------------------------------------------------------------------
ACID = {
    "rim":   (38, 20, 56, 255),
    "deep":  (72, 38, 108, 255),
    "mid":   (112, 64, 160, 255),
    "light": (150, 94, 200, 255),
    "glint": (206, 158, 246, 255),
}

FIRE = {
    "soot":  (58, 22, 10, 255),
    "deep":  (150, 52, 16, 255),
    "edge":  (255, 138, 48, 255),
    "glow":  (255, 198, 124, 255),
    "core":  (255, 246, 214, 255),
}

POOL_RADIUS = 26.0
POOL_FRAMES = 4
POOL_SIZE = 64

GOLD = {
    "rim":  (122, 88, 14, 255),
    "edge": (214, 162, 40, 255),
    "core": (255, 230, 130, 255),
}
GOLD_RING_SIZE = 32
GOLD_RING_RADIUS = 14.0

BLAST_RADIUS = 44.0
RING_FRAMES = 8
BURST_FRAMES = 5
BLAST_SIZE = 96

BG = (20, 24, 28, 255)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _wobble(theta: float, seed: float) -> float:
    """Organic radius multiplier: a puddle, not a circle."""
    return (1.0
            + 0.085 * math.sin(3.0 * theta + seed)
            + 0.050 * math.sin(5.0 * theta + 2.1 * seed)
            + 0.030 * math.sin(7.0 * theta + 0.7 * seed))


def _put(px, size: int, x: int, y: int, colour) -> None:
    if 0 <= x < size and 0 <= y < size:
        px[x, y] = colour


def _bubble(img: Image.Image, cx: float, cy: float, r: int, light) -> None:
    """A 2-3 px pixel bubble: dark rim, light body, one specular pixel."""
    px = img.load()
    size = img.size[0]
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy > r * r + 0.4:
                continue
            edge = abs(dx) == r or abs(dy) == r
            _put(px, size, int(cx + dx), int(cy + dy),
                 ACID["deep"] if edge else light)
    _put(px, size, int(cx - r + 1), int(cy - r + 1), ACID["glint"])


# ---------------------------------------------------------------------------
# 1. Acid pool - four frames of bubbles rising and popping
# ---------------------------------------------------------------------------
def acid_pool_frame(phase: int) -> Image.Image:
    size = POOL_SIZE
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    centre = size / 2.0

    for y in range(size):
        for x in range(size):
            dx = x + 0.5 - centre
            dy = y + 0.5 - centre
            dist = math.hypot(dx, dy)
            if dist <= 0.001:
                px[x, y] = ACID["light"]
                continue
            theta = math.atan2(dy, dx)
            outer = POOL_RADIUS * _wobble(theta, 1.7)
            t = dist / outer
            if t > 1.0:
                continue
            if t > 0.90:
                colour = ACID["rim"]
            elif t > 0.72:
                colour = ACID["deep"]
            elif t > 0.62:
                # Thin dithered seam between bands: the classic pixel-art way
                # to blend two flat tones without a third colour.
                colour = ACID["mid"] if (x + y) % 2 == 0 else ACID["deep"]
            elif t > 0.34:
                colour = ACID["mid"]
            elif t > 0.26:
                colour = ACID["light"] if (x + y) % 2 == 0 else ACID["mid"]
            else:
                colour = ACID["light"]
            px[x, y] = colour

    # Five bubbles, each on its own loop so the surface never "breathes in
    # sync" (which is what makes procedural loops look cheap).
    for i in range(5):
        angle = i * 2.399 + 0.6
        spread = POOL_RADIUS * (0.20 + 0.48 * ((i * 0.37) % 1.0))
        bx = centre + math.cos(angle) * spread
        by = centre + math.sin(angle) * spread
        t = ((phase / POOL_FRAMES) + i * 0.23) % 1.0
        if t > 0.82:          # popped: gone for the rest of the cycle
            continue
        r = 2 if (i % 2) else 3
        if t > 0.62:
            r = 1             # shrinks as it rises, then pops
        _bubble(img, bx, by - t * 7.0, r, ACID["glint"])

    return img


# ---------------------------------------------------------------------------
# 2. Ember fuse - eight frames of a charge meter made of pixels
# ---------------------------------------------------------------------------
def _row_span(dy: float, radius: float) -> float:
    inner = radius * radius - dy * dy
    return math.sqrt(inner) if inner > 0.0 else 0.0


def blast_ring_frame(charge: float) -> Image.Image:
    size = BLAST_SIZE
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    centre = size / 2.0
    fill_radius = BLAST_RADIUS * charge
    thickness = 2.6

    for y in range(size):
        dy = y + 0.5 - centre
        outer_half = _row_span(dy, BLAST_RADIUS)
        inner_half = _row_span(dy, BLAST_RADIUS - thickness)
        for x in range(size):
            dx = x + 0.5 - centre
            dist = math.hypot(dx, dy)
            if inner_half < abs(dx) <= outer_half:
                # Outline: dithered between the two oranges so the ring has
                # texture instead of reading as a vector stroke.
                px[x, y] = FIRE["core"] if (x + y) % 3 == 0 else FIRE["edge"]
            elif dist <= fill_radius:
                # Charged interior: a 50 % dither that gets denser as the
                # fuse burns down (2 tones is all a 1-pixel grid can carry).
                dense = charge > 0.6
                if (x + y) % 2 == 0 or (dense and (x + y) % 4 == 0):
                    px[x, y] = FIRE["deep"] if not dense else FIRE["edge"]
    return img


# ---------------------------------------------------------------------------
# 3. Detonation - five frames of an expanding shockwave
# ---------------------------------------------------------------------------
def blast_burst_frame(index: int) -> Image.Image:
    size = BLAST_SIZE
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    centre = size / 2.0
    t = index / float(BURST_FRAMES - 1)          # 0 -> 1 across the burst
    ring_radius = BLAST_RADIUS * (0.30 + 0.70 * t)
    thickness = 3.4 - 1.6 * t

    for y in range(size):
        dy = y + 0.5 - centre
        outer_half = _row_span(dy, ring_radius)
        inner_half = _row_span(dy, ring_radius - thickness)
        for x in range(size):
            dx = x + 0.5 - centre
            if inner_half < abs(dx) <= outer_half:
                px[x, y] = FIRE["core"] if t < 0.35 else FIRE["glow"]

    # Hot core for the first two frames only, dithered so it still reads as
    # pixel art instead of a flat vector blob.
    if index < 2:
        core_r = BLAST_RADIUS * (0.42 - 0.16 * index)
        for y in range(size):
            dy = y + 0.5 - centre
            half = _row_span(dy, core_r)
            for x in range(size):
                if abs(x + 0.5 - centre) <= half:
                    edge = y % 2 == 0
                    px[x, y] = FIRE["glow"] if edge else FIRE["core"]

    # Sparks flung out: short 2 px dashes along 10 directions.
    spark_len = 3 + index
    for i in range(10):
        angle = i * (math.tau / 10.0) + 0.3
        for step in range(spark_len):
            dist = ring_radius + 2 + step
            x = int(centre + math.cos(angle) * dist)
            y = int(centre + math.sin(angle) * dist)
            _put(px, size, x, y, FIRE["edge"] if step % 2 == 0 else FIRE["deep"])

    return img


# ---------------------------------------------------------------------------
# 4. Elite aura - the golden ring under a hero-version enemy (bonus fix)
# ---------------------------------------------------------------------------
def gold_ring_frame() -> Image.Image:
    """A 32x32 pixel-art ring, radius 14 px: the tower's floor ring.

    Same reason as the hazards: a Line2D polygon is a smooth vector ring and
    reads as UI floating under a pixel-art enemy.
    """
    size = GOLD_RING_SIZE
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    centre = size / 2.0
    outer = GOLD_RING_RADIUS + 1.0
    inner = GOLD_RING_RADIUS - 1.6

    for y in range(size):
        dy = y + 0.5 - centre
        for x in range(size):
            dx = x + 0.5 - centre
            dist = math.hypot(dx, dy)
            if not (inner <= dist <= outer):
                continue
            if dist > outer - 0.9:
                colour = GOLD["rim"]
            elif dist > inner + 0.9:
                colour = GOLD["core"]
            else:
                colour = GOLD["edge"]
            px[x, y] = colour

    # Four specular ticks so the ring sparkles instead of looking stamped.
    for i in range(4):
        angle = i * (math.tau / 4.0) + math.pi / 4.0
        x = int(centre + math.cos(angle) * (GOLD_RING_RADIUS + 0.5))
        y = int(centre + math.sin(angle) * (GOLD_RING_RADIUS + 0.5))
        _put(px, size, x, y, (255, 250, 210, 255))
    return img


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
def strip(frames) -> Image.Image:
    width = frames[0].size[0]
    height = frames[0].size[1]
    sheet = Image.new("RGBA", (width * len(frames), height), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * width, 0))
    return sheet


def _font(size: int):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def preview(pool: Image.Image, ring: Image.Image, burst: Image.Image,
            gold: Image.Image) -> Image.Image:
    """One review sheet: every hazard strip, at a readable zoom."""
    pad = 12
    rows = [
        (pool, POOL_FRAMES, 4, "ACID POOL  -  r 26, 4-frame bubble loop"),
        (ring, RING_FRAMES, 2, "EMBER FUSE  -  r 44, 8 charge frames"),
        (burst, BURST_FRAMES, 2, "DETONATION  -  5 frames, plays over 0.35 s"),
        (gold, 1, 5, "ELITE AURA  -  r 14 gold ring (was a Line2D)"),
    ]

    def row_height(source: Image.Image, zoom: int) -> int:
        return 26 + source.size[1] * zoom + 14

    width = pad
    for source, count, zoom, _title in rows:
        frame_w = (source.size[0] // count) * zoom
        width = max(width, pad + count * (frame_w + pad))
    height = pad + sum(row_height(src, zoom) for src, _c, zoom, _t in rows) + pad

    img = Image.new("RGBA", (width, height), BG)
    draw = ImageDraw.Draw(img)
    title, label = _font(18), _font(14)

    y = pad
    for source, count, zoom, text in rows:
        draw.text((pad, y), text, font=title, fill=(232, 240, 232, 255))
        y += 26
        frame_w = source.size[0] // count
        for i in range(count):
            frame = source.crop((i * frame_w, 0, (i + 1) * frame_w, source.size[1]))
            big = frame.resize((frame_w * zoom, source.size[1] * zoom), Image.NEAREST)
            img.alpha_composite(big, (pad + i * (big.size[0] + pad), y))
            draw.text((pad + i * (big.size[0] + pad) + 2, y + big.size[1] + 1),
                      str(i), font=label, fill=(150, 170, 160, 255))
        y += row_height(source, zoom) - 26 + 12
    return img


def main() -> None:
    pool = strip([acid_pool_frame(i) for i in range(POOL_FRAMES)])
    ring = strip([blast_ring_frame(i / float(RING_FRAMES)) for i in range(RING_FRAMES)])
    burst = strip([blast_burst_frame(i) for i in range(BURST_FRAMES)])

    gold = gold_ring_frame()
    pool.save("assets/textures/fx_acid_pool.png")
    ring.save("assets/textures/fx_blast_ring.png")
    burst.save("assets/textures/fx_blast_burst.png")
    gold.save("assets/textures/fx_gold_ring.png")

    import os
    os.makedirs("docs/images", exist_ok=True)
    preview(pool, ring, burst, gold).save("docs/images/slime_hazards_preview.png")

    print("wrote assets/textures/fx_acid_pool.png ", pool.size,
          "-> hframes", POOL_FRAMES)
    print("wrote assets/textures/fx_blast_ring.png", ring.size,
          "-> hframes", RING_FRAMES)
    print("wrote assets/textures/fx_blast_burst.png", burst.size,
          "-> hframes", BURST_FRAMES)
    print("wrote assets/textures/fx_gold_ring.png   ", gold.size, "-> 1 frame")
    print("wrote docs/images/slime_hazards_preview.png")


if __name__ == "__main__":
    main()
