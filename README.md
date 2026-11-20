# Roguelike Brawler (Godot 4.7)

A pixel-art top-down 2D action roguelike built in **Godot 4.7** with pure GDScript and procedural retro audio.

## Playable Heroes (Choose on Launch!)

When the game opens, inspect and choose from **4 distinct heroes** on the Showcase Character Select screen (`Hover / A-D` to preview in the live Arena, `Click` or `1–4` / `Enter` to play):

1. **Behemoth — Brawler (`100 HP`)**: Heavy melee brawler with a **3-Hit Escalating Combo** (*Jab → Cross → Shockwave Uppercut*) and a 14-damage **Shoulder Dash**.
2. **Knight — Frost Greatsword (`120 HP`)**: Armored tank wielding a wide frost greatsword (`24 DMG`) and his signature **Winter Aura** that chills & slows nearby enemies (charging wider + pulsing frost damage when standing firm).
3. **Sylvara — Elven Ranger (`75 HP`)**: Fastest hero in the arena! Fires swift emerald arrows (3-arrow fan every 4th quick shot), or **hold Attack** (`≥0.35s`) to unleash a 2× damage **Piercing Great-Arrow**.
4. **Velmira — Crimson Vampire (`85 HP`)**: Hurls a spinning **Boomerang Blood Blade** that slices enemies going out *and* returning. Every hit **leeches HP** and builds Blood Orbs toward an explosive **Crimson Blood Nova**.

## Controls

| Action | Keys / Mouse |
|--------|--------------|
| Move (8-directional) | `W A S D` or `Arrow Keys` |
| Attack / Charge (Sylvara) | `Space` or `Left Mouse Click` |
| **Dash** (`1.0s` cooldown, phases & damages enemies!) | `Shift` |
| Inspect Hero on Select Screen | `Mouse Hover`, `A / D`, or `Left / Right` |
| Confirm Hero / Pick Upgrade | `Click`, `1`–`4`, or `Enter / Space` |
| Quick Retry (on Game Over, same hero) | `R` |
| Change Hero (anytime or on Game Over) | `Esc` (or `C` on Game Over) |

## Core Features

- **Showcase Character Select + Live Arena Preview** (`scripts/ui/character_select_menu.gd`): Animated 3× hero pedestal, graphical stat bars (`HP / ATK / SPD / DASH`), full kit breakdown, and translucent live-arena backdrop.
- **Top-Right Tactical Mini-Map** (`scripts/ui/minimap.gd`): Exact `1:10` live radar of the `1280×720` arena showing stone obstacles, active camera window, player facing, and color-coded enemy blips (Slimes, Archers, Golems, golden-ring Elites, and Boss beacons).
- **4 Playable Characters + `PlayerBase` Architecture** (`scripts/player/`): Shared input (`_read_input()`), health, i-frames, and `1.0s` Shift-Dash contract across all heroes.
- **Endless Escalating Waves, Elites & Bosses** (`WaveSpawner` + `ForestColossus`): Slimes, Skeleton Archers, Stone Golems, `3x HP` Elites, and 5th-wave Boss encounters.
- **Between-Wave Roguelike Upgrades** (`UpgradePool` + `UpgradeMenu`): Pick 1 of 3 stacking run upgrades after every cleared wave.
- **Procedural Combat Juice**: `ScreenShake`, `HitStop`, and procedural 16-bit PCM synth SFX (`SFXGenerator` on the `"SFX"` bus — zero external audio files).

## Automated Headless Tests

```bash
godot --headless --path . tests/heroes_and_dash_test.tscn
godot --headless --path . tests/archer_test.tscn
godot --headless --path . tests/boss_test.tscn
```
