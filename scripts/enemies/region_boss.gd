extends CharacterBody2D
class_name RegionBoss
## Region 2 & Region 3 Bosses (`assets/textures/region_bosses.png`, `64x64`):
##   - Region 2 Boss (`boss_region_id = 2`): **Malakor, Arch-Lich**
##       * Teleports across the Crypt, fires 8-way Cursed Hex Novas, erupts Soul Sigils
##         under the player, and summons Blink-Stalker minions!
##   - Region 3 Boss (`boss_region_id = 3`): **Igniszar, Dreadlord**
##       * Calls down 4-Crater Meteor Hellstorms, fires rotating Hellfire Spirals,
##         bull-charges across the Citadel, and summons Hellfire Imps!

signal died
signal boss_defeated(region_id: int)

const SHEET_PATH := "res://assets/textures/region_bosses.png"
const ARROW_SCENE := preload("res://scenes/enemies/Arrow.tscn")
const RegionEnemyScript := preload("res://scripts/enemies/region_enemy.gd")
const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")

var boss_region_id: int = 2
var boss_title: String = "Malakor, Arch-Lich"
var max_health: int = 650
var current_health: int = 650
var move_speed: float = 58.0
var max_move_speed: float = 135.0
var attack_damage: int = 22
var detection_range: float = 2500.0

var is_dead: bool = false
var is_enraged: bool = false
var visuals: Sprite2D = null

var _frames: Array[AtlasTexture] = []
var _anim_t: float = 0.0
var _pattern_timer: float = 1.6
var _pattern_step: int = 0
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_left: float = 0.0
var _contact_cd: float = 0.0


class BossOverheadBar extends Node2D:
	var boss_owner: RegionBoss = null

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if boss_owner == null or boss_owner.is_dead:
			return
		var bar_size := Vector2(64.0, 6.0)
		var pos := Vector2(-bar_size.x * 0.5, -42.0)
		var ratio := clampf(float(boss_owner.current_health) / float(maxi(boss_owner.max_health, 1)), 0.0, 1.0)
		draw_rect(Rect2(pos - Vector2(1, 1), bar_size + Vector2(2, 2)), Color(0.04, 0.02, 0.06, 0.96), true)
		var fill_col := Color(0.72, 0.36, 1.0) if boss_owner.boss_region_id == 2 else Color(1.0, 0.34, 0.12)
		if boss_owner.is_enraged:
			fill_col = Color(1.0, 0.18, 0.32)
		draw_rect(Rect2(pos, Vector2(bar_size.x * ratio, bar_size.y)), fill_col, true)
		var font := ThemeDB.fallback_font
		if font != null:
			draw_string(font, Vector2(-64.0, -46.0), boss_owner.boss_title, HORIZONTAL_ALIGNMENT_CENTER, 128.0, 7, Color(1.0, 0.92, 0.62))


func configure_for_region(region_id: int) -> void:
	boss_region_id = clampi(region_id, 2, 3)
	if boss_region_id == 2:
		boss_title = "Malakor, Arch-Lich"
		name = "MalakorArchLich"
		max_health = 650
		move_speed = 58.0
		attack_damage = 20
	else:
		boss_title = "Igniszar, Dreadlord"
		name = "IgniszarDreadlord"
		max_health = 950
		move_speed = 68.0
		attack_damage = 28
	current_health = max_health


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 5

	var body_cs := CollisionShape2D.new()
	var body_cir := CircleShape2D.new()
	body_cir.radius = 15.0
	body_cs.shape = body_cir
	add_child(body_cs)

	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var hb_cs := CollisionShape2D.new()
	var hb_rect := RectangleShape2D.new()
	hb_rect.size = Vector2(34.0, 38.0)
	hb_cs.shape = hb_rect
	hb_cs.position = Vector2(0.0, -10.0)
	hurtbox.add_child(hb_cs)
	add_child(hurtbox)

	visuals = Sprite2D.new()
	visuals.name = "Visuals"
	visuals.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visuals.position = Vector2(0.0, -14.0)
	visuals.scale = Vector2(0.85, 0.85)
	add_child(visuals)

	if ResourceLoader.exists(SHEET_PATH):
		var sheet: Texture2D = load(SHEET_PATH)
		if sheet != null:
			for i in range(4):
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(float(i * 64), 0.0, 64.0, 64.0)
				_frames.append(at)
	_apply_boss_frame(false)

	var bar := BossOverheadBar.new()
	bar.boss_owner = self
	add_child(bar)


func _apply_boss_frame(casting: bool) -> void:
	if visuals == null or _frames.size() < 4:
		return
	var base_idx := 0 if boss_region_id == 2 else 2
	visuals.texture = _frames[base_idx + (1 if casting else 0)]


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_anim_t += delta
	if _contact_cd > 0.0:
		_contact_cd = maxf(_contact_cd - delta, 0.0)

	if EnemyStatusScript.is_stunned(self):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not is_instance_valid(player) or player.get("is_dead") == true:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized() if dist > 0.5 else Vector2.RIGHT
	if visuals != null and absf(dir.x) > 0.05:
		visuals.flip_h = (dir.x < 0.0)

	var slow_m := EnemyStatusScript.get_slow_multiplier(self)
	var enrage_m := 1.32 if is_enraged else 1.0

	if _charge_left > 0.0:
		_charge_left -= delta
		_apply_boss_frame(true)
		velocity = _charge_dir * (move_speed * 3.1 * slow_m * enrage_m)
		move_and_slide()
		if dist <= 32.0 and _contact_cd <= 0.0:
			_contact_cd = 0.75
			player.take_damage(attack_damage, global_position, false)
		return

	_apply_boss_frame(false)
	if boss_region_id == 2 and dist < 130.0:
		velocity = -dir * (move_speed * 0.75 * slow_m)
	else:
		velocity = dir * (move_speed * slow_m * enrage_m)
	move_and_slide()

	if dist <= 28.0 and _contact_cd <= 0.0:
		_contact_cd = 0.9
		player.take_damage(attack_damage, global_position, false)

	_pattern_timer -= delta * enrage_m
	if _pattern_timer <= 0.0:
		_pattern_timer = 2.1 if boss_region_id == 2 else 1.9
		_execute_next_boss_pattern(player, dir)


