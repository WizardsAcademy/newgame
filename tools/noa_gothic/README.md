# Noa Gothic Noble Reskin — Sprite Forge production run (2026-11-26)

Replaces `assets/textures/player_noa.png` and `assets/textures/portrait_noa.png`
with a version of the user's reference character (petite vampire princess: long
silver-white hair waterfall, gold crown with crimson gems, deep-red rose, black
gothic dress with crimson trim, gold chains/crosses, white cross-emblem stockings).

Same pipeline as `tools/sylvara_autumn` (`pipeline.py`): magenta chroma-key +
border flood-fill + despill → crop → NEAREST scale → 24-colour palette lock
(`palette.json`, ramps sampled from the reference) → 64×64 ground placement →
per-frame QA gate (body height, exact ground row, off-palette colours, #000000,
magenta spill, edge clipping).

## Old-sheet geometry replicated

| Frame | Old sheet | New sheet |
|---|---|---|
| standing | 41 px, bottom 53 | 40 px, bottom 53 |
| f05 charge (crouch) | 30 px, bottom 52 | 31 px, bottom 52 |
| f06 hurt | 42 px, bottom 54 | 41 px, bottom 54 |
| f09 death pool | 9 px puddle, bottom 54 | 11 px puddle + crown/rose/hair, bottom 54 |
| ground set | {52,53,54} | {52,53,54} |

`noa_fx.png` (Blood Splash slash VFX) is untouched and still matches: its crimson
reds were the basis of the dress-trim ramp.

## Frames (sheet order = game mapping)

`f00 idle · f01/f02 walk · f03 cast windup (crimson orb) · f04 cast slash
follow-through · f05 crouched charge · f06 hurt · f07 blink · f08 idle_b ·
f09 die pool · f10 idle_down · f11/f12 walk_down · f13 idle_up · f14/f15 walk_up`.
All pose edits of the approved master (`raw/f00_idle.png`); front/back views
derived from a single front-facing edit of it (edit-locality).

## Portraits (`portrait_sheet.png`, 5 × 64×64)

`0 idle · 1 idle_b (1px sway) · 2 blink · 3 low_hp (pale blend over hurt) ·
4 hurt` — matches `hero_hud.gd` state indices.

## Verification

- `python3 tools/measure_hero_sheets.py --strict` → exit 0 for all heroes
  (noa: 16 frames, f0_h 40, 23 colours ≤ 24, 0.00% semi-alpha, 0 black px)
- Per-frame QA logs in the run output; previews in `qa/`
- Godot headless suites to be run where a godot binary exists

## Cost

19 image generations total: 1 master + 9 move-set edits + 6 view frames (5 lost to
a source-image race on one batch and regenerated) + 1 portrait base + 2 portrait
edits. QA-rejected takes: 0. Budget: 10 first message + 9 second message.

Rollback: previous sheets recoverable from git history of `assets/textures/`.
