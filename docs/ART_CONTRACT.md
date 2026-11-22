# Hero Art Contract (`96×96` Pixel-Art Specification)

This document defines the binding art, proportion, palette, shading, and scene-scale contract for all playable heroes in **Roguelike Brawler** (`WizardsAcademy/newgame`), working alongside [`docs/HERO_SKELETON_SPEC.md`](HERO_SKELETON_SPEC.md). Any new hero or hero reskin must pass `python3 tools/hero_skeleton_check.py --strict`, `python3 tools/measure_hero_sheets.py --strict`, and `godot --headless --path . tests/sprite_contract_test.tscn`.

---

## 1. Cell Size, Ground Line & Scene Scale

| Parameter | Contract Value | Notes |
|-----------|----------------|-------|
| **Cell dimensions** | `96 × 96 px` | Single horizontal strip `(96 * frame_count) × 96`, RGBA PNG |
| **Per-hero standing height (`f0_h`)** | `Behemoth 68 [66–70]`, `Knight 76 [74–80]`, `Sylvara 80 [78–84]`, `Velmira 64 [62–68]` | Four distinct skeletons defined in [`docs/HERO_SKELETON_SPEC.md`](HERO_SKELETON_SPEC.md) |
| **Ground baseline (`GROUND_Y`)** | `80` (`bottom_y == 80`) | Every frame's lowest opaque pixel sits at `y = 79` (`bbox.bottom = 80`); `16 px` bottom margin reserved for downward follow-through FX |
| **Head-to-body ratio** | `25–33%` per hero (`[22–36%]`) | `Sylvara 25%`, `Knight 26%`, `Behemoth 31%`, `Velmira 33%` |
| **Pairwise silhouette IoU** | `<= 0.45` target (`<= 0.55` hard gate) | Verified by `python3 tools/hero_skeleton_check.py --strict --iou` |
| **`Visuals.scale`** | `Vector2(0.5, 0.5)` | Uniform X=Y scale across all 4 heroes (`32–40 px` world height; `64–80 px` at `2×` camera zoom vs `~32 px` Slime) |
| **`Visuals.position`** | `Vector2(0, -16)` | `-(GROUND_Y - CELL/2) * scale = -(80 - 48) * 0.5 = -16.0`, grounding feet on the `CharacterBody2D` origin |
| **`Shadow.position`** | `Vector2(0, 32)` | Evaluated in `Visuals` local space (`32 * 0.5 = +16 px` below sprite center = exact `y = 0` foot line) |
| **Texture filtering** | `NEAREST` everywhere | `default_texture_filter = 0`, `Visuals.texture_filter = 1`, zero `LINEAR*` or `mipmaps/generate=true` in scenes, UI, or `.import` files |
| **Alpha channel** | Binary (`0` or `255`) | Semi-transparent pixels (`0 < a < 255`) must be `0.00%` (`<= 2.0%` hard gate) |

Visual proofs live in:
- `docs/images/silhouettes.png` — pure-black `96×96` stand-pose silhouette gate across all 4 heroes.
- `docs/images/hero_size_lineup.png` — true on-screen scale (`@2×` camera zoom) comparing Slime + all 4 heroes before and after unification.

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
| **Velmira** | `player_velmira.png` (`1536×96`) | `16` | `64 × 23 px` | `13` | Shortest & petite vampire, widest part is asymmetric silver-white hair waterfall reaching below left knee only, flared gothic skirt hem | `16.0` |

### Frame Index Mapping (Invariant)
- **Behemoth (`16` frames)**: `0:idle`, `1..2:walk`, `3:windup`, `4:jab`, `5:cross`, `6:uppercut`, `7:charge`, `8:hurt`, `9:blink`, `10:idle_down`, `11..12:walk_down`, `13:idle_up`, `14..15:walk_up`.
- **Knight (`16` frames)**: `0:idle`, `1..2:walk`, `3:windup`, `4:sweep`, `5:spin`, `6:guard`, `7:charge`, `8:hurt`, `9:blink`, `10:idle_down`, `11..12:walk_down`, `13:idle_up`, `14..15:walk_up`.
- **Sylvara (`15` frames)**: `0:idle`, `1..2:walk`, `3:bow_draw`, `4:bow_charge`, `5:bow_release`, `6:charge`, `7:hurt`, `8:blink`, `9:idle_down`, `10..11:walk_down`, `12:idle_up`, `13..14:walk_up`.
- **Velmira (`16` frames)**: `0:idle`, `1..2:walk`, `3:cast_windup`, `4:cast_slash`, `5:charge`, `6:hurt`, `7:blink`, `8:idle_b`, `9:die_kneel`, `10:idle_down`, `11..12:walk_down`, `13:idle_up`, `14..15:walk_up` (all 16 cells are grounded full-character poses; spell slash VFX lives exclusively in `assets/textures/velmira_fx.png` via `BloodSplashSlash`).

---

## 4. Regeneration & Automated Verification

```bash
# Regenerate all 4 hero sheets, HUD portraits & silhouette/lineup deliverables
python3 tools/make_behemoth_sprites.py
python3 tools/make_knight_sprites.py
python3 tools/make_sylvara_sprites.py
python3 tools/make_velmira_sprites.py
python3 tools/make_hero_portraits.py
python3 tools/make_art_deliverables.py

# Enforce per-hero skeleton proportions & pairwise silhouette IoU
python3 tools/hero_skeleton_check.py --strict --iou

# Enforce sheet dimensions, per-hero f0_h, GROUND_Y=80, <=24 colours, 0% semi-alpha, zero #000000
python3 tools/measure_hero_sheets.py --strict

# Run headless Godot art-contract & hero suites
godot --headless --path . tests/sprite_contract_test.tscn
godot --headless --path . tests/heroes_and_dash_test.tscn
```
