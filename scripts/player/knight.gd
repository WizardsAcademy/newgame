extends PlayerBase
## Knight - Classic Silver & Gold Crusader (Hero 2 of 4).
##
## Reworked Kit + Distinct Exclusive-Pillar OP Skill Tree (ZERO arrow spam!):
##   - `solo_top`    : **Sacred Aegis Shield** — Glowing protective Shield Dome around Knight
##                     that absorbs hits & instantly refreshes on Shift!
##   - Pillar 0      : **Greatsword Cleave** — Wide sweep, Armor Sunder, 2.5x Templar Crits, Excalibur Spin!
##   - Pillar 1      : **Lion Bastion** — Golden Lion Plate, Holy Retribution block blast, Consecrated Regen!
##   - Pillar 2      : **Sky Crusader** — Thunder Shield-Ram, Heavensfall Lightning Smite, Stun & Execute!
##   - `solo_bottom` : **`[R]` Royal War Banner** — Plants a Lion War Banner & summons **1 Allied Knight**
##                     to fight alongside you for **7.0s** (**60.0s / 1 min** cooldown)!

const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")
const AlliedKnightScript := preload("res://scripts/player/allied_knight.gd")

@export var armor_flat_block: int = 3
@export var shield_move_multiplier: float = 0.56
@export var shield_hold_drain_per_sec: float = 0.0
@export var shield_hit_energy_base: float = 20.0
@export var shield_hit_energy_per_dmg: float = 1.2
@export var banner_ally_duration: float = 7.0
@export var banner_cooldown: float = 60.0

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
var aegis_unlocked: bool = false
var aegis_ready: bool = false
var aegis_recharge_timer: float = 0.0
const AEGIS_RECHARGE_DURATION: float = 5.0

var _manual_shield_hold: bool = false
var _swing_counter: int = 0
var _shield_arc: ShieldArcVisual = null
var _aegis_dome_fx: KnightAegisDomeFX = null
var _shield_sfx: AudioStreamPlayer = null
var _shield_flash_timer: float = 0.0
var _consecrate_timer: float = 0.0


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


class KnightAegisDomeFX extends Node2D:
	var dome_ready: bool = false
	var sanct_active: bool = false
	var anim_t: float = 0.0

	func _process(delta: float) -> void:
		anim_t += delta
		if dome_ready or sanct_active:
			queue_redraw()

	func _draw() -> void:
		if sanct_active:
			var sp := 0.5 + 0.5 * sin(anim_t * 4.5)
			draw_arc(Vector2(0.0, 6.0), 42.0 + sp * 2.0, 0.0, TAU, 32, Color(1.0, 0.86, 0.36, 0.30), 1.6)
		if dome_ready:
			var p := 0.5 + 0.5 * sin(anim_t * 6.5)
			draw_circle(Vector2(0.0, -4.0), 18.0, Color(0.24, 0.68, 1.0, 0.16 + p * 0.06))
			draw_arc(Vector2(0.0, -4.0), 18.5 + p * 1.2, 0.0, TAU, 28, Color(0.46, 0.86, 1.0, 0.90), 2.0)
			var sx := cos(anim_t * 2.8) * 14.0
			var sy := -4.0 + sin(anim_t * 2.8) * 9.0
			var crest := PackedVector2Array([
				Vector2(sx - 3.0, sy - 3.5),
				Vector2(sx + 3.0, sy - 3.5),
				Vector2(sx + 2.5, sy + 1.5),
				Vector2(sx, sy + 4.2),
				Vector2(sx - 2.5, sy + 1.5),
			])
			draw_colored_polygon(crest, Color(0.32, 0.78, 1.0, 0.94))
			draw_polyline(crest, Color(1.0, 0.88, 0.42, 0.98), 1.2)


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
	ult_cooldown = banner_cooldown

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

	_aegis_dome_fx = KnightAegisDomeFX.new()
	_aegis_dome_fx.name = "KnightAegisDomeFX"
	_aegis_dome_fx.z_index = 3
	add_child(_aegis_dome_fx)

	_shield_sfx = AudioStreamPlayer.new()
	_shield_sfx.name = "ShieldSFX"
	_shield_sfx.bus = &"SFX"
	_shield_sfx.stream = SFXGenerator.create_shield_block_sfx()
	add_child(_shield_sfx)


