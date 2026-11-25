extends PlayerBase
## Behemoth - Savage Muscular Barbarian Brawler (Hero 1 of 4).
##
## Unique Skill Tree & `[R]` Ultimate:
##   - `solo_top`    : **Unstoppable Invincibility** — 100% INVINCIBLE to all damage for `1.0s` after Shift!
##   - Pillar 0      : **Earthshaker** — Seismic shockwaves, bonus stun DMG, Tectonic Crater Pull!
##   - Pillar 1      : **Blood Berserker** — Attack speed, 360° Whirlwind Cleave, Low-HP Frenzy, Rampage!
##   - Pillar 2      : **Volcanic Lord** — Ignite Burn DoT punches, Magma Thorns, Volcanic Pillars & Lava Novas!
##   - `solo_bottom` : **`[R]` Infernal Rage** — Surrounds Behemoth with roaring Fire VFX & DOUBLES (`2x`) ALL damage!

const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")

@export var combo_window: float = 0.95
@export var punch_stun_duration: float = 0.45
@export var uppercut_stun_duration: float = 0.90
@export var charge_stun_duration: float = 1.10
@export var rage_duration: float = 8.0

var _base_max_hp: int = 120
var _base_atk: int = 18
var _base_move_spd: float = 92.0
var _base_atk_dur: float = 0.44
var _base_atk_windup: float = 0.14
var _base_dash_cd: float = 1.0

var _combo_step: int = 0
var _combo_reset_timer: float = 0.0
var _active_combo_step: int = 0
var _swing_counter: int = 0
var _stun_sfx: AudioStreamPlayer = null
var _aura_fx: BehemothAuraFX = null


class BehemothAuraFX extends Node2D:
	var rage_on: bool = false
	var invinc_on: bool = false
	var anim_t: float = 0.0

	func _process(delta: float) -> void:
		anim_t += delta
		if rage_on or invinc_on:
			queue_redraw()

	func _draw() -> void:
		if invinc_on:
			var p := 0.5 + 0.5 * sin(anim_t * 14.0)
			draw_arc(Vector2(0.0, -4.0), 19.0 + p * 2.0, 0.0, TAU, 24, Color(1.0, 0.92, 0.38, 0.92), 2.4)
			draw_circle(Vector2(0.0, -4.0), 17.5, Color(1.0, 0.88, 0.30, 0.18))

		if rage_on:
			# Roaring Infernal Fire Ring + swirling flame tongues around Behemoth!
			draw_circle(Vector2(0.0, 2.0), 23.0, Color(1.0, 0.24, 0.06, 0.18))
			draw_arc(Vector2(0.0, 2.0), 22.0, 0.0, TAU, 28, Color(1.0, 0.38, 0.08, 0.88), 2.5)
			for i in range(10):
				var ang := anim_t * 5.2 + float(i) * (TAU / 10.0)
				var base_p := Vector2(cos(ang) * 20.0, 2.0 + sin(ang) * 11.0)
				var flame_h := 9.0 + 4.5 * sin(anim_t * 13.0 + float(i) * 1.7)
				var flame_poly := PackedVector2Array([
					base_p + Vector2(-3.4, 0.0),
					base_p + Vector2(3.4, 0.0),
					base_p + Vector2(sin(anim_t * 9.0 + float(i)) * 2.0, -flame_h),
				])
				draw_colored_polygon(flame_poly, Color(1.0, 0.32, 0.06, 0.90))
				var core_poly := PackedVector2Array([
					base_p + Vector2(-1.8, -1.0),
					base_p + Vector2(1.8, -1.0),
					base_p + Vector2(0.0, -flame_h * 0.68),
				])
				draw_colored_polygon(core_poly, Color(1.0, 0.90, 0.30, 0.95))


