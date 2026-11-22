#!/usr/bin/env python3
"""Shared 32-colour palette, top-left 4-step shader, selective selout, and
anatomical limb/mask primitives for the Hero Skeleton Spec (`docs/HERO_SKELETON_SPEC.md`).

Guarantees:
  - Shared 32-colour master palette: 8 material ramps x 4 steps
    (`shadow/selout`, `base`, `light`, `highlight`), zero `#000000`.
  - Consistent top-left directional light `(-0.68, -0.73)` across all heroes.
  - Selective selout: every 1px outline uses step 0 (`shadow`) of the adjacent
    material (never pure black `#000000`).
  - Binary alpha (`0` or `255`), `<= 24` colours per hero, `GROUND_Y = 80`.
  - `tapered_limb` & `cutout_poly` / `cutout_ellipse` so each hero has a bespoke
    anatomical skeleton with slender legs narrower than the torso and crisp
    silhouette cutouts (bow hoop, daylight between legs, etc.).
"""

from __future__ import annotations

import math
from PIL import Image, ImageDraw

CELL = 96
GROUND_Y = 80

# Shared 32-colour master ramp (8 materials x 4 steps: shadow/selout, base, light, highlight).
# Zero #000000 anywhere in the palette.
RAMPS: dict[str, tuple[tuple[int, int, int, int], ...]] = {
    # 1. Warm human/elven skin (selout #40262a)
    "skin": (
        (0x40, 0x26, 0x2A, 255),
        (0x9E, 0x62, 0x58, 255),
        (0xD9, 0x9B, 0x84, 255),
        (0xF4, 0xCD, 0xB8, 255),
    ),
    # 2. Tempered steel & dark plate (selout #1a2030)
    "steel": (
        (0x1A, 0x20, 0x30, 255),
        (0x46, 0x54, 0x6E, 255),
        (0x82, 0x96, 0xB5, 255),
        (0xC7, 0xD9, 0xF0, 255),
    ),
    # 3. Aged leather, wood & dark brown hair (selout #2b1a14)
    "leather": (
        (0x2B, 0x1A, 0x14, 255),
        (0x5C, 0x38, 0x28, 255),
        (0x94, 0x60, 0x43, 255),
        (0xC7, 0x90, 0x66, 255),
    ),
    # 4. Sunlit gold, brass & blonde hair (selout #4a2f12)
    "gold": (
        (0x4A, 0x2F, 0x12, 255),
        (0x9C, 0x68, 0x20, 255),
        (0xDE, 0xB0, 0x3C, 255),
        (0xFA, 0xE3, 0x8C, 255),
    ),
    # 5. Royal crimson cloth & blood magic (selout #380c1c)
    "crimson": (
        (0x38, 0x0C, 0x1C, 255),
        (0x82, 0x18, 0x32, 255),
        (0xCC, 0x2B, 0x4C, 255),
        (0xFA, 0x6E, 0x86, 255),
    ),
    # 6. Sylvan emerald cloth & forest gems (selout #132b22)
    "emerald": (
        (0x13, 0x2B, 0x22, 255),
        (0x25, 0x59, 0x3F, 255),
        (0x46, 0x96, 0x64, 255),
        (0x82, 0xD9, 0x96, 255),
    ),
    # 7. Moonlit porcelain & silver-white hair (selout #3a2d44)
    "moon": (
        (0x3A, 0x2D, 0x44, 255),
        (0x8C, 0x82, 0xA6, 255),
        (0xCF, 0xCB, 0xE3, 255),
        (0xF4, 0xF2, 0xFC, 255),
    ),
    # 8. Obsidian velvet, dark trousers & gothic boots (selout #161224)
    "obsidian": (
        (0x16, 0x12, 0x24, 255),
        (0x2E, 0x26, 0x47, 255),
        (0x52, 0x46, 0x78, 255),
        (0x80, 0x72, 0xAB, 255),
    ),
}

ALL_32_RGB = {col[:3] for ramp in RAMPS.values() for col in ramp}
assert len(ALL_32_RGB) == 32, f"Expected 32 unique colours, got {len(ALL_32_RGB)}"
assert (0, 0, 0) not in ALL_32_RGB, "Pure black #000000 is forbidden!"


