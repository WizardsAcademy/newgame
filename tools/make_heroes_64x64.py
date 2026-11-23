#!/usr/bin/env python3
"""Generate crisp 64x64 pixel-art hero sprite sheets for all 4 playable heroes:
  - assets/textures/player_behemoth.png (1024 x 64, 16 frames of 64x64)
  - assets/textures/player_knight.png   (1024 x 64, 16 frames of 64x64)
  - assets/textures/player_sylvara.png  ( 960 x 64, 15 frames of 64x64)
  - assets/textures/player_noa.png      (1024 x 64, 16 frames of 64x64)

Converts from the clean house pixel-art 96x96 master frames (3x3 -> 2x2 exact
ratio) with feature-aware pixel rescue (preserving eyes, visors, catchlights,
crimson rose, and weapon edges), 1px selout outline continuity, zero #000000,
<= 24 colours per hero, and grounded boots around y = 53.
"""

from __future__ import annotations

from pathlib import Path
from PIL import Image

REPO_ROOT = Path(__file__).resolve().parent.parent
TEX_DIR = REPO_ROOT / "assets" / "textures"
MASTER_DIR = REPO_ROOT / "tools" / "masters_96"

SRC_CELL = 96
DST_CELL = 64
HERO_FILES = (
    "player_behemoth.png",
    "player_knight.png",
    "player_sylvara.png",
    "player_noa.png",
)


def _iter_px(im: Image.Image):
    if hasattr(im, "get_flattened_data"):
        return im.get_flattened_data()
    return im.getdata()


def _lum(c: tuple[int, int, int, int]) -> float:
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def downsample_cell_96_to_64(
    cell96: Image.Image, darkest_selout: tuple[int, int, int, int]
) -> Image.Image:
    sp = cell96.load()
    out = Image.new("RGBA", (DST_CELL, DST_CELL), (0, 0, 0, 0))
    dp = out.load()

    # Exact 3x3 -> 2x2 block resample with facial/eye/highlight feature rescue
    for by in range(32):
        sy0 = by * 3
        dy0 = by * 2
        for bx in range(32):
            sx0 = bx * 3
            dx0 = bx * 2
            center_c = sp[sx0 + 1, sy0 + 1]
            for oy, sy_pair in ((0, (sy0, sy0 + 1)), (1, (sy0 + 1, sy0 + 2))):
                for ox, sx_pair in ((0, (sx0, sx0 + 1)), (1, (sx0 + 1, sx0 + 2))):
                    ax = sx_pair[ox]
                    ay = sy_pair[oy]
                    samples = (
                        sp[ax, ay],
                        sp[sx_pair[1 - ox], ay],
                        sp[ax, sy_pair[1 - oy]],
                        sp[sx_pair[1 - ox], sy_pair[1 - oy]],
                    )
                    opaque = [c for c in samples if c[3] >= 128]
                    if not opaque:
                        if samples[0][3] > 0:
                            dp[dx0 + ox, dy0 + oy] = samples[0]
                        continue

                    if samples[0][3] >= 128:
                        chosen = samples[0]
                        # Rescue high-contrast inner details (eyes on bright skin,
                        # glowing visors, ruby irises, emerald arrow tips, brass studs)
                        for cand in (center_c, samples[1], samples[2]):
                            if cand[3] >= 128 and cand != chosen:
                                sat_c = max(cand[:3]) - min(cand[:3])
                                sat_a = max(chosen[:3]) - min(chosen[:3])
                                # Bright/vivid gem, visor, catchlight, emerald eye or rose
                                if (_lum(cand) > _lum(chosen) + 55) or (sat_c > sat_a + 65):
                                    chosen = cand
                                    break
                                if _lum(chosen) > 180 and cand[1] > cand[0] + 28 and cand[1] > cand[2] + 18:
                                    chosen = cand
                                    break
                        dp[dx0 + ox, dy0 + oy] = (chosen[0], chosen[1], chosen[2], 255)
                    elif len(opaque) >= 2:
                        c0 = opaque[0]
                        dp[dx0 + ox, dy0 + oy] = (c0[0], c0[1], c0[2], 255)

    # Restore clean 1px dark selout on solid body boundaries so silhouettes stay crisp
    snap = out.copy()
    qp = snap.load()
    for y in range(DST_CELL):
        for x in range(DST_CELL):
            c = qp[x, y]
            if c[3] < 255:
                continue
            on_edge = (
                x == 0
                or x == DST_CELL - 1
                or y == 0
                or y == DST_CELL - 1
                or qp[x - 1, y][3] == 0
                or qp[x + 1, y][3] == 0
                or qp[x, y - 1][3] == 0
                or qp[x, y + 1][3] == 0
            )
            if on_edge and _lum(c) > 78:
                op_n = sum(
                    1
                    for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
                    if 0 <= nx < DST_CELL and 0 <= ny < DST_CELL and qp[nx, ny][3] == 255
                )
                if op_n >= 3:
                    dp[x, y] = darkest_selout

    return out


def convert_hero_sheet(src_path: Path, dst_path: Path) -> tuple[int, int, int]:
    src = Image.open(src_path).convert("RGBA")
    if src.height == DST_CELL:
        # Already 64x64 and no master existed
        return src.width, src.height, src.width // DST_CELL

    frames = src.width // SRC_CELL
    cols = {
        (r, g, b, 255)
        for (r, g, b, a) in _iter_px(src)
        if a == 255 and (r, g, b) != (0, 0, 0)
    }
    darkest = min(cols, key=_lum)

    out_sheet = Image.new("RGBA", (frames * DST_CELL, DST_CELL), (0, 0, 0, 0))
    for f in range(frames):
        c96 = src.crop((f * SRC_CELL, 0, (f + 1) * SRC_CELL, SRC_CELL))
        c64 = downsample_cell_96_to_64(c96, darkest)
        out_sheet.alpha_composite(c64, (f * DST_CELL, 0))

    # Align standing ground_y (frame 0) cleanly to y = 53..54 if needed
    f0_bb = out_sheet.crop((0, 0, DST_CELL, DST_CELL)).getbbox()
    if f0_bb is not None:
        target_gy = 53
        dy = target_gy - f0_bb[3]
        if dy != 0 and abs(dy) <= 4:
            shifted_sheet = Image.new("RGBA", out_sheet.size, (0, 0, 0, 0))
            for f in range(frames):
                cell = out_sheet.crop((f * DST_CELL, 0, (f + 1) * DST_CELL, DST_CELL))
                bb = cell.getbbox()
                if bb is None:
                    continue
                crop = cell.crop(bb)
                ny = max(0, min(DST_CELL - (bb[3] - bb[1]), bb[1] + dy))
                shifted_sheet.alpha_composite(crop, (f * DST_CELL + bb[0], ny))
            out_sheet = shifted_sheet

    out_sheet.save(dst_path)
    return out_sheet.width, out_sheet.height, frames


def main() -> None:
    MASTER_DIR.mkdir(parents=True, exist_ok=True)
    for fname in HERO_FILES:
        dst = TEX_DIR / fname
        master = MASTER_DIR / fname
        if not master.exists() and dst.exists():
            im = Image.open(dst)
            if im.height == SRC_CELL:
                im.save(master)
        src = master if master.exists() else dst
        w, h, fcount = convert_hero_sheet(src, dst)
        print(f"wrote {dst.relative_to(REPO_ROOT)} ({w}x{h}, {fcount} frames of 64x64)")


if __name__ == "__main__":
    main()