func _character_ready() -> void:
	character_id = "behemoth"
	character_name = "Behemoth"
	dash_deals_damage = true
	dash_phases_enemies = true
	dash_damage = 18
	dash_knockback_px = 18.0
	dash_tint = Color(1.0, 0.76, 0.32, 0.80)
	ult_cooldown = 28.0

	_base_max_hp = max_health
	_base_atk = attack_damage
	_base_move_spd = move_speed
	_base_atk_dur = attack_duration
	_base_atk_windup = attack_windup
	_base_dash_cd = dash_cooldown

	_stun_sfx = AudioStreamPlayer.new()
	_stun_sfx.name = "StunSFX"
	_stun_sfx.bus = &"SFX"
	_stun_sfx.stream = SFXGenerator.create_stun_sfx()
	add_child(_stun_sfx)

	_aura_fx = BehemothAuraFX.new()
	_aura_fx.name = "BehemothRageFireFX"
	_aura_fx.z_index = 3
	add_child(_aura_fx)


func _on_skill_tree_ranks_applied() -> void:
	# Skill 1 (`solo_top`): 1.0s Full Invincibility after Shift (NOT projectile dodge!)
	post_dash_dodge_duration = 0.0
	post_dash_invincible_duration = 1.0 if skill_rank("solo_top") >= 1 else 0.0

	var p0_1 := skill_rank("p0_t1")
	var p0_2 := skill_rank("p0_t2")
	var p0_4 := skill_rank("p0_t4")
	var p1_1 := skill_rank("p1_t1")
	var p1_3 := skill_rank("p1_t3")
	var p1_4 := skill_rank("p1_t4")
	var p2_1 := skill_rank("p2_t1")
	var p2_2 := skill_rank("p2_t2")
	var p2_4 := skill_rank("p2_t4")

	max_health = _base_max_hp + p0_4 * 55 + p1_4 * 60 + p2_2 * 50
	current_health = clampi(current_health + (max_health - _base_max_hp), 1, max_health)

	attack_damage = _base_atk + p0_1 * 14 + p0_4 * 26 + p1_4 * 24 + p2_1 * 12 + p2_4 * 30
	move_speed = _base_move_spd + float(p1_1 * 16)

	var spd_mult := 1.0 / (1.0 + 0.16 * float(p1_1))
	attack_duration = maxf(0.16, _base_atk_dur * spd_mult)
	attack_windup = maxf(0.05, _base_atk_windup * spd_mult)

	dash_cooldown = _base_dash_cd * (0.50 if p1_3 > 0 else 1.0)
	punch_stun_duration = 0.45 + 0.40 * float(p0_2)
	uppercut_stun_duration = 0.90 + 0.40 * float(p0_2)
	charge_stun_duration = 1.10 + 0.40 * float(p0_2)

	reset_dash_on_kill = (p1_4 > 0)
	kill_heal_ratio = 0.20 if p1_4 > 0 else 0.0
	if p2_4 > 0:
		kill_explosion_damage = 50 + 25 * p2_4
		kill_explosion_radius = 88.0
		kill_explosion_color = Color(1.0, 0.44, 0.12, 0.95)
	else:
		kill_explosion_damage = 0
		kill_explosion_radius = 0.0


func _activate_ultimate() -> bool:
	ult_active = true
	ult_active_left = rage_duration
	ult_cooldown_left = ult_cooldown
	ScreenShake.shake(5.5, 0.24)
	_spawn_radial_ring(global_position, 38.0, Color(1.0, 0.36, 0.08, 0.96))
	if visuals != null:
		visuals.modulate = Color(1.22, 0.84, 0.72, 1.0)
	return true


func get_rage_damage_multiplier() -> float:
	return 2.0 if ult_active else 1.0


func get_ability_hud_info() -> Array[Dictionary]:
	return [
		{"key": "LMB", "title": "Combo", "icon_idx": 1, "cd_left": 0.0, "cd_max": 1.0, "unlocked": true, "active": is_attacking},
		{"key": "SHIFT", "title": "Slam", "icon_idx": 0, "cd_left": dash_cooldown_left, "cd_max": maxf(dash_cooldown, 0.1), "unlocked": true, "active": is_dashing or invincible_left > 0.0},
		{"key": "R", "title": "Rage 2x", "icon_idx": 14, "cd_left": ult_cooldown_left, "cd_max": maxf(ult_cooldown, 0.1), "unlocked": is_ultimate_unlocked(), "active": ult_active},
	]


