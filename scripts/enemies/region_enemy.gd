extends CharacterBody2D
class_name RegionEnemy
## Annoying ("ro-mokh") Region 2 & Region 3 Dungeon Monsters (`assets/textures/region_enemies.png`)!
##
## Archetypes:
##   Region 2 (`Cursed Bone Crypt`):
##     - `0` (`CRYPT_STALKER`): **Shadow Blink-Stalker** — Scurries & TELEPORTS behind the player!
##     - `1` (`CRYPT_HEXER`)  : **Necro Hex-Weaver** — Kites backward & fires twin chilling Hex Bolts!
##     - `2` (`CRYPT_PHALANX`): **Undead Bone Phalanx** — Frontal Bone-Shield blocks 65% of front hits!
##   Region 3 (`Infernal Citadel`):
##     - `3` (`CITADEL_IMP`)   : **Hellfire Kamikaze Imp** — Erratic zigzag sprint & explodes on death/touch!
##     - `4` (`CITADEL_SNIPER`): **Void Flame-Sniper** — Aims laser sight & fires 3-way blazing Fireball Volley!
##     - `5` (`CITADEL_BRUTE`) : **Magma Juggernaut** — Unstoppable bull-charge & fiery ground shockwave!

signal died

enum Kind {
	CRYPT_STALKER = 0,
	CRYPT_HEXER = 1,
	CRYPT_PHALANX = 2,
	CITADEL_IMP = 3,
	CITADEL_SNIPER = 4,
	CITADEL_BRUTE = 5,
}

const SHEET_PATH := "res://assets/textures/region_enemies.png"
const ARROW_SCENE := preload("res://scenes/enemies/Arrow.tscn")
const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")

var kind: int = Kind.CRYPT_STALKER
var max_health: int = 55
var current_health: int = 55
var move_speed: float = 82.0
var max_move_speed: float = 175.0
var attack_damage: int = 12
var detection_range: float = 235.0
var shooting_distance: float = 0.0
var slam_trigger_range: float = 0.0

var is_dead: bool = false
var is_elite: bool = false
var visuals: Sprite2D = null

var _frames: Array[AtlasTexture] = []
var _anim_t: float = 0.0
var _action_cd: float = 1.1
var _special_cd: float = 2.0
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_left: float = 0.0
var _aim_windup_left: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT
var _facing: float = 1.0


class MiniHPBar extends Node2D:
	var owner_enemy: RegionEnemy = null

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if owner_enemy == null or owner_enemy.is_dead:
			return
		var ratio := clampf(float(owner_enemy.current_health) / float(maxi(owner_enemy.max_health, 1)), 0.0, 1.0)
		if ratio >= 0.999 and not owner_enemy.is_elite:
			return
		var w := 24.0
		var p := Vector2(-w * 0.5, -26.0)
		draw_rect(Rect2(p, Vector2(w, 3.5)), Color(0.08, 0.04, 0.08, 0.92), true)
		var col := Color(0.68, 0.42, 1.0) if owner_enemy.kind <= 2 else Color(1.0, 0.38, 0.14)
		draw_rect(Rect2(p, Vector2(w * ratio, 3.5)), col, true)


func configure_kind(new_kind: int) -> void:
	kind = clampi(new_kind, 0, 5)
	match kind:
		Kind.CRYPT_STALKER:
			name = "BlinkStalker"
			max_health = 48
			move_speed = 98.0
			attack_damage = 12
			detection_range = 240.0
			_special_cd = 1.8
		Kind.CRYPT_HEXER:
			name = "HexWeaver"
			max_health = 42
			move_speed = 72.0
			attack_damage = 11
			detection_range = 270.0
			shooting_distance = 245.0
			_special_cd = 1.5
		Kind.CRYPT_PHALANX:
			name = "BonePhalanx"
			max_health = 105
			move_speed = 56.0
			attack_damage = 16
			detection_range = 225.0
			slam_trigger_range = 34.0
		Kind.CITADEL_IMP:
			name = "HellfireImp"
			max_health = 46
			move_speed = 124.0
			attack_damage = 16
			detection_range = 255.0
		Kind.CITADEL_SNIPER:
			name = "VoidFlameSniper"
			max_health = 54
			move_speed = 76.0
			attack_damage = 15
			detection_range = 290.0
			shooting_distance = 275.0
			_special_cd = 1.6
		Kind.CITADEL_BRUTE:
			name = "MagmaJuggernaut"
			max_health = 135
			move_speed = 64.0
			attack_damage = 22
			detection_range = 245.0
			slam_trigger_range = 42.0
			_special_cd = 2.4
	current_health = max_health


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 5

	var body_cs := CollisionShape2D.new()
	var body_cir := CircleShape2D.new()
	body_cir.radius = 9.0
	body_cs.shape = body_cir
	add_child(body_cs)

	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var hb_cs := CollisionShape2D.new()
	var hb_rect := RectangleShape2D.new()
	hb_rect.size = Vector2(20.0, 22.0)
	hb_cs.shape = hb_rect
	hb_cs.position = Vector2(0.0, -6.0)
	hurtbox.add_child(hb_cs)
	add_child(hurtbox)

	visuals = Sprite2D.new()
	visuals.name = "Visuals"
	visuals.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visuals.position = Vector2(0.0, -10.0)
	visuals.scale = Vector2(0.65, 0.65)
	add_child(visuals)

	if ResourceLoader.exists(SHEET_PATH):
		var sheet: Texture2D = load(SHEET_PATH)
		if sheet != null:
			for i in range(8):
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(float(i * 48), 0.0, 48.0, 48.0)
				_frames.append(at)
	_apply_sprite_frame()

	var hp_bar := MiniHPBar.new()
	hp_bar.owner_enemy = self
	add_child(hp_bar)


