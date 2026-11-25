extends Node2D
## Knight's `[R]` Ultimate Ability: **Royal War Banner + Allied Crusader Knight**!
##
## Specs:
##   - Plants the Royal Lion War Banner at Knight's position (`region_enemies.png` frame 7).
##   - Summons **1 Allied Knight** (`player_knight.png` animated 64x64 sprite) who chases
##     and slashes nearby enemies alongside the player!
##   - Duration: **7.0 seconds** (`duration knight 7 sec`), Cooldown: **60.0 seconds (`1 min`)**.

const BANNER_SHEET_PATH := "res://assets/textures/region_enemies.png"
const KNIGHT_SHEET_PATH := "res://assets/textures/player_knight.png"

var owner_knight: PlayerBase = null
var duration: float = 7.0
var slash_damage: int = 32
var move_speed: float = 138.0
var slash_interval: float = 0.44

var _elapsed: float = 0.0
var _slash_timer: float = 0.1
var _ally_node: Node2D = null
var _ally_sprite: Sprite2D = null
var _knight_frames: Array[AtlasTexture] = []
var _slash_anim_left: float = 0.0


func setup(summoner: PlayerBase, dur: float = 7.0) -> void:
	owner_knight = summoner
	duration = dur
	if summoner != null:
		slash_damage = maxi(int(roundf(float(summoner.attack_damage) * 0.90)), 24)
	add_to_group("knight_war_banners")


func _ready() -> void:
	z_index = 2
	if ResourceLoader.exists(BANNER_SHEET_PATH):
		var btex: Texture2D = load(BANNER_SHEET_PATH)
		if btex != null:
			var banner_sp := Sprite2D.new()
			banner_sp.name = "WarBannerSprite"
			banner_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var at := AtlasTexture.new()
			at.atlas = btex
			at.region = Rect2(7.0 * 48.0, 0.0, 48.0, 48.0)
			banner_sp.texture = at
			banner_sp.offset = Vector2(0.0, -18.0)
			banner_sp.scale = Vector2(0.85, 0.85)
			add_child(banner_sp)

			banner_sp.scale = Vector2(0.2, 1.3)
			var tw := banner_sp.create_tween()
			tw.tween_property(banner_sp, "scale", Vector2(0.85, 0.85), 0.22)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if ResourceLoader.exists(KNIGHT_SHEET_PATH):
		var ktex: Texture2D = load(KNIGHT_SHEET_PATH)
		if ktex != null:
			for i in range(16):
				var kat := AtlasTexture.new()
				kat.atlas = ktex
				kat.region = Rect2(float(i * 64), 0.0, 64.0, 64.0)
				_knight_frames.append(kat)

	_ally_node = Node2D.new()
	_ally_node.name = "AlliedKnight"
	_ally_node.add_to_group("allied_knights")
	_ally_node.position = Vector2(22.0, 6.0)
	add_child(_ally_node)

	_ally_sprite = Sprite2D.new()
	_ally_sprite.name = "Visuals"
	_ally_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ally_sprite.position = Vector2(0.0, -11.0)
	_ally_sprite.scale = Vector2(0.5, 0.5)
	_ally_sprite.modulate = Color(0.82, 0.96, 1.15, 0.98)
	if not _knight_frames.is_empty():
		_ally_sprite.texture = _knight_frames[0]
	_ally_node.add_child(_ally_sprite)


func get_allied_knight_node() -> Node2D:
	return _ally_node


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return

	if _slash_anim_left > 0.0:
		_slash_anim_left = maxf(_slash_anim_left - delta, 0.0)
	_slash_timer = maxf(_slash_timer - delta, 0.0)

	if _ally_node != null and is_instance_valid(_ally_node):
		var target := _find_nearest_enemy(_ally_node.global_position)
		if target != null:
			var to_foe := target.global_position - _ally_node.global_position
			var dist := to_foe.length()
			var dir := to_foe.normalized() if dist > 0.5 else Vector2.RIGHT
			if _ally_sprite != null:
				_ally_sprite.scale.x = 0.5 if dir.x >= 0.0 else -0.5

			if dist > 26.0:
				_ally_node.global_position += dir * move_speed * delta
				if _ally_sprite != null and _knight_frames.size() >= 3 and _slash_anim_left <= 0.0:
					var wframe := 1 + (int(_elapsed * 9.0) % 2)
					_ally_sprite.texture = _knight_frames[wframe]
			else:
				if _slash_timer <= 0.0:
					_slash_timer = slash_interval
					_slash_anim_left = 0.22
					_perform_ally_slash(target, dir)
		else:
			# Guard near the banner when arena is clear
			var home := global_position + Vector2(22.0, 6.0)
			if _ally_node.global_position.distance_to(home) > 10.0:
				var back_dir := (home - _ally_node.global_position).normalized()
				_ally_node.global_position += back_dir * (move_speed * 0.75) * delta
			elif _ally_sprite != null and not _knight_frames.is_empty() and _slash_anim_left <= 0.0:
				_ally_sprite.texture = _knight_frames[0]

		if _slash_anim_left > 0.0 and _ally_sprite != null and _knight_frames.size() >= 6:
			_ally_sprite.texture = _knight_frames[4 if _slash_anim_left > 0.11 else 5]

	queue_redraw()


func _perform_ally_slash(target: Node2D, dir: Vector2) -> void:
	var origin := _ally_node.global_position
	var arc := Line2D.new()
	arc.width = 3.0
	arc.default_color = Color(0.55, 0.90, 1.0, 0.95)
	var pts := PackedVector2Array()
	var base_a := dir.angle()
	for i in range(11):
		var a := base_a + lerpf(-1.1, 1.1, float(i) / 10.0)
		pts.append(Vector2(cos(a), sin(a)) * 24.0)
	arc.points = pts
	if get_parent() != null:
		get_parent().add_child(arc)
		arc.global_position = origin
		var tw := arc.create_tween()
		tw.tween_property(arc, "modulate:a", 0.0, 0.16)
		tw.tween_callback(arc.queue_free)

	# Cleave target + any adjacent enemy within sword reach
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == null or not is_instance_valid(n) or not (n is Node2D):
			continue
		if n.get("is_dead") == true or not (n as Node2D).visible:
			continue
		if (n as Node2D).global_position.distance_to(origin) <= 44.0 or n == target:
			if owner_knight != null and is_instance_valid(owner_knight):
				owner_knight.deal_combat_damage(n, slash_damage, false, 8.0, (n as Node2D).global_position)
			elif n.has_method("take_damage"):
				n.take_damage(slash_damage)


func _find_nearest_enemy(from_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := 520.0
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == null or not is_instance_valid(n) or not (n is Node2D):
			continue
		if n.is_in_group("training_dummy") and get_tree().get_nodes_in_group("enemies").size() > 1:
			continue
		if n.get("is_dead") == true or not (n as Node2D).visible:
			continue
		var d := from_pos.distance_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n as Node2D
	return best


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_elapsed * 7.0)
	var rem_ratio := clampf(1.0 - (_elapsed / maxf(duration, 0.1)), 0.0, 1.0)
	draw_arc(Vector2.ZERO, 32.0 + pulse * 2.0, 0.0, TAU, 32, Color(0.36, 0.76, 1.0, 0.34), 1.8)
	draw_arc(Vector2.ZERO, 26.0, -PI * 0.5, -PI * 0.5 + TAU * rem_ratio, 28, Color(1.0, 0.86, 0.36, 0.85), 2.2)
