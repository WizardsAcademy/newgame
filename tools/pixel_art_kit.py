#!/usr/bin/env python3
"""Aseprite-style layered pixel-art toolkit for hand-crafted dark-fantasy heroes.

100% procedural pixel-art engine: zero external images are read or copied.
Provides:
  - `Layer`: RGBA + ramp-index pixel buffer supporting scanline polygons,
    tapered bezier ribbons (hair locks, tattered cloak strips, fur tufts,
    curved bow limbs, crescent blades), capsules/limbs, circles, ellipses,
    per-material directional lighting + subtle 2x2 Bayer pixel dithering,
    and selective 1px hue-tinted outlines before compositing!
"""
from __future__ import annotations

import math
from typing import Sequence, Tuple
import numpy as np
from PIL import Image

RGBA = Tuple[int, int, int, int]

# 2x2 ordered Bayer matrix normalized to [-0.5, +0.5] for crisp pixel dithering
BAYER2 = np.array([[-0.375, 0.125], [0.375, -0.125]], dtype=np.float32)


def hex_rgba(h: str, a: int = 255) -> RGBA:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def lerp_col(c1: RGBA, c2: RGBA, t: float) -> RGBA:
    t = max(0.0, min(1.0, t))
    return (
        int(round(c1[0] + (c2[0] - c1[0]) * t)),
        int(round(c1[1] + (c2[1] - c1[1]) * t)),
        int(round(c1[2] + (c2[2] - c1[2]) * t)),
        int(round(c1[3] + (c2[3] - c1[3]) * t)),
    )


