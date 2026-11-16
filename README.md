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
- **Attack animation:** 4-frame 64x16 sprite sheet (`idle` = frame 0,
  `walk` = frames 1-2, `attack` = frame 0 @ 0.0 s -> frame 3 punch pose @ 0.05 s
  -> frame 0 @ 0.15 s, loop disabled) on a single `Visuals` sprite.
- **Damage:** `attack_damage = 10`; hits call `enemy.take_damage()` once
  per swing per enemy and broadcast `attack_hit(enemy)`.
- **Feedback:** the enemy flashes white for 0.1 s, a 6x6 fist-colored hit spark
  pops only on impact, `-10` floats up, and the HUD tracks damage and kills.
- **Enemy:** `Slime` - 30 HP, custom health bar, follows the player at
  40 px/s inside 200 px, stops at 24 px, and pops in 3 hits.
- **Arena:** 3 slimes at (200, 200), (600, 400), (1000, 300).

Design notes and the full combat walkthrough: [`docs/combat.md`](docs/combat.md).

## Verify

```bash
godot --headless --path . tests/combat_test.tscn
```

68 automated checks (4-frame sprite sheet & punch pose region, no duplicate
body sprite during attack, hitbox timing, 3-hit kill math, single-hit-per-swing,
white flash, 6x6 hit spark, signals, AI chase/stop, `queue_free()`, Phase 1
regression). Exit code `0` means everything passed.
