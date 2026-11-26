# Roguelike Brawler (Godot 4.7)

A pixel-art top-down 2D action roguelike built in **Godot 4.7** with pure GDScript, unified `96×96` pixel-art hero sprites (`0.5×` world scale, `GROUND_Y = 80`), and procedural retro audio.

## Playable Heroes (Choose in the Guild Hub!)

Inspect and choose from **4 distinct heroes** in the Guild Hub / Character Select screen (`Hover / A-D` to preview live, `Click` or `1–4` / `Enter` to play):

1. **Behemoth — Pit-Champion Brawler (`120 HP`)**: Broad melee pit-champion with spiked iron cestus gauntlets, a **3-Hit Escalating Combo** (*Jab `18` → Cross `21` → Stun Uppercut `29 DMG`*), and an **18-DMG Shoulder-Ram Shift Dash**.
2. **Knight — Fallen Knight (`150 HP`)**: Plated frontline tank wielding a colossal Zweihander greatsword (`28 DMG`), a **16-DMG Shield-Wall Ram (`Shift`)**, and an active **Tower Shield (`Right-Click` or `E`)** that blocks **100%** of frontal attacks and arrows.
3. **Sylvara — Elven Ranger (`100 HP`)**: Fastest hero in the arena! Fires rapid recurve-bow shots (`15 DMG`, 3-arrow fan every 4th quick shot) or **hold Attack** (`≥0.35s`) for a `30 DMG` **Piercing Wind-Shot**. Her `Shift` **Wind-Vault** deals `0` damage and **phases cleanly through enemies**!
4. **Noa — Crimson Vampire (`75 HP`)**: Unleashes a mid-range **Crimson Blood Splash** slash (`18 DMG` + stacking Vampire Fang marks). Every cast sacrifices **`-5 HP`** of her own blood, and hitting an enemy drains **`+7 HP`** (`+2 HP` net gain) — rewarding accuracy and punishing blind spam! (`Shift` is a `0`-damage Crimson Mist-Step.)

## Controls

| Action | Keys / Mouse |
|--------|--------------|
| Move (8-directional) | `W A S D` or `Arrow Keys` |
| Attack / Charge Bow (Sylvara) | `Space` or `Left Mouse Click` |
| **Raise Tower Shield** (Knight — 100% Frontal Block) | `Right Mouse Click` or `E` |
| **Shift Dash** (`1.0s` CD — DMG on Behemoth/Knight; Enemy Phase on Sylvara/Noa) | `Shift` |
| Confirm Hero / Pick Upgrade | `Click`, `1`–`4`, or `Enter / Space` |
| Quick Retry (on Game Over, same hero) | `R` |
| Change Hero (anytime or on Game Over) | `Esc` (or `C` on Game Over) |

## Core Features

- **Unified `96×96` Pixel-Art Heroes (`docs/ART_CONTRACT.md`)**: Four distinct medieval heroes (**Behemoth**, **Knight**, **Sylvara**, and **Noa**) rendered on crisp `96×96` `NEAREST`-filtered strips at `Visuals.scale = Vector2(0.5, 0.5)` (`72 px` standing height, `GROUND_Y = 80`, shared 32-colour 4-step ramp, selective selout outlines) with circular HUD portraits (`tools/make_*_sprites.py`, `tools/measure_hero_sheets.py`).
- **Hand-Animated Jelly Slimes** (`slime_visuals.gd` + `tools/make_slime_sprites.py`): rounded 32×32 dome with banded pixel shading, glossy specular, blink, a 3-stage hop with squash & stretch, red tremble wind-up, white silhouette hit flash, goo-splat death decal, and an elite variant — regenerated from one command (`docs/SLIME_REDESIGN.md`).
- **Heavy Stone Golems** (`golem_visuals.gd` + `tools/make_golem_sprites.py`): a 40×40, 12-pose brute — tiny head between boulder shoulders, arms to the knees, a chest cracked open with amber seams — with a stomp cycle that drops the whole body, kicks dust and nudges the camera on every footfall, both fists overhead for the 0.8 s telegraph, fists-in-the-floor slam, a slumped stuck-in-the-ground punish window, an elite flare and a crumble into rubble. Same 90 HP, 30 px/s and 15 damage as before (`docs/GOLEM_REDESIGN.md`).
- **Rattling Skeleton Archers** (`archer_visuals.gd` + `tools/make_archer_sprites.py`): a 32×32, 12-pose hooded skeleton rig — aged bone under a torn cloak, two ember eyes in a void face, a full bow draw → release → mocking head tilt, idle bone rattles, a white silhouette hit flash and a collapse into a bone heap. The "annoying" is all in the motion: its HP, speed and damage are untouched (`docs/ARCHER_REDESIGN.md`).
- **A Slime Family That Escalates** (`slime_variant.gd`): the slime slot now rolls **Grass → Acid (wave 3) → Ember (wave 6) → Basalt (wave 9)** with a wave-weighted ladder. Each one is the same 12-pose rig with its own silhouette feature (sizzling base, flame crest, stone spikes), its own stat multipliers, and exactly one new mechanic: acid dies into a `3 dmg / 0.5 s` pool, ember detonates `0.55 s` after death behind a painted ground circle, basalt's spiked shell does `4` contact damage on a `0.8 s` tick. The hazards they leave behind are pixel-art strips drawn at exactly the damaging radius, never vector circles (`tools/make_fx_sprites.py`, `docs/SLIME_VARIANTS.md`).
- **Tactical Proximity Mini-Map** (`scripts/ui/minimap.gd`): Top-right `1:10` arena map showing walls, obstacles, and player position (no camera box clutter). Distant enemies (`> 210 px`) only display **directional arrows (`➔`)** pointing their way until you close in (`<= 210 px`) to reveal their exact position!
- **Endless Escalating Waves, Elites & Bosses** (`WaveSpawner` + `ForestColossus`): Slimes, Skeleton Archers, Stone Golems, `3x HP` Elites, and 5th-wave Boss fights.
- **Between-Wave Roguelike Upgrades** (`UpgradePool` + `UpgradeMenu`): Pick 1 of 3 stacking run upgrades after every cleared wave.
- **Procedural Combat Juice**: `ScreenShake`, `HitStop`, and procedural 16-bit PCM synth SFX (`SFXGenerator` on the `"SFX"` bus — zero external audio files).

## AI Sprite Pipeline (Agent Sprite Forge)

**Agent Sprite Forge v0.6.0** (`tools/agent-sprite-forge/`) is vendored alongside the hand-rolled
`tools/make_*.py` generators: five agent skills (`generate2dsprite`, `video2dsprite`,
`generate2dmap`, `generate2dmedia`, `codeart2d`) that take characters from one approved master
still through keyed, QA-gated, registered animation sets to Godot `SpriteFrames` exports.
See `docs/SPRITE_FORGE.md` for capability status, usage and update instructions.

## Automated Headless Tests

```bash
python3 tools/measure_hero_sheets.py --strict
godot --headless --path . tests/sprite_contract_test.tscn
godot --headless --path . tests/heroes_and_dash_test.tscn
godot --headless --path . tests/archer_test.tscn
godot --headless --path . tests/boss_test.tscn
godot --headless --path . tests/combat_test.tscn
godot --headless --path . tests/slime_variants_test.tscn
```
