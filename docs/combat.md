# Combat system (Phase 2)

A short tour of how a punch travels from "key pressed" to "slime dies",
plus the places you will want to touch when you add the next enemy.

## The cast

| File | What it is |
| --- | --- |
| `scenes/player/Player.tscn` | Player root, `Hitbox` Area2D, `attack` animation |
| `scripts/player/player.gd` | Input, swing timing, hit detection, damage |
| `scenes/enemies/Slime.tscn` | Dummy slime: body, hurtbox, health bar |
| `scripts/enemies/slime.gd` | Health, white flash, death, follow AI |
| `scripts/ui/health_bar.gd` | Immediate-mode `draw_rect()` health bar |
| `scenes/fx/HitSpark.tscn` | One-shot impact spark |
| `scripts/utils/ScreenShake.gd` | Autoload `Camera2D` shake with stacking & decay |
| `scripts/utils/HitStop.gd` | Autoload `Engine.time_scale` impact freeze |
| `scripts/audio/sfx_generator.gd` | Procedural 16-bit `AudioStreamWAV` synth |
| `default_bus_layout.tres` | `"Master"` + `"SFX"` audio bus layout |
| `scenes/main.tscn` | Arena + 3 slimes at (200,200), (600,400), (1000,300) |
| `scripts/main.gd` | Level wiring: HUD stats, floating damage numbers |
| `tests/combat_test.gd` + `.tscn` | Headless verification suite (94 checks) |

## One punch, step by step

```
Space / left click
   └─ Player._unhandled_input()          "attack" action pressed
       └─ Player._start_attack()         is_attacking = true  (movement locks)
           ├─ AnimPlayer.play("attack")  0.0 s frame 0, 0.05 s frame 3 (punch), 0.15 s frame 0
           ├─ PunchSFX.play()            0.10 s swing burst (even on empty air)
           ├─ await 0.05 s               wind-up (attack_windup)
           ├─ Hitbox.monitoring = true   the fist is live + ScreenShake.shake(2.0, 0.1)
           ├─ await 0.1 s                ... for 6 physics frames (hitbox_active_time)
           └─ Hitbox.monitoring = false  fist off at 0.15 s, movement unlocks at 0.2 s

   meanwhile, while the fist is live:
   physics engine → Hitbox.area_entered(enemy Hurtbox)
       └─ Player._try_hit()
           ├─ already hit this enemy this swing?  → return (no multi-hit)
           ├─ HitStop.freeze(0.05)       50 ms impact freeze (time_scale = 0.05)
           ├─ ScreenShake.shake(3.0, 0.15) stronger impact shake (stacks!)
           ├─ enemy.take_damage(10)
           │     ├─ current_health -= 10
           │     ├─ HitSFX.play()        0.08 s higher-pitched impact pop
           │     ├─ HealthBar.set_health()
           │     ├─ flash_white(0.1)     sprite turns white, then back
           │     └─ current_health <= 0 → die() → DeathSFX.play() → tween → queue_free()
           ├─ spawn 6x6 fist-colored HitSpark (only on hit)
           └─ emit attack_hit(enemy)          anyone can listen
```

## Signals: the "broadcast, don't call" idea

The player never reaches into the slime to change its health bar, and it
never talks to the HUD, a sound manager or a score counter. It applies
damage, then **broadcasts a fact**:

```gdscript
signal attack_hit(enemy)          # player.gd
signal health_changed(current_health, max_health)   # slime.gd
signal died                       # slime.gd
```

Any node that cares can subscribe - it needs no reference to the player:

```gdscript
# Somewhere in a HUD script:
func _ready() -> void:
    var player := get_tree().get_first_node_in_group("player")
    player.attack_hit.connect(_on_attack_hit)

func _on_attack_hit(enemy: Node) -> void:
    print("Hit ", enemy.name)
```

This keeps modules independent: deleting the HUD must not break combat,
and adding a combo counter must not require editing `player.gd`.

## Collision layers

Set in the Inspector under **CollisionObject2D → Collision → Layer / Mask**.

