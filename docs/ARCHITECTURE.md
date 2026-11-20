# Technical Architecture

> Purpose of this document: when we reach local co-op and online play,
> we should not be forced into a full rewrite. These are the "building
> rules" — any change that breaks one of them means we either update the
> rule here or change the code.

## Engine and Tooling

- **Godot 4.7.2** — GDScript, pixel art (texture filter = Nearest)
- The `godot_ai` addon for agent-driven development (we lean on it
  heavily — the game itself does not depend on it, but our development does)
- Logical resolution: 1280×720; sprites 24×24 (player), 16×16 (current enemies)

## Collision Layers (committed — do not change without updating this table)

| Bit | Value | Meaning |
|-----|-------|---------|
| 1 | world | Walls / obstacles |
| 2 | player body | Player body |
| 3 | enemy body | Enemy body |
| 8 | player hitbox | Player dealing damage |
| 16 | enemy hurtbox | Enemy receiving damage |
| 32 | enemy attack | Enemy attack |
| 64 | player hurtbox | Player receiving damage |

## Signal Pattern (the most important rule)

Game components **emit signals**; what those signals do on screen is
wired in `main.gd` (HUD wiring):

```
Player.attack_hit(enemy)      → floating damage number
Player.health_changed(h, max) → health bar + red flash
Slime.died                    → kill count + wave empty
WaveSpawner.wave_started(n)   → "Wave n" banner
WaveSpawner.enemy_spawned(e)  → watch the newly spawned enemy
WaveSpawner.wave_cleared(n)   → "wave cleared" banner
```

Why? (1) Remove or replace the HUD and the game doesn't break. (2) In
co-op these same signals plug into a two-column HUD with no component
changes. (3) In netcode these same signals sync over the network.

Related hard rule: **damage logic flows one way only** — the player
damages the enemy, the enemy damages the player; never compute both
sides of a single collision.

## File Structure (convention)

```text
scenes/
  main.tscn              arena scene + UI + WaveSpawner
  player/Player.tscn     the player
  enemies/Slime.tscn     one scene per enemy
scripts/
  main.gd                signal wiring + HUD + game over
  player/player.gd       input / movement / combo
  enemies/slime.gd       enemy state machine (AI, health, signals)
  enemies/slime_visuals.gd the slime's look: poses, hop, squash, goo FX
  enemies/archer_visuals.gd the archer's look: shamble, rattle, bow draw,
                         mocking tilt, white flash, bone-heap death
  enemies/golem_visuals.gd the golem's look: stomp + dust + footstep shake,
                         arm-raise, slam, stuck recovery, crumble
  enemies/wave_spawner.gd wave system
  ui/                    health bar and HUD
  fx/                    effects
  audio/sfx_generator.gd procedural sound (static factories)
  upgrades/upgrade_pool.gd in-run roguelike upgrade pool
assets/textures/         pixel art (slime.png is a 12x8 family pose sheet;
                         fx_acid_pool / fx_blast_ring / fx_blast_burst are
                         1:1 hazard strips from tools/make_fx_sprites.py)
docs/SLIME_REDESIGN.md   the slime art/animation bible
docs/ARCHER_REDESIGN.md   the archer art/animation bible
docs/GOLEM_REDESIGN.md    the golem art/animation bible
docs/VELMIRA_REDESIGN.md  the vampire hero art bible (female redesign)
docs/                    these documents
tests/                   headless test scripts
```

## Cookbook: Adding a New Enemy

1. Build a 16×16 (or 24×24) sprite with Python/PIL → `assets/textures/`
   (for multi-pose enemies, generate a sheet like `tools/make_slime_sprites.py`
   and separate "look" from "brain" like `slime_visuals.gd` does)
2. `scenes/enemies/<Name>.tscn` following the Slime.tscn skeleton: Body +
   HurtBox + AttackArea + health bar + SFX players
3. Script under `scripts/enemies/` — state machine with a **clear telegraph**
   (pillar 4 from VISION)
4. The `died` signal must be emitted (the wave system depends on it)
5. Add the type to the list in `wave_spawner.gd` (weighted in later waves)
6. Test: manual spawn, death with particle burst, zero log errors

## Multiplayer-Readiness Rules (follow from day one)

1. **Read input in one place**: all input reading in player.gd lives only
   in `_read_input()`; in Phase 10 this same function goes behind the
   input profile of player 1/2 without touching the rest of the code.
2. **Decisions happen at the "owner" only**: every game number and
   decision (damage, death, wave count) is computed in exactly one place —
   the player deals its own damage, the spawner builds its own wave.
   Future clients only display results (authoritative model).
3. **No cross-scene node-name dependencies**: communication only via
   signals or references passed in `_ready` — never forced find-from-outside
   into a scene tree.
4. `reload_current_scene` is a single-player-only shortcut; run reset must
   become a central function (`reset_run()` in Phase 10) that wipes all
   state.

## Known Weak Spots To Strengthen

- **Balance**: every numeric balance change gets recorded in the Balance
  Log (`docs/CHARACTERS.md`).
- **Progress saving**: none yet; Phase 9 adds it with `user://save.json`.
