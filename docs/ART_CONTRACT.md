# Hero Art Contract (`96×96` Pixel-Art Specification)

This document defines the binding `96×96` pixel-art, palette, shading, and scene-scale contract for all playable heroes in **Roguelike Brawler** (`WizardsAcademy/newgame`). Any new hero or hero reskin must pass `python3 tools/measure_hero_sheets.py --strict` and `godot --headless --path . tests/sprite_contract_test.tscn`.

---

## 1. Cell Size, Ground Line & Scene Scale

| Parameter | Contract Value | Notes |
|-----------|----------------|-------|
| **Cell dimensions** | `96 × 96 px` | Single horizontal strip `(96 * frame_count) × 96`, RGBA PNG |
| **Standing height (`f0_h`)** | `56–84 px` | Classic 96×96 pixel-art proportions (`Behemoth 60`, `Sylvara 61`, `Noa 68`, `Knight 72`) |
| **Standing ground (`f0 bottom_y`)** | `78–86` | Standing feet sit consistently near `y = 80` (`85` on Knight to leave room for helmet & sword arc) |
| **`Visuals.scale`** | `Vector2(0.5, 0.5)` | Exact integer `2:1` pixel scale across all 4 heroes |
| **`Visuals.position`** | `Vector2(0, -16)` (`-18.5` Knight) | Grounds each hero's standing boots on the `CharacterBody2D` origin |
| **`Shadow`** | `res://assets/textures/slime_shadow.png` | Soft `32×10` pixel-art oval shadow beneath feet (never a rectangular square sprite) |
| **Texture filtering** | `NEAREST` everywhere | `default_texture_filter = 0`, `Visuals.texture_filter = 1`, zero `LINEAR*` or `mipmaps/generate=true` in scenes, UI, or `.import` files |
| **Alpha channel** | Crisp (`<= 2.0%` semi-alpha) | Clean pixel edges without blurry linear fringes |

---

## 2. Shared 32-Colour Master Ramp & Shading Rules

All 4 heroes draw exclusively from one shared **32-colour master palette** (`tools/hero_art_lib.py` → `RAMPS`), organized into **8 material ramps × 4 tonal steps** (`0: shadow/selout`, `1: base`, `2: light`, `3: highlight`):

| Material Ramp | Step 0 (`shadow / selout`) | Step 1 (`base`) | Step 2 (`light`) | Step 3 (`highlight`) |
|---------------|----------------------------|-----------------|------------------|----------------------|
| **`skin`** | `#40262a` | `#9e6258` | `#d99b84` | `#f4cdb8` |
| **`steel`** | `#1a2030` | `#46546e` | `#8296b5` | `#c7d9f0` |
| **`leather`** | `#2b1a14` | `#5c3828` | `#946043` | `#c79066` |
| **`gold`** | `#4a2f12` | `#9c6820` | `#deb03c` | `#fae38c` |
| **`crimson`** | `#380c1c` | `#821832` | `#cc2b4c` | `#fa6e86` |
| **`emerald`** | `#132b22` | `#25593f` | `#469664` | `#82d996` |
| **`moon`** | `#3a2d44` | `#8c82a6` | `#cfcbe3` | `#f4f2fc` |
| **`obsidian`** | `#161224` | `#2e2647` | `#524678` | `#8072ab` |

### Shading & Outline Rules
1. **Per-hero colour budget**: `<= 24` opaque colours per hero sheet (at most 6 material ramps × 4 steps).
2. **4-step directional lighting**: Primary light source is **top-left** (`L = (-0.68, -0.73)`). Every major form renders 4 steps (`shadow`, `base`, `light`, `highlight`).
3. **Selective outlines (selout — zero `#000000`)**: Pure black (`#000000`) is **forbidden** in hero sprite sheets. Exterior silhouette pixels use Step `0` (`shadow`) of the neighbouring material (e.g. `#40262a` on skin, `#1a2030` on steel, `#161224` on obsidian), modulated slightly lighter along top-left lit edges and darker along bottom-right shadow edges.

---

## 3. Silhouette & Frame Layout Contract

Each hero must read unmistakably as a pure-black `96×96` silhouette (`docs/images/silhouettes.png`):

| Hero | Sheet (`assets/textures/`) | Frames | Standing (`h × sh_w`) | Colours | Silhouette Key | Weapon Reach (`attack_point_offset_x`) |
|------|----------------------------|--------|-----------------------|---------|----------------|----------------------------------------|
| **Behemoth** | `player_behemoth.png` (`1536×96`) | `16` | `68 × 48 px` | `23` | Thickest hunched pit-champion, head sunk between bull-traps & pushed `+3px` forward, `48px` shoulders vs `28px` hips, hanging Iron Cestus fists | `18.0` |
| **Knight** | `player_knight.png` (`1536×96`) | `16` | `76 × 29 px` | `18` | Straight vertical human baseline, visored greathelm, Zweihander rising diagonally above right shoulder, crimson cape wedge on left hip | `24.0` |
| **Sylvara** | `player_sylvara.png` (`1440×96`) | `15` | `80 × 25 px` | `18` | Tallest & thinnest ranger, closed Golden-Yew Recurve Bow hoop extending `+10px` past body with open D-window, `45°` feathered quiver on upper back | `14.0` (arrow muzzle) |
| **Noa** | `player_noa.png` (`1536×96`) | `16` | `64 × 23 px` | `13` | Shortest & petite vampire, widest part is asymmetric silver-white hair waterfall reaching below left knee only, flared gothic skirt hem | `16.0` |

### Frame Index Mapping (Invariant)
- **Behemoth (`16` frames)**: `0:idle`, `1..2:walk`, `3:windup`, `4:jab`, `5:cross`, `6:uppercut`, `7:charge`, `8:hurt`, `9:blink`, `10:idle_down`, `11..12:walk_down`, `13:idle_up`, `14..15:walk_up`.
- **Knight (`16` frames)**: `0:idle`, `1..2:walk`, `3:windup`, `4:sweep`, `5:spin`, `6:guard`, `7:charge`, `8:hurt`, `9:blink`, `10:idle_down`, `11..12:walk_down`, `13:idle_up`, `14..15:walk_up`.
- **Sylvara (`15` frames)**: `0:idle`, `1..2:walk`, `3:bow_draw`, `4:bow_charge`, `5:bow_release`, `6:charge`, `7:hurt`, `8:blink`, `9:idle_down`, `10..11:walk_down`, `12:idle_up`, `13..14:walk_up`.
- **Noa (`16` frames)**: `0:idle`, `1..2:walk`, `3:cast_windup`, `4:cast_slash`, `5:charge`, `6:hurt`, `7:blink`, `8:idle_b`, `9:die_kneel`, `10:idle_down`, `11..12:walk_down`, `13:idle_up`, `14..15:walk_up` (all 16 cells are grounded full-character poses; spell slash VFX lives exclusively in `assets/textures/noa_fx.png` via `BloodSplashSlash`).

---

## 4. Regeneration & Automated Verification

```bash
# Regenerate classic 96x96 hero sheets, Noa hand-drawn sheet & HUD portraits
python3 tools/make_behemoth_sprites.py
python3 tools/make_knight_sprites.py
python3 tools/make_sylvara_sprites.py
python3 tools/import_pose_sheet.py --hero noa

# Enforce sheet dimensions, standing height, <=24 colours, <=2% semi-alpha, zero #000000
python3 tools/measure_hero_sheets.py --strict

# Run headless Godot art-contract & hero suites
godot --headless --path . tests/sprite_contract_test.tscn
godot --headless --path . tests/heroes_and_dash_test.tscn
```
