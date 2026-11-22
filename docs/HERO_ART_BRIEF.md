# Agent Brief — Hero Art Unification & Quality Pass

> **How to use this file:** paste its contents to the coding agent as the task
> description. It is written to be executed top-to-bottom, phase by phase, each
> phase ending in a green headless test run. Do not skip Phase 0 — every later
> number comes from it.

---

## 0. Context (read before touching anything)

Repo: `WizardsAcademy/newgame` — a 2D top-down roguelike brawler in **Godot 4.7.2** (GDScript).
All work happens on a feature branch; open one PR at the end of each phase, not one giant PR.

Current state (verified on `main`):

- 4 heroes, each a **96×96 pixel-art sheet**, 8–16 frames per row, plus a `320×64` (5 × 64×64) HUD portrait strip.
  - `assets/textures/player_behemoth.png` (16 frames, 20 colours)
  - `assets/textures/player_knight.png` (16 frames, 19 colours)
  - `assets/textures/player_sylvara.png` (15 frames, 21 colours)
  - `assets/textures/player_noa.png` (16 frames, 15 colours)
  - `assets/textures/portrait_*.png` (48–58 colours each, 0% semi-transparent)
- Scenes: `scenes/player/Behemoth.tscn`, `Knight.tscn`, `Sylvara.tscn`, `Noa.tscn`
  (all `extends PlayerBase`, see `scripts/player/player_base.gd`).
- Enemy art is 1:1 in world units and **must not change**: slime 32×32 cell,
  golem 80×80 cell, archer 64×64 cell.
- 5 headless test suites exist and must stay green:
  `tests/heroes_and_dash_test.tscn`, `tests/archer_test.tscn`, `tests/boss_test.tscn`,
  `tests/combat_test.tscn`, `tests/slime_variants_test.tscn`.

### The problem to solve

The hero art is technically clean (limited palette, binary alpha) but reads as
"chibi / childish" and inconsistent. Measured on current `main` (frame 0 of each sheet):

| Hero | Body height in the 96px cell | Ground line (bottom-Y per frame) | `Visuals.scale` | On-screen height @2× zoom |
|---|---|---|---|---|
| Slime (enemy, reference) | 32 px | 32 | 1.0 | **64 px** |
| Behemoth | 60.4 px | 78–80 | 0.36 | ~43 px |
| **Knight** | **74.9 px** | **84–96** | 0.36 | **~54 px** |
| Sylvara | 59.4 px | **68**, 79, 80 | 0.34 | ~40 px |
| **Noa** | **56.4 px** | 77–81 | 0.34 | **~38 px** |

Consequences visible in game: the slime is taller than the heroes; Knight is 45%
taller than Noa; Sylvara jumps ~11 px vertically between frames; Knight
sinks to the cell bottom. Nothing shares a ground line or a body height.

### Non-goals (do NOT do these)

- Do **not** reintroduce 224×224 cells, reference-sheet crops, or AI-generated art.
- Do **not** use `TEXTURE_FILTER_LINEAR*` or mipmaps on gameplay sprites.
- Do **not** change gameplay: hitboxes, damage, speeds, frame indices or
  animation names stay exactly as they are. This is an art pipeline pass.
- Do **not** rewrite the enemy art.

---

## 1. Target (the definition of "good" we are aiming at)

| Decision | Value | Rationale |
|---|---|---|
| Cell size | **96×96**, 8 columns per row | already in place; keep it |
| Target body height | **72 px** inside the cell | between current Knight (75) and the rest (56–60) |
| Ground line | **`GROUND_Y = 80`** for every frame of every hero | kills vertical jitter |
| In-game scale | **`Visuals.scale = Vector2(0.5, 0.5)`** | 96×0.5 = 48 world px → 96 screen px at 2× zoom; heroes finally bigger than the 32px slime |
| Palette | ≤ **24 colours per hero, from one shared 32-colour base ramp** | visual unity of the roster |
| Shading per material | **3 steps + 1 highlight**, light from top-left only | the single biggest "professional" upgrade |
| Outline | **selective selout** (darker tint of the material), never pure `#000000` | removes the "sticker" look |
| Head ratio | ~**30%** of body height (from ~40% now) | moves the read from "chibi" toward "heroic" |
| Silhouette | each hero readable as a black shape at 96×96 | identity over detail |

