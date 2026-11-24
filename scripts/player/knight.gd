extends PlayerBase
## Knight - Classic Silver & Gold Crusader (Hero 2 of 4).
##
## Base Kit + Exclusive-Pillar OP Skill Tree:
##   - `solo_top`    : **Crusader's Holy Aegis** — Reflects & dodges 100% of projectiles for `1.0s` after Shift!
##   - Pillar 0      : **Swordmaster** — Piercing Holy Sword-Beams, giant Spin Cleave, 2.5x Templar Crits, Excalibur speed!
##   - Pillar 1      : **Lion Bastion** — Golden Lion Plate, Holy Retribution block blast, Consecrated HP Regen, Unbreakable Shield!
##   - Pillar 2      : **Sky Vanguard** — Thunder Shield-Ram, Heavensfall Lightning Smite, 1.5s Ram Stun & Execute!
##   - `solo_bottom` : **Storm of Sacred Blades** — Auto-fires radiant judgment blades at nearby foes for `35%` Attack DMG!

const PLAYER_ARROW_SCENE := preload("res://scenes/player/PlayerArrow.tscn")
const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")

@export var armor_flat_block: int = 3
@export var shield_move_multiplier: float = 0.56
@export var shield_hold_drain_per_sec: float = 0.0
@export var shield_hit_energy_base: float = 20.0
@export var shield_hit_energy_per_dmg: float = 1.2

var _base_max_hp: int = 150
var _base_atk: int = 26
var _base_move_spd: float = 68.0
var _base_atk_dur: float = 0.54
var _base_atk_windup: float = 0.17
var _base_dash_cd: float = 1.0
var _base_dash_dmg: int = 16
var _base_en_regen: float = 24.0
var _base_armor: int = 3
var _base_sh_base: float = 20.0
var _base_sh_per: float = 1.2

var is_shielding: bool = false
var shield_exhausted: bool = false
var _manual_shield_hold: bool = false
var _shield_arc: ShieldArcVisual = null
var _shield_sfx: AudioStreamPlayer = null
var _shield_flash_timer: float = 0.0
var _consecrate_timer: float = 0.0
var _sacred_blade_timer: float = 0.0


class ShieldArcVisual extends Node2D:
	var facing_dir: float = 1.0
	var flash_ratio: float = 0.0
	var energy_ratio: float = 1.0
	var charging: bool = false

	func _draw() -> void:
		var base_col := Color(0.46, 0.84, 1.0, 0.72).lerp(Color(1.0, 0.96, 0.68, 0.98), flash_ratio)
		if energy_ratio < 0.30 and not charging:
			base_col = Color(1.0, 0.48, 0.28, 0.78).lerp(Color.WHITE, flash_ratio)
		var rim_col := Color(0.96, 0.80, 0.34, 0.92).lerp(Color.WHITE, flash_ratio)
		var center := Vector2((8.0 if charging else 5.0) * facing_dir, 1.0)
		var start_a := -0.90 if facing_dir > 0.0 else PI - 0.90
		var end_a := 0.90 if facing_dir > 0.0 else PI + 0.90
		draw_arc(center, 16.5, start_a, end_a, 14, base_col, 3.2)
		draw_arc(center, 18.2, start_a * 0.88, end_a * 0.88, 14, rim_col, 1.5)


func _create_attack_sfx() -> AudioStreamWAV:
	return SFXGenerator.create_blade_sfx()


func _character_ready() -> void:
	character_id = "knight"
	character_name = "Knight"
	attack_point_offset_x = 22.0
	dash_deals_damage = true
	dash_phases_enemies = true
	dash_damage = 16
	dash_knockback_px = 22.0
	dash_tint = Color(0.48, 0.82, 1.0, 0.82)

	_base_max_hp = max_health
	_base_atk = attack_damage
	_base_move_spd = move_speed
	_base_atk_dur = attack_duration
	_base_atk_windup = attack_windup
	_base_dash_cd = dash_cooldown
	_base_dash_dmg = dash_damage
	_base_en_regen = energy_regen_per_sec
	_base_armor = armor_flat_block
	_base_sh_base = shield_hit_energy_base
	_base_sh_per = shield_hit_energy_per_dmg

	_shield_arc = ShieldArcVisual.new()
	_shield_arc.name = "ShieldArc"
	_shield_arc.visible = false
	add_child(_shield_arc)

	_shield_sfx = AudioStreamPlayer.new()
	_shield_sfx.name = "ShieldSFX"
	_shield_sfx.bus = &"SFX"
	_shield_sfx.stream = SFXGenerator.create_shield_block_sfx()
	add_child(_shield_sfx)


