# Behemoth Pit-Champion Reskin — Sprite Forge production run (2026-11-26)

Replaces `assets/textures/player_behemoth.png` and `assets/textures/portrait_behemoth.png`
with a version of the user's reference character (wild-haired bearded shirtless
pit-champion: enormous spiky dark-brown hair, full beard, hand wraps, bare
torso, tattered pants with tan-gold sash, bare feet).

Same pipeline as `tools/sylvara_autumn` / `tools/noa_gothic` / `tools/knight_gothic`
(`pipeline.py`): magenta chroma-key + border flood-fill + despill → crop →
NEAREST scale → 24-colour palette lock (`palette.json`) → 64×64 ground placement
→ per-frame QA gate (body height, exact ground row, off-palette colours,
#000000, magenta spill, edge clipping).

Palette reuses the game's master skin/leather/gold ramps (docs/ART_CONTRACT.md §2)
plus a new tawny ramp for the hair/beard and obsidian for the hand wraps.

## Old-sheet geometry replicated

| Frame | Old sheet | New sheet |
|---|---|---|
| standing | 49 px, bottom 54 | 48 px, bottom 54 |
| f06 uppercut | 51 px (top y=3) | 51 px (fist overhead) |
| f04/f05 jab/cross | reach x=64 (right edge) | reach x=61–62 |
| ground set | {54} | {54} |

QA: 0 rejected takes across all 19 generations this run — every frame passed
the gate on its first pipeline pass.

## Frames (sheet order = game mapping)

`f00 fight-stance idle · f01/f02 walk · f03 coiled windup · f04 jab · f05 cross ·
f06 rising uppercut · f07 shoulder-ram charge · f08 hurt (flying tooth) · f09 blink ·
f10 idle_down · f11/f12 walk_down · f13 idle_up (bare back + hair) · f14/f15 walk_up`.
All pose edits of the approved master (`raw/f00_idle.png`); front/back views
derived from a single front-facing edit of it (edit-locality).

## Portraits (`portrait_sheet.png`, 5 × 64×64)

`0 glare · 1 idle_b (1px sway) · 2 blink · 3 low_hp (bruised drained blend) ·
4 hurt (scrape + flying tooth)` — matches `hero_hud.gd` state indices.

## Verification

- `python3 tools/measure_hero_sheets.py --strict` → exit 0 for all four heroes
  (behemoth: 16 frames, f0_h 48, 20 colours ≤ 24, 0.00% semi-alpha, 0 black px)
- Godot headless suites to be run where a godot binary exists

## Cost

19 image generations: 1 master + 9 combat-pose edits + 6 view frames + 1 portrait
base + 2 portrait edits. Budgets: 10 first message + 9 second.

Rollback: previous sheets recoverable from git history of `assets/textures/`.
