extends PlayerBase
## Behemoth - the Iron-Fist Brawler (Hero 1 of 4, docs/CHARACTERS.md).
##
## Role: Melee brawler & soft tank (100 HP).
## Signature mechanic: **3-Hit Brawler Combo** (Jab -> Cross -> Uppercut!).
##   - Chaining punches within `combo_window` escalates into a 3rd-hit
##     Uppercut Finisher (1.6x damage + golden shockwave + heavy launch).
##   - Shift Dash: **Shoulder-Smash Dash** (1.0s CD, deals 16 Shift damage!).

@export var combo_window: float = 0.95

var _combo_step: int = 0
var _combo_reset_timer: float = 0.0
var _active_combo_step: int = 0


func _character_ready() -> void:
	character_id = "behemoth"
	character_name = "Behemoth"
	dash_deals_damage = true
	dash_phases_enemies = true
	dash_damage = 16
	dash_tint = Color(1.0, 0.74, 0.32, 0.78)


func _character_physics_process(delta: float) -> void:
	if not is_attacking and _combo_reset_timer > 0.0:
		_combo_reset_timer = maxf(_combo_reset_timer - delta, 0.0)
		if _combo_reset_timer <= 0.0:
			_combo_step = 0


func _start_attack() -> void:
	if is_attacking or is_dashing or is_dead:
		return

	_active_combo_step = _combo_step
	_combo_step = (_combo_step + 1) % 3
	_combo_reset_timer = combo_window + attack_duration

	_attack_token += 1
	var my_token := _attack_token
	is_attacking = true
	_enemies_hit_this_swing.clear()

	match _active_combo_step:
		0: punch_sfx.pitch_scale = 1.00
		1: punch_sfx.pitch_scale = 1.15
		2: punch_sfx.pitch_scale = 0.80

	anim_player.stop()
	anim_player.play("attack")
	punch_sfx.play()

	var step_windup := attack_windup * (0.82 if _active_combo_step == 1 else 1.0)
	await get_tree().create_timer(step_windup).timeout
	if my_token != _attack_token or is_dead:
		return

	_enable_hitbox()
	if _active_combo_step == 2:
		_spawn_uppercut_wave()
		ScreenShake.shake(4.5, 0.18)

	await get_tree().physics_frame
	await get_tree().physics_frame
	if my_token != _attack_token or is_dead:
		return
	for area in hitbox.get_overlapping_areas():
		_try_hit(area)
	for body in hitbox.get_overlapping_bodies():
		_try_hit(body)

	await get_tree().create_timer(hitbox_active_time).timeout
	if my_token != _attack_token or is_dead:
		return

	_disable_hitbox()

	var remaining := maxf(attack_duration - step_windup - hitbox_active_time, 0.0)
	await get_tree().create_timer(remaining).timeout
	if my_token != _attack_token or is_dead:
		return

	is_attacking = false


func _compute_melee_damage() -> int:
	match _active_combo_step:
		1: return int(roundf(float(attack_damage) * 1.15))
		2: return int(roundf(float(attack_damage) * 1.60))
		_: return attack_damage


func _compute_melee_knockback_px() -> float:
	var base_kb := super._compute_melee_knockback_px()
	if _active_combo_step == 2:
		return base_kb + 22.0
	return base_kb + 5.0


func _spawn_uppercut_wave() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(1.0, 0.85, 0.35, 0.9)
	var pts := PackedVector2Array()
	var segs := 20
	for i in segs + 1:
		var a := TAU * float(i) / float(segs)
		pts.append(Vector2(cos(a), sin(a)) * 8.0)
	ring.points = pts
	parent.add_child(ring)
	ring.global_position = hitbox.global_position
	ring.scale = Vector2(0.5, 0.5)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.18)
	tw.tween_property(ring, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(ring.queue_free)
