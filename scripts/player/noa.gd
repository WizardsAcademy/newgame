extends PlayerBase
## Noa - Royal Aristocrat Vampire (Hero 4 of 4).
##
## Reworked Core + Distinct Skill Tree + Toggle `[R]` Sanguine Rain:
##   - **Baseline**: Basic attacks cost **0 self-HP** (`azash hp kam nemishe`) and restore
##     **0 flat HP** (`va hp ham por nemikone`)!
##   - **8-Hit Debuff**: Inflicts 1 Vampire Fang stack per attack; at **8 stacks**, erupts
##     a `30%` Max HP Ground Blood Fountain and **lifesteals 10% of the HP damage dealt**!
##   - `solo_top`    : **Sanguine 1% HP Bite** — Attacks heal Noa for **1% of the hit enemy's Max HP**!
##   - Pillar 0      : **Hemomancer** — Bonus Fang stacks, stronger Blood Fountain, wider reach & Contagion!
##   - Pillar 1      : **Bat Empress** — Damaging Bat-Swarm Shift + **3 Orbiting Bat Familiars**!
##   - Pillar 2      : **Blood Reaper** — Blazing claw speed, 2.5x Crits, Corpse Novas & Execute DMG!
##   - `solo_bottom` : **`[R]` Sanguine Rain (Active / Deactive Toggle)** — Pours blood in a medium
##                     circle (`118px`), dealing **1% self-HP/s** and **1% enemy-HP DPS**, while
##                     **lifestealing 1%** when damaging enemies with `R`!

signal blood_rain_toggled(is_active_now: bool)

const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")
const BAT_SHEET_PATH := "res://assets/textures/crimson_bat.png"
const FX_SHEET_PATH := "res://assets/textures/noa_fx.png"

@export var splash_range: float = 92.0
@export var splash_cone_dot: float = 0.22
@export var blood_self_cost_ratio: float = 0.0
@export var heal_per_enemy_hit: int = 0
@export var blood_rain_radius: float = 118.0
@export var blood_rain_tick_interval: float = 1.0

var blood_rain_active: bool = false
var fang_burst_bonus_hp_ratio: float = 0.0
var fang_burst_bonus_lifesteal_ratio: float = 0.0

var _base_max_hp: int = 75
var _base_atk: int = 14
var _base_move_spd: float = 104.0
var _base_atk_dur: float = 0.34
var _base_atk_windup: float = 0.10
var _base_dash_cd: float = 1.0
var _base_splash_range: float = 92.0

var _combo_idx: int = 0
var _bat_frames: Array[AtlasTexture] = []
var _fx_frames: Array[AtlasTexture] = []
var _swarm_root: Node2D = null
var _swarm_time: float = 0.0
var _blood_rain_timer: float = 0.0
var _familiar_bite_timer: float = 0.0
var _blood_rain_fx: NoaBloodRainFX = null


class NoaBloodRainFX extends Node2D:
	var rain_on: bool = false
	var orbit_bats_count: int = 0
	var radius: float = 118.0
	var anim_t: float = 0.0

	func _process(delta: float) -> void:
		anim_t += delta
		if rain_on or orbit_bats_count > 0:
			queue_redraw()

	func _draw() -> void:
		if rain_on:
			var pulse := 0.5 + 0.5 * sin(anim_t * 6.0)
			draw_circle(Vector2.ZERO, radius, Color(0.55, 0.02, 0.10, 0.14 + pulse * 0.05))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.95, 0.12, 0.24, 0.86), 2.2)
			draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 32, Color(1.0, 0.30, 0.42, 0.38), 1.3)
			for i in range(18):
				var seed_f := float(i) * 2.39996
				var fall_phase := fmod(anim_t * 2.4 + float(i) * 0.19, 1.0)
				var rr := radius * 0.88 * sqrt(fmod(float(i * 7 + 3), 18.0) / 18.0)
				var px := cos(seed_f) * rr
				var py := sin(seed_f) * rr * 0.72
				var drop_top := Vector2(px + 3.0, py - 22.0 * (1.0 - fall_phase))
				var drop_bot := Vector2(px, py - 12.0 * (1.0 - fall_phase))
				draw_line(drop_top, drop_bot, Color(1.0, 0.16, 0.28, 0.85), 1.6)
				if fall_phase > 0.78:
					var rip := (fall_phase - 0.78) / 0.22
					draw_arc(Vector2(px, py), 2.0 + rip * 6.0, 0.0, TAU, 12, Color(1.0, 0.28, 0.38, 0.75 * (1.0 - rip)), 1.1)

		if orbit_bats_count > 0:
			for b in range(orbit_bats_count):
				var ang := anim_t * 3.8 + float(b) * (TAU / float(orbit_bats_count))
				var bp := Vector2(cos(ang) * 32.0, -4.0 + sin(ang) * 20.0)
				var flap := sin(anim_t * 22.0 + float(b) * 2.0) * 3.5
				var bat_poly := PackedVector2Array([
					bp + Vector2(-6.0, -flap), bp + Vector2(-2.0, -1.5),
					bp + Vector2(0.0, -3.0), bp + Vector2(2.0, -1.5),
					bp + Vector2(6.0, -flap), bp + Vector2(2.0, 2.2), bp + Vector2(-2.0, 2.2),
				])
				draw_colored_polygon(bat_poly, Color(0.24, 0.03, 0.08, 0.96))
				draw_polyline(bat_poly, Color(1.0, 0.18, 0.30, 0.92), 1.1)