func _on_skill_tree_ranks_applied() -> void:
	# Skill 1 (`solo_top`): Sacred Aegis Shield Dome on Knight (NO 1s projectile dodge!)
	post_dash_dodge_duration = 0.0
	post_dash_invincible_duration = 0.0
	aegis_unlocked = (skill_rank("solo_top") >= 1)
	aegis_ready = aegis_unlocked
	aegis_recharge_timer = 0.0

	var p0_1 := skill_rank("p0_t1")
	var p0_2 := skill_rank("p0_t2")
	var p0_4 := skill_rank("p0_t4")
	var p1_1 := skill_rank("p1_t1")
	var p1_4 := skill_rank("p1_t4")
	var p2_1 := skill_rank("p2_t1")
	var p2_4 := skill_rank("p2_t4")

	max_health = _base_max_hp + p1_1 * 60 + p1_4 * 70
	current_health = clampi(current_health + (max_health - _base_max_hp), 1, max_health)

	attack_damage = _base_atk + p0_1 * 15 + p0_2 * 12 + p0_4 * 28 + p1_4 * 20 + p2_4 * 26
	armor_flat_block = _base_armor + p1_1 * 4
	move_speed = _base_move_spd + float(p2_1 * 16)
	dash_damage = _base_dash_dmg + p2_1 * 24
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
	ult_cooldown = banner_cooldown


func _activate_ultimate() -> bool:
	var parent := get_parent()
	if parent == null:
		return false
	var banner := AlliedKnightScript.new()
	banner.name = "RoyalWarBanner"
	banner.setup(self, banner_ally_duration)
	parent.add_child(banner)
	banner.global_position = global_position + Vector2(facing * 14.0, 2.0)

	ult_active = true
	ult_active_left = banner_ally_duration
	ult_cooldown_left = banner_cooldown
	ScreenShake.shake(4.2, 0.18)
	return true


func get_ability_hud_info() -> Array[Dictionary]:
	return [
		{"key": "LMB", "title": "Cleave", "icon_idx": 1, "cd_left": 0.0, "cd_max": 1.0, "unlocked": true, "active": is_attacking},
		{"key": "RMB", "title": "Shield", "icon_idx": 7, "cd_left": 0.0, "cd_max": 1.0, "unlocked": true, "active": is_shielding or aegis_ready},
		{"key": "SHIFT", "title": "Ram", "icon_idx": 11, "cd_left": dash_cooldown_left, "cd_max": maxf(dash_cooldown, 0.1), "unlocked": true, "active": is_dashing},
		{"key": "R", "title": "Banner", "icon_idx": 15, "cd_left": ult_cooldown_left, "cd_max": maxf(ult_cooldown, 0.1), "unlocked": is_ultimate_unlocked(), "active": ult_active},
	]


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
		var show_arc := is_shielding or is_dashing
		_shield_arc.visible = show_arc
		_shield_arc.facing_dir = facing
		_shield_arc.charging = is_dashing
		_shield_arc.energy_ratio = clampf(current_energy / maxf(max_energy, 1.0), 0.0, 1.0)
		_shield_arc.flash_ratio = clampf(_shield_flash_timer / 0.18, 0.0, 1.0)
		if show_arc:
			_shield_arc.queue_redraw()


func _character_physics_process(delta: float) -> void:
	if _shield_flash_timer > 0.0:
		_shield_flash_timer = maxf(_shield_flash_timer - delta, 0.0)

	if ult_active:
		ult_active_left = maxf(ult_active_left - delta, 0.0)
		if ult_active_left <= 0.0:
			ult_active = false
			ultimate_state_changed.emit(false, ult_cooldown_left, ult_cooldown)

	if aegis_unlocked and not aegis_ready and not is_dead:
		aegis_recharge_timer -= delta
		if aegis_recharge_timer <= 0.0:
			aegis_ready = true

	if _aegis_dome_fx != null:
		_aegis_dome_fx.dome_ready = (aegis_unlocked and aegis_ready and not is_dead)
		_aegis_dome_fx.sanct_active = (skill_rank("p1_t3") > 0 and not is_dead)
		_aegis_dome_fx.visible = (_aegis_dome_fx.dome_ready or _aegis_dome_fx.sanct_active)

	_refresh_shield_state()
	if is_shielding and shield_hold_drain_per_sec > 0.0:
		consume_energy(shield_hold_drain_per_sec * delta)
		if current_energy <= 0.01:
			_trigger_shield_exhaustion()
			_refresh_shield_state()

	# Pillar 1 Tier 3: Consecrated Sanctuary Regen & Holy Burn!
	var p1_3 := skill_rank("p1_t3")
	if p1_3 > 0 and not is_dead:
		_consecrate_timer -= delta
		if _consecrate_timer <= 0.0:
			_consecrate_timer = 1.0
			heal(10 + 6 * p1_3)
			for n in get_tree().get_nodes_in_group("enemies"):
				if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
					if (n as Node2D).global_position.distance_to(global_position) <= 88.0:
						n.take_damage(12 + 8 * p1_3)


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

		# Pillar 1 Tier 2: Lion's Roar Holy Counter Blast on Block!
		var p1_2 := skill_rank("p1_t2")
		if p1_2 > 0:
			var ret_dmg := 50 + 24 * p1_2
			for n in get_tree().get_nodes_in_group("enemies"):
				if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
					if (n as Node2D).global_position.distance_to(global_position) <= 115.0:
						deal_combat_damage(n, ret_dmg, false, 16.0, global_position)
		return 0

	# 2. SKILL 1 (`solo_top`): Sacred Aegis Shield Barrier absorbs 1 full hit!
	if aegis_unlocked and aegis_ready:
		aegis_ready = false
		aegis_recharge_timer = AEGIS_RECHARGE_DURATION
		if _shield_sfx != null:
			_shield_sfx.pitch_scale = 1.15
			_shield_sfx.play()
		_spawn_hit_spark_at(global_position)
		last_mitigation_label = "AEGIS!"
		return 0

	# 3. PASSIVE PLATE ARMOR: Flat damage block on all hits!
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