---

## 2. Phases

### Phase 0 — Measurement & guardrails (1 hour, no art changes)

Build the measuring tools first so every later change is provable.

1. `tools/measure_hero_sheets.py`
   - For every sheet in `assets/textures/player_*.png`: split into 96px cells,
     and per frame report `bbox`, `body_height`, `bottom_y`, `top_y`.
   - Print a per-hero summary table: `frames`, `body_h avg/min/max`,
     `ground_y set`, `colour_count`, `semi_alpha_pct`.
   - Exit non-zero if any frame has no pixels, if a sheet width is not a
     multiple of 96, or if `semi_alpha_pct > 2.0`.
2. `tests/sprite_contract_test.gd` + `tests/sprite_contract_test.tscn`
   - Loads `character_registry.gd` and every hero sheet.
   - Asserts per hero: sheet width % 96 == 0; frame count matches
     `frame_count` in the registry; `Visuals.texture_filter == NEAREST`;
     `Visuals.texture` cell size == 96; no `.png` has `mipmaps/generate=true`.
   - Prints PASS/FAIL lines and quits with code `0`/`1` (mirror the style of
     `tests/combat_test.gd`).
   - **Initially this test will fail** on body height / ground line — that is
     expected: it is the red test that Phase 1 turns green.

**Acceptance:** both tools run; `measure_hero_sheets.py` prints the table above;
the contract test runs and reports which heroes violate the targets.

---

### Phase 1 — Normalize height and ground line (mechanical, no redraw)