class BloodSplashSlash extends Node2D:
	var aim_dir: Vector2 = Vector2.RIGHT
	var reach: float = 92.0
	var is_nova_finisher: bool = false
	var anim_frames: Array[Texture2D] = []
	var elapsed: float = 0.0
	var duration: float = 0.25
	var _sprite: Sprite2D = null
	var _glow_sprite: Sprite2D = null

	func setup(dir: Vector2, max_r: float, nova: bool, frames_seq: Array[Texture2D]) -> void:
		aim_dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
		reach = max_r
		is_nova_finisher = nova
		anim_frames = frames_seq
		rotation = aim_dir.angle()
		z_index = 4

		if not anim_frames.is_empty():
			var base_pos := Vector2(reach * (0.34 if nova else 0.36), 0.0)
			var base_s := 0.50 if nova else 0.44

			_sprite = Sprite2D.new()
			_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_sprite.texture = anim_frames[0]
			_sprite.position = base_pos
			_sprite.scale = Vector2(base_s * 0.86, base_s * 0.86)
			add_child(_sprite)

			var add_mat := CanvasItemMaterial.new()
			add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			_glow_sprite = Sprite2D.new()
			_glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_glow_sprite.material = add_mat
			_glow_sprite.texture = anim_frames[0]
			_glow_sprite.position = base_pos
			_glow_sprite.scale = Vector2(base_s * 0.92, base_s * 0.92)
			_glow_sprite.modulate = Color(1.0, 0.24, 0.42, 0.48)
			add_child(_glow_sprite)

			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(_sprite, "scale", Vector2(base_s * 1.08, base_s * 1.06), duration * 0.70)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(_sprite, "modulate:a", 0.0, duration * 0.36).set_delay(duration * 0.64)
			tw.tween_property(_glow_sprite, "scale", Vector2(base_s * 1.15, base_s * 1.12), duration * 0.70)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(_glow_sprite, "modulate:a", 0.0, duration * 0.45).set_delay(duration * 0.45)

	func _process(delta: float) -> void:
		elapsed += delta
		var p := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
		if _sprite != null and anim_frames.size() >= 3:
			var idx := 0 if p < 0.26 else (1 if p < 0.68 else 2)
			_sprite.texture = anim_frames[idx]
			if _glow_sprite != null:
				_glow_sprite.texture = anim_frames[idx]
		queue_redraw()
		if elapsed >= duration:
			queue_free()

	func _draw() -> void:
		var p := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
		var alpha := (1.0 - p * p) * 0.86
		var sweep_r := lerpf(reach * 0.52, reach * 0.90, sin(p * PI * 0.5))
		var half_ang := 1.12 if is_nova_finisher else 0.96
		var origin := Vector2(10.0, 0.0)
		for i in range(6):
			var frac := -0.78 + 1.56 * (float(i) / 5.0)
			var ang := frac * half_ang
			var dr := sweep_r + 5.0 + p * (13.0 + float(i % 3) * 4.5)
			var dp := origin + Vector2(cos(ang) * dr, sin(ang) * dr)
			draw_circle(dp, maxf(0.8, 2.1 - p * 1.1), Color(0.92, 0.08, 0.25, alpha))


func _create_attack_sfx() -> AudioStreamWAV:
	return SFXGenerator.create_blood_splash_sfx()