| Layer | Name | Used by |
| --- | --- | --- |
| 1 | world | walls, obstacles |
| 2 | player body | `Player` (`collision_layer = 2`, mask 5) |
| 3 | enemy body | `Slime` (`collision_layer = 4`, mask 3) |
| 4 | player hitbox | `Player/Hitbox` (layer 8, **mask 16**) |
| 5 | enemy hurtbox | `Slime/Hurtbox` (layer 16, **mask 8**) |

In `.tscn` text files the number is a **bitmask**: `1 << (layer - 1)`,
so layer 2 = 2, layer 3 = 4, layer 4 = 8, layer 5 = 16.

`collision_layer` answers *"who am I?"*, `collision_mask` answers *"who
do I look for?"*. Detection is not mutual - the fist must look for
hurtboxes **and** the hurtbox must look for fists. Miss one half and the
punch silently does nothing; that is the classic first bug.

The fist deliberately does **not** mask layer 3 (enemy bodies), so a
swing can never hit another player or an enemy's physical body - only a
`Hurtbox` counts as a target.

## Tuning knobs (Inspector)

Player: `attack_damage` (10), `attack_duration` (0.2), `attack_windup`
(0.05), `hitbox_active_time` (0.1), `move_speed` (120).

Slime: `max_health` / `current_health` (30), `move_speed` (40),
`detection_range` (200), `stop_distance` (24), `flash_duration` (0.1),
`death_duration` (0.3), `body_color`.

30 health / 10 damage = **3 hits** to kill.

## Debug output

Run the game and watch the Output dock - every important step prints:

```
[Combat] Hitbox ON
[Slime] Slime1 took 10 damage  ->  HP 20/30
[Combat] Hit Slime1 for 10 damage
[Slime] Slime1 died
```

The on-screen HUD (`UI/Stats`) shows damage dealt, the last hit and the
kill counter, all fed by signals - see `scripts/main.gd`.

## Adding a second enemy

1. Duplicate `Slime.tscn`, rename the root, attach a new script (or
   extend `slime.gd`).
2. Keep the child names: `Visuals`, `AnimPlayer`, `Hurtbox` (+ child
   `CollisionShape2D`), `HealthBar`.
3. Keep `Hurtbox` on layer 5 with mask 8, and the body on layer 3.
4. Implement `take_damage(amount: int)` - that is the whole contract the
   player's hitbox needs. Nothing in `player.gd` changes.

## Verification

```bash
godot --headless --path . tests/combat_test.tscn
```

Exit code 0 = every check passed (94 checks). The suite loads the real
`main.tscn` and covers:

- scene & Phase 3 wiring: `ScreenShake` & `HitStop` autoloads, `"SFX"` bus,
  `AudioStreamPlayer` nodes on Player and Slimes, 64x16 4-frame sprite sheet,
  no `PunchFx` body overlay, 20x16 hitbox at (12,0) disabled by default,
  3 slimes at (200,200) / (600,400) / (1000,300) at 30 HP
- attack flow from a real `InputEventAction("attack")`: `PunchSFX` on start
  (without `HitSFX` / `DeathSFX`), hitbox off → on at 0.05 s with camera
  shake → off at 0.15 s, `Visuals` region switches to frame 3
  (`Rect2(48, 0, 16, 16)`) with only one visible player sprite node,
  movement locked for 0.2 s, additive `ScreenShake` stacking & clamp
- damage: 30 → 20 → 10 → 0 HP in exactly 3 hits, health bar follows
- feedback & juice: `Engine.time_scale` drops during 50 ms `HitStop` and
  restores to `1.0`, stronger hit shake, `HitSFX` only on hit, `DeathSFX`
  only on kill, white flash for 0.1 s, 6x6 fist-colored hit spark,
  `attack_hit(enemy)` payload, HUD counters
- no multi-hit: one full swing removes exactly 10 HP
- AI: idle beyond 200 px, ~40 px/s chase inside 200 px, stops at 24 px
- death: `died` signal, still valid during the 0.3 s fade, freed after
- Phase 1 & footstep regression: walking, animation switching, and
  `FootstepSFX` playing while moving and stopping when idle

This repository was verified against a headless **Godot 4.7.2** build
(`4.7.2.stable.custom_build`); `--headless --path . --import` plus the
test run above finish with zero engine errors or warnings.
