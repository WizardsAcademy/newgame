# Roguelike Brawler (Godot 4.7)

A pixel-art top-down 2D action roguelike built in **Godot 4.7** with pure GDScript, high-detail `32×32` hero sprites, and procedural retro audio.

## Playable Heroes (Choose on Launch!)

Inspect and choose from **4 distinct heroes** on the Showcase Character Select screen (`Hover / A-D` to preview live in the Arena, `Click` or `1–4` / `Enter` to play):

1. **Behemoth — Iron-Fist Brawler (`100 HP`)**: Heavy melee brawler with spiked iron gauntlets, a **3-Hit Escalating Combo** (*Jab → Cross → Shockwave Uppercut*), and a **16-DMG Shoulder-Smash Shift Dash**.
2. **Knight — Shield & Greatsword (`120 HP`)**: Armored tank wielding a wide steel greatsword (`24 DMG`), a **14-DMG Shield Charge (`Shift`)**, and an active **Kite Shield (`Right-Click` or `E`)** that reduces incoming damage by **60%** (e.g. `10` damage → blocks `6`, takes `4`!).
3. **Sylvara — Elven Ranger (`75 HP`)**: Fastest hero in the arena! Fires rapid recurve-bow shots (3-arrow fan every 4th quick shot) or **hold Attack** (`≥0.35s`) for a 2× damage **Piercing Great-Arrow**. Her `Shift` **Phantom Windstep** deals `0` damage and **phases cleanly through enemies**!
4. **Velmira — Crimson Vampire (`85 HP`)**: Unleashes a mid-range **Crimson Blood Splash** cone (`17 DMG`). Every cast sacrifices **`-6 HP`** of her own blood, and hitting an enemy heals **`+8 HP`** (`+2 HP` net gain) — rewarding accuracy and punishing blind spam! (`Shift` is a `0`-damage Crimson Evade.)

## Controls

| Action | Keys / Mouse |
|--------|--------------|
| Move (8-directional) | `W A S D` or `Arrow Keys` |
| Attack / Charge Bow (Sylvara) | `Space` or `Left Mouse Click` |
| **Raise Kite Shield** (Knight — 60% DMG Reduction) | `Right Mouse Click` or `E` |
| **Shift Dash** (`1.0s` CD — DMG on Behemoth/Knight; Enemy Phase on Sylvara) | `Shift` |
| Confirm Hero / Pick Upgrade | `Click`, `1`–`4`, or `Enter / Space` |
| Quick Retry (on Game Over, same hero) | `R` |
| Change Hero (anytime or on Game Over) | `Esc` (or `C` on Game Over) |

## Core Features

- **High-Detail `32×32` Pixel-Art Heroes**: Custom-shaded spritesheets with dark pixel outlines, weapons, shields, quivers, and gothic cloaks. **Velmira** is generated from a script (`tools/make_velmira_sprites.py`): long lilac hair falling to her waist over a pale face with crimson eyes, a dark violet gown cinched `13 → 9 → 17` px at the waist with a crimson underbust sash and a gold hem, and blood magic in her gloves — same 85 HP and 17 DMG Blood Splash (`docs/VELMIRA_REDESIGN.md`).
- **Hand-Animated Jelly Slimes** (`slime_visuals.gd` + `tools/make_slime_sprites.py`): rounded 32×32 dome with banded pixel shading, glossy specular, blink, a 3-stage hop with squash & stretch, red tremble wind-up, white silhouette hit flash, goo-splat death decal, and an elite variant — regenerated from one command (`docs/SLIME_REDESIGN.md`).
- **Heavy Stone Golems** (`golem_visuals.gd` + `tools/make_golem_sprites.py`): a 40×40, 12-pose brute — tiny head between boulder shoulders, arms to the knees, a chest cracked open with amber seams — with a stomp cycle that drops the whole body, kicks dust and nudges the camera on every footfall, both fists overhead for the 0.8 s telegraph, fists-in-the-floor slam, a slumped stuck-in-the-ground punish window, an elite flare and a crumble into rubble. Same 90 HP, 30 px/s and 15 damage as before (`docs/GOLEM_REDESIGN.md`).
- **Rattling Skeleton Archers** (`archer_visuals.gd` + `tools/make_archer_sprites.py`): a 32×32, 12-pose hooded skeleton rig — aged bone under a torn cloak, two ember eyes in a void face, a full bow draw → release → mocking head tilt, idle bone rattles, a white silhouette hit flash and a collapse into a bone heap. The "annoying" is all in the motion: its HP, speed and damage are untouched (`docs/ARCHER_REDESIGN.md`).
- **A Slime Family That Escalates** (`slime_variant.gd`): the slime slot now rolls **Grass → Acid (wave 3) → Ember (wave 6) → Basalt (wave 9)** with a wave-weighted ladder. Each one is the same 12-pose rig with its own silhouette feature (sizzling base, flame crest, stone spikes), its own stat multipliers, and exactly one new mechanic: acid dies into a `3 dmg / 0.5 s` pool, ember detonates `0.55 s` after death behind a painted ground circle, basalt's spiked shell does `4` contact damage on a `0.8 s` tick. The hazards they leave behind are pixel-art strips drawn at exactly the damaging radius, never vector circles (`tools/make_fx_sprites.py`, `docs/SLIME_VARIANTS.md`).
- **Tactical Proximity Mini-Map** (`scripts/ui/minimap.gd`): Top-right `1:10` arena map showing walls, obstacles, and player position (no camera box clutter). Distant enemies (`> 210 px`) only display **directional arrows (`➔`)** pointing their way until you close in (`<= 210 px`) to reveal their exact position!
- **Endless Escalating Waves, Elites & Bosses** (`WaveSpawner` + `ForestColossus`): Slimes, Skeleton Archers, Stone Golems, `3x HP` Elites, and 5th-wave Boss fights.
- **Between-Wave Roguelike Upgrades** (`UpgradePool` + `UpgradeMenu`): Pick 1 of 3 stacking run upgrades after every cleared wave.
- **Procedural Combat Juice**: `ScreenShake`, `HitStop`, and procedural 16-bit PCM synth SFX (`SFXGenerator` on the `"SFX"` bus — zero external audio files).

## Automated Headless Tests

```bash
godot --headless --path . tests/heroes_and_dash_test.tscn
godot --headless --path . tests/archer_test.tscn
godot --headless --path . tests/boss_test.tscn
godot --headless --path . tests/combat_test.tscn
godot --headless --path . tests/slime_variants_test.tscn
```
