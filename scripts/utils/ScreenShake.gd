extends Node
## Reusable Camera2D screen shake singleton (Autoload: `ScreenShake`).
##
## Call from anywhere in the game:
##     ScreenShake.shake(2.0, 0.1)   # subtle swing nudge
##     ScreenShake.shake(3.0, 0.15)  # meaty impact shake
##
## =========================================================================
## HOW SCREEN SHAKE DECAY & STACKING WORK (beginner-friendly)
## =========================================================================
## 1. OFFSET, NOT POSITION:
##    We move `Camera2D.offset` instead of `Camera2D.position`. That way the
##    camera's normal follow logic, `position_smoothing`, and arena `limit_*`
##    borders keep working untouched underneath the shake.
##
## 2. STACKING MULTIPLE SHAKES:
##    In an action game, two shakes often overlap - for example, the 0.1 s
##    swing shake starts at 0.05 s, and 20 ms later the fist hits a slime and
##    triggers a stronger 0.15 s hit shake. Instead of overwriting the first
##    shake, we store a list of active shakes (`_active_shakes`), add their
##    current strengths together each frame, and cap the sum at `max_intensity`
##    so a huge multi-hit never throws the camera off the screen.
##
## 3. SMOOTH DECAY TO ZERO:
##    A shake that stays at full strength and then stops abruptly feels
##    robotic. Each active shake fades out over its `duration` using both its
##    remaining lifetime fraction (`remaining / duration`) and an exponential
##    damping curve controlled by `decay_rate` (`exp(-decay_rate * progress)`):
##      - Right at impact (`progress = 0`): full intensity.
##      - Each frame after: smaller and smaller random offsets.
##      - At `remaining <= 0`: removed, and once no shakes remain we snap
##        `camera.offset = Vector2.ZERO` so the view never stays crooked.
##
## 4. REAL-TIME CLOCK (WORKS DURING HIT STOP):
##    `process_mode` is set to `PROCESS_MODE_ALWAYS` and we measure elapsed
##    wall-clock time via `Time.get_ticks_usec()`. That means the camera can
##    still tremble right through a 50 ms `HitStop.freeze()` when
##    `Engine.time_scale` is near zero!

## Hard ceiling on combined shake offset (in pixels) when multiple shakes stack.
@export var max_intensity: float = 8.0

## Controls how quickly each shake damps out over its lifetime.
## Higher values = snappy initial jolt that settles fast; lower = longer rumble.
@export var decay_rate: float = 4.0

## Active shake entries. Each entry is:
##   { "intensity": float, "duration": float, "elapsed": float }
var _active_shakes: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _last_ticks_usec: int = 0


func _ready() -> void:
	# Keep processing even if the tree pauses or Engine.time_scale drops.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_last_ticks_usec = Time.get_ticks_usec()


## Trigger a camera shake of `intensity` pixels lasting `duration` seconds.
## Multiple overlapping calls stack additively up to `max_intensity`.
func shake(intensity: float, duration: float) -> void:
	if intensity <= 0.0 or duration <= 0.0:
		return

	_active_shakes.append({
		"intensity": intensity,
		"duration": duration,
		"elapsed": 0.0,
	})

	# Apply an offset immediately so the very frame `shake()` is called
	# already shows the jolt (and tests inspecting `camera.offset` right
	# after `shake()` see a non-zero offset right away).
	_apply_current_offset()


func _process(_delta: float) -> void:
	var now_usec := Time.get_ticks_usec()
	var real_dt := float(now_usec - _last_ticks_usec) / 1_000_000.0
	_last_ticks_usec = now_usec
	# Clamp giant frame spikes (e.g. window drag or scene load).
	real_dt = clampf(real_dt, 0.0, 0.1)

	if _active_shakes.is_empty():
		return

	# Advance every active shake and remove finished ones (walking backward
	# so removing an element never skips the next index).
	for i in range(_active_shakes.size() - 1, -1, -1):
		var entry: Dictionary = _active_shakes[i]
		entry["elapsed"] = float(entry["elapsed"]) + real_dt
		if float(entry["elapsed"]) >= float(entry["duration"]):
			_active_shakes.remove_at(i)

	var camera := _get_active_camera()
	if _active_shakes.is_empty():
		if camera != null:
			camera.offset = Vector2.ZERO
		return

	_apply_current_offset()


## Sum the decayed strength of all active shakes and push a random offset
## of that magnitude onto the active Camera2D.
func _apply_current_offset() -> void:
	var camera := _get_active_camera()
	if camera == null:
		return

	var total_intensity := get_current_intensity()
	if total_intensity <= 0.001:
		camera.offset = Vector2.ZERO
		return

	# Pick a random 2D direction on the unit circle (`Vector2.from_angle`)
	# rather than independent randf_range(-x, x) axes. That guarantees the
	# offset vector has length == `total_intensity` (never (0, 0) by bad luck)
	# and feels equally strong in every direction.
	var angle := _rng.randf() * TAU
	camera.offset = Vector2.from_angle(angle) * total_intensity


## Current combined shake amplitude in pixels (clamped to `max_intensity`).
func get_current_intensity() -> float:
	var total := 0.0
	for entry in _active_shakes:
		var dur := maxf(float(entry["duration"]), 0.0001)
		var elapsed := clampf(float(entry["elapsed"]), 0.0, dur)
		var progress := elapsed / dur
		var linear_left := 1.0 - progress
		# Combine linear completion (guarantees exact 0 at `duration`) with
		# exponential decay (`decay_rate`) for a punchy front-loaded jolt.
		var envelope := linear_left * exp(-decay_rate * elapsed)
		total += float(entry["intensity"]) * envelope
	return minf(total, max_intensity)


func _get_active_camera() -> Camera2D:
	var viewport := get_viewport()
	if viewport != null:
		var cam := viewport.get_camera_2d()
		if cam != null:
			return cam
	# Fallback in case a test inspects a player camera before viewport sync.
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_node("Camera2D"):
		return player.get_node("Camera2D") as Camera2D
	return null
