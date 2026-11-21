extends PlayerBase
## Velmira - the White-Haired Gothic Vampire (Hero 4 of 4).
##
## Stats & Kit:
##   - 75 HP (lowest HP of all heroes!), 104 Move Speed, 100 Energy.
##   - **Blood Price (`blood_self_cost_ratio = 0.06` + `1 HP` Floor Lock)**:
##       * Every attack sacrifices ~6% of Max HP (4 HP at 75 Max HP).
##       * **1 HP Lock:** At 1 HP, casting never kills Velmira (`paid = 0`,
##         HP stays locked at 1 — only enemy attacks can kill her!).
##   - **Returning Liquid Blood Orb Whip (`BloodWhipOrb`)**:
##       * Sends a glossy, water-like crimson Blood Orb on a sinuous whip-tendril
##         out toward enemies (`128 px`) and curves it right back into Velmira!
##       * **Balanced Return Siphon:** When the blood orb returns to Velmira,
##         if it hit `N >= 1` enemies, she heals **`paid_hp + N` HP**
##         (e.g. 3 enemies hit -> `+3 HP + the HP she paid`; 0 hits -> 0 heal!).
##   - **2-Fang + Filling Crimson Circle Debuff (`EnemyStatus`)**:
##       * Every whip hit fills 25% of a 2-Fang Crimson Ring above the enemy;
##         on the 4th hit (`100%`), it **explodes for 30% of enemy Max HP**!
##   - **Bat-Swarm Vanish (`Shift`)**:
##       * Velmira vanishes (`visuals.visible = false`, 0 DMG, phases enemies),
##         spawning **5 flapping Crimson Bats** that fly to her destination,
##         where she materializes back out of crimson mist!

const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")
const BAT_SHEET_PATH := "res://assets/textures/crimson_bat.png"

@export var whip_range: float = 128.0
@export var whip_duration: float = 0.28
@export var blood_self_cost_ratio: float = 0.06
@export var heal_per_enemy_hit: int = 1

var _rest_tex: Texture2D = null
var _blink_tex: Texture2D = null
var _blink_state: int = 0
var _blink_hold: float = 0.0
var _double_pending: bool = false
var _next_blink: float = 3.0

var _bat_frames: Array[AtlasTexture] = []
var _swarm_root: Node2D = null
var _swarm_time: float = 0.0


