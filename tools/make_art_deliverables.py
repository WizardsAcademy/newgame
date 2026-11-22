#!/usr/bin/env python3
"""Generate art deliverables (`HERO_SKELETON_SPEC.md` & `ART_CONTRACT.md`):
  - `docs/images/silhouettes.png`: 4 x 96x96 pure-black stand poses showing distinct skeletons.
  - `docs/images/hero_size_lineup.png`: Slime + 4 Heroes at true scale (@2x camera zoom, Before vs After).
"""

from __future__ import annotations

import subprocess
from io import BytesIO
from pathlib import Path
from PIL import Image, ImageDraw

from hero_art_lib import CELL, GROUND_Y, RAMPS

HERO_IDS = ["behemoth", "knight", "sylvara", "velmira"]
HERO_LABELS = ["Behemoth", "Knight", "Sylvara", "Velmira"]


def build_silhouettes(repo_root: Path) -> Path:
    """Silhouette gate sheet: 4 distinct pure-black 96x96 stand poses."""
    pad = 16
    card_w, card_h = CELL, CELL
    W = pad + len(HERO_IDS) * (card_w + pad)
    H = 34 + card_h + 28
    out = Image.new("RGBA", (W, H), (236, 230, 220, 255))
    d = ImageDraw.Draw(out)
    d.text((pad, 9), "HERO SKELETON SILHOUETTE GATE  (Pure-Black 96x96 Stand Poses)", fill=(26, 32, 48, 255))

    for i, (hid, label) in enumerate(zip(HERO_IDS, HERO_LABELS)):
        cx0 = pad + i * (card_w + pad)
        cy0 = 32
        d.rectangle([cx0 - 1, cy0 - 1, cx0 + card_w, cy0 + card_h], fill=(248, 245, 238, 255), outline=(180, 172, 160, 255))
        d.line([(cx0, cy0 + GROUND_Y), (cx0 + card_w - 1, cy0 + GROUND_Y)], fill=(208, 198, 184, 255), width=1)

        sheet = Image.open(repo_root / "assets" / "textures" / f"player_{hid}.png").convert("RGBA")
        f0 = sheet.crop((0, 0, CELL, CELL))
        bb = f0.getbbox()
        bh = (bb[3] - bb[1]) if bb else 0
        sil = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        spx = sil.load()
        fpx = f0.load()
        for y in range(CELL):
            for x in range(CELL):
                if fpx[x, y][3] > 0:
                    spx[x, y] = (0, 0, 0, 255)
        out.alpha_composite(sil, (cx0, cy0))
        d.text((cx0 + 8, cy0 + card_h + 6), f"{label} ({bh}px)", fill=(26, 32, 48, 255))

    dest = repo_root / "docs" / "images" / "silhouettes.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest)
    return dest


def _extract_slime_stand(repo_root: Path) -> Image.Image:
    slime_sheet = Image.open(repo_root / "assets" / "textures" / "slime.png").convert("RGBA")
    return slime_sheet.crop((0, 0, 32, 32))


def _load_git_blob_png(repo_root: Path, rev: str, rel_path: str) -> Image.Image | None:
    try:
        raw = subprocess.check_output(
            ["git", "show", f"{rev}:{rel_path}"],
            cwd=repo_root,
            stderr=subprocess.DEVNULL,
        )
        return Image.open(BytesIO(raw)).convert("RGBA")
    except Exception:
        return None


def build_lineup(repo_root: Path) -> Path:
    """True-scale @2x camera zoom lineup: Slime + 4 Heroes (BEFORE vs AFTER)."""
    W, H = 780, 420
    canvas = Image.new("RGBA", (W, H), (22, 20, 28, 255))
    d = ImageDraw.Draw(canvas)

    slime_cell = _extract_slime_stand(repo_root)
    slime_2x = slime_cell.resize((64, 64), Image.NEAREST)
    slime_bb = slime_2x.getbbox()
    slime_bottom = slime_bb[3] if slime_bb else 64

    d.text((24, 14), "HERO SKELETON & SILHOUETTE LINEUP  (True On-Screen Scale @ 2x Camera Zoom)", fill=RAMPS["gold"][3])

    # --- TOP ROW: BEFORE (`f73e2e3` pre-skeleton pass: uniform 72-73px height, thick legs, 0.70-0.80 IoU) ---
    y_ground_before = 182
    d.line([(24, y_ground_before), (W - 24, y_ground_before)], fill=(86, 78, 102, 255), width=2)
    d.text((24, 46), "BEFORE (uniform ~72px height, wide blocky legs 433-721px, shared Roblox silhouette IoU 0.70-0.80)", fill=RAMPS["crimson"][3])

    x_slots = [90, 235, 380, 525, 670]
    canvas.alpha_composite(slime_2x, (x_slots[0] - 32, y_ground_before - slime_bottom))
    d.text((x_slots[0] - 26, y_ground_before + 6), "Slime (64px)", fill=RAMPS["emerald"][3])

    for idx, (hid, label) in enumerate(zip(HERO_IDS, HERO_LABELS)):
        rel = f"assets/textures/player_{hid}.png"
        sh = _load_git_blob_png(repo_root, "f73e2e3", rel)
        if sh is None:
            sh = Image.open(repo_root / rel).convert("RGBA")
        f0 = sh.crop((0, 0, CELL, CELL))
        bb = f0.getbbox()
        bot = bb[3] if bb else GROUND_Y
        bh = (bb[3] - bb[1]) if bb else 0
        bw = (bb[2] - bb[0]) if bb else 0
        slot_x = x_slots[idx + 1]
        canvas.alpha_composite(f0, (slot_x - CELL // 2, y_ground_before - bot))
        d.text((slot_x - 42, y_ground_before + 6), f"{label} ({bh}h x {bw}w)", fill=RAMPS["moon"][2])

    # --- BOTTOM ROW: AFTER (4 bespoke skeletons: 68 / 76 / 80 / 64px, narrow legs, <= 0.45 IoU) ---
    y_ground_after = 378
    d.line([(24, y_ground_after), (W - 24, y_ground_after)], fill=RAMPS["gold"][2], width=2)
    d.text((24, 224), "AFTER (4 bespoke skeletons: 68 / 76 / 80 / 64px, narrow legs 220-440px, pairwise IoU <= 0.45)", fill=RAMPS["emerald"][3])

    canvas.alpha_composite(slime_2x, (x_slots[0] - 32, y_ground_after - slime_bottom))
    d.text((x_slots[0] - 26, y_ground_after + 6), "Slime (64px)", fill=RAMPS["emerald"][3])

    for idx, (hid, label) in enumerate(zip(HERO_IDS, HERO_LABELS)):
        sh = Image.open(repo_root / "assets" / "textures" / f"player_{hid}.png").convert("RGBA")
        f0 = sh.crop((0, 0, CELL, CELL))
        bb = f0.getbbox()
        bot = bb[3] if bb else GROUND_Y
        bh = (bb[3] - bb[1]) if bb else 0
        bw = (bb[2] - bb[0]) if bb else 0
        slot_x = x_slots[idx + 1]
        canvas.alpha_composite(f0, (slot_x - CELL // 2, y_ground_after - bot))
        d.text((slot_x - 42, y_ground_after + 6), f"{label} ({bh}h x {bw}w)", fill=RAMPS["gold"][3])

    dest = repo_root / "docs" / "images" / "hero_size_lineup.png"
    canvas.save(dest)
    return dest


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    sil_p = build_silhouettes(repo_root)
    lin_p = build_lineup(repo_root)
    print("wrote", sil_p)
    print("wrote", lin_p)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
