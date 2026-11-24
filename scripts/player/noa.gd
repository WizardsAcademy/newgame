extends PlayerBase
## Noa - Royal Aristocrat Vampire (Hero 4 of 4).
##
## Base Kit + Exclusive-Pillar OP Skill Tree:
##   - `solo_top`    : **Aristocrat's Mist Veil** — 100% projectile & hit dodge for `1.0s` after Bat-Swarm Shift!
##   - Pillar 0      : **Blood Empress** — Zero self-HP cost Blood-Splash, 2-hit 30% Blood Fountain, huge Scarlet Arc!
##   - Pillar 1      : **Night Swarm** — Damaging/healing Bat-Swarm Shift, Homing Bat Familiars, kill resets Shift!
##   - Pillar 2      : **White Sovereign** — Blazing Blood-Splash speed, 2.5x White-Rose Crits, Crimson Corpse Novas!
##   - `solo_bottom` : **Royal Crimson Cataclysm** — Ruby Crown auto-fires rapid Blood Lances at nearby foes
##                     dealing `30%` of `attack_damage` + Life Drain + Vampire Curse stacks!

const PLAYER_ARROW_SCENE := preload("res://scenes/player/PlayerArrow.tscn")
const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")
const BAT_SHEET_PATH := "res://assets/textures/crimson_bat.png"
const FX_SHEET_PATH := "res://assets/textures/noa_fx.png"

@export var splash_range: float = 92.0
@export var splash_cone_dot: float = 0.22
@export var blood_self_cost_ratio: float = 0.06
@export var heal_per_enemy_hit: int = 1

var _base_max_hp: int = 75
var _base_atk: int = 14
var _base_move_spd: float = 104.0
var _base_atk_dur: float = 0.34
var _base_atk_windup: float = 0.10
var _base_dash_cd: float = 1.0
var _base_splash_range: float = 92.0
var _base_cost_ratio: float = 0.06
var _base_heal_hit: int = 1

var _combo_idx: int = 0
var _bat_frames: Array[AtlasTexture] = []
var _fx_frames: Array[AtlasTexture] = []
var _swarm_root: Node2D = null
var _swarm_time: float = 0.0
var _crimson_lance_timer: float = 0.0


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

	_base_max_hp = max_health
	_base_atk = attack_damage
	_base_move_spd = move_speed
	_base_atk_dur = attack_duration
	_base_atk_windup = attack_windup
	_base_dash_cd = dash_cooldown
	_base_splash_range = splash_range
	_base_cost_ratio = blood_self_cost_ratio
	_base_heal_hit = heal_per_enemy_hit

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


func _on_skill_tree_ranks_applied() -> void:
	post_dash_full_immunity = (skill_rank("solo_top") >= 1)
	var p0_1 := skill_rank("p0_t1")
	var p0_3 := skill_rank("p0_t3")
	var p0_4 := skill_rank("p0_t4")
	var p1_1 := skill_rank("p1_t1")
	var p1_2 := skill_rank("p1_t2")
	var p1_4 := skill_rank("p1_t4")
	var p2_1 := skill_rank("p2_t1")
	var p2_3 := skill_rank("p2_t3")
	var p2_4 := skill_rank("p2_t4")

	max_health = _base_max_hp + p0_4 * 24 + p2_4 * 25
	current_health = clampi(current_health + (max_health - _base_max_hp), 1, max_health)

	attack_damage = _base_atk + p0_3 * 7 + p0_4 * 14 + p1_4 * 12 + p2_1 * 6 + p2_4 * 14
	move_speed = _base_move_spd + float(p1_2 * 16)
	splash_range = _base_splash_range + float(p0_3 * 22)

	blood_self_cost_ratio = 0.0 if p0_1 > 0 else _base_cost_ratio
	heal_per_enemy_hit = _base_heal_hit + (1 + 2 * p0_1 if p0_1 > 0 else 0) + (4 * p2_4)

	if p1_1 > 0:
		dash_deals_damage = true
		dash_damage = 16 + 10 * p1_1
	else:
		dash_deals_damage = false
		dash_damage = 0

	dash_cooldown = maxf(0.32, _base_dash_cd * pow(0.88, float(p1_2)))

	if p2_1 > 0:
		attack_duration = _base_atk_dur * 0.65
		attack_windup = _base_atk_windup * 0.65
	else:
		attack_duration = _base_atk_dur
		attack_windup = _base_atk_windup

	reset_dash_on_kill = (p1_4 > 0)
	if p2_3 > 0:
		kill_explosion_damage = 30 + 12 * p2_3
		kill_explosion_radius = 85.0
		kill_explosion_color = Color(0.98, 0.22, 0.44, 0.94)
	else:
		kill_explosion_damage = 0
		kill_explosion_radius = 0.0