func _apply_sprite_frame() -> void:
	if visuals == null or _frames.size() < 7:
		return
	var fidx := 0
	match kind:
		Kind.CRYPT_STALKER:
			fidx = int(_anim_t * 6.0) % 2
		Kind.CRYPT_HEXER:
			fidx = 2
		Kind.CRYPT_PHALANX:
			fidx = 3
		Kind.CITADEL_IMP:
			fidx = 4
		Kind.CITADEL_SNIPER:
			fidx = 5
		Kind.CITADEL_BRUTE:
			fidx = 6
	visuals.texture = _frames[fidx]


func become_elite() -> void:
	if is_elite:
		return
	is_elite = true
	max_health = int(roundf(float(max_health) * 2.4))
	current_health = max_health
	attack_damage = int(roundf(float(attack_damage) * 1.45))
	if visuals != null:
		visuals.modulate = Color(1.22, 1.05, 0.78)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_anim_t += delta
	_apply_sprite_frame()
	if _action_cd > 0.0:
		_action_cd = maxf(_action_cd - delta, 0.0)
	if _special_cd > 0.0:
		_special_cd = maxf(_special_cd - delta, 0.0)

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
	if dist > detection_range:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir := to_player.normalized() if dist > 0.5 else Vector2.RIGHT
	if absf(dir.x) > 0.05:
		_facing = 1.0 if dir.x >= 0.0 else -1.0
		if visuals != null:
			visuals.flip_h = (_facing < 0.0)

	var slow_m := EnemyStatusScript.get_slow_multiplier(self)
	var eff_spd := move_speed * slow_m

	if _charge_left > 0.0:
		_charge_left -= delta
		velocity = _charge_dir * (eff_spd * 2.55)
		move_and_slide()
		if dist <= 24.0 and _action_cd <= 0.0:
			_action_cd = 0.9
			player.take_damage(attack_damage, global_position, false)
		queue_redraw()
		return

	if _aim_windup_left > 0.0:
		_aim_windup_left -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		if _aim_windup_left <= 0.0:
			_fire_sniper_volley(_aim_dir)
		return

	match kind:
		Kind.CRYPT_STALKER:
			# Annoying Blink-Behind Teleport!
			if _special_cd <= 0.0 and dist > 48.0 and dist < 220.0:
				_special_cd = 2.8
				_blink_behind_player(player, dir)
				return
			velocity = dir * eff_spd
			move_and_slide()
			if dist <= 22.0 and _action_cd <= 0.0:
				_action_cd = 0.75
				player.take_damage(attack_damage, global_position, false)

		Kind.CRYPT_HEXER:
			# Annoying Kiting Mage: retreats when player gets close, fires twin chilling hex bolts!
			if dist < 115.0:
				velocity = -dir * (eff_spd * 0.95)
			elif dist > 195.0:
				velocity = dir * eff_spd
			else:
				velocity = Vector2(-dir.y, dir.x) * (eff_spd * 0.55)
			move_and_slide()
			if _special_cd <= 0.0 and dist <= shooting_distance:
				_special_cd = 1.95
				_fire_hex_spread(dir)

		Kind.CRYPT_PHALANX:
			velocity = dir * eff_spd
			move_and_slide()
			if dist <= 25.0 and _action_cd <= 0.0:
				_action_cd = 1.05
				player.take_damage(attack_damage, global_position, false)
			queue_redraw()

		Kind.CITADEL_IMP:
			# Erratic zigzag sprint + suicide kamikaze blast!
			var perp := Vector2(-dir.y, dir.x) * sin(_anim_t * 11.0) * 0.65
			velocity = (dir + perp).normalized() * eff_spd
			move_and_slide()
			if dist <= 22.0:
				_detonate_hellfire_blast(player)
				take_damage(current_health + 999)

		Kind.CITADEL_SNIPER:
			if dist < 130.0:
				velocity = -dir * eff_spd
				move_and_slide()
			elif _special_cd <= 0.0 and dist <= shooting_distance:
				_special_cd = 2.3
				_aim_dir = dir
				_aim_windup_left = 0.48
				queue_redraw()
			else:
				velocity = dir * (eff_spd * 0.75)
				move_and_slide()

		Kind.CITADEL_BRUTE:
			if _special_cd <= 0.0 and dist > 55.0 and dist <= 210.0:
				_special_cd = 3.1
				_charge_dir = dir
				_charge_left = 0.46
				return
			velocity = dir * eff_spd
			move_and_slide()
			if dist <= 26.0 and _action_cd <= 0.0:
				_action_cd = 1.1
				player.take_damage(attack_damage, global_position, false)


