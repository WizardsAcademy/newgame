extends Node
## Impact freeze ("hit stop") singleton (Autoload: `HitStop`).
##
## Call when a melee attack connects:
##     HitStop.freeze(0.05)   # 50 ms impact pause
##
## =========================================================================
## WHY `Engine.time_scale` AFFECTS EVERYTHING (beginner-friendly)
## =========================================================================
## Every frame, Godot measures how much real time passed since the last frame
## (`raw_delta`, e.g. 0.0167 s at 60 FPS) and multiplies it by
## `Engine.time_scale` BEFORE handing `delta` to the rest of the engine:
##
##     scaled_delta = raw_delta * Engine.time_scale
##
## Because almost every built-in system consumes `scaled_delta`:
##   - `_process(delta)` and `_physics_process(delta)` slow down or stop,
##   - `CharacterBody2D.move_and_slide()` scales velocity integration by it,
##   - `AnimationPlayer` advances keyframes at `Engine.time_scale` speed,
##   - default `Tween`s and `get_tree().create_timer()` wait longer in lockstep.
##
## Lowering `Engine.time_scale` to `0.05` (5 % speed - effectively frozen on
## screen, without risking divide-by-zero in physics code) freezes the player's
## extended fist right against the flashing white enemy for 50 ms. Your brain
## reads that tiny pause as physical *weight* and resistance, just like classic
## arcade brawlers and fighting games.
##
## THE #1 BEGINNER GOTCHA:
## If `HitStop` used a normal `create_timer(0.05)` or a default `Tween` to
## restore `Engine.time_scale = 1.0`, THAT timer would ALSO be multiplied by
## `Engine.time_scale`! At `0.0` it would freeze itself forever (soft-locking
## the game); at `0.05` a "50 ms" freeze would accidentally last a full second
## (`0.05 / 0.05 = 1.0 s`).
##
## Solution: configure our unfreeze `Tween` with BOTH:
##   - `set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` (keeps running if paused)
##   - `set_ignore_time_scale(true)`               (ticks in real wall-clock s!)

## Near-zero time scale applied during a hit-stop freeze.
## Using 0.05 instead of 0.0 gives an unmistakable freeze while keeping
## physics deltas strictly positive.
@export var freeze_time_scale: float = 0.05

var _freeze_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Slow the entire engine down to `freeze_time_scale` for `duration` real-world
## seconds, then restore `Engine.time_scale = 1.0`.
func freeze(duration: float) -> void:
	if duration <= 0.0:
		return

	# If another hit lands while we are already frozen, replace the old tween
	# so the first hit's callback cannot unfreeze the second hit prematurely.
	if _freeze_tween != null and _freeze_tween.is_valid():
		_freeze_tween.kill()

	Engine.time_scale = freeze_time_scale

	_freeze_tween = create_tween()
	_freeze_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_freeze_tween.set_ignore_time_scale(true)
	_freeze_tween.tween_interval(duration)
	_freeze_tween.tween_callback(_restore_time_scale)


func _restore_time_scale() -> void:
	Engine.time_scale = 1.0
	_freeze_tween = null


func _exit_tree() -> void:
	# Safety net: never leave the engine stuck in slow-motion on scene quit.
	Engine.time_scale = 1.0