func _execute_next_boss_pattern(player: Node2D, dir: Vector2) -> void:
	_apply_boss_frame(true)
	var step := _pattern_step % 3
	_pattern_step += 1

	if boss_region_id == 2:
		match step:
			0:
				# 8-Way Cursed Orb Ring!
				var parent := get_parent()
				if parent != null:
					var count := 10 if is_enraged else 8
					for i in range(count):
						var a := TAU * float(i) / float(count) + _anim_t
						var sdir := Vector2(cos(a), sin(a))
						var bolt := ARROW_SCENE.instantiate()
						bolt.speed = 205.0
						bolt.slow_player_duration = 1.2
						bolt.puff_color = Color(0.68, 0.36, 1.0)
						bolt.modulate = Color(0.76, 0.44, 1.3)
						parent.add_child(bolt)
						bolt.launch(global_position + sdir * 18.0, sdir, attack_damage)
			1:
				# Teleport across Crypt + Soul Drain Sigil under player!
				var blink_pos := Vector2(
					clampf(player.global_position.x + randf_range(-190.0, 190.0), 96.0, 1184.0),
					clampf(player.global_position.y + randf_range(-150.0, 150.0), 96.0, 624.0)
				)
				global_position = blink_pos
				_spawn_delayed_hazard_crater(player.global_position, 54.0, Color(0.68, 0.32, 1.0, 0.90))
			_:
				# Summon annoying Blink-Stalker!
				_summon_boss_minion(RegionEnemyScript.Kind.CRYPT_STALKER)
	else:
		match step:
			0:
				# Infernal Dreadlord Bull-Charge + 10-way Fireball Nova!
				_charge_dir = dir
				_charge_left = 0.55
				var parent2 := get_parent()
				if parent2 != null:
					var count2 := 12 if is_enraged else 8
					for i in range(count2):
						var a2 := TAU * float(i) / float(count2)
						var sdir2 := Vector2(cos(a2), sin(a2))
						var fball := ARROW_SCENE.instantiate()
						fball.speed = 245.0
						fball.puff_color = Color(1.0, 0.36, 0.10)
						fball.modulate = Color(1.35, 0.50, 0.18)
						parent2.add_child(fball)
						fball.launch(global_position + sdir2 * 20.0, sdir2, attack_damage)
			1:
				# 3-Crater Meteor Hellstorm around the player!
				for k in range(3):
					var offset := Vector2.ZERO if k == 0 else Vector2(randf_range(-85.0, 85.0), randf_range(-75.0, 75.0))
					_spawn_delayed_hazard_crater(player.global_position + offset, 58.0, Color(1.0, 0.36, 0.10, 0.92))
			_:
				_summon_boss_minion(RegionEnemyScript.Kind.CITADEL_IMP)


func _spawn_delayed_hazard_crater(world_pos: Vector2, rad: float, col: Color) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var warn := Line2D.new()
	warn.width = 2.4
	warn.default_color = col
	var pts := PackedVector2Array()
	for i in range(21):
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a), sin(a)) * rad)
	warn.points = pts
	parent.add_child(warn)
	warn.global_position = world_pos

	await get_tree().create_timer(0.80).timeout
	if not is_instance_valid(warn):
		return
	warn.queue_free()
	if not is_inside_tree() or is_dead:
		return
	ScreenShake.shake(3.5, 0.16)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player) and player.get("is_dead") != true:
		if player.global_position.distance_to(world_pos) <= rad:
			player.take_damage(attack_damage, world_pos, false)


func _summon_boss_minion(minion_kind: int) -> void:
	var parent := get_parent()
	if parent == null:
		return
	# Cap active boss summons so arena stays fair
	var active_cnt := 0
	for ch in parent.get_children():
		if ch is RegionEnemy and ch.get("is_dead") != true:
			active_cnt += 1
	if active_cnt >= 4:
		return
	var m := RegionEnemyScript.new()
	m.configure_kind(minion_kind)
	m.max_health = maxi(int(roundf(float(max_health) * 0.08)), 36)
	m.current_health = m.max_health
	m.detection_range = 2500.0
	parent.add_child(m)
	m.global_position = global_position + Vector2(randf_range(-42.0, 42.0), randf_range(-36.0, 36.0))


func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_health = maxi(current_health - amount, 0)
	if not is_enraged and float(current_health) <= float(max_health) * 0.35:
		is_enraged = true
		ScreenShake.shake(5.0, 0.25)

	if visuals != null:
		visuals.modulate = Color(1.85, 0.55, 0.55)
		var tw := create_tween()
		tw.tween_property(visuals, "modulate", Color(1.22, 0.82, 0.88) if is_enraged else Color.WHITE, 0.12)

	if current_health <= 0:
		_die()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	ScreenShake.shake(7.0, 0.35)
	boss_defeated.emit(boss_region_id)
	died.emit()
	queue_free()
