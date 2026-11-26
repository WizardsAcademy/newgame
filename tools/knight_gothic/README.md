# Knight Gothic Reskin — Sprite Forge production run (2026-11-26)

Replaces `assets/textures/player_knight.png` and `assets/textures/portrait_knight.png`
with a version of the user's reference character (great-helm knight: cylindrical
riveted helm, crimson scarf, tattered dark cape with crimson lining, dark plate,
silver cross pendant, blue-cross heater shield, blue-sheen Zweihander).

Same pipeline as `tools/sylvara_autumn` / `tools/noa_gothic` (`pipeline.py`):
magenta chroma-key + border flood-fill + despill → crop → NEAREST scale →
24-colour palette lock (`palette.json`) → 64×64 ground placement → per-frame QA
gate (body height, exact ground row, off-palette colours, #000000, magenta spill,
edge clipping).

Palette reuses the game's own master ramps (`docs/ART_CONTRACT.md` §2) for
steel / obsidian / crimson / leather, plus new sapphire (blue cross, blade sheen,
pommel gem) and bone (pendant, rivets) ramps — keeps the knight consistent with
the cast while matching the reference.

## Old-sheet geometry replicated

| Frame | Old sheet | New sheet |
|---|---|---|
| standing | 48 px, bottom 54 | 48 px, bottom 54 |
| f03 windup | 51 px (top y=3) | 51 px (blade overhead) |
| f04/f05 sweep+spin | 48 px, x=11–64 (wide) | 44 px, x=2–61 (same scale-to-fit trick) |
| ground set | {54} | {54} |

Two QA failures on the first pass (sweep/spin 64px wide, touching both cell edges)
were fixed deterministically with the repo's own uniform-scale-to-fit technique —
the same approach the original hand-drawn sheet used. 0 bad frames shipped.

## Frames (sheet order = game mapping)

`f00 idle · f01/f02 walk · f03 windup · f04 sweep · f05 spin · f06 guard ·
f07 shield-ram charge · f08 hurt · f09 blink (dark visor slit) · f10 idle_down ·
f11/f12 walk_down · f13 idle_up (shield-on-back) · f14/f15 walk_up`.
All pose edits of the approved master (`raw/f00_idle.png`); front/back views
derived from a single front-facing edit of it (edit-locality).

## Portraits (`portrait_sheet.png`, 5 × 64×64)

`0 idle (crimson glint in visor) · 1 idle_b (1px sway) · 2 blink (dark slit) ·
3 low_hp (cool steel-void dim over hurt) · 4 hurt (dented helm, flaring crimson
eyes, impact spark)` — matches `hero_hud.gd` state indices.

## Verification

- `python3 tools/measure_hero_sheets.py --strict` → exit 0 for all heroes
  (knight: 16 frames, f0_h 48, 24 colours ≤ 24, 0.00% semi-alpha, 0 black px)
- Godot headless suites to be run where a godot binary exists

## Cost

19 image generations: 1 master + 9 combat-pose edits + 6 view frames + 1 portrait
base + 2 portrait edits. QA-rejected takes: 2 (both recovered by scale-to-fit,
no regeneration needed). Budgets: 10 first message + 9 second.

Rollback: previous sheets recoverable from git history of `assets/textures/`.