func _character_ready() -> void:
	character_id = "noa"
	character_name = "Noa"
	dash_speed = 375.0
	dash_duration = 0.24
	dash_deals_damage = false
	dash_phases_enemies = true
	dash_spawns_ghosts = false
	dash_damage = 0
	dash_tint = Color(0.95, 0.18, 0.34, 0.82)
	ult_is_toggle = true
	ult_cooldown = 0.15

	# Enforce baseline rework even if `.tscn` serialized older exported defaults!
	blood_self_cost_ratio = 0.0
	heal_per_enemy_hit = 0

	_base_max_hp = max_health
	_base_atk = attack_damage
	_base_move_spd = move_speed
	_base_atk_dur = attack_duration
	_base_atk_windup = attack_windup
	_base_dash_cd = dash_cooldown
	_base_splash_range = splash_range

	if ResourceLoader.exists(BAT_SHEET_PATH):
		var btex: Texture2D = load(BAT_SHEET_PATH)
		if btex != null:
			var bsize := maxi(btex.get_height(), 1)
			var bcount := maxi(int(btex.get_width() / bsize), 1)
			for i in range(bcount):
				var at := AtlasTexture.new()
				at.atlas = btex
				at.region = Rect2(float(i * bsize), 0.0, float(bsize), float(bsize))
				_bat_frames.append(at)

	if ResourceLoader.exists(FX_SHEET_PATH):
		var ftex: Texture2D = load(FX_SHEET_PATH)
		if ftex != null:
			var fcell := maxi(ftex.get_height(), 1)
			var fcount := maxi(int(ftex.get_width() / fcell), 1)
			for i in range(fcount):
				var fx_at := AtlasTexture.new()
				fx_at.atlas = ftex
				fx_at.region = Rect2(float(i * fcell), 0.0, float(fcell), float(fcell))
				_fx_frames.append(fx_at)

	_blood_rain_fx = NoaBloodRainFX.new()
	_blood_rain_fx.name = "NoaBloodRainFX"
	_blood_rain_fx.radius = blood_rain_radius
	_blood_rain_fx.z_index = 2
	add_child(_blood_rain_fx)


func _on_skill_tree_ranks_applied() -> void:
	# Skill 1 (`solo_top`) is 1% Enemy HP Lifesteal (NOT 1s projectile dodge!)
	post_dash_dodge_duration = 0.0
	post_dash_invincible_duration = 0.0

	var p0_1 := skill_rank("p0_t1")
	var p0_2 := skill_rank("p0_t2")
	var p0_3 := skill_rank("p0_t3")
	var p0_4 := skill_rank("p0_t4")
	var p1_1 := skill_rank("p1_t1")
	var p1_2 := skill_rank("p1_t2")
	var p1_4 := skill_rank("p1_t4")
	var p2_1 := skill_rank("p2_t1")
	var p2_3 := skill_rank("p2_t3")
	var p2_4 := skill_rank("p2_t4")

	max_health = _base_max_hp + p0_4 * 48 + p1_4 * 42 + p2_4 * 50
	current_health = clampi(current_health + (max_health - _base_max_hp), 1, max_health)

	attack_damage = _base_atk + p0_1 * 12 + p0_3 * 15 + p0_4 * 26 + p1_4 * 22 + p2_1 * 12 + p2_4 * 26
	move_speed = _base_move_spd + float(p1_2 * 18)
	splash_range = _base_splash_range + float(p0_3 * 22)

	fang_burst_bonus_hp_ratio = 0.06 * float(p0_2)
	fang_burst_bonus_lifesteal_ratio = 0.04 * float(p0_2)

	if p1_1 > 0:
		dash_deals_damage = true
		dash_damage = 32 + 18 * p1_1
	else:
		dash_deals_damage = false
		dash_damage = 0

	dash_cooldown = maxf(0.32, _base_dash_cd * pow(0.88, float(p1_2)))

	var spd_mult := 1.0 / (1.0 + 0.16 * float(p2_1))
	attack_duration = maxf(0.14, _base_atk_dur * spd_mult)
	attack_windup = maxf(0.04, _base_atk_windup * spd_mult)

	reset_dash_on_kill = (p1_4 > 0)
	if p2_3 > 0:
		kill_explosion_damage = 52 + 24 * p2_3
		kill_explosion_radius = 88.0
		kill_explosion_color = Color(0.98, 0.22, 0.44, 0.94)
	else:
		kill_explosion_damage = 0
		kill_explosion_radius = 0.0

	if not is_ultimate_unlocked() and blood_rain_active:
		_set_blood_rain_active(false)


