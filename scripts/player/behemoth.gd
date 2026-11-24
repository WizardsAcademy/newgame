extends PlayerBase
## Behemoth - Savage Muscular Barbarian Brawler (Hero 1 of 4).
##
## Base Kit + Exclusive-Pillar OP Skill Tree:
##   - `solo_top`    : **Unstoppable Savage** — 100% projectile & melee dodge for `1.0s` after Shift + Ground Slam!
##   - Pillar 0      : **Earthshaker** — Seismic shockwaves on every punch, longer concussion stuns, Meteor Charge crater!
##   - Pillar 1      : **Blood Frenzy** — Blistering punch speed, lifesteal punches, low-HP rampage multiplier!
##   - Pillar 2      : **Volcanic Lord** — Magma FireWave punches, volcanic thorns hide, Inferno Pillar & corpse explosions!
##   - `solo_bottom` : **Cataclysmic Tremor Aura** — Rapidly auto-slams nearby foes for `40%` of `attack_damage`!

const PLAYER_ARROW_SCENE := preload("res://scenes/player/PlayerArrow.tscn")
const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")

@export var combo_window: float = 0.95
@export var punch_stun_duration: float = 0.45
@export var uppercut_stun_duration: float = 0.90
@export var charge_stun_duration: float = 1.10

var _base_max_hp: int = 120
var _base_atk: int = 18
var _base_move_spd: float = 92.0
var _base_atk_dur: float = 0.44
var _base_atk_windup: float = 0.14
var _base_dash_cd: float = 1.0

var _combo_step: int = 0
var _combo_reset_timer: float = 0.0
var _active_combo_step: int = 0
var _tremor_timer: float = 0.0
var _stun_sfx: AudioStreamPlayer = null


func _character_ready() -> void:
	character_id = "behemoth"
	character_name = "Behemoth"
	dash_deals_damage = true
	dash_phases_enemies = true
	dash_damage = 18
	dash_knockback_px = 18.0
	dash_tint = Color(1.0, 0.76, 0.32, 0.80)

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


func _on_skill_tree_ranks_applied() -> void:
	post_dash_full_immunity = (skill_rank("solo_top") >= 1)
	var p0_1 := skill_rank("p0_t1")
	var p0_2 := skill_rank("p0_t2")
	var p0_4 := skill_rank("p0_t4")
	var p1_1 := skill_rank("p1_t1")
	var p1_2 := skill_rank("p1_t2")
	var p1_3 := skill_rank("p1_t3")
	var p1_4 := skill_rank("p1_t4")
	var p2_2 := skill_rank("p2_t2")
	var p2_4 := skill_rank("p2_t4")

	max_health = _base_max_hp + p0_4 * 25 + p1_4 * 30 + p2_2 * 24
	current_health = clampi(current_health + (max_health - _base_max_hp), 1, max_health)

	attack_damage = _base_atk + p0_1 * 6 + p0_4 * 14 + p1_4 * 10 + p2_4 * 15
	move_speed = _base_move_spd + float(p1_1 * 14)

	var spd_mult := 1.0 / (1.0 + 0.12 * float(p1_1))
	attack_duration = maxf(0.18, _base_atk_dur * spd_mult)
	attack_windup = maxf(0.06, _base_atk_windup * spd_mult)

	dash_cooldown = _base_dash_cd * (0.50 if p1_3 > 0 else 1.0)
	punch_stun_duration = 0.45 + 0.35 * float(p0_2)
	uppercut_stun_duration = 0.90 + 0.35 * float(p0_2)
	charge_stun_duration = 1.10 + 0.35 * float(p0_2)

	reset_dash_on_kill = (p1_4 > 0)
	kill_heal_ratio = 0.18 if p1_2 > 0 else 0.0
	if p2_4 > 0:
		kill_explosion_damage = 28 + 10 * p2_4
		kill_explosion_radius = 80.0
		kill_explosion_color = Color(1.0, 0.48, 0.14, 0.95)
	else:
		kill_explosion_damage = 0
		kill_explosion_radius = 0.0


func _character_physics_process(delta: float) -> void:
	if not is_attacking and _combo_reset_timer > 0.0:
		_combo_reset_timer = maxf(_combo_reset_timer - delta, 0.0)
		if _combo_reset_timer <= 0.0:
			_combo_step = 0

	# --- ULTIMATE CONVERGED SOLO NODE (`solo_bottom`): CATACLYSMIC TREMOR AURA ---
	if skill_rank("solo_bottom") >= 1 and not is_dead:
		_tremor_timer -= delta
		if _tremor_timer <= 0.0:
			var hit_any := _pulse_cataclysmic_tremor()
			_tremor_timer = 0.18 if hit_any else 0.08


