#!/usr/bin/env python3
"""Generate Phase 4 art deliverables:
  - `docs/images/silhouettes.png`: 4 x 96x96 pure-black stand poses on transparent background.
  - `docs/images/hero_size_lineup.png`: Slime + 4 Heroes at true scale (Before vs After @2x zoom).
"""

from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

from hero_art_lib import CELL, GROUND_Y, RAMPS

HERO_IDS = ["behemoth", "knight", "sylvara", "velmira"]
HERO_LABELS = ["Behemoth", "Knight", "Sylvara", "Velmira"]
OLD_SCALES = {"behemoth": 0.36, "knight": 0.36, "sylvara": 0.34, "velmira": 0.34}


def build_silhouettes(repo_root: Path) -> Path:
    """Phase 4 silhouette gate sheet: 4 distinct pure-black 96x96 stand poses."""
    pad = 16
    card_w, card_h = CELL, CELL
    W = pad + len(HERO_IDS) * (card_w + pad)
    H = 34 + card_h + 28
    # Transparent outer sheet with crisp light parchment cards behind each pure-black 96x96 cell
    # so the black `#000000` silhouettes read clearly on both dark-mode and light-mode viewers!
    out = Image.new("RGBA", (W, H), (236, 230, 220, 255))
    d = ImageDraw.Draw(out)
    d.text((pad, 9), "PHASE 4 SILHOUETTE GATE  (Pure-Black 96x96 Stand Poses)", fill=(26, 32, 48, 255))

    for i, (hid, label) in enumerate(zip(HERO_IDS, HERO_LABELS)):
        cx0 = pad + i * (card_w + pad)
        cy0 = 32
        d.rectangle([cx0 - 1, cy0 - 1, cx0 + card_w, cy0 + card_h], fill=(248, 245, 238, 255), outline=(180, 172, 160, 255))
        d.line([(cx0, cy0 + GROUND_Y), (cx0 + card_w - 1, cy0 + GROUND_Y)], fill=(208, 198, 184, 255), width=1)

        sheet = Image.open(repo_root / "assets" / "textures" / f"player_{hid}.png").convert("RGBA")
        f0 = sheet.crop((0, 0, CELL, CELL))
        sil = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        spx = sil.load()
        fpx = f0.load()
        for y in range(CELL):
            for x in range(CELL):
                if fpx[x, y][3] > 0:
                    spx[x, y] = (0, 0, 0, 255)
        out.alpha_composite(sil, (cx0, cy0))
        d.text((cx0 + 18, cy0 + card_h + 6), label, fill=(26, 32, 48, 255))

    dest = repo_root / "docs" / "images" / "silhouettes.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest)
    return dest


def _extract_slime_stand(repo_root: Path) -> Image.Image:
    slime_sheet = Image.open(repo_root / "assets" / "textures" / "slime.png").convert("RGBA")
    return slime_sheet.crop((0, 0, 32, 32))


def build_lineup(repo_root: Path, before_dir: Path) -> Path:
    """True-scale @2x camera zoom lineup: Slime + 4 Heroes (BEFORE vs AFTER)."""
    W, H = 760, 420
    canvas = Image.new("RGBA", (W, H), (22, 20, 28, 255))
    d = ImageDraw.Draw(canvas)

    slime_cell = _extract_slime_stand(repo_root)
    # Slime @2x zoom: 32x32 * 2 = 64x64
    slime_2x = slime_cell.resize((64, 64), Image.NEAREST)
    slime_bb = slime_2x.getbbox()
    slime_bottom = slime_bb[3] if slime_bb else 64

    # Header
    d.text((24, 14), "HERO SIZE & ART UNIFICATION LINEUP  (True On-Screen Scale @ 2x Camera Zoom)", fill=RAMPS["gold"][3])

    # --- TOP ROW: BEFORE (if /tmp/before_heroes exists, else fallback) ---
    y_ground_before = 182
    d.line([(24, y_ground_before), (W - 24, y_ground_before)], fill=(86, 78, 102, 255), width=2)
    d.text((24, 46), "BEFORE (main: chibi 40% head, mixed 0.34/0.36 scale, inconsistent ground, smaller than Slime)", fill=RAMPS["crimson"][3])

    x_slots = [90, 230, 370, 510, 650]
    # Slime reference on left
    canvas.alpha_composite(slime_2x, (x_slots[0] - 32, y_ground_before - slime_bottom))
    d.text((x_slots[0] - 26, y_ground_before + 6), "Slime (1.0x)", fill=RAMPS["emerald"][3])

    for idx, (hid, label) in enumerate(zip(HERO_IDS, HERO_LABELS)):
        cand = before_dir / f"player_{hid}.png"
        src_path = cand if cand.exists() else (repo_root / "assets" / "textures" / f"player_{hid}.png")
        sh = Image.open(src_path).convert("RGBA")
        f0 = sh.crop((0, 0, CELL, CELL))
        sc = OLD_SCALES[hid] * 2.0  # @2x zoom
        px_sz = int(round(CELL * sc))
        scaled = f0.resize((px_sz, px_sz), Image.NEAREST)
        bb = scaled.getbbox()
        bot = bb[3] if bb else px_sz
        bh = (bb[3] - bb[1]) if bb else 0
        slot_x = x_slots[idx + 1]
        canvas.alpha_composite(scaled, (slot_x - px_sz // 2, y_ground_before - bot))
        d.text((slot_x - 32, y_ground_before + 6), f"{label} ({OLD_SCALES[hid]:.2f}x, {bh}px)", fill=RAMPS["moon"][2])

    # --- BOTTOM ROW: AFTER (Unified 0.50x scale, 72px @2x zoom, shared GROUND_Y=80, 4-step ramp + selout) ---
    y_ground_after = 378
    d.line([(24, y_ground_after), (W - 24, y_ground_after)], fill=RAMPS["gold"][2], width=2)
    d.text((24, 224), "AFTER (Unified Visuals.scale = 0.50, 72px heroic body, GROUND_Y = 80, 4-step shading + selout)", fill=RAMPS["emerald"][3])

    canvas.alpha_composite(slime_2x, (x_slots[0] - 32, y_ground_after - slime_bottom))
    d.text((x_slots[0] - 26, y_ground_after + 6), "Slime (64px cell)", fill=RAMPS["emerald"][3])

    for idx, (hid, label) in enumerate(zip(HERO_IDS, HERO_LABELS)):
        sh = Image.open(repo_root / "assets" / "textures" / f"player_{hid}.png").convert("RGBA")
        f0 = sh.crop((0, 0, CELL, CELL))
        # Visuals.scale = 0.5 * Camera zoom 2.0 = exact 1:1 96x96 screen pixels!
        bb = f0.getbbox()
        bot = bb[3] if bb else GROUND_Y
        bh = (bb[3] - bb[1]) if bb else 0
        slot_x = x_slots[idx + 1]
        canvas.alpha_composite(f0, (slot_x - CELL // 2, y_ground_after - bot))
        d.text((slot_x - 36, y_ground_after + 6), f"{label} (0.50x, {bh}px)", fill=RAMPS["gold"][3])

    dest = repo_root / "docs" / "images" / "hero_size_lineup.png"
    canvas.save(dest)
    return dest


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    sil_p = build_silhouettes(repo_root)
    lin_p = build_lineup(repo_root, Path("/tmp/before_heroes"))
    print("wrote", sil_p)
    print("wrote", lin_p)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