func _on_skill_tree_ranks_applied() -> void:
	var p0_1 := skill_rank("p0_t1")
	var p0_2 := skill_rank("p0_t2")
	var p0_4 := skill_rank("p0_t4")
	var p1_1 := skill_rank("p1_t1")
	var p1_4 := skill_rank("p1_t4")
	var p2_1 := skill_rank("p2_t1")
	var p2_4 := skill_rank("p2_t4")

	max_health = _base_max_hp + p1_1 * 30 + p1_4 * 35
	current_health = clampi(current_health + (max_health - _base_max_hp), 1, max_health)

	attack_damage = _base_atk + p0_1 * 6 + p0_2 * 7 + p0_4 * 14 + p1_4 * 8 + p2_4 * 12
	armor_flat_block = _base_armor + p1_1 * 2
	move_speed = _base_move_spd + float(p2_1 * 14)
	dash_damage = _base_dash_dmg + p2_1 * 12
	dash_cooldown = maxf(0.35, _base_dash_cd * pow(0.88, float(p2_1)))
	energy_regen_per_sec = _base_en_regen * (2.0 if p2_4 > 0 else 1.0)

	var drain_mult := 0.0 if p1_4 > 0 else (0.50 if p1_1 > 0 else 1.0)
	shield_hit_energy_base = _base_sh_base * drain_mult
	shield_hit_energy_per_dmg = _base_sh_per * drain_mult
	if p1_4 > 0:
		shield_exhausted = false

	if p0_4 > 0:
		attack_duration = _base_atk_dur * 0.65
		attack_windup = _base_atk_windup * 0.65
	else:
		attack_duration = _base_atk_dur
		attack_windup = _base_atk_windup

	reset_dash_on_kill = (p2_4 > 0)


func can_use_shield() -> bool:
	if skill_rank("p1_t4") > 0:
		return not is_dead
	return (not is_dead) and (not shield_exhausted) and current_energy > 0.05


func set_shielding(active: bool) -> void:
	_manual_shield_hold = active
	_refresh_shield_state()


func _can_regenerate_energy() -> bool:
	return (not is_dashing) and (not is_shielding)


func _on_energy_regenerated() -> void:
	if shield_exhausted and current_energy >= max_energy - 0.01:
		shield_exhausted = false


func _trigger_shield_exhaustion() -> void:
	if skill_rank("p1_t4") > 0:
		return
	current_energy = 0.0
	shield_exhausted = true
	is_shielding = false
	energy_changed.emit(current_energy, max_energy)


func _refresh_shield_state() -> void:
	if is_dead or is_dashing or is_attacking or not can_use_shield():
		is_shielding = false
	else:
		var held := bool(_read_input().get("shield_held", false))
		is_shielding = _manual_shield_hold or held

	if _shield_arc != null:
		var show_arc := is_shielding or is_dashing or post_dash_dodge_left > 0.0
		_shield_arc.visible = show_arc
		_shield_arc.facing_dir = facing
		_shield_arc.charging = is_dashing or post_dash_dodge_left > 0.0
		_shield_arc.energy_ratio = clampf(current_energy / maxf(max_energy, 1.0), 0.0, 1.0)
		_shield_arc.flash_ratio = clampf(_shield_flash_timer / 0.18, 0.0, 1.0)
		if show_arc:
			_shield_arc.queue_redraw()


func _character_physics_process(delta: float) -> void:
	if _shield_flash_timer > 0.0:
		_shield_flash_timer = maxf(_shield_flash_timer - delta, 0.0)

	_refresh_shield_state()
	if is_shielding and shield_hold_drain_per_sec > 0.0:
		consume_energy(shield_hold_drain_per_sec * delta)
		if current_energy <= 0.01:
			_trigger_shield_exhaustion()
			_refresh_shield_state()

	# Pillar 1 Tier 3: Consecrated Crusader Regen & Holy Burn!
	var p1_3 := skill_rank("p1_t3")
	if p1_3 > 0 and not is_dead:
		_consecrate_timer -= delta
		if _consecrate_timer <= 0.0:
			_consecrate_timer = 1.0
			heal(3 + 3 * p1_3)
			for n in get_tree().get_nodes_in_group("enemies"):
				if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
					if (n as Node2D).global_position.distance_to(global_position) <= 88.0:
						n.take_damage(8 + 4 * p1_3)

	# --- ULTIMATE CONVERGED SOLO NODE (`solo_bottom`): STORM OF SACRED BLADES ---
	if skill_rank("solo_bottom") >= 1 and not is_dead:
		_sacred_blade_timer -= delta
		if _sacred_blade_timer <= 0.0:
			var target := _find_nearest_crusader_target(300.0)
			if target != null:
				_fire_sacred_blade(target)
				_sacred_blade_timer = 0.14
			else:
				_sacred_blade_timer = 0.06


