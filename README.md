# Roguelike Brawler

A top-down 2D brawler built with **Godot 4.7** (GDScript, `gl_compatibility`
renderer, placeholder art).

## Run

```bash
godot --path .            # or open project.godot in the editor and hit F5
```

**Controls:** `WASD` / arrow keys to move, `Space` or left click to punch.

## Phase 1 - movement baseline

Tile-sized 16x16 player, 8-directional movement, idle/walk animation,
smoothing camera with arena limits, wall collisions, and an attack flag
that locks movement for the length of a swing.

## Phase 2 - melee combat + first enemy

- **Melee hitbox:** `Player/Hitbox` (Area2D, 20x16) at the `AttackPoint`,
  off by default, enabled for 0.1 s starting 0.05 s into a 0.2 s swing.
- **Attack animation:** `idle` / `walk` / `attack` (3 keys, no loop) plus a
  `PunchFx` overlay that shows the extended punch for the hit window.
- **Damage:** `attack_damage = 10`; hits call `enemy.take_damage()` once
  per swing per enemy and broadcast `attack_hit(enemy)`.
- **Feedback:** the enemy flashes white for 0.1 s, a hit spark pops at the
  impact point, `-10` floats up, and the HUD tracks damage and kills.
- **Enemy:** `Slime` - 30 HP, custom health bar, follows the player at
  40 px/s inside 200 px, stops at 24 px, and pops in 3 hits.
- **Arena:** 3 slimes at (200, 200), (600, 400), (1000, 300).

Design notes and the full combat walkthrough: [`docs/combat.md`](docs/combat.md).

## Verify

```bash
godot --headless --path . tests/combat_test.tscn
```

60 automated checks (hitbox timing, 3-hit kill math, single-hit-per-swing,
white flash, signals, AI chase/stop, `queue_free()`, Phase 1 regression).
Exit code `0` means everything passed.