func _on_dealt_damage(enemy: Node, _amount: int, _from_dash: bool) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead") == true:
		return
	var p0_2 := skill_rank("p0_t2")
	if p0_2 > 0:
		EnemyStatusScript.add_sunder_stack(enemy, p0_2)


func _on_dash_started() -> void:
	if aegis_unlocked:
		aegis_ready = true
		aegis_recharge_timer = 0.0


func _on_dash_hit_enemy(enemy: Node) -> void:
	if skill_rank("p2_t3") > 0 and enemy != null and is_instance_valid(enemy) and enemy.get("is_dead") != true:
		EnemyStatusScript.apply_stun(enemy, 1.6)
		if not enemy.is_in_group("boss") and enemy.get("immovable_dummy") != true and "max_health" in enemy and "current_health" in enemy:
			var mx := int(enemy.max_health)
			if mx > 0 and float(enemy.current_health) / float(mx) <= 0.28:
				enemy.take_damage(int(enemy.current_health) + 10)


func _on_dash_ended() -> void:
	var p2_2 := skill_rank("p2_t2")
	if p2_2 > 0:
		var smite_dmg := 65 + 28 * p2_2
		for n in get_tree().get_nodes_in_group("enemies"):
			if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
				if (n as Node2D).global_position.distance_to(global_position) <= 95.0:
					deal_combat_damage(n, smite_dmg, true, 12.0, global_position)


func _get_incoming_knockback_multiplier() -> float:
	return 0.25 if is_shielding else 0.72


func _compute_melee_knockback_px() -> float:
	return super._compute_melee_knockback_px() + 16.0


func _on_melee_strike_active() -> void:
	_swing_counter += 1
	var parent := get_parent()
	if parent == null:
		return

	# Pure Melee Greatsword Cleave & 3rd-hit 360° Excalibur Spin (ZERO arrows/projectiles!)
	var full_spin := (skill_rank("p0_t4") > 0 and (_swing_counter % 3 == 0))
	var sweep_rad := 84.0 if (skill_rank("p0_t1") > 0 or full_spin) else 56.0
	var aim := get_aim_direction()
	if skill_rank("p0_t1") > 0 or skill_rank("p0_t2") > 0 or full_spin:
		for n in get_tree().get_nodes_in_group("enemies"):
			if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
				var to_foe := (n as Node2D).global_position - global_position
				var d := to_foe.length()
				if d <= sweep_rad and (full_spin or d < 18.0 or to_foe.normalized().dot(aim) >= -0.15):
					var eid := n.get_instance_id()
					if not _enemies_hit_this_swing.has(eid):
						_enemies_hit_this_swing[eid] = true
						var sund_mult := EnemyStatusScript.get_sunder_multiplier(n)
						var strike := int(roundf(float(_compute_melee_damage()) * sund_mult))
						deal_combat_damage(n, strike, false, _compute_melee_knockback_px())

	var ring := Node2D.new()
	parent.add_child(ring)
	ring.global_position = global_position + Vector2(4.0 * facing, 0.0)

	var rad_mult := 1.45 if (skill_rank("p0_t1") > 0 or full_spin) else 1.0
	var outer := Line2D.new()
	outer.width = 4.5
	outer.default_color = Color(1.0, 0.90, 0.38, 0.96) if full_spin else Color(0.84, 0.92, 1.0, 0.94)
	var inner := Line2D.new()
	inner.width = 2.2
	inner.default_color = Color(1.0, 0.84, 0.34, 0.88)
	var pts_o := PackedVector2Array()
	var pts_i := PackedVector2Array()
	var steps := 20
	for i in steps + 1:
		var t := (TAU * float(i) / float(steps)) if full_spin else lerpf(-2.1, 2.1, float(i) / float(steps))
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