func _character_physics_process(delta: float) -> void:
	if not is_attacking and _combo_reset_timer > 0.0:
		_combo_reset_timer = maxf(_combo_reset_timer - delta, 0.0)
		if _combo_reset_timer <= 0.0:
			_combo_step = 0

	if ult_active:
		ult_active_left = maxf(ult_active_left - delta, 0.0)
		if ult_active_left <= 0.0:
			ult_active = false
			if visuals != null and not is_dead and not _is_flashing:
				visuals.modulate = Color.WHITE
			ultimate_state_changed.emit(false, ult_cooldown_left, ult_cooldown)

	if _aura_fx != null:
		_aura_fx.rage_on = ult_active
		_aura_fx.invinc_on = (invincible_left > 0.0)
		_aura_fx.visible = (_aura_fx.rage_on or _aura_fx.invinc_on)


func _compute_dash_damage() -> int:
	return int(roundf(float(dash_damage) * get_rage_damage_multiplier()))


func _start_attack() -> void:
	if is_attacking or is_dashing or is_dead:
		return

	_active_combo_step = _combo_step
	_combo_step = (_combo_step + 1) % 3
	_swing_counter += 1
	_combo_reset_timer = combo_window + attack_duration

	_attack_token += 1
	var my_token := _attack_token
	is_attacking = true
	_hurt_anim_left = 0.0
	_enemies_hit_this_swing.clear()

	var aim := get_aim_direction()

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
	if WitchCauldronProgression.wizard_cheat_active:
		step_windup = 0.03
	await get_tree().create_timer(step_windup).timeout
	if my_token != _attack_token or is_dead:
		return

	_enable_hitbox()
	_trigger_barbarian_strike_skills(aim)
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


func _trigger_barbarian_strike_skills(aim: Vector2) -> void:
	var rage_m := get_rage_damage_multiplier()

	# Pillar 0 Tier 1: Seismic Knuckles AoE shockwave!
	if skill_rank("p0_t1") > 0:
		var origin := hitbox.global_position
		var rad := 120.0 if skill_rank("p0_t4") > 0 else 76.0
		_spawn_radial_ring(origin, rad * 0.45, Color(1.0, 0.72, 0.28, 0.85))
		for n in get_tree().get_nodes_in_group("enemies"):
			if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
				if (n as Node2D).global_position.distance_to(origin) <= rad:
					var eid := n.get_instance_id()
					if not _enemies_hit_this_swing.has(eid):
						_enemies_hit_this_swing[eid] = true
						deal_combat_damage(n, _compute_melee_damage_on(n), false, 10.0)

	# Pillar 0 Tier 3: Tectonic Crater Pull on 3rd combo hit!
	var p0_3 := skill_rank("p0_t3")
	if p0_3 > 0 and _active_combo_step == 2:
		_pull_and_crater(global_position + aim * 24.0, int(roundf(float(45 + 25 * p0_3) * rage_m)), 96.0)

	# Pillar 1 Tier 2: 360° Whirlwind Barbarian Cleave every 2nd swing!
	var p1_2 := skill_rank("p1_t2")
	if p1_2 > 0 and (_swing_counter % 2 == 0):
		_spawn_radial_ring(global_position, 38.0, Color(1.0, 0.26, 0.22, 0.90))
		for n in get_tree().get_nodes_in_group("enemies"):
			if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
				if (n as Node2D).global_position.distance_to(global_position) <= 84.0:
					var eid2 := n.get_instance_id()
					if not _enemies_hit_this_swing.has(eid2):
						_enemies_hit_this_swing[eid2] = true
						deal_combat_damage(n, _compute_melee_damage_on(n), false, 12.0)

	# Pillar 2 Tier 3: Volcanic Eruption Pillar on 3rd combo hit!
	var p2_3 := skill_rank("p2_t3")
	if p2_3 > 0 and _active_combo_step == 2:
		var center := global_position + aim * 36.0
		_spawn_radial_ring(center, 46.0, Color(1.0, 0.32, 0.10, 0.95))
		var erup_dmg := int(roundf(float(65 + 28 * p2_3) * rage_m))
		for n in get_tree().get_nodes_in_group("enemies"):
			if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
				if (n as Node2D).global_position.distance_to(center) <= 94.0:
					deal_combat_damage(n, erup_dmg, false, 14.0, center)


