#!/usr/bin/env python3
"""Verify & render unified 4-Hero Showcase + 20-State Circular HUD Portrait Preview!

All 4 heroes (`Behemoth`, `Knight`, `Sylvara`, `Velmira`) now share the exact same
`224x224` cell grid (`scale = 0.165`, `GROUND_Y = 200`) and `960x192` (`5 x 192x192`)
circular HUD portrait format!

Outputs:
  - docs/images/portraits_preview.png
  - docs/images/heroes_lineup_preview.png
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
TEX = ROOT / "assets/textures"
OUT_PORTRAITS = ROOT / "docs/images/portraits_preview.png"
OUT_LINEUP = ROOT / "docs/images/heroes_lineup_preview.png"


def main() -> None:
    heroes = [
        ("BEHEMOTH (Pit-Brawler)", "player_borzo.png", "portrait_borzo.png", (238, 168, 72, 255)),
        ("SER BAHMAN (Golden-Lion Knight)", "player_bahman.png", "portrait_bahman.png", (232, 188, 92, 255)),
        ("SYLVARA (High-Elf Archer)", "player_pari.png", "portrait_pari.png", (120, 224, 164, 255)),
        ("VELMIRA (Vampire Noble - Benchmark)", "player_shabnam.png", "portrait_shabnam.png", (228, 74, 108, 255)),
    ]
    state_labels = ["0: idle_a", "1: idle_b", "2: blink", "3: low_hp", "4: hurt"]

    # 1. Render 4x5 Circular HUD Portrait Preview (`docs/images/portraits_preview.png`)
    prev_p = Image.new("RGBA", (920, 660), (16, 18, 26, 255))
    dp = ImageDraw.Draw(prev_p)
    dp.text((24, 14), "4-HERO CIRCULAR HUD MEDALLIONS (960x192 = 5x 192x192 RGBA, Exact Velmira Pipeline)", fill=(236, 228, 214, 255))

    for row, (title, _, p_file, rim_col) in enumerate(heroes):
        strip = Image.open(TEX / p_file).convert("RGBA")
        assert strip.size == (960, 192), f"Expected 960x192 for {p_file}, got {strip.size}"
        y0 = 52 + row * 150
        dp.text((24, y0 + 48), title, fill=rim_col)
        for col in range(5):
            x0 = 300 + col * 120
            cell = strip.crop((col * 192, 0, (col + 1) * 192, 192)).resize((100, 100), Image.Resampling.LANCZOS)
            prev_p.alpha_composite(cell, (x0, y0))
            dp.ellipse((x0 - 2, y0 - 2, x0 + 102, y0 + 102), outline=rim_col, width=2)
            if row == 0:
                dp.text((x0 + 18, y0 - 18), state_labels[col], fill=(195, 200, 215, 255))

    OUT_PORTRAITS.parent.mkdir(parents=True, exist_ok=True)
    prev_p.save(OUT_PORTRAITS)

    # 2. Render Side-by-Side 4-Hero Scale & Dungeon Grounding Comparison (`docs/images/heroes_lineup_preview.png`)
    lineup = Image.new("RGBA", (1180, 560), (24, 27, 36, 255))
    dl = ImageDraw.Draw(lineup)
    dl.text((24, 16), "SIDE-BY-SIDE 4-HERO WORLD SCALE & DUNGEON GROUNDING (All 224x224 @ scale 0.165, GROUND_Y = 200)", fill=(238, 232, 220, 255))

    # Row A: Standing Side Idle (`frame 0`) + Walk (`frame 4`) + Primary Attack + Death (`last frame`)
    pose_indices = [
        ("player_borzo.png", [0, 8, 23, 27, 31]),
        ("player_bahman.png", [0, 8, 22, 27, 31]),
        ("player_pari.png", [0, 8, 23, 26, 31]),
        ("player_shabnam.png", [0, 8, 21, 35, 39]),
    ]
    pose_names = ["Idle (+X)", "Front / Guard", "Signature Attack", "Dash / Charge", "Fallen Death"]

    for r_idx, ((title, s_file, _, rim_col), (_, f_indices)) in enumerate(zip(heroes, pose_indices)):
        sheet = Image.open(TEX / s_file).convert("RGBA")
        y_top = 56 + r_idx * 122
        dl.text((20, y_top + 46), title.split(" (")[0], fill=rim_col)
        for c_idx, f_idx in enumerate(f_indices):
            x_left = 190 + c_idx * 192
            dl.rectangle([x_left, y_top, x_left + 112, y_top + 112], fill=(34, 38, 50, 255), outline=(66, 74, 94, 255))
            gy = y_top + int(round(200 * (112.0 / 224.0)))
            dl.line([(x_left + 8, gy), (x_left + 104, gy)], fill=rim_col[:3] + (135,), width=1)
            fx, fy = (f_idx % 8) * 224, (f_idx // 8) * 224
            cell = sheet.crop((fx, fy, fx + 224, fy + 224)).resize((112, 112), Image.Resampling.LANCZOS)
            lineup.alpha_composite(cell, (x_left, y_top))
            if r_idx == 0:
                dl.text((x_left + 8, y_top - 16), pose_names[c_idx], fill=(205, 212, 226, 255))

    lineup.save(OUT_LINEUP)
    print(f"Wrote {OUT_PORTRAITS} and {OUT_LINEUP}")


if __name__ == "__main__":
    main()