func _pulse_cataclysmic_tremor() -> bool:
	var tremor_dmg := maxi(int(roundf(float(attack_damage) * 0.40)), 1)
	var hit_any := false
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == null or not is_instance_valid(n) or not (n is Node2D):
			continue
		if n.get("is_dead") == true or not (n as Node2D).visible:
			continue
		if global_position.distance_to((n as Node2D).global_position) <= 118.0:
			deal_combat_damage(n, tremor_dmg, false, 4.0, (n as Node2D).global_position)
			hit_any = true
	if hit_any:
		_spawn_radial_ring(global_position, 44.0, Color(1.0, 0.56, 0.18, 0.88))
	return hit_any


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
	# Pillar 0 Tier 1: Seismic Bare-Knuckles 72px AoE shockwave!
	if skill_rank("p0_t1") > 0:
		var origin := hitbox.global_position
		_spawn_radial_ring(origin, 34.0, Color(1.0, 0.72, 0.28, 0.85))
		for n in get_tree().get_nodes_in_group("enemies"):
			if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
				if (n as Node2D).global_position.distance_to(origin) <= 72.0:
					var eid := n.get_instance_id()
					if not _enemies_hit_this_swing.has(eid):
						_enemies_hit_this_swing[eid] = true
						deal_combat_damage(n, _compute_melee_damage(), false, 10.0)

	# Pillar 2 Tier 1: Magma Fists piercing FireWave!
	var p2_1 := skill_rank("p2_t1")
	if p2_1 > 0 and get_parent() != null:
		var fw: Area2D = PLAYER_ARROW_SCENE.instantiate()
		fw.speed = 360.0
		fw.max_range = 240.0
		fw.scale = Vector2(1.5, 1.5)
		fw.modulate = Color(1.0, 0.50, 0.14, 0.96)
		fw.puff_color = Color(1.0, 0.45, 0.12)
		get_parent().add_child(fw)
		fw.launch(global_position + aim * 16.0, aim, self, 14 + 8 * p2_1, true)

	# Pillar 2 Tier 3: Inferno Eruption on 3rd combo hit!
	var p2_3 := skill_rank("p2_t3")
	if p2_3 > 0 and _active_combo_step == 2:
		var center := global_position + aim * 36.0
		_spawn_radial_ring(center, 46.0, Color(1.0, 0.32, 0.10, 0.95))
		for n in get_tree().get_nodes_in_group("enemies"):
			if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
				if (n as Node2D).global_position.distance_to(center) <= 92.0:
					deal_combat_damage(n, 33 + 12 * p2_3, false, 14.0, center)


func _on_dealt_damage(enemy: Node, _amount: int, from_dash: bool) -> void:
	if skill_rank("p1_t2") > 0 and not from_dash:
		heal(2 + 2 * skill_rank("p1_t2"))
	if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead") == true:
		return
	var stun_dur := charge_stun_duration if from_dash else (
		uppercut_stun_duration if _active_combo_step == 2 else punch_stun_duration
	)
	if EnemyStatusScript.apply_stun(enemy, stun_dur):
		if _stun_sfx != null and not _stun_sfx.playing:
			_stun_sfx.play()


func _mitigate_incoming_damage(amount: int, from_position: Vector2) -> int:
	var p2_2 := skill_rank("p2_t2")
	if p2_2 > 0 and from_position != Vector2.INF:
		for n in get_tree().get_nodes_in_group("enemies"):
			if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
				if (n as Node2D).global_position.distance_to(global_position) <= 64.0:
					n.take_damage(12 + 8 * p2_2)
	return maxi(amount - p2_2, 1) if p2_2 > 0 else amount


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
	if slam_rk > 0 or skill_rank("solo_top") >= 1:
		var dmg := (25 + 15 * slam_rk) if slam_rk > 0 else 18
		var rad := 96.0 if slam_rk > 0 else 64.0
		_spawn_radial_ring(global_position, rad * 0.45, Color(1.0, 0.62, 0.20, 0.92))
		for n in get_tree().get_nodes_in_group("enemies"):
			if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
				if (n as Node2D).global_position.distance_to(global_position) <= rad:
					deal_combat_damage(n, dmg, true, 16.0, global_position)


func _compute_melee_damage() -> int:
	var mult := 1.0
	if _active_combo_step == 1:
		mult = 1.15
	elif _active_combo_step == 2:
		mult = 1.60
	if skill_rank("p0_t2") > 0:
		mult *= 1.35
	var p1_3 := skill_rank("p1_t3")
	if p1_3 > 0 and float(current_health) <= float(max_health) * 0.60:
		mult *= (1.45 + 0.15 * float(p1_3))
	return int(roundf(float(attack_damage) * mult))


func _compute_melee_knockback_px() -> float:
	var base_kb := super._compute_melee_knockback_px()
	if _active_combo_step == 2:
		return base_kb + 20.0
	return base_kb + 4.0


func _spawn_uppercut_wave() -> void:
	var sc := 3.6 if skill_rank("p0_t4") > 0 else 2.5
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
