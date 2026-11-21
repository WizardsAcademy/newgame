extends PlayerBase
## Sylvara - the Blonde Medieval Elven Ranger (Hero 3 of 4).
##
## Stats & Kit:
##   - 100 HP, 124 Move Speed (FASTEST of all 4 heroes!).
##   - **Held Golden-Yew Recurve Bow + Visible Charge Animation**:
##       * Always holds her Recurve Bow in hand.
##       * Tap Attack: swift 15-DMG emerald arrow (every 4th quick shot fires a
##         3-arrow Elven Fan!).
##       * Hold Attack (>= 0.35s) & release: visibly draws & charges a blazing
##         emerald arrow (`bow_charge` pose) and fires a **30-DMG Piercing
##         Great-Arrow** through ALL enemies in a line!
##   - **Sylvan Gale Vault (`Shift`)**:
##       * Phases cleanly through enemy bodies (`0` Shift damage) in a graceful
##         airborne leap (`charge` / `vault` pose),
##       * Leaves a swirling **Sylvan Wind-Leaf Gust** at her takeoff spot that
##         slows nearby enemies by 45% for 1.8s, and grants Sylvara **+28%
##         Tailwind Haste** for 1.4s!

const PLAYER_ARROW_SCENE := preload("res://scenes/player/PlayerArrow.tscn")
const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")

@export var charge_threshold: float = 0.35
@export var gust_slow_radius: float = 68.0
@export var gust_slow_factor: float = 0.55
@export var gust_slow_duration: float = 1.8
@export var tailwind_duration: float = 1.4
@export var tailwind_speed_mult: float = 1.28

var _is_drawing: bool = false
var _draw_time: float = 0.0
var _shot_cooldown_left: float = 0.0
var _quick_shot_counter: int = 0
var _tailwind_left: float = 0.0
var _charge_ring: Line2D = null


func _create_attack_sfx() -> AudioStreamWAV:
	return SFXGenerator.create_bow_sfx()


func _character_ready() -> void:
	character_id = "sylvara"
	character_name = "Sylvara"
	dash_speed = 400.0
	dash_deals_damage = false
	dash_phases_enemies = true
	dash_damage = 0
	dash_tint = Color(0.45, 0.98, 0.62, 0.78)
	_setup_charge_ring()


func _setup_charge_ring() -> void:
	_charge_ring = Line2D.new()
	_charge_ring.name = "ChargeRing"
	_charge_ring.width = 1.6
	_charge_ring.show_behind_parent = true
	_charge_ring.z_index = 0
	_charge_ring.visible = false
	add_child(_charge_ring)


func _get_attack_move_multiplier() -> float:
	return 0.60 if _is_drawing else 0.0


func _get_bonus_speed_multiplier() -> float:
	return tailwind_speed_mult if _tailwind_left > 0.0 else 1.0


func _on_attack_pressed(_event: InputEvent) -> void:
	if is_dead or is_dashing or _is_drawing or _shot_cooldown_left > 0.0:
		return
	_is_drawing = true
	is_attacking = true
	_hurt_anim_left = 0.0
	_draw_time = 0.0
	get_aim_direction()
	anim_player.stop()
	if anim_player.has_animation("bow_draw"):
		anim_player.play("bow_draw")
	else:
		anim_player.play("attack")
		anim_player.pause()
		anim_player.seek(0.0, true)


func _on_attack_released(_event: InputEvent) -> void:
	if not _is_drawing:
		return
	_release_bow_shot()


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
	if _tailwind_left > 0.0:
		_tailwind_left = maxf(_tailwind_left - delta, 0.0)

	if _is_drawing:
		if is_dead:
			_cancel_draw()
			return
		_draw_time += delta
		if _last_attack_used_mouse:
			get_aim_direction()
		# Switch sprite from initial nock (`bow_draw`) into full glowing arrow taut pull (`bow_charge`)!
		if _draw_time >= charge_threshold * 0.55 and anim_player.has_animation("bow_charge"):
			if anim_player.current_animation != "bow_charge":
				anim_player.play("bow_charge")
		_update_charge_ring()
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
		pts.append(Vector2(cos(a), sin(a)) * r + Vector2(0.0, 6.0))
	_charge_ring.points = pts
	_charge_ring.default_color = Color(0.80, 1.0, 0.58, 0.95) if ratio >= 1.0 \
		else Color(0.38, 0.94, 0.58, 0.58)


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

	if anim_player.has_animation("bow_release"):
		anim_player.play("bow_release")
	else:
		anim_player.play("attack")
		anim_player.seek(0.10, true)

	if charged:
		var great_dmg := int(roundf(float(attack_damage) * 2.0))
		_spawn_arrow(dir, great_dmg, true, 480.0)
		ScreenShake.shake(3.0, 0.14)
	else:
		_quick_shot_counter += 1
		_spawn_arrow(dir, attack_damage, false, 395.0)
		if _quick_shot_counter % 4 == 0:
			_spawn_arrow(dir.rotated(deg_to_rad(-9.0)), maxi(int(attack_damage * 0.75), 1), false, 380.0)
			_spawn_arrow(dir.rotated(deg_to_rad(9.0)), maxi(int(attack_damage * 0.75), 1), false, 380.0)
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
	var muzzle := global_position + dir.normalized() * 14.0 + Vector2(0.0, -2.0)
	arrow.launch(muzzle, dir, self, dmg, is_piercing)


func _cancel_draw() -> void:
	_is_drawing = false
	is_attacking = false
	if _charge_ring != null:
		_charge_ring.visible = false


func _on_dash_started() -> void:
	_cancel_draw()
	_tailwind_left = tailwind_duration
	_spawn_sylvan_gust(global_position)


func _spawn_sylvan_gust(origin: Vector2) -> void:
	# Slow nearby pursuing enemies with an emerald woodland vortex!
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node2D and is_instance_valid(node) and node.get("is_dead") != true:
			if (node as Node2D).global_position.distance_to(origin) <= gust_slow_radius:
				EnemyStatusScript.apply_slow(node, gust_slow_factor, gust_slow_duration)

	var parent := get_parent()
	if parent == null:
		return

	var vortex := Line2D.new()
	vortex.width = 2.0
	vortex.default_color = Color(0.45, 0.98, 0.62, 0.85)
	var pts := PackedVector2Array()
	for i in range(25):
		var t := float(i) / 24.0
		var r := lerpf(4.0, 22.0, t)
		var a := t * TAU * 1.6
		pts.append(Vector2(cos(a), sin(a)) * r)
	vortex.points = pts
	parent.add_child(vortex)
	vortex.global_position = origin
	var tw := vortex.create_tween()
	tw.set_parallel(true)
	tw.tween_property(vortex, "rotation", 2.4, 0.32)
	tw.tween_property(vortex, "scale", Vector2(1.6, 1.6), 0.32)
	tw.tween_property(vortex, "modulate:a", 0.0, 0.32)
	tw.chain().tween_callback(vortex.queue_free)

	var leaves := CPUParticles2D.new()
	leaves.one_shot = true
	leaves.amount = 10
	leaves.lifetime = 0.38
	leaves.explosiveness = 0.95
	leaves.spread = 180.0
	leaves.initial_velocity_min = 24.0
	leaves.initial_velocity_max = 62.0
	leaves.gravity = Vector2(0, 12)
	leaves.scale_amount_min = 1.6
	leaves.scale_amount_max = 2.8
	leaves.color = Color(0.56, 1.0, 0.66, 0.90)
	leaves.emitting = false
	parent.add_child(leaves)
	leaves.global_position = origin
	leaves.emitting = true
	leaves.finished.connect(leaves.queue_free)
