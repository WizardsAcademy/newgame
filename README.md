# Roguelike Brawler (Godot 4.7)

A pixel-art top-down 2D action roguelike built in **Godot 4.7** with pure GDScript and procedural retro audio.

## Playable Heroes (Choose on Launch!)

When the game opens, pick from **4 distinct heroes** via the Character Select screen (`Click`, `1–4`, or `Arrows + Enter/Space`):

1. **Borzo — Brawler (`100 HP`)**: Heavy melee brawler with a **3-Hit Escalating Combo** (*Jab → Cross → Shockwave Uppercut*) and a 14-damage **Shoulder Dash**.
2. **Bahman — Frost Knight (`120 HP`)**: Armored tank wielding a wide frost greatsword (`24 DMG`) and his signature **Winter Aura** that chills & slows nearby enemies (charging wider + pulsing frost damage when standing firm).
3. **Pari — Elf Ranger (`75 HP`)**: Fastest hero in the arena! Fires swift emerald arrows (3-arrow fan every 4th quick shot), or **hold Attack** (`≥0.35s`) to unleash a 2× damage **Piercing Great-Arrow**.
4. **Shabnam — Crimson Vampire (`85 HP`)**: Hurls a spinning **Boomerang Blood Blade** that slices enemies going out *and* returning. Every hit **leeches HP** and builds Blood Orbs toward an explosive **Crimson Blood Nova**.

## Controls

| Action | Keys / Mouse |
|--------|--------------|
| Move (8-directional) | `W A S D` or `Arrow Keys` |
| Attack / Charge (Pari) | `Space` or `Left Mouse Click` |
| **Dash** (`1.0s` cooldown, phases & damages enemies!) | `Shift` |
| Pick Upgrade / Hero | `1` / `2` / `3` (`/ 4` on Hero Select) or `Click` |
| Quick Retry (on Game Over, same hero) | `R` |
| Change Hero (anytime or on Game Over) | `Esc` (or `C` on Game Over) |

## Core Features

- **4 Playable Characters + `PlayerBase` Architecture** (`scripts/player/`): Shared input (`_read_input()`), health, i-frames, and Shift-Dash contract across all heroes.
- **Shift-Dash Combat Mobility**: `1.0s` cooldown burst that phases through enemies while respecting walls, grants brief i-frames, leaves afterimages, and deals dash damage.
- **Endless Escalating Waves & Elites** (`WaveSpawner`): Slimes, Skeleton Archers (with ground risk lines & panic exhaustion), Stone Golems, and golden-ring `3x HP` Elites.
- **Boss Waves (`Forest Colossus`)**: Every 5th wave features a 1v1 boss fight with floor danger-zone telegraphs (`SLAM` / `SWEEP` / `ROOTS`) and `<30% HP` Enrage.
- **Between-Wave Roguelike Upgrades** (`UpgradePool` + `UpgradeMenu`): Pick 1 of 3 stacking run upgrades after every cleared wave.
- **Procedural Combat Juice**: `ScreenShake`, `HitStop`, and procedural 16-bit PCM synth SFX (`SFXGenerator` on the `"SFX"` bus — zero external audio files).

## Automated Headless Tests

```bash
godot --headless --path . tests/heroes_and_dash_test.tscn
godot --headless --path . tests/archer_test.tscn
godot --headless --path . tests/boss_test.tscn
```
