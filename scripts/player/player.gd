extends PlayerBase
## Behemoth - the Medieval Pit-Champion Brawler (Hero 1 of 4).
##
## Stats & Kit:
##   - 120 HP, 92 Move Speed, 100 Energy.
##   - **3-Hit Stunning Cestus Combo**:
##       * Hit 1 (`attack` / Jab): lead iron fist snaps forward + 0.45s Stun!
##       * Hit 2 (`attack_cross` / Cross): heavy rear fist drives across + 0.50s Stun!
##       * Hit 3 (`attack_uppercut` / Uppercut): skyward 1.6x damage finisher + 0.90s Stun!
##   - **Shoulder-Smash Charge (`Shift`)**:
##       * Braces his iron-plated shoulder and charges through enemies, dealing
##         18 damage + heavy knockback + **1.10s Stun**!

const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")

@export var combo_window: float = 0.95
@export var punch_stun_duration: float = 0.45
@export var uppercut_stun_duration: float = 0.90
@export var charge_stun_duration: float = 1.10

var _combo_step: int = 0
var _combo_reset_timer: float = 0.0
var _active_combo_step: int = 0
var _stun_sfx: AudioStreamPlayer = null


func _character_ready() -> void:
	character_id = "behemoth"
	character_name = "Behemoth"
	dash_deals_damage = true
	dash_phases_enemies = true
	dash_damage = 18
	dash_knockback_px = 18.0
	dash_tint = Color(1.0, 0.76, 0.32, 0.80)

	_stun_sfx = AudioStreamPlayer.new()
	_stun_sfx.name = "StunSFX"
	_stun_sfx.bus = &"SFX"
	_stun_sfx.stream = SFXGenerator.create_stun_sfx()
	add_child(_stun_sfx)


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
	_hurt_anim_left = 0.0
	_enemies_hit_this_swing.clear()

	get_aim_direction()

	var anim_name := "attack"
	match _active_combo_step:
		0:
			punch_sfx.pitch_scale = 1.02
			anim_name = "attack"
		1:
			punch_sfx.pitch_scale = 1.16
			anim_name = "attack_cross" if anim_player.has_animation("attack_cross") else "attack"
		2:
			punch_sfx.pitch_scale = 0.80
			anim_name = "attack_uppercut" if anim_player.has_animation("attack_uppercut") else "attack"

	anim_player.stop()
	anim_player.play(anim_name)
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


func _on_dealt_damage(enemy: Node, _amount: int, from_dash: bool) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead") == true:
		return
	var stun_dur := charge_stun_duration if from_dash else (
		uppercut_stun_duration if _active_combo_step == 2 else punch_stun_duration
	)
	if EnemyStatusScript.apply_stun(enemy, stun_dur):
		if _stun_sfx != null and not _stun_sfx.playing:
			_stun_sfx.play()


func _on_dash_started() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var arc := Line2D.new()
	arc.width = 3.0
	arc.default_color = Color(1.0, 0.84, 0.36, 0.92)
	var pts := PackedVector2Array()
	var base_a := _dash_dir.angle()
	for i in range(9):
		var a := base_a + lerpf(-0.9, 0.9, float(i) / 8.0)
		pts.append(Vector2(cos(a), sin(a)) * 14.0)
	arc.points = pts
	parent.add_child(arc)
	arc.global_position = global_position + _dash_dir * 8.0
	var tw := arc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(arc, "global_position", global_position + _dash_dir * 42.0, 0.16)
	tw.tween_property(arc, "modulate:a", 0.0, 0.16)
	tw.chain().tween_callback(arc.queue_free)


func _compute_melee_damage() -> int:
	match _active_combo_step:
		1: return int(roundf(float(attack_damage) * 1.15))
		2: return int(roundf(float(attack_damage) * 1.60))
		_: return attack_damage


func _compute_melee_knockback_px() -> float:
	var base_kb := super._compute_melee_knockback_px()
	if _active_combo_step == 2:
		return base_kb + 20.0
	return base_kb + 4.0


func _spawn_uppercut_wave() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ring := Line2D.new()
	ring.width = 2.2
	ring.default_color = Color(1.0, 0.86, 0.35, 0.92)
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
	tw.tween_property(ring, "scale", Vector2(2.5, 2.5), 0.18)
	tw.tween_property(ring, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(ring.queue_free)