func _exit_tree() -> void:
	_cleanup_bat_swarm()
	super._exit_tree()


func _character_physics_process(delta: float) -> void:
	# --- ULTIMATE CONVERGED SOLO NODE (`solo_bottom`): ROYAL CRIMSON CATACLYSM ---
	if skill_rank("solo_bottom") >= 1 and not is_dead:
		_crimson_lance_timer -= delta
		if _crimson_lance_timer <= 0.0:
			var target := _find_nearest_vampire_target(320.0)
			if target != null:
				_fire_royal_blood_lance(target)
				_crimson_lance_timer = 0.13
			else:
				_crimson_lance_timer = 0.06


func _find_nearest_vampire_target(max_r: float) -> Node2D:
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


func _fire_royal_blood_lance(target: Node2D) -> void:
	if get_parent() == null:
		return
	var dir := (target.global_position - global_position).normalized()
	if dir.length() <= 0.01:
		dir = Vector2(facing, 0.0)
	var dmg := maxi(int(roundf(float(attack_damage) * 0.30)), 1)
	var lance: Area2D = PLAYER_ARROW_SCENE.instantiate()
	lance.speed = 540.0
	lance.max_range = 350.0
	lance.modulate = Color(1.0, 0.20, 0.42, 0.96)
	lance.homing_strength = 9.0
	lance.lifesteal_heal = 2
	lance.apply_vampire_stack = true
	lance.puff_color = Color(0.95, 0.14, 0.34)
	get_parent().add_child(lance)
	lance.launch(global_position + dir * 14.0, dir, self, dmg, false)


func _get_attack_move_multiplier() -> float:
	return 0.42


func get_blood_cast_cost() -> int:
	if blood_self_cost_ratio <= 0.0001:
		return 0
	return maxi(int(roundf(float(max_health) * blood_self_cost_ratio)), 1)


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

	await get_tree().create_timer(attack_windup).timeout
	if my_token != _attack_token or is_dead:
		return

	var paid_hp := _pay_blood_cost()
	_unleash_blood_splash(dir, paid_hp, is_nova)

	var remaining := maxf(attack_duration - attack_windup, 0.08)
	await get_tree().create_timer(remaining).timeout
	if my_token != _attack_token or is_dead:
		return

	is_attacking = false


func _pay_blood_cost() -> int:
	if is_dead:
		return 0
	var desired_cost := get_blood_cast_cost()
	if desired_cost <= 0:
		return 0
	var paid := mini(desired_cost, maxi(current_health - 1, 0))
	if paid > 0:
		last_health_change_was_self_cost = true
		current_health -= paid
		health_changed.emit(current_health, max_health)
	return paid


func _unleash_blood_splash(dir: Vector2, paid_hp: int, is_nova: bool) -> void:
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

		# Pillar 1 Tier 3: Seeker Bat Familiars!
		var p1_3 := skill_rank("p1_t3")
		if p1_3 > 0:
			var fam_dmg := maxi(int(roundf(float(attack_damage) * (0.38 + 0.12 * float(p1_3)))), 2)
			for off_deg in [-10.0, 10.0]:
				var seeker: Area2D = PLAYER_ARROW_SCENE.instantiate()
				seeker.speed = 380.0
				seeker.max_range = 300.0
				seeker.modulate = Color(0.95, 0.18, 0.36, 0.95)
				seeker.homing_strength = 10.0
				seeker.lifesteal_heal = 2
				seeker.puff_color = Color(0.92, 0.14, 0.32)
				parent.add_child(seeker)
				seeker.launch(global_position + aim * 12.0, aim.rotated(deg_to_rad(off_deg)), self, fam_dmg, false)

	var hits_landed := 0
	var origin := global_position
	var eff_range := splash_range * (1.08 if is_nova else 1.0)
	var min_dot := -0.15 if is_nova else splash_cone_dot
	var p2_2 := skill_rank("p2_t2")
	var double_curse := (skill_rank("p0_t2") > 0)

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

		hits_landed += 1
		var hit_dmg := attack_damage
		if p2_2 > 0 and randf() < clampf(0.30 + 0.10 * float(p2_2), 0.0, 0.85):
			hit_dmg = int(roundf(float(hit_dmg) * 2.5))
		deal_combat_damage(node, hit_dmg, false, 9.0, origin)
		EnemyStatusScript.add_vampire_fang_stack(node, self)
		if double_curse and node != null and is_instance_valid(node) and node.get("is_dead") != true:
			EnemyStatusScript.add_vampire_fang_stack(node, self)

	if hits_landed > 0:
		var total_heal := paid_hp + heal_per_enemy_hit * hits_landed
		if total_heal > 0:
			heal(total_heal)


func _on_dash_hit_enemy(_enemy: Node) -> void:
	if skill_rank("p1_t1") > 0:
		heal(4)


func _die() -> void:
	super._die()


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
