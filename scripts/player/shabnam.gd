extends PlayerBase
## Velmira - the Royal Crimson Vampire (Hero 4 of 4).
##
## Built faithfully from the canonical 1536x1024 Vampire reference sheet:
##   - 75 HP (lowest HP), 104 Move Speed (grounded boots in all 4 directions:
##     `idle`/`walk`, `idle_down`/`walk_down`, `idle_up`/`walk_up` — ZERO floating!).
##   - **Crimson Blood-Splash Slash (`attack` & `attack_splash` — NO yoyo!)**:
##       1. Costs `6%` Max HP (`5 HP`), **STRICTLY LOCKED AT `1 HP` FLOOR** (never
##          self-kills by attacking — only enemy hits can kill her!).
##       2. Unleashes a wide sweeping **Reference Crimson Blood-Splash Arc** in
##          her aim direction (`92 px` reach), splashing all enemies in the arc
##          and healing **`paid_hp + 1 * hits_landed`** (`+1 HP` net on 1 foe,
##          more on multi-hit, `0` on miss)!
##   - **2-Fang + Reference Ground Blood Fountain (`30%` Max HP)**:
##       * Every 4th Blood-Splash hit on a foe erupts a massive **Crimson Blood
##         Fountain** from beneath them for **`30%` of enemy Max HP** + `+4 HP` heal!
##   - **Classic Bat-Swarm Vanish (`Shift`)**:
##       * Velmira vanishes (`visuals.visible = false`) in crimson mist while
##         **5 crisp flapping pixel-art Vampire Bats** fly to the destination!
##   - **8-Frame Blood-Pool Dissolution Death (`die`)**:
##       * Collapses to her knees and melts into a swirling crimson blood pool!

const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")
const BAT_SHEET_PATH := "res://assets/textures/crimson_bat.png"
const FX_SHEET_PATH := "res://assets/textures/velmira_fx.png"

@export var splash_range: float = 92.0
@export var splash_cone_dot: float = 0.22
@export var blood_self_cost_ratio: float = 0.06
@export var heal_per_enemy_hit: int = 1

var _combo_idx: int = 0
var _bat_frames: Array[AtlasTexture] = []
var _fx_frames: Array[AtlasTexture] = []
var _swarm_root: Node2D = null
var _swarm_time: float = 0.0