func get_fang_burst_hp_ratio() -> float:
	return 0.30 + fang_burst_bonus_hp_ratio


func get_fang_burst_lifesteal_ratio() -> float:
	return 0.10 + fang_burst_bonus_lifesteal_ratio


func _activate_ultimate() -> bool:
	_set_blood_rain_active(not blood_rain_active)
	return true


func _set_blood_rain_active(enable_now: bool) -> void:
	blood_rain_active = enable_now
	ult_active = enable_now
	_blood_rain_timer = 0.15 if enable_now else 0.0
	if _blood_rain_fx != null:
		_blood_rain_fx.rain_on = enable_now
	blood_rain_toggled.emit(enable_now)
	ultimate_state_changed.emit(ult_active, ult_cooldown_left, ult_cooldown)


func get_ability_hud_info() -> Array[Dictionary]:
	return [
		{"key": "LMB", "title": "Claws", "icon_idx": 2, "cd_left": 0.0, "cd_max": 1.0, "unlocked": true, "active": is_attacking},
		{"key": "SHIFT", "title": "Bats", "icon_idx": 5, "cd_left": dash_cooldown_left, "cd_max": maxf(dash_cooldown, 0.1), "unlocked": true, "active": is_dashing},
		{"key": "R", "title": "Rain ON" if blood_rain_active else "Rain", "icon_idx": 14, "cd_left": 0.0, "cd_max": 1.0, "unlocked": is_ultimate_unlocked(), "active": blood_rain_active},
	]


func _exit_tree() -> void:
	_cleanup_bat_swarm()
	super._exit_tree()


func _character_physics_process(delta: float) -> void:
	if is_dead:
		if blood_rain_active:
			_set_blood_rain_active(false)
		return

	var fam_rk := skill_rank("p1_t3")
	if _blood_rain_fx != null:
		_blood_rain_fx.rain_on = blood_rain_active
		_blood_rain_fx.orbit_bats_count = 3 if fam_rk > 0 else 0
		_blood_rain_fx.visible = (_blood_rain_fx.rain_on or _blood_rain_fx.orbit_bats_count > 0)

	# Pillar 1 Tier 3: 3 Orbiting Crimson Bat Familiars bite nearby enemies!
	if fam_rk > 0:
		_familiar_bite_timer -= delta
		if _familiar_bite_timer <= 0.0:
			_familiar_bite_timer = 0.65
			var bite_dmg := 14 + 16 * fam_rk
			for n in get_tree().get_nodes_in_group("enemies"):
				if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true and (n as Node2D).visible:
					if (n as Node2D).global_position.distance_to(global_position) <= 72.0:
						deal_combat_damage(n, bite_dmg, false, 2.0, (n as Node2D).global_position)
						EnemyStatusScript.add_vampire_fang_stack(n, self)
						break

	# `[R]` Sanguine Rain Toggle: 1% self-HP cost, 1% enemy-HP DPS, & 1% lifesteal on hit!
	if blood_rain_active:
		_blood_rain_timer -= delta
		if _blood_rain_timer <= 0.0:
			_blood_rain_timer = blood_rain_tick_interval
			_process_blood_rain_tick()


func _process_blood_rain_tick() -> void:
	# 1% self-HP cost per tick (`1 darsad hp khodesh mire`, floor at 1 HP)
	if not WitchCauldronProgression.wizard_cheat_active and current_health > 1:
		var self_cost := maxi(int(roundf(float(max_health) * 0.01)), 1)
		var actual_cost := mini(self_cost, current_health - 1)
		if actual_cost > 0:
			last_health_change_was_self_cost = true
			current_health -= actual_cost
			health_changed.emit(current_health, max_health)

	# 1% enemy-HP DPS in medium circle + 1% lifesteal on hitting enemies with R!
	var total_lifesteal: int = 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == null or not is_instance_valid(node) or not (node is Node2D):
			continue
		if node.get("is_dead") == true or not (node as Node2D).visible:
			continue
		if (node as Node2D).global_position.distance_to(global_position) > blood_rain_radius:
			continue
		var enemy_max_hp: int = int(node.get("max_health")) if "max_health" in node else 40
		var tick_dmg := maxi(int(roundf(float(enemy_max_hp) * 0.01)), 1)
		if WitchCauldronProgression.wizard_cheat_active:
			tick_dmg = 9999999
		if node.has_method("take_damage"):
			var was_dead: bool = (node.get("is_dead") == true)
			node.take_damage(tick_dmg)
			if not was_dead and is_instance_valid(node) and node.get("is_dead") == true:
				_on_killed_enemy_with_combat(node)
			var ls := maxi(int(roundf(float(max_health) * 0.01 + float(tick_dmg) * 0.01)), 1)
			total_lifesteal += ls

	if total_lifesteal > 0:
		heal(total_lifesteal)


