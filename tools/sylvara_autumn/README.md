# Sylvara Autumn Reskin — Sprite Forge production run (2026-11-26)

Replaces `assets/textures/player_sylvara.png` and `assets/textures/portrait_sylvara.png`
with a version of the user's reference character (red-haired autumn elf ranger with
golden recurve bow, green cape, leather corset/boots, autumn-leaf decorations).

## Pipeline (every frame, no exceptions)

`raw/` (1024x1024 magenta-keyed generations) → `pipeline.py`:
1. magenta chroma-key: `min(R,B) - G > 35` + border flood-fill + green-despill
2. crop → `NEAREST` scale to target body height (41 px, vault 40)
3. palette lock to 24 colours (`palette.json`: 6 ramps × 4 steps, sampled from the
   reference; snap threshold d<90, outliers rejected by QA)
4. 64×64 placement on the contract ground line
5. QA gate: body height range, exact bottom row, off-palette colours, `#000000`,
   magenta spill, cell-edge clipping — failures are never shipped

## Frames (sheet order = game frame mapping)

`f00 idle · f01/f02 walk · f03 bow draw · f04 charge · f05 release · f06 vault (air,
bottom=46) · f07 hurt (54) · f08 blink · f09 idle_down · f10/f11 walk_down · f12 idle_up
· f13/f14 walk_up` — all generated as single-change edits of the approved master
(`raw/f00_idle.png`), per the forge's edit-locality discipline.

Ground set `{46,53,54}` matches the previous hand-drawn sheet exactly, so no scene or
`Visuals.position` changes were needed.

## Portraits (`portrait_sheet.png`, 5 × 64×64)

HUD states in `hero_hud.gd` order: `0 idle · 1 idle_b (1px sway) · 2 blink · 3 low_hp
(pale skin blend over hurt face) · 4 hurt`. Base close-up generated from the reference,
blink/hurt as single-change edits.

## Verification

- `python3 tools/measure_hero_sheets.py --strict` → exit 0 for all heroes
  (sylvara: 15 frames, f0_h 41, 23 colours ≤ 24, 0.00% semi-alpha, 0 black px)
- Per-frame QA logs: see the run output; `qa/` holds contact sheets and previews
- Godot headless suites (`tests/sprite_contract_test.tscn`) still to be run where a
  godot binary is available (not installed in this sandbox)

## Cost

19 image generations total: 1 master + 14 pose edits + 1 portrait base + 2 portrait edits
+ 1 spare from a failed batch (source-image race, regenerated). QA-rejected takes: 0.

Rollback: previous sheets recoverable from git history of `assets/textures/`.