class HeroCanvas:
    """96x96 pixel-art canvas with automatic top-left 4-step shading & selout."""

    def __init__(self, w: int = CELL, h: int = CELL) -> None:
        self.w = w
        self.h = h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self._px = self.img.load()

    def _shade_mask(
        self,
        mask: Image.Image,
        mat: str,
        bias: float = 0.0,
        selout: bool = True,
        spec_boost: bool = True,
    ) -> None:
        ramp = RAMPS[mat]
        bb = mask.getbbox()
        if bb is None:
            return
        x0, y0, x1, y1 = bb
        cx = 0.5 * (x0 + x1 - 1)
        cy = 0.5 * (y0 + y1 - 1)
        rx = max(0.5 * (x1 - x0), 1.2)
        ry = max(0.5 * (y1 - y0), 1.2)
        mpx = mask.load()

        for y in range(y0, y1):
            for x in range(x0, x1):
                if mpx[x, y] == 0:
                    continue
                is_edge = (
                    x == 0
                    or y == 0
                    or x == self.w - 1
                    or y == self.h - 1
                    or mpx[x - 1, y] == 0
                    or mpx[x + 1, y] == 0
                    or mpx[x, y - 1] == 0
                    or mpx[x, y + 1] == 0
                )
                if selout and is_edge:
                    self._px[x, y] = ramp[0]
                    continue

                nx = (x - cx) / rx
                ny = (y - cy) / ry
                light = (-0.68 * nx - 0.73 * ny) - 0.16 * (nx * nx + ny * ny) + bias

                if spec_boost and light >= 0.44:
                    step = 3
                elif light >= -0.06:
                    step = 2
                elif light >= -0.54:
                    step = 1
                else:
                    step = 0
                self._px[x, y] = ramp[step]

    def poly(
        self,
        pts: list[tuple[float, float]],
        mat: str,
        bias: float = 0.0,
        selout: bool = True,
        spec_boost: bool = True,
    ) -> None:
        mask = Image.new("L", (self.w, self.h), 0)
        d = ImageDraw.Draw(mask)
        ipts = [(int(round(x)), int(round(y))) for x, y in pts]
        d.polygon(ipts, fill=255)
        self._shade_mask(mask, mat, bias=bias, selout=selout, spec_boost=spec_boost)

    def ellipse(
        self,
        cx: float,
        cy: float,
        rx: float,
        ry: float,
        mat: str,
        bias: float = 0.0,
        selout: bool = True,
        spec_boost: bool = True,
    ) -> None:
        mask = Image.new("L", (self.w, self.h), 0)
        d = ImageDraw.Draw(mask)
        d.ellipse(
            [
                int(round(cx - rx)),
                int(round(cy - ry)),
                int(round(cx + rx)),
                int(round(cy + ry)),
            ],
            fill=255,
        )
        self._shade_mask(mask, mat, bias=bias, selout=selout, spec_boost=spec_boost)

    def rrect(
        self,
        x0: float,
        y0: float,
        x1: float,
        y1: float,
        radius: int,
        mat: str,
        bias: float = 0.0,
        selout: bool = True,
        spec_boost: bool = True,
    ) -> None:
        mask = Image.new("L", (self.w, self.h), 0)
        d = ImageDraw.Draw(mask)
        d.rounded_rectangle(
            [int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))],
            radius=radius,
            fill=255,
        )
        self._shade_mask(mask, mat, bias=bias, selout=selout, spec_boost=spec_boost)

    def tapered_limb(
        self,
        x0: float,
        y0: float,
        r0: float,
        x1: float,
        y1: float,
        r1: float,
        mat: str,
        bias: float = 0.0,
        selout: bool = True,
    ) -> None:
        """Anatomical tapered limb with exact sub-pixel capsule distance."""
        mask = Image.new("L", (self.w, self.h), 0)
        mpx = mask.load()
        dx, dy = x1 - x0, y1 - y0
        len_sq = dx * dx + dy * dy
        rmax = max(r0, r1) + 1.5
        bx0 = max(0, int(math.floor(min(x0, x1) - rmax)))
        bx1 = min(self.w - 1, int(math.ceil(max(x0, x1) + rmax)))
        by0 = max(0, int(math.floor(min(y0, y1) - rmax)))
        by1 = min(self.h - 1, int(math.ceil(max(y0, y1) + rmax)))

        for py in range(by0, by1 + 1):
            for px in range(bx0, bx1 + 1):
                if len_sq <= 1e-6:
                    t = 0.0
                else:
                    t = max(0.0, min(1.0, ((px - x0) * dx + (py - y0) * dy) / len_sq))
                cx = x0 + dx * t
                cy = y0 + dy * t
                r = r0 + (r1 - r0) * t
                if (px - cx) ** 2 + (py - cy) ** 2 <= r * r:
                    mpx[px, py] = 255
        self._shade_mask(mask, mat, bias=bias, selout=selout, spec_boost=True)

    def limb(
        self,
        x0: float,
        y0: float,
        x1: float,
        y1: float,
        r: float,
        mat: str,
        bias: float = 0.0,
        selout: bool = True,
    ) -> None:
        self.tapered_limb(x0, y0, r, x1, y1, r, mat, bias=bias, selout=selout)

    def erase_poly(self, pts: list[tuple[float, float]], border_mat: str | None = None) -> None:
        """Carve a crisp transparent negative-space opening (with optional selout border)."""
        mask = Image.new("L", (self.w, self.h), 0)
        d = ImageDraw.Draw(mask)
        ipts = [(int(round(x)), int(round(y))) for x, y in pts]
        d.polygon(ipts, fill=255)
        mpx = mask.load()
        bb = mask.getbbox()
        if bb is None:
            return
        for y in range(bb[1], bb[3]):
            for x in range(bb[0], bb[2]):
                if mpx[x, y] > 0:
                    self._px[x, y] = (0, 0, 0, 0)
        if border_mat is not None:
            sel = RAMPS[border_mat][0]
            for y in range(max(0, bb[1] - 1), min(self.h, bb[3] + 1)):
                for x in range(max(0, bb[0] - 1), min(self.w, bb[2] + 1)):
                    if self._px[x, y][3] == 0:
                        continue
                    for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                        if 0 <= nx < self.w and 0 <= ny < self.h and mpx[nx, ny] > 0:
                            self._px[x, y] = sel
                            break

    def dot(self, x: int, y: int, mat: str, step: int) -> None:
        ix, iy = int(round(x)), int(round(y))
        if 0 <= ix < self.w and 0 <= iy < self.h:
            self._px[ix, iy] = RAMPS[mat][max(0, min(3, step))]

    def stroke(
        self,
        x0: float,
        y0: float,
        x1: float,
        y1: float,
        mat: str,
        step: int,
        width: int = 1,
    ) -> None:
        col = RAMPS[mat][max(0, min(3, step))]
        steps = max(int(math.hypot(x1 - x0, y1 - y0) * 2.5), 2)
        half = (width - 1) / 2.0
        for i in range(steps + 1):
            t = i / float(steps)
            px = x0 + (x1 - x0) * t
            py = y0 + (y1 - y0) * t
            if width <= 1:
                ix, iy = int(round(px)), int(round(py))
                if 0 <= ix < self.w and 0 <= iy < self.h:
                    self._px[ix, iy] = col
            else:
                for oy in range(int(math.floor(py - half)), int(math.ceil(py + half)) + 1):
                    for ox in range(int(math.floor(px - half)), int(math.ceil(px + half)) + 1):
                        if 0 <= ox < self.w and 0 <= oy < self.h:
                            self._px[ox, oy] = col

    def arc_stroke(
        self,
        cx: float,
        cy: float,
        rx: float,
        ry: float,
        deg0: float,
        deg1: float,
        mat: str,
        step: int,
        width: int = 1,
        selout_wrap: bool = False,
    ) -> None:
        steps = max(int(abs(deg1 - deg0) * 0.9), 8)
        pts = []
        for i in range(steps + 1):
            a = math.radians(deg0 + (deg1 - deg0) * (i / float(steps)))
            pts.append((cx + math.cos(a) * rx, cy + math.sin(a) * ry))
        if selout_wrap:
            for idx in range(len(pts) - 1):
                self.stroke(pts[idx][0], pts[idx][1], pts[idx + 1][0], pts[idx + 1][1], mat, 0, width + 2)
        for idx in range(len(pts) - 1):
            t = idx / float(max(len(pts) - 1, 1))
            st = min(3, step + (1 if t < 0.35 else 0)) if selout_wrap else step
            self.stroke(pts[idx][0], pts[idx][1], pts[idx + 1][0], pts[idx + 1][1], mat, st, width)

    def finalize(self, ground_y: int = GROUND_Y) -> Image.Image:
        """Snap bottom pixel row to `ground_y` with ZERO scaling (preserves exact skeleton!)."""
        bb = self.img.getbbox()
        if bb is None:
            return self.img
        x0, y0, x1, y1 = bb
        w = x1 - x0
        h = y1 - y0
        crop = self.img.crop(bb)
        if h > ground_y:
            crop = crop.crop((0, h - ground_y, w, h))
            h = ground_y
        nx = max(0, min(self.w - w, x0))
        ny = ground_y - h
        out = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        out.alpha_composite(crop, (nx, ny))
        return out