func _on_killed_enemy_with_combat(enemy: Node) -> void:
	super._on_killed_enemy_with_combat(enemy)
	if skill_rank("p0_t3") > 0 and enemy is Node2D:
		var epos := (enemy as Node2D).global_position
		for other in get_tree().get_nodes_in_group("enemies"):
			if other != null and is_instance_valid(other) and other != enemy and other.get("is_dead") != true and other is Node2D:
				if (other as Node2D).global_position.distance_to(epos) <= 95.0:
					for _k in range(4):
						EnemyStatusScript.add_vampire_fang_stack(other, self)


func _get_attack_move_multiplier() -> float:
	return 0.42


func get_blood_cast_cost() -> int:
	return 0


func _start_attack() -> void:
	if is_attacking or is_dashing or is_dead:
		return

	_attack_token += 1
	var my_token := _attack_token
	is_attacking = true
	_hurt_anim_left = 0.0

	var dir := get_aim_direction()
	if absf(dir.x) > 0.05:
		facing = 1.0 if dir.x > 0.0 else -1.0
	_sync_facing_nodes()

	var is_nova := (_combo_idx % 3 == 2)
	_combo_idx += 1
	var anim_name := "attack_splash" if (is_nova and anim_player.has_animation("attack_splash")) else "attack"

	anim_player.stop()
	anim_player.play(anim_name)
	punch_sfx.pitch_scale = randf_range(0.95, 1.08)
	punch_sfx.play()

	var eff_windup := 0.03 if WitchCauldronProgression.wizard_cheat_active else attack_windup
	await get_tree().create_timer(eff_windup).timeout
	if my_token != _attack_token or is_dead:
		return

	_unleash_blood_splash(dir, is_nova)

	var remaining := 0.04 if WitchCauldronProgression.wizard_cheat_active else maxf(attack_duration - attack_windup, 0.08)
	await get_tree().create_timer(remaining).timeout
	if my_token != _attack_token or is_dead:
		return

	is_attacking = false


func _unleash_blood_splash(dir: Vector2, is_nova: bool) -> void:
	var aim := dir.normalized() if dir.length() > 0.01 else Vector2(facing, 0.0)
	var parent := get_parent()
	if parent != null:
		var fx := BloodSplashSlash.new()
		fx.name = "NoaBloodSplash"
		var seq: Array[Texture2D] = []
		if _fx_frames.size() >= 5:
			if is_nova:
				seq.append(_fx_frames[3])
				seq.append(_fx_frames[4])
				seq.append(_fx_frames[2])
			else:
				seq.append(_fx_frames[0])
				seq.append(_fx_frames[1])
				seq.append(_fx_frames[2])
		elif not _fx_frames.is_empty():
			seq.append(_fx_frames[0])
		parent.add_child(fx)
		fx.global_position = global_position + Vector2(0.0, -3.0)
		fx.setup(aim, splash_range, is_nova, seq)

	var origin := global_position
	var eff_range := splash_range * (1.08 if is_nova else 1.0)
	var min_dot := -0.15 if is_nova else splash_cone_dot
	var p2_2 := skill_rank("p2_t2")
	var p2_4 := skill_rank("p2_t4")
	var extra_fang := (skill_rank("p0_t1") > 0 and (_combo_idx % 2 == 0))
	var has_skill1_lifesteal := (skill_rank("solo_top") >= 1)
	var total_lifesteal: int = 0

	for node in get_tree().get_nodes_in_group("enemies"):
		if node == null or not is_instance_valid(node) or node.get("is_dead") == true:
			continue
		if not (node is Node2D):
			continue
		var enemy_pos := (node as Node2D).global_position
		var to_enemy := enemy_pos - origin
		var dist := to_enemy.length()
		if dist > eff_range:
			continue
		var in_arc := dist <= 26.0 or (to_enemy.normalized().dot(aim) >= min_dot)
		if not in_arc:
			continue

		var enemy_max_hp: int = int(node.get("max_health")) if "max_health" in node else 40
		var hit_dmg := float(attack_damage)
		if p2_2 > 0 and randf() < clampf(0.28 + 0.10 * float(p2_2), 0.0, 0.85):
			hit_dmg *= 2.5
		if p2_4 > 0 and "current_health" in node and enemy_max_hp > 0:
			if float(int(node.get("current_health"))) <= float(enemy_max_hp) * 0.40:
				hit_dmg *= 1.50
		deal_combat_damage(node, int(roundf(hit_dmg)), false, 9.0, origin)

		if has_skill1_lifesteal:
			total_lifesteal += maxi(int(roundf(float(enemy_max_hp) * 0.01)), 1)

		EnemyStatusScript.add_vampire_fang_stack(node, self)
		if extra_fang and node != null and is_instance_valid(node) and node.get("is_dead") != true:
			EnemyStatusScript.add_vampire_fang_stack(node, self)

	if total_lifesteal > 0:
		heal(total_lifesteal)