class Layer:
    """Single Aseprite-style pixel layer with crisp 1px primitives & shading."""

    def __init__(self, w: int, h: int) -> None:
        self.w = w
        self.h = h
        self.buf = np.zeros((h, w, 4), dtype=np.uint8)

    def copy(self) -> "Layer":
        out = Layer(self.w, self.h)
        out.buf[:] = self.buf
        return out

    def pset(self, x: int, y: int, col: RGBA) -> None:
        if 0 <= x < self.w and 0 <= y < self.h and col[3] > 0:
            if col[3] >= 255 or self.buf[y, x, 3] == 0:
                self.buf[y, x] = col
            else:
                sa = col[3] / 255.0
                da = self.buf[y, x, 3] / 255.0
                oa = sa + da * (1.0 - sa)
                if oa > 1e-5:
                    for c in range(3):
                        self.buf[y, x, c] = int(
                            round((col[c] * sa + self.buf[y, x, c] * da * (1.0 - sa)) / oa)
                        )
                    self.buf[y, x, 3] = int(round(oa * 255.0))

    def pget(self, x: int, y: int) -> RGBA:
        if 0 <= x < self.w and 0 <= y < self.h:
            p = self.buf[y, x]
            return (int(p[0]), int(p[1]), int(p[2]), int(p[3]))
        return (0, 0, 0, 0)

    def line(self, x0: float, y0: float, x1: float, y1: float, col: RGBA, r: float = 0.0) -> None:
        ix0, iy0 = int(round(x0)), int(round(y0))
        ix1, iy1 = int(round(x1)), int(round(y1))
        dx = abs(ix1 - ix0)
        dy = -abs(iy1 - iy0)
        sx = 1 if ix0 < ix1 else -1
        sy = 1 if iy0 < iy1 else -1
        err = dx + dy
        while True:
            if r <= 0.45:
                self.pset(ix0, iy0, col)
            else:
                self.disc(ix0, iy0, r, col)
            if ix0 == ix1 and iy0 == iy1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                ix0 += sx
            if e2 <= dx:
                err += dx
                iy0 += sy

    def disc(self, cx: float, cy: float, r: float, col: RGBA) -> None:
        x_min = max(0, int(math.floor(cx - r - 0.5)))
        x_max = min(self.w - 1, int(math.ceil(cx + r + 0.5)))
        y_min = max(0, int(math.floor(cy - r - 0.5)))
        y_max = min(self.h - 1, int(math.ceil(cy + r + 0.5)))
        r2 = (r + 0.22) * (r + 0.22)
        for y in range(y_min, y_max + 1):
            dy2 = (y - cy) * (y - cy)
            for x in range(x_min, x_max + 1):
                if (x - cx) * (x - cx) + dy2 <= r2:
                    self.pset(x, y, col)

    def ellipse(
        self, cx: float, cy: float, rx: float, ry: float, col: RGBA, angle_deg: float = 0.0
    ) -> None:
        ang = math.radians(angle_deg)
        ca, sa = math.cos(ang), math.sin(ang)
        rmax = max(rx, ry) + 1.0
        x_min = max(0, int(math.floor(cx - rmax)))
        x_max = min(self.w - 1, int(math.ceil(cx + rmax)))
        y_min = max(0, int(math.floor(cy - rmax)))
        y_max = min(self.h - 1, int(math.ceil(cy + rmax)))
        rx2 = max(rx, 0.45) ** 2
        ry2 = max(ry, 0.45) ** 2
        for y in range(y_min, y_max + 1):
            dy = y - cy
            for x in range(x_min, x_max + 1):
                dx = x - cx
                ux = dx * ca + dy * sa
                uy = -dx * sa + dy * ca
                if (ux * ux) / rx2 + (uy * uy) / ry2 <= 1.05:
                    self.pset(x, y, col)

    def capsule(
        self, x0: float, y0: float, x1: float, y1: float, r0: float, r1: float, col: RGBA
    ) -> None:
        steps = max(2, int(math.hypot(x1 - x0, y1 - y0) * 2.0) + 2)
        for i in range(steps + 1):
            t = i / steps
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            r = r0 + (r1 - r0) * t
            self.disc(x, y, r, col)

    def poly(self, pts: Sequence[Tuple[float, float]], col: RGBA) -> None:
        if len(pts) < 3:
            return
        ys = [p[1] for p in pts]
        y_min = max(0, int(math.floor(min(ys))))
        y_max = min(self.h - 1, int(math.ceil(max(ys))))
        n = len(pts)
        for y in range(y_min, y_max + 1):
            py = y + 0.5
            xs = []
            for i in range(n):
                x0, y0 = pts[i]
                x1, y1 = pts[(i + 1) % n]
                if (y0 <= py < y1) or (y1 <= py < y0):
                    t = (py - y0) / (y1 - y0)
                    xs.append(x0 + t * (x1 - x0))
            xs.sort()
            for k in range(0, len(xs) - 1, 2):
                xa = max(0, int(math.ceil(xs[k] - 0.5)))
                xb = min(self.w - 1, int(math.floor(xs[k + 1] + 0.5)))
                for x in range(xa, xb + 1):
                    self.pset(x, y, col)

    def ribbon(
        self,
        ctrl: Sequence[Tuple[float, float]],
        r_start: float,
        r_end: float,
        col: RGBA,
        steps: int = 24,
    ) -> None:
        """Draw a smooth quadratic/cubic bezier tapered ribbon (cloak, hair, fur, slash)."""
        n = len(ctrl)
        if n < 2:
            return
        for i in range(steps + 1):
            t = i / steps
            if n == 2:
                x = ctrl[0][0] + (ctrl[1][0] - ctrl[0][0]) * t
                y = ctrl[0][1] + (ctrl[1][1] - ctrl[0][1]) * t
            elif n == 3:
                u = 1.0 - t
                x = u * u * ctrl[0][0] + 2 * u * t * ctrl[1][0] + t * t * ctrl[2][0]
                y = u * u * ctrl[0][1] + 2 * u * t * ctrl[1][1] + t * t * ctrl[2][1]
            else:
                u = 1.0 - t
                x = (
                    u**3 * ctrl[0][0]
                    + 3 * u * u * t * ctrl[1][0]
                    + 3 * u * t * t * ctrl[2][0]
                    + t**3 * ctrl[3][0]
                )
                y = (
                    u**3 * ctrl[0][1]
                    + 3 * u * u * t * ctrl[1][1]
                    + 3 * u * t * t * ctrl[2][1]
                    + t**3 * ctrl[3][1]
                )
            r = r_start + (r_end - r_start) * t
            if r <= 0.45:
                self.pset(int(round(x)), int(round(y)), col)
            else:
                self.disc(x, y, r, col)

    def shade_ramp(
        self,
        ramp: Sequence[RGBA],
        light_dir: Tuple[float, float] = (-0.65, -0.75),
        dither: float = 0.28,
        rim_right: bool = False,
    ) -> "Layer":
        """Apply volumetric pixel-art ramp shading across all opaque pixels in this layer!

        Uses signed distance inside the silhouette + directional light gradient
        + subtle 2x2 Bayer ordered pixel dithering so flat shapes turn into
        hand-shaded Aseprite pixel art!
        """
        mask = self.buf[:, :, 3] > 0
        if not np.any(mask):
            return self
        ys, xs = np.where(mask)
        x0, x1 = int(xs.min()), int(xs.max())
        y0, y1 = int(ys.min()), int(ys.max())
        cx = 0.5 * (x0 + x1)
        cy = 0.5 * (y0 + y1)
        rx = max(1.5, 0.5 * (x1 - x0 + 1))
        ry = max(1.5, 0.5 * (y1 - y0 + 1))

        lx, ly = light_dir
        ln = max(1e-5, math.hypot(lx, ly))
        lx, ly = lx / ln, ly / ln

        # Compute 1px boundary mask for bevel/depth
        padded = np.pad(mask, 1, mode="constant", constant_values=False)
        interior = (
            padded[1:-1, 1:-1]
            & padded[:-2, 1:-1]
            & padded[2:, 1:-1]
            & padded[1:-1, :-2]
            & padded[1:-1, 2:]
        )

        m = len(ramp)
        for y, x in zip(ys, xs):
            nx = (x - cx) / rx
            ny = (y - cy) / ry
            # Directional dot product: lit where (nx, ny) aligns with light_dir
            dot = nx * lx + ny * ly  # in roughly [-1.2, +1.2]
            # Spherical dome falloff keeps center fuller than raw edges
            dome = max(0.0, 1.0 - 0.35 * (nx * nx + ny * ny))
            val = 0.50 + 0.38 * dot + 0.14 * (dome - 0.5)
            if not interior[y, x]:
                # Edge bevel: top-left edge catches light, bottom-right edge deepens shadow
                if dot < 0.05:
                    val -= 0.16
                elif rim_right and nx > 0.35:
                    val += 0.18
            if rim_right and interior[y, x] and nx > 0.55 and ny < 0.25:
                val += 0.14

            val += dither * float(BAYER2[y & 1, x & 1]) / max(m - 1, 1) * 1.8
            idx = int(round(max(0.0, min(1.0, val)) * (m - 1)))
            c = ramp[idx]
            self.buf[y, x, 0] = c[0]
            self.buf[y, x, 1] = c[1]
            self.buf[y, x, 2] = c[2]
        return self

    def outline(self, out_col: RGBA, skip_bottom_y: int | None = None) -> "Layer":
        """Add a crisp 1px Aseprite outer/eroded silhouette outline on empty neighbors."""
        mask = self.buf[:, :, 3] > 128
        if not np.any(mask):
            return self
        padded = np.pad(mask, 1, mode="constant", constant_values=False)
        dilated = (
            padded[:-2, 1:-1]
            | padded[2:, 1:-1]
            | padded[1:-1, :-2]
            | padded[1:-1, 2:]
        )
        ring = dilated & (~mask)
        ys, xs = np.where(ring)
        for y, x in zip(ys, xs):
            if skip_bottom_y is not None and y > skip_bottom_y:
                continue
            self.buf[y, x] = out_col
        return self

    def blit_onto(self, dst: "Layer", dx: int = 0, dy: int = 0) -> None:
        ys, xs = np.where(self.buf[:, :, 3] > 0)
        for y, x in zip(ys, xs):
            tx, ty = int(x + dx), int(y + dy)
            if 0 <= tx < dst.w and 0 <= ty < dst.h:
                c = self.buf[y, x]
                dst.pset(tx, ty, (int(c[0]), int(c[1]), int(c[2]), int(c[3])))

    def to_image(self) -> Image.Image:
        return Image.fromarray(self.buf, mode="RGBA")


def new_part(w: int, h: int) -> Layer:
    return Layer(w, h)
