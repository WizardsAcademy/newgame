#!/usr/bin/env python
"""Generate the Forest Colossus boss sprite (48x48, single frame).

Precedent: the golem/slime sprites are single-frame PNGs and the juice
(idle bob, walk bounce, telegraph stretch) is done with tweens in the
enemy scripts - see golem.gd. The boss follows the same pattern, so one
big readable frame is all we need. Re-run after editing:

    python tools/make_colossus_sprite.py
"""
from PIL import Image, ImageDraw

SCALE = 8            # draw 8x, downscale with NEAREST for crisp pixels
SIZE = 48            # final texture size (single frame)

# palette: forest colossus = ancient tree-trunk body over stone roots
BARK      = (94, 66, 44)
BARK_DARK = (66, 45, 30)
BARK_LITE = (121, 88, 58)
MOSS      = (78, 122, 58)
MOSS_DARK = (56, 90, 42)
ROOTS     = (74, 60, 40)
EYE       = (232, 163, 61)   # amber glow
EYE_HOT   = (255, 214, 120)
CANVAS    = (0, 0, 0, 0)

img = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE), CANVAS)
d = ImageDraw.Draw(img)
S = SCALE


def rect(x, y, w, h, color):
    d.rectangle([x * S, y * S, (x + w) * S - 1, (y + h) * S - 1], fill=color)


# ---------------- root legs (wide stance ---------------------
rect(8,  34, 8, 10, ROOTS)
rect(32, 34, 8, 10, ROOTS)
rect(10, 40, 10, 4, BARK_DARK)
rect(28, 40, 10, 4, BARK_DARK)

# ---------------- torso (big barrel trunk) -------------------
rect(12, 14, 24, 22, BARK)
rect(12, 14, 24, 3, BARK_LITE)          # top light
rect(12, 32, 24, 4, BARK_DARK)          # bottom shade
rect(14, 14, 2, 22, BARK_DARK)          # left rim
rect(32, 14, 2, 22, BARK_DARK)          # right rim
# bark streaks
rect(18, 18, 2, 14, BARK_DARK)
rect(24, 16, 2, 18, BARK_DARK)
rect(29, 20, 2, 12, MOSS_DARK)

# ---------------- moss cap (the "head") ----------------------
rect(10, 8, 28, 7, MOSS)
rect(12, 6, 24, 3, MOSS)
rect(16, 4, 12, 3, MOSS)
rect(10, 13, 28, 2, MOSS_DARK)
rect(14, 5, 8, 2, (96, 142, 70))        # moss highlights
rect(24, 8, 10, 2, (96, 142, 70))

# ---------------- eyes (amber, menacing) --------------------
rect(18, 17, 4, 3, EYE)
rect(27, 17, 4, 3, EYE)
rect(20, 18, 2, 1, EYE_HOT)
rect(29, 18, 2, 1, EYE_HOT)

# ---------------- arms (heavy branch limbs) ------------------
rect(4, 16, 8, 6, BARK)                 # left upper arm
rect(2, 20, 6, 5, BARK_DARK)            # left fist
rect(36, 16, 8, 6, BARK)                # right upper arm
rect(40, 20, 6, 5, BARK_DARK)           # right fist
rect(4, 15, 8, 2, MOSS)                 # moss on shoulders
rect(36, 15, 8, 2, MOSS)

img = img.resize((SIZE, SIZE), Image.NEAREST)
img.save("assets/textures/colossus_forest.png")
print("wrote assets/textures/colossus_forest.png", img.size)