## Liquid Crimson Blood Orb tethered to Velmira by a curved whip-stream;
## lashes out to `max_reach` and flows back into Velmira to deliver stolen HP!
class BloodWhipOrb extends Node2D:
	var owner_vampire: Node2D = null
	var aim_dir: Vector2 = Vector2.RIGHT
	var max_reach: float = 128.0
	var total_time: float = 0.28
	var base_damage: int = 13
	var paid_hp: int = 0
	var bonus_per_hit: int = 1
	var status_script: Script = null

	var elapsed: float = 0.0
	var orb_world_pos: Vector2 = Vector2.ZERO
	var hit_ids: Dictionary = {}
	var hits_landed: int = 0

	func setup(vampire: Node2D, dir: Vector2, reach: float, dur: float,
			dmg: int, paid: int, per_hit: int, st_script: Script) -> void:
		owner_vampire = vampire
		aim_dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
		max_reach = reach
		total_time = maxf(dur, 0.10)
		base_damage = dmg
		paid_hp = paid
		bonus_per_hit = per_hit
		status_script = st_script
		orb_world_pos = vampire.global_position + aim_dir * 12.0

	func _physics_process(delta: float) -> void:
		if owner_vampire == null or not is_instance_valid(owner_vampire) or owner_vampire.get("is_dead") == true:
			queue_free()
			return

		elapsed += delta
		var p := clampf(elapsed / total_time, 0.0, 1.0)
		var origin := owner_vampire.global_position + Vector2(0.0, -2.0)
		var perp := Vector2(-aim_dir.y, aim_dir.x)

		if p <= 0.52:
			# Outbound whip lash with sinuous lateral curve
			var u := p / 0.52
			var ease_out := 1.0 - pow(1.0 - u, 2.0)
			var lateral := sin(u * PI) * 14.0
			orb_world_pos = origin + aim_dir * (12.0 + (max_reach - 12.0) * ease_out) + perp * lateral
		else:
			# Inbound liquid return curving back into Velmira's chest!
			var u := (p - 0.52) / 0.48
			var apex := origin + aim_dir * max_reach
			var lateral := -sin(u * PI) * 16.0
			orb_world_pos = apex.lerp(origin, pow(u, 1.35)) + perp * lateral

		global_position = Vector2.ZERO
		_scan_enemy_hits(origin)
		queue_redraw()

		if p >= 1.0:
			_deliver_returned_blood()
			queue_free()

	func _scan_enemy_hits(origin: Vector2) -> void:
		var seg_vec := orb_world_pos - origin
		var seg_len_sq := maxf(seg_vec.length_squared(), 1.0)

		for node in get_tree().get_nodes_in_group("enemies"):
			if node == null or not is_instance_valid(node) or node.get("is_dead") == true:
				continue
			if not (node is Node2D):
				continue
			var eid := node.get_instance_id()
			if hit_ids.has(eid):
				continue

			var enemy_pos := (node as Node2D).global_position
			var d_orb := enemy_pos.distance_to(orb_world_pos)
			# Also check whip tendril body so enemies along the whip line get lashed!
			var proj_t := clampf((enemy_pos - origin).dot(seg_vec) / seg_len_sq, 0.15, 1.0)
			var closest := origin + seg_vec * proj_t
			var d_whip := enemy_pos.distance_to(closest)

			if d_orb <= 20.0 or d_whip <= 13.5:
				hit_ids[eid] = true
				hits_landed += 1
				if owner_vampire.has_method("deal_combat_damage"):
					owner_vampire.deal_combat_damage(node, base_damage, false, 7.0, enemy_pos)
				if status_script != null and is_instance_valid(node) and node.get("is_dead") != true:
					status_script.add_vampire_fang_stack(node, owner_vampire)

	func _deliver_returned_blood() -> void:
		if hits_landed <= 0 or owner_vampire == null or not is_instance_valid(owner_vampire):
			return
		if bool(owner_vampire.get("is_dead")):
			return
		var total_heal := paid_hp + hits_landed * bonus_per_hit
		if total_heal > 0 and owner_vampire.has_method("heal"):
			owner_vampire.heal(total_heal)

	func _draw() -> void:
		if owner_vampire == null or not is_instance_valid(owner_vampire):
			return
		var fdir := 1.0 if owner_vampire.get("facing") == null else float(owner_vampire.get("facing"))
		var origin := owner_vampire.global_position + Vector2(fdir * 8.0, -2.0)
		var delta_v := orb_world_pos - origin
		var perp := Vector2(-delta_v.y, delta_v.x).normalized() if delta_v.length() > 1.0 else Vector2.UP
		var wave_phase := elapsed * 26.0

		# Sinuous liquid whip-tendril connecting Velmira's hand to the Blood Orb!
		var pts := PackedVector2Array()
		var steps := 14
		for i in range(steps + 1):
			var t := float(i) / float(steps)
			var ripple := sin(t * PI) * sin(t * 9.0 - wave_phase) * 4.5
			pts.append(origin.lerp(orb_world_pos, t) + perp * ripple)

		for i in range(steps):
			var w := lerpf(1.6, 3.8, float(i) / float(steps))
			draw_line(pts[i], pts[i + 1], Color(0.45, 0.03, 0.12, 0.90), w + 1.4)
			draw_line(pts[i], pts[i + 1], Color(0.94, 0.14, 0.32, 0.95), w)

		# Glossy Water-Like Crimson Blood Orb at the whip tip (swells with stolen blood!)
		var orb_r := 5.2 + minf(float(hits_landed) * 0.9, 3.5)
		draw_circle(orb_world_pos, orb_r + 1.5, Color(0.18, 0.02, 0.06, 0.92))
		draw_circle(orb_world_pos, orb_r, Color(0.86, 0.08, 0.26, 0.98))
		draw_circle(orb_world_pos + Vector2(-1.4, -1.4), orb_r * 0.55, Color(1.0, 0.38, 0.52, 0.96))
		draw_circle(orb_world_pos + Vector2(-2.0, -2.0), 1.3, Color(1.0, 0.92, 0.95, 0.98))


func _create_attack_sfx() -> AudioStreamWAV:
	return SFXGenerator.create_blood_splash_sfx()


func _character_ready() -> void:
	character_id = "velmira"
	character_name = "Velmira"
	dash_speed = 375.0
	dash_duration = 0.24
	dash_deals_damage = false
	dash_phases_enemies = true
	dash_spawns_ghosts = false
	dash_damage = 0
	dash_tint = Color(0.95, 0.18, 0.34, 0.82)

	if visuals != null and visuals.texture is AtlasTexture:
		_rest_tex = visuals.texture
		var sheet := (visuals.texture as AtlasTexture).atlas
		var blink := AtlasTexture.new()
		blink.atlas = sheet
		blink.region = Rect2(480.0, 0.0, 96.0, 96.0)
		_blink_tex = blink
	_next_blink = randf_range(1.6, 4.0)

	if ResourceLoader.exists(BAT_SHEET_PATH):
		var btex: Texture2D = load(BAT_SHEET_PATH)
		if btex != null:
			for i in range(3):
				var at := AtlasTexture.new()
				at.atlas = btex
				at.region = Rect2(float(i * 24), 0.0, 24.0, 24.0)
				_bat_frames.append(at)