func _pull_and_crater(center: Vector2, dmg: int, rad: float) -> void:
	_spawn_radial_ring(center, rad * 0.45, Color(1.0, 0.62, 0.20, 0.92))
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
			var d := (n as Node2D).global_position.distance_to(center)
			if d <= rad:
				if n is CharacterBody2D and n.get("immovable_dummy") != true and d > 14.0:
					var pull := (center - (n as Node2D).global_position).normalized() * minf(28.0, d - 12.0)
					(n as CharacterBody2D).move_and_collide(pull)
				deal_combat_damage(n, dmg, false, 4.0, center)


func _on_dealt_damage(enemy: Node, _amount: int, from_dash: bool) -> void:
	var p1_2 := skill_rank("p1_t2")
	if p1_2 > 0 and not from_dash:
		heal(2 + 4 * p1_2)
	if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead") == true:
		return
	var p2_1 := skill_rank("p2_t1")
	if p2_1 > 0:
		var burn_dps := int(roundf(float(18 + 14 * p2_1) * get_rage_damage_multiplier()))
		EnemyStatusScript.apply_burn(enemy, burn_dps, 3.0, self)
	var stun_dur := charge_stun_duration if from_dash else (
		uppercut_stun_duration if _active_combo_step == 2 else punch_stun_duration
	)
	if EnemyStatusScript.apply_stun(enemy, stun_dur):
		if _stun_sfx != null and not _stun_sfx.playing:
			_stun_sfx.play()


func _mitigate_incoming_damage(amount: int, from_position: Vector2) -> int:
	var p2_2 := skill_rank("p2_t2")
	if p2_2 > 0 and from_position != Vector2.INF:
		var thorns := int(roundf(float(30 + 18 * p2_2) * get_rage_damage_multiplier()))
		for n in get_tree().get_nodes_in_group("enemies"):
			if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
				if (n as Node2D).global_position.distance_to(global_position) <= 68.0:
					n.take_damage(thorns)
					EnemyStatusScript.apply_burn(n, 16 + 8 * p2_2, 2.5, self)
	return maxi(amount - p2_2 * 2, 1) if p2_2 > 0 else amount


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


func _on_dash_ended() -> void:
	var slam_rk := skill_rank("p0_t3")
	if slam_rk > 0:
		var dmg := int(roundf(float(45 + 25 * slam_rk) * get_rage_damage_multiplier()))
		_pull_and_crater(global_position, dmg, 96.0)


func _compute_melee_damage() -> int:
	return _compute_melee_damage_on(null)


func _compute_melee_damage_on(target: Node) -> int:
	var mult := 1.0
	if _active_combo_step == 1:
		mult = 1.15
	elif _active_combo_step == 2:
		mult = 1.60
	var p0_2 := skill_rank("p0_t2")
	if p0_2 > 0 and (target == null or EnemyStatusScript.is_stunned(target)):
		mult *= (1.28 + 0.12 * float(p0_2))
	var p1_3 := skill_rank("p1_t3")
	if p1_3 > 0:
		var missing_ratio := clampf(1.0 - float(current_health) / float(maxi(max_health, 1)), 0.0, 1.0)
		mult *= (1.0 + missing_ratio * (0.68 + 0.22 * float(p1_3)))
	mult *= get_rage_damage_multiplier()
	return int(roundf(float(attack_damage) * mult))


func _compute_melee_knockback_px() -> float:
	var base_kb := super._compute_melee_knockback_px()
	if _active_combo_step == 2:
		return base_kb + 20.0
	return base_kb + 4.0


func _spawn_uppercut_wave() -> void:
	var sc := 3.8 if skill_rank("p0_t4") > 0 else 2.5
	_spawn_radial_ring(hitbox.global_position, 8.0 * sc * 0.4, Color(1.0, 0.86, 0.35, 0.92))


func _spawn_radial_ring(at: Vector2, base_r: float, col: Color) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ring := Line2D.new()
	ring.width = 2.4
	ring.default_color = col
	var pts := PackedVector2Array()
	for i in range(21):
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a), sin(a)) * base_r)
	ring.points = pts
	parent.add_child(ring)
	ring.global_position = at
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(2.2, 2.2), 0.18)
	tw.tween_property(ring, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(ring.queue_free)