## 100% Hand-Crafted Directional Crimson Blood-Splash Slash VFX!
class BloodSplashSlash extends Node2D:
	var aim_dir: Vector2 = Vector2.RIGHT
	var reach: float = 92.0
	var is_nova_finisher: bool = false
	var anim_frames: Array[Texture2D] = []
	var elapsed: float = 0.0
	var duration: float = 0.25
	var _sprite: Sprite2D = null

	func setup(dir: Vector2, max_r: float, nova: bool, frames_seq: Array[Texture2D]) -> void:
		aim_dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
		reach = max_r
		is_nova_finisher = nova
		anim_frames = frames_seq
		rotation = aim_dir.angle()
		z_index = 4

		if not anim_frames.is_empty():
			_sprite = Sprite2D.new()
			_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_sprite.texture = anim_frames[0]
			_sprite.position = Vector2(reach * (0.34 if nova else 0.36), 0.0)
			var base_s := 0.50 if nova else 0.44
			_sprite.scale = Vector2(base_s * 0.86, base_s * 0.86)
			add_child(_sprite)
			var tw := _sprite.create_tween()
			tw.set_parallel(true)
			tw.tween_property(_sprite, "scale", Vector2(base_s * 1.08, base_s * 1.06), duration * 0.70)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(_sprite, "modulate:a", 0.0, duration * 0.36).set_delay(duration * 0.64)

	func _process(delta: float) -> void:
		elapsed += delta
		var p := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
		if _sprite != null and anim_frames.size() >= 3:
			var idx := 0 if p < 0.26 else (1 if p < 0.68 else 2)
			_sprite.texture = anim_frames[idx]
		queue_redraw()
		if elapsed >= duration:
			queue_free()

	func _draw_tapered_crescent(
		center: Vector2,
		radius: float,
		a0: float,
		a1: float,
		max_thick: float,
		col: Color
	) -> void:
		var segs := 18
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in range(segs + 1):
			var t := float(i) / float(segs)
			var ang := lerpf(a0, a1, t)
			var half_w := max_thick * 0.5 * sin(t * PI)
			var dir_v := Vector2(cos(ang), sin(ang))
			outer.append(center + dir_v * (radius + half_w))
			inner.append(center + dir_v * maxf(2.0, radius - half_w))
		var poly := PackedVector2Array()
		for pt in outer:
			poly.append(pt)
		for i in range(inner.size() - 1, -1, -1):
			poly.append(inner[i])
		if poly.size() >= 6:
			draw_colored_polygon(poly, col)

	func _draw() -> void:
		var p := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
		var alpha := (1.0 - p * p) * 0.86
		var sweep_r := lerpf(reach * 0.52, reach * 0.90, sin(p * PI * 0.5))
		var half_ang := 1.12 if is_nova_finisher else 0.96
		var origin := Vector2(10.0, 0.0)

		# Needle-tapered crimson crescent glow & razor ruby core (never blunt line caps!)
		_draw_tapered_crescent(origin, sweep_r, -half_ang, half_ang,
			7.0 * (1.0 - p * 0.45), Color(0.42, 0.03, 0.11, alpha * 0.72))
		_draw_tapered_crescent(origin, sweep_r + 1.0, -half_ang * 0.88, half_ang * 0.88,
			3.4 * (1.0 - p * 0.35), Color(0.94, 0.10, 0.28, alpha * 0.85))
		_draw_tapered_crescent(origin, sweep_r + 1.8, -half_ang * 0.65, half_ang * 0.65,
			1.5 * (1.0 - p * 0.30), Color(1.0, 0.72, 0.80, alpha * 0.82))

		# Crisp flying blood droplets radiating forward
		for i in range(6):
			var frac := -0.78 + 1.56 * (float(i) / 5.0)
			var ang := frac * half_ang
			var dr := sweep_r + 5.0 + p * (13.0 + float(i % 3) * 4.5)
			var dp := origin + Vector2(cos(ang) * dr, sin(ang) * dr)
			draw_circle(dp, maxf(0.8, 2.1 - p * 1.1), Color(0.92, 0.08, 0.25, alpha))


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


func _exit_tree() -> void:
	_cleanup_bat_swarm()
	super._exit_tree()


func _get_attack_move_multiplier() -> float:
	return 0.42


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

	# 1. Pay percentage self-HP cost — STRICTLY LOCKED AT 1 HP FLOOR!
	var paid_hp := _pay_blood_cost()

	# 2. Unleash Reference Crimson Blood-Splash Cleave (NO yoyo!) & drain blood!
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
		fx.name = "VelmiraBloodSplash"
		var seq: Array[Texture2D] = []
		if _fx_frames.size() >= 5:
			if is_nova:
				seq = [_fx_frames[3], _fx_frames[4], _fx_frames[2]]
			else:
				seq = [_fx_frames[0], _fx_frames[1], _fx_frames[2]]
		elif not _fx_frames.is_empty():
			seq = [_fx_frames[0]]
		fx.setup(aim, splash_range, is_nova, seq)
		parent.add_child(fx)
		fx.global_position = global_position + Vector2(0.0, -3.0)

	var hits_landed := 0
	var origin := global_position
	var eff_range := splash_range * (1.08 if is_nova else 1.0)
	var min_dot := -0.15 if is_nova else splash_cone_dot

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
		deal_combat_damage(node, attack_damage, false, 9.0, origin)
		EnemyStatusScript.add_vampire_fang_stack(node, self)

	if hits_landed > 0:
		var total_heal := paid_hp + heal_per_enemy_hit * hits_landed
		if total_heal > 0:
			heal(total_heal)


func _die() -> void:
	super._die()


# =====================================================================
# CLASSIC BAT-SWARM VANISH & REAPPEAR SHIFT!
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
	_swarm_root.name = "VelmiraBatSwarm"
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