func _process(delta: float) -> void:
	if visuals == null or is_dead:
		return
	var t := float(Time.get_ticks_msec()) / 1000.0

	visuals.position.y = 1.0 * sin(t * 1.9)
	visuals.scale.y = _base_visual_scale.y * (1.0 + 0.022 * sin(t * 1.9 + 0.7))

	var amb := get_node_or_null("Visuals/AmbientBat") as AnimatedSprite2D
	if amb != null:
		amb.position.y = 4.0 * sin(t * 2.4 + 1.3)
		amb.position.x = 2.0 * sin(t * 1.3)

	_tick_blink(delta)


func _tick_blink(delta: float) -> void:
	if _blink_tex == null:
		return
	var idle := anim_player != null and anim_player.current_animation == "idle" and _hurt_anim_left <= 0.0
	if _blink_state == 0:
		if idle:
			_next_blink -= delta
			if _next_blink <= 0.0:
				_blink_state = 1
				_blink_hold = 0.09
				_double_pending = randf() < 0.35
				visuals.texture = _blink_tex
	elif _blink_state == 1:
		_blink_hold -= delta
		if _blink_hold <= 0.0:
			_blink_state = 2
			_blink_hold = 0.06
			if _double_pending:
				visuals.texture = _rest_tex
			else:
				_finish_blink()
	elif _blink_state == 2:
		_blink_hold -= delta
		if _blink_hold <= 0.0:
			_finish_blink()
	if not idle and _blink_state != 0:
		_blink_state = 0


func _finish_blink() -> void:
	_blink_state = 0
	_double_pending = false
	if visuals != null and is_instance_valid(visuals):
		visuals.texture = _rest_tex
	_next_blink = randf_range(2.2, 6.0)


func _get_attack_move_multiplier() -> float:
	return 0.45


func get_blood_cast_cost() -> int:
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

	anim_player.stop()
	anim_player.play("attack")
	punch_sfx.pitch_scale = randf_range(0.95, 1.08)
	punch_sfx.play()

	await get_tree().create_timer(attack_windup).timeout
	if my_token != _attack_token or is_dead:
		return

	# 1. Pay percentage self-HP cost — STRICTLY LOCKED AT 1 HP MINIMUM!
	var paid_hp := _pay_blood_cost()

	# 2. Launch Returning Liquid Blood Orb Whip!
	_launch_blood_whip(dir, paid_hp)

	var remaining := maxf(attack_duration - attack_windup, 0.08)
	await get_tree().create_timer(remaining).timeout
	if my_token != _attack_token or is_dead:
		return

	is_attacking = false


func _pay_blood_cost() -> int:
	if is_dead:
		return 0
	var desired_cost := get_blood_cast_cost()
	# Never drops below 1 HP — Velmira can NEVER kill herself by attacking!
	var paid := mini(desired_cost, maxi(current_health - 1, 0))
	if paid > 0:
		last_health_change_was_self_cost = true
		current_health -= paid
		health_changed.emit(current_health, max_health)
	return paid


func _launch_blood_whip(dir: Vector2, paid_hp: int) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var whip := BloodWhipOrb.new()
	whip.name = "BloodWhipOrb"
	whip.setup(self, dir, whip_range, whip_duration, attack_damage, paid_hp, heal_per_enemy_hit, EnemyStatusScript)
	parent.add_child(whip)


# =====================================================================
# BAT-SWARM VANISH & REAPPEAR SHIFT!
# =====================================================================

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
	var frame_idx := int(_swarm_time * 18.0) % 3
	var count := _swarm_root.get_child_count()
	for i in range(count):
		var bat := _swarm_root.get_child(i) as Sprite2D
		if bat == null:
			continue
		var phase := _swarm_time * 11.0 + float(i) * 1.25
		var spread_x := -_dash_dir.x * float(i % 3) * 7.5 + cos(phase) * 5.0
		var spread_y := float(i - 2) * 5.2 + sin(phase * 1.3) * 4.5
		bat.position = Vector2(spread_x, spread_y)
		bat.flip_h = _dash_dir.x < -0.05
		if _bat_frames.size() == 3:
			bat.texture = _bat_frames[(frame_idx + i) % 3]


func _on_dash_ended() -> void:
	if _swarm_root != null and is_instance_valid(_swarm_root):
		_swarm_root.queue_free()
	_swarm_root = null
	if visuals != null and not is_dead:
		visuals.visible = true
	_spawn_crimson_mist(global_position)


func _create_bat_swarm() -> void:
	var parent := get_parent()
	if parent == null:
		return
	if _swarm_root != null and is_instance_valid(_swarm_root):
		_swarm_root.queue_free()
	_swarm_root = Node2D.new()
	_swarm_root.name = "VelmiraBatSwarm"
	_swarm_time = 0.0
	parent.add_child(_swarm_root)
	_swarm_root.global_position = global_position

	for i in range(5):
		var bat := Sprite2D.new()
		bat.scale = Vector2(0.85, 0.85)
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
