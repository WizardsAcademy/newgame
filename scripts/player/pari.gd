extends PlayerBase
## Sylvara - the Elven Ranger (Hero 3 of 4, docs/CHARACTERS.md).
##
## Role: Fragile, ultra-fast ranged kiter (75 HP, 118 move speed).
## Signature mechanic: **Hunter's Charge + Elven Volley**
##   - Tap Space / Click: quick emerald arrow (every 4th quick shot fires a
##     3-arrow Elven Fan!).
##   - Hold Space / Click (>= 0.35s) & release: **Hunter's Piercing Great-Arrow**
##     that deals 2x damage and pierces through ALL enemies in a line!
##   - Shift Dash: nimble **Wind-Step Dash** (1.0s cooldown, 390 speed, 11 dmg).

const PLAYER_ARROW_SCENE := preload("res://scenes/player/PlayerArrow.tscn")

@export var charge_threshold: float = 0.35

var _is_drawing: bool = false
var _draw_time: float = 0.0
var _shot_cooldown_left: float = 0.0
var _quick_shot_counter: int = 0
var _charge_ring: Line2D = null


func _create_attack_sfx() -> AudioStreamWAV:
	return SFXGenerator.create_bow_sfx()


func _character_ready() -> void:
	character_id = "sylvara"
	character_name = "Sylvara"
	dash_speed = 390.0
	dash_damage = 11
	dash_tint = Color(0.45, 0.98, 0.62, 0.78)
	_setup_charge_ring()


func _setup_charge_ring() -> void:
	_charge_ring = Line2D.new()
	_charge_ring.name = "ChargeRing"
	_charge_ring.width = 1.5
	_charge_ring.show_behind_parent = true
	_charge_ring.z_index = 0
	_charge_ring.visible = false
	add_child(_charge_ring)


func _get_attack_move_multiplier() -> float:
	# Agile ranger: Sylvara can still glide at 55% speed while drawing her bow!
	return 0.55 if _is_drawing else 0.0


func _on_attack_pressed(_event: InputEvent) -> void:
	if is_dead or is_dashing or _is_drawing or _shot_cooldown_left > 0.0:
		return
	_is_drawing = true
	is_attacking = true
	_draw_time = 0.0
	# Update facing toward mouse if clicked
	get_aim_direction()
	anim_player.stop()
	anim_player.play("attack")
	anim_player.pause()
	anim_player.seek(0.0, true)


func _on_attack_released(_event: InputEvent) -> void:
	if not _is_drawing:
		return
	_release_bow_shot()


## Direct call fallback (e.g. automated tests calling `_start_attack()`).
func _start_attack() -> void:
	if is_dead or is_dashing or _shot_cooldown_left > 0.0:
		return
	_is_drawing = true
	is_attacking = true
	_draw_time = 0.0
	_release_bow_shot()


func _character_physics_process(delta: float) -> void:
	if _shot_cooldown_left > 0.0:
		_shot_cooldown_left = maxf(_shot_cooldown_left - delta, 0.0)

	if _is_drawing:
		if is_dead:
			_cancel_draw()
			return
		_draw_time += delta
		# Keep tracking cursor while holding mouse button
		if _last_attack_used_mouse:
			get_aim_direction()
		_update_charge_ring()
		# Safety: if the attack button is no longer held (e.g. focus loss), release!
		if not (_read_input()["attack_held"] as bool) and _draw_time > 0.05:
			_release_bow_shot()
	elif _charge_ring != null and _charge_ring.visible:
		_charge_ring.visible = false


func _update_charge_ring() -> void:
	if _charge_ring == null:
		return
	_charge_ring.visible = true
	var ratio := clampf(_draw_time / charge_threshold, 0.0, 1.0)
	var r := lerpf(16.0, 11.0, ratio)
	var segs := 20
	var max_seg := maxi(int(roundf(float(segs) * ratio)), 2)
	var pts := PackedVector2Array()
	for i in max_seg + 1:
		var a := -PI * 0.5 + TAU * ratio * (float(i) / float(max_seg))
		pts.append(Vector2(cos(a), sin(a)) * r + Vector2(0.0, 5.0))
	_charge_ring.points = pts
	_charge_ring.default_color = Color(0.75, 1.0, 0.55, 0.92) if ratio >= 1.0 \
		else Color(0.38, 0.92, 0.58, 0.55)


func _release_bow_shot() -> void:
	var charged := _draw_time >= charge_threshold
	_is_drawing = false
	if _charge_ring != null:
		_charge_ring.visible = false

	var dir := get_aim_direction()
	if absf(dir.x) > 0.05:
		facing = 1.0 if dir.x > 0.0 else -1.0
		_sync_facing_nodes()

	punch_sfx.pitch_scale = 0.82 if charged else 1.08
	punch_sfx.play()

	# Play release portion of bow animation (Frame 4 -> Frame 0).
	anim_player.play("attack")
	anim_player.seek(0.10, true)

	if charged:
		var great_dmg := int(roundf(float(attack_damage) * 2.0))
		_spawn_arrow(dir, great_dmg, true, 470.0)
		ScreenShake.shake(3.0, 0.14)
	else:
		_quick_shot_counter += 1
		_spawn_arrow(dir, attack_damage, false, 390.0)
		# Every 4th quick shot unleashes a 3-arrow Elven Fan!
		if _quick_shot_counter % 4 == 0:
			_spawn_arrow(dir.rotated(deg_to_rad(-9.0)), maxi(int(attack_damage * 0.75), 1), false, 375.0)
			_spawn_arrow(dir.rotated(deg_to_rad(9.0)), maxi(int(attack_damage * 0.75), 1), false, 375.0)
		else:
			ScreenShake.shake(1.2, 0.07)

	_shot_cooldown_left = maxf(attack_duration * 0.85, 0.14)
	_attack_token += 1
	var my_token := _attack_token
	await get_tree().create_timer(0.14).timeout
	if my_token == _attack_token:
		is_attacking = false


func _spawn_arrow(dir: Vector2, dmg: int, is_piercing: bool, arrow_speed: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var arrow: Area2D = PLAYER_ARROW_SCENE.instantiate()
	arrow.speed = arrow_speed
	parent.add_child(arrow)
	var muzzle := global_position + dir.normalized() * 12.0 + Vector2(0.0, -1.0)
	arrow.launch(muzzle, dir, self, dmg, is_piercing)


func _cancel_draw() -> void:
	_is_drawing = false
	is_attacking = false
	if _charge_ring != null:
		_charge_ring.visible = false


func _on_dash_started() -> void:
	_cancel_draw()