func _on_dash_hit_enemy(enemy: Node) -> void:
	if skill_rank("p1_t1") > 0 and enemy != null and is_instance_valid(enemy) and enemy.get("is_dead") != true:
		EnemyStatusScript.add_vampire_fang_stack(enemy, self)
		EnemyStatusScript.add_vampire_fang_stack(enemy, self)


func _on_dash_started() -> void:
	if visuals != null:
		visuals.visible = false
	_spawn_crimson_mist(global_position)
	_create_bat_swarm()


func _on_dash_tick(delta: float) -> void:
	_swarm_time += delta
	if _swarm_root == null or not is_instance_valid(_swarm_root):
		return
	_swarm_root.global_position = global_position
	var frame_idx := int(_swarm_time * 18.0) % maxi(_bat_frames.size(), 1)
	var count := _swarm_root.get_child_count()
	for i in range(count):
		var bat := _swarm_root.get_child(i) as Sprite2D
		if bat == null:
			continue
		var phase := _swarm_time * 11.0 + float(i) * 1.25
		var spread_x := -_dash_dir.x * float(i % 3) * 7.5 + cos(phase) * 5.0
		var spread_y := -_dash_dir.y * float(i % 3) * 5.0 + float(i - 2) * 5.0 + sin(phase * 1.3) * 4.5
		bat.position = Vector2(spread_x, spread_y)
		bat.flip_h = _dash_dir.x < -0.05
		if not _bat_frames.is_empty():
			bat.texture = _bat_frames[(frame_idx + i) % _bat_frames.size()]


func _on_dash_ended() -> void:
	_cleanup_bat_swarm()
	if visuals != null and not is_dead:
		visuals.visible = true
	_spawn_crimson_mist(global_position)


func _cleanup_bat_swarm() -> void:
	if _swarm_root != null and is_instance_valid(_swarm_root):
		_swarm_root.queue_free()
	_swarm_root = null


func _create_bat_swarm() -> void:
	var parent := get_parent()
	if parent == null:
		return
	_cleanup_bat_swarm()
	_swarm_root = Node2D.new()
	_swarm_root.name = "NoaBatSwarm"
	_swarm_time = 0.0
	parent.add_child(_swarm_root)
	_swarm_root.global_position = global_position

	for i in range(5):
		var bat := Sprite2D.new()
		bat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bat.scale = Vector2(0.95, 0.95)
		if not _bat_frames.is_empty():
			bat.texture = _bat_frames[i % _bat_frames.size()]
		_swarm_root.add_child(bat)


func _spawn_crimson_mist(at_pos: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mist := CPUParticles2D.new()
	mist.one_shot = true
	mist.amount = 10
	mist.lifetime = 0.24
	mist.explosiveness = 1.0
	mist.spread = 180.0
	mist.initial_velocity_min = 28.0
	mist.initial_velocity_max = 68.0
	mist.scale_amount_min = 1.6
	mist.scale_amount_max = 3.0
	mist.color = Color(0.92, 0.14, 0.32, 0.88)
	mist.emitting = false
	parent.add_child(mist)
	mist.global_position = at_pos
	mist.emitting = true
	mist.finished.connect(mist.queue_free)