func _blink_behind_player(player: Node2D, dir: Vector2) -> void:
	_spawn_ring(global_position, Color(0.68, 0.36, 1.0, 0.90))
	var candidate := player.global_position + dir * 42.0
	candidate.x = clampf(candidate.x, 56.0, 1224.0)
	candidate.y = clampf(candidate.y, 56.0, 664.0)
	global_position = candidate
	_spawn_ring(global_position, Color(0.45, 0.92, 1.0, 0.92))


func _fire_hex_spread(dir: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	for deg in [-11.0, 11.0]:
		var arrow := ARROW_SCENE.instantiate()
		var sdir := dir.rotated(deg_to_rad(deg))
		arrow.speed = 215.0
		arrow.slow_player_duration = 1.35
		arrow.puff_color = Color(0.66, 0.36, 1.0)
		arrow.modulate = Color(0.75, 0.45, 1.25)
		parent.add_child(arrow)
		arrow.launch(global_position + sdir * 12.0, sdir, attack_damage)


func _fire_sniper_volley(dir: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	for deg in [-14.0, 0.0, 14.0]:
		var arrow := ARROW_SCENE.instantiate()
		var sdir := dir.rotated(deg_to_rad(deg))
		arrow.speed = 275.0
		arrow.puff_color = Color(1.0, 0.38, 0.12)
		arrow.modulate = Color(1.3, 0.52, 0.20)
		parent.add_child(arrow)
		arrow.launch(global_position + sdir * 14.0, sdir, attack_damage)


func _detonate_hellfire_blast(player: Node2D) -> void:
	_spawn_ring(global_position, Color(1.0, 0.34, 0.08, 0.96))
	if player != null and is_instance_valid(player) and player.get("is_dead") != true:
		if player.global_position.distance_to(global_position) <= 56.0:
			player.take_damage(attack_damage, global_position, false)


func _spawn_ring(at: Vector2, col: Color) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ring := Line2D.new()
	ring.width = 2.2
	ring.default_color = col
	var pts := PackedVector2Array()
	for i in range(17):
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * 14.0)
	ring.points = pts
	parent.add_child(ring)
	ring.global_position = at
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.20)
	tw.tween_property(ring, "modulate:a", 0.0, 0.20)
	tw.chain().tween_callback(ring.queue_free)


func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	var final_dmg := amount
	# Bone Phalanx frontal shield reduces non-stunned frontal hits by 65%!
	if kind == Kind.CRYPT_PHALANX and not EnemyStatusScript.is_stunned(self) and amount < 999999:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and is_instance_valid(player):
			var from_front: bool = ((player.global_position.x - global_position.x) * _facing >= -4.0)
			if from_front:
				final_dmg = maxi(int(roundf(float(amount) * 0.35)), 1)

	current_health = maxi(current_health - final_dmg, 0)
	if visuals != null:
		visuals.modulate = Color(1.8, 0.55, 0.55)
		var tw := create_tween()
		tw.tween_property(visuals, "modulate", Color(1.22, 1.05, 0.78) if is_elite else Color.WHITE, 0.12)

	if current_health <= 0:
		_die()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	if kind == Kind.CITADEL_IMP:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		_detonate_hellfire_blast(p)
	died.emit()
	queue_free()


func _draw() -> void:
	if _aim_windup_left > 0.0:
		draw_line(Vector2(0, -8), _aim_dir * 240.0, Color(1.0, 0.24, 0.12, 0.80), 1.4)
	elif kind == Kind.CRYPT_PHALANX and not EnemyStatusScript.is_stunned(self):
		var sx := 10.0 * _facing
		draw_arc(Vector2(sx, -6.0), 11.0, -0.9 if _facing > 0.0 else PI - 0.9, 0.9 if _facing > 0.0 else PI + 0.9, 10, Color(0.56, 0.88, 1.0, 0.72), 2.2)