func _find_nearest_crusader_target(max_r: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_r
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == null or not is_instance_valid(n) or not (n is Node2D):
			continue
		if n.get("is_dead") == true or not (n as Node2D).visible:
			continue
		var d := global_position.distance_to((n as Node2D).global_position)
		if d <= best_d:
			best_d = d
			best = n as Node2D
	return best


func _fire_sacred_blade(target: Node2D) -> void:
	if get_parent() == null:
		return
	var dir := (target.global_position - global_position).normalized()
	if dir.length() <= 0.01:
		dir = Vector2(facing, 0.0)
	var dmg := maxi(int(roundf(float(attack_damage) * 0.35)), 1)
	var blade: Area2D = PLAYER_ARROW_SCENE.instantiate()
	blade.speed = 520.0
	blade.max_range = 340.0
	blade.scale = Vector2(1.2, 1.2)
	blade.modulate = Color(0.55, 0.88, 1.0, 0.96)
	blade.homing_strength = 8.0
	blade.puff_color = Color(0.52, 0.85, 1.0)
	get_parent().add_child(blade)
	blade.launch(global_position + dir * 14.0, dir, self, dmg, false)


func _on_post_dash_projectile_dodged(proj_pos: Vector2) -> void:
	# Crusader's Holy Aegis reflects a Golden Bolt right back toward the projectile!
	if get_parent() == null:
		return
	var dir := (proj_pos - global_position).normalized()
	if dir.length() <= 0.01:
		dir = Vector2(facing, 0.0)
	var bolt: Area2D = PLAYER_ARROW_SCENE.instantiate()
	bolt.speed = 480.0
	bolt.max_range = 360.0
	bolt.modulate = Color(1.0, 0.90, 0.36, 0.98)
	bolt.puff_color = Color(1.0, 0.86, 0.32)
	get_parent().add_child(bolt)
	bolt.launch(global_position + dir * 14.0, dir, self, attack_damage, true)


func _get_stance_move_multiplier() -> float:
	return shield_move_multiplier if is_shielding else 1.0


func _update_animation() -> void:
	if is_dashing:
		if anim_player.has_animation("charge") and anim_player.current_animation != "charge":
			anim_player.play("charge")
		return
	if is_attacking:
		return
	if is_shielding and anim_player.has_animation("guard"):
		if anim_player.current_animation != "guard":
			anim_player.play("guard")
		return
	super._update_animation()


func _mitigate_incoming_damage(amount: int, _from_position: Vector2) -> int:
	if amount <= 0:
		return 0
	_refresh_shield_state()

	# 1. ACTIVE TOWER SHIELD: 100% HP Damage Block powered by Green Energy!
	if is_shielding and can_use_shield():
		var energy_cost := shield_hit_energy_base + float(amount) * shield_hit_energy_per_dmg
		consume_energy(energy_cost)
		if current_energy <= 0.01:
			_trigger_shield_exhaustion()

		_shield_flash_timer = 0.18
		if _shield_sfx != null:
			_shield_sfx.pitch_scale = 1.0
			_shield_sfx.play()
		_spawn_hit_spark_at(global_position + Vector2(facing * 14.0, 0.0))
		ScreenShake.shake(1.8, 0.09)
		last_mitigation_label = "SHIELD BREAK!" if shield_exhausted else "SHIELD"
		_refresh_shield_state()

		# Pillar 1 Tier 2: Roar of Retribution Holy Lion Blast on Block!
		var p1_2 := skill_rank("p1_t2")
		if p1_2 > 0:
			var ret_dmg := 23 + 12 * p1_2
			for n in get_tree().get_nodes_in_group("enemies"):
				if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
					if (n as Node2D).global_position.distance_to(global_position) <= 115.0:
						deal_combat_damage(n, ret_dmg, false, 16.0, global_position)
		return 0

	# 2. PASSIVE PLATE ARMOR: Flat damage block on all hits!
	if armor_flat_block > 0:
		var reduced := maxi(amount - armor_flat_block, 1)
		if reduced < amount:
			last_mitigation_label = "ARMOR"
			if _shield_sfx != null and not _shield_sfx.playing:
				_shield_sfx.pitch_scale = 0.78
				_shield_sfx.play()
		return reduced

	return amount


func _compute_melee_damage() -> int:
	var p0_3 := skill_rank("p0_t3")
	if p0_3 > 0 and randf() < clampf(0.30 + 0.10 * float(p0_3), 0.0, 0.85):
		return int(roundf(float(attack_damage) * 2.5))
	return attack_damage


func _on_dash_hit_enemy(enemy: Node) -> void:
	if skill_rank("p2_t3") > 0 and enemy != null and is_instance_valid(enemy) and enemy.get("is_dead") != true:
		EnemyStatusScript.apply_stun(enemy, 1.5)
		if enemy.get("immovable_dummy") != true and "max_health" in enemy and "current_health" in enemy:
			var mx := int(enemy.max_health)
			if mx > 0 and mx <= 400 and float(enemy.current_health) / float(mx) <= 0.28:
				enemy.take_damage(int(enemy.current_health) + 1)


func _on_dash_ended() -> void:
	var p2_2 := skill_rank("p2_t2")
	if p2_2 > 0:
		var smite_dmg := 28 + 14 * p2_2
		for n in get_tree().get_nodes_in_group("enemies"):
			if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
				if (n as Node2D).global_position.distance_to(global_position) <= 95.0:
					deal_combat_damage(n, smite_dmg, true, 12.0, global_position)


func _get_incoming_knockback_multiplier() -> float:
	return 0.25 if is_shielding else 0.72


func _compute_melee_knockback_px() -> float:
	return super._compute_melee_knockback_px() + 16.0


func _on_melee_strike_active() -> void:
	var parent := get_parent()
	if parent == null:
		return

	# Pillar 0 Tier 1: Sacred Sword-Beam Projectile!
	var p0_1 := skill_rank("p0_t1")
	if p0_1 > 0:
		var aim := get_aim_direction()
		var beam: Area2D = PLAYER_ARROW_SCENE.instantiate()
		beam.speed = 430.0
		beam.max_range = 320.0
		beam.scale = Vector2(1.55, 1.55)
		beam.modulate = Color(0.55, 0.88, 1.0, 0.96)
		beam.puff_color = Color(0.45, 0.82, 1.0)
		parent.add_child(beam)
		beam.launch(global_position + aim * 18.0, aim, self, int(roundf(float(attack_damage) * 0.80)), true)

	# Pillar 0 Tier 2: Grandmaster Extended Cleave AoE!
	if skill_rank("p0_t2") > 0:
		for n in get_tree().get_nodes_in_group("enemies"):
			if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
				if (n as Node2D).global_position.distance_to(global_position) <= 74.0:
					var eid := n.get_instance_id()
					if not _enemies_hit_this_swing.has(eid):
						_enemies_hit_this_swing[eid] = true
						deal_combat_damage(n, _compute_melee_damage(), false, _compute_melee_knockback_px())

	var ring := Node2D.new()
	parent.add_child(ring)
	ring.global_position = global_position + Vector2(4.0 * facing, 0.0)

	var rad_mult := 1.45 if skill_rank("p0_t2") > 0 else 1.0
	var outer := Line2D.new()
	outer.width = 4.5
	outer.default_color = Color(0.84, 0.92, 1.0, 0.94)
	var inner := Line2D.new()
	inner.width = 2.2
	inner.default_color = Color(1.0, 0.84, 0.34, 0.88)
	var pts_o := PackedVector2Array()
	var pts_i := PackedVector2Array()
	var steps := 20
	for i in steps + 1:
		var t := lerpf(-2.1, 2.1, float(i) / float(steps))
		pts_o.append(Vector2(cos(t) * 32.0 * rad_mult * facing, sin(t) * 24.0 * rad_mult))
		pts_i.append(Vector2(cos(t) * 24.0 * rad_mult * facing, sin(t) * 18.0 * rad_mult))
	outer.points = pts_o
	inner.points = pts_i
	ring.add_child(outer)
	ring.add_child(inner)

	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "rotation", 0.75 * facing, 0.20)
	tw.tween_property(ring, "scale", Vector2(1.20, 1.16), 0.20)
	tw.tween_property(ring, "modulate:a", 0.0, 0.20)
	tw.chain().tween_callback(ring.queue_free)