1. `tools/normalize_hero_sheets.py`
   - For each sheet: find the **standing frame's** body height (skip `die`
     frames, which are legitimately short).
   - Compute a single uniform vertical scale factor `k = 72 / body_height`
     **per hero** and scale the *whole cell* by `k` with `Image.NEAREST`.
   - Re-ground every frame so that the character's bottom sits at `GROUND_Y = 80`
     (pad with transparent pixels; never crop the top of an attack pose).
   - **Horizontal rule:** if the scaled body would exceed the 96px cell width
     (Knight's sword arcs will), scale the cell down as one unit instead of
     squashing the X axis — body proportions must never distort.
   - Write results back in place, and print a before/after table.
2. Fix Sylvara's outlier frames (the ones at `bottom_y = 68`) — those are the
   frames that cause the 11px hop.
3. Re-run Phase 0 tools until the contract test's height/ground assertions pass.

**Acceptance:** all four heroes report `body_h` in 70–74 and a single
`ground_y` value per hero; no new transparent gaps; frame counts unchanged.

---

### Phase 2 — Put them on screen at the right size (2 hours)

1. Set `Visuals.scale = Vector2(0.5, 0.5)` in the four hero scenes
   (`Behemoth.tscn`, `Knight.tscn`, `Sylvara.tscn`, `Noa.tscn`) — one value
   for all four, no per-hero exceptions.
2. Set `Visuals.position.y` so the drawn feet land on the node origin.
3. Keep body collision at 16×16; only visual size changes. Verify the attack
   `Hitbox` / `AttackPoint` offsets still land where the sprites' weapons are —
   if a weapon now extends further, adjust `attack_point_offset_x` only
   (and note it in the PR).
4. Fix the leftover `LINEAR_WITH_MIPMAPS` conditionals in
   `scripts/ui/hero_hud.gd:137` and `scripts/ui/character_select_menu.gd:365,481`
   → always `TEXTURE_FILTER_NEAREST`, no size-based switching.
5. Run all 5 existing headless suites. They must stay green.

**Acceptance:** on-screen hero height 46–50 px (≈2× the slime's 64px cell body),
no blur, all suites green, gameplay timing unchanged.

---

### Phase 3 — Noa attack VFX (the known bug)

`scripts/player/shabnam.gd` currently draws the attack **twice**:

- the `noa_fx.png` sprite strip (`BloodSplashSlash._sprite`), **and**
- a procedural three-layer crescent + droplets in `BloodSplashSlash._draw()`.

Pick **one** and delete the other. Recommended: keep the hand-drawn strip,
delete the crescent polygons from `_draw()`, keep only the six blood droplets
and add an additive glow layer on top of the sprite.

Also remove the two stray art cells from `player_noa.png`:
frame 4 (a 65×61 red orb) and frame 9 (a 57×13 blood puddle on the floor) —
they are leftovers from an older pipeline and show up mid-animation. Replace
frame 4 with a proper slash pose, or reindex the animation so the orb is never
reached.

**Acceptance:** one crescent visible per swing, no floating orb, no duplicated
trail; `tests/heroes_and_dash_test.tscn` still green.

---

### Phase 4 — Shading & silhouette pass (art work, 2–3 days)

This is the only phase where art has to be drawn. Work in this order:

1. **Silhouette gate (do this first, 1 hour).** For each hero produce a pure-black
   96×96 stand pose on transparent background. If any two heroes' silhouettes
   read the same at a glance, change the shape *before* shading:
   - Behemoth — broad, hunched, shoulders wider than hips, fists forward.
   - Knight — tall, upright, sword resting on the shoulder, cape wedge behind.
   - Sylvara — narrow, bow hoop visible against the body, quiver breaking the back line.
   - Noa — heavy hair mass with an asymmetric fall, narrow shoulders.
2. **Ramp pass.** For every material (skin, cloth, leather, steel, hair, gold)
   define exactly 4 colours: `shadow / base / light / highlight`, sampled from
   the shared 32-colour base ramp. Light source: **top-left** for all four heroes.
3. **Selout pass.** Replace the pure-black outline with a darker tint of the
   adjacent material (e.g. skin → `#40262a`, steel → `#1a2030`).
4. **Head ratio.** Reduce head height to ~30% of body height; the freed pixels
   go into torso and legs. Faces stay readable: eyes are the identity, not detail.
5. **Keep the frame count and frame order stable** — animations are wired by
   index in the scenes.

**Acceptance:** ≤24 colours per hero; every material has 4 steps; outlines are
never `#000000`; a silhouette sheet exists proving 4 distinct shapes.

---

### Phase 5 — Documentation & CI (30 minutes)

1. `docs/ART_CONTRACT.md` — record the table from section 1 of this brief
   (cell, body height, ground line, palette, outline rule, shading rule). This
   is the file future PRs are measured against.
2. Update `README.md`: it still claims `32×32` sprites, Behemoth 100 HP,
   Knight 120 HP / 60% shield, Noa 85 HP — all wrong. Use the real values
   from `docs/CHARACTERS.md` (120 / 150 / 100 / 75 HP, Knight 100% block).
3. Fix the dead link in `docs/ROADMAP.md` to the deleted `NOA_REDESIGN.md`
   and `VAMPIRE_IDLE.md`.
4. Add `.github/workflows/tests.yml` running the 5 existing suites plus
   `tests/sprite_contract_test.tscn` on every PR. Any red = no merge.

**Acceptance:** CI runs on a PR and is green; no docs reference deleted files.

---

## 3. Guardrails (repeat for safety)

- Never scale the X axis independently from Y — proportions must stay intact.
- Never change frame counts, animation names, or frame indices.
- Never touch enemy sheets, enemy scenes, damage numbers, or speeds.
- Every phase ends with: `measure_hero_sheets.py` clean **and** all 5 existing
  headless suites green **and** `sprite_contract_test` green.
- Commit per phase with a clear message; one PR per phase.
- If a decision is ambiguous (e.g. the exact shade of a ramp), make the choice,
  record it in `docs/ART_CONTRACT.md`, and continue — do not stop and ask.

## 4. Deliverables

```
tools/measure_hero_sheets.py
tools/normalize_hero_sheets.py
tests/sprite_contract_test.gd
tests/sprite_contract_test.tscn
docs/ART_CONTRACT.md
docs/images/silhouettes.png          # Phase 4 gate
docs/images/hero_size_lineup.png     # heroes + slime, true scale, before/after
.github/workflows/tests.yml
```
