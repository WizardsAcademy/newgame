extends Control
class_name MiniMap
## Tactical Top-Right Mini-Map (`128x72`, 1:10 scale of `1280x720` arena).
##
## Rules:
##   - Shows Arena walls, obstacles, and our Player marker (NO camera box!).
##   - Fog-of-Proximity enemy tracking:
##       * Distant enemies (`distance > enemy_reveal_distance`) DO NOT reveal
##         their exact spot on the map — instead, a crisp directional arrow
##         (`➔`) orbits the player pointing in the direction of the enemy!
##       * Nearby enemies (`distance <= enemy_reveal_distance`) reveal their
##         exact map position and enemy type!

@export var world_size: Vector2 = Vector2(1280.0, 720.0)
@export var map_size: Vector2 = Vector2(128.0, 72.0)
@export var top_right_margin: Vector2 = Vector2(10.0, 8.0)
@export var enemy_reveal_distance: float = 210.0
@export var arrow_orbit_radius: float = 12.5

var player_ref: Node2D = null
var level_ref: Node2D = null
var player_accent: Color = Color(0.32, 1.0, 0.68)
var is_in_menu: bool = false
var last_enemy_count: int = 0

var _obstacle_rects: Array[Rect2] = []
var _pulse_time: float = 0.0
var _caption: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_caption = Label.new()
	_caption.name = "Caption"
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_caption.add_theme_font_size_override("font_size", 8)
	_caption.add_theme_color_override("font_color", Color(0.84, 0.90, 0.96, 0.95))
	_caption.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	_caption.add_theme_constant_override("outline_size", 2)
	_caption.position = Vector2(0.0, map_size.y + 2.0)
	_caption.size = Vector2(map_size.x, 12.0)
	add_child(_caption)

	if not get_viewport().size_changed.is_connected(_relayout):
		get_viewport().size_changed.connect(_relayout)
	_relayout()


func _relayout() -> void:
	var vp := get_viewport_rect().size
	position = Vector2(vp.x - map_size.x - top_right_margin.x, top_right_margin.y)
	size = Vector2(map_size.x, map_size.y + 14.0)


func set_arena_refs(level_node: Node2D, player_node: Node2D) -> void:
	level_ref = level_node
	player_ref = player_node
	_scan_obstacles()
	queue_redraw()


func set_player_accent(color: Color) -> void:
	player_accent = color
	queue_redraw()


func _scan_obstacles() -> void:
	_obstacle_rects.clear()
	if level_ref == null or not is_instance_valid(level_ref):
		return
	for child in level_ref.get_children():
		if child is StaticBody2D and String(child.name).begins_with("Obstacle"):
			var body := child as StaticBody2D
			var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if shape_node != null and shape_node.shape is RectangleShape2D:
				var sz: Vector2 = (shape_node.shape as RectangleShape2D).size
				_obstacle_rects.append(Rect2(body.position - sz * 0.5, sz))


func world_to_map(world_pos: Vector2) -> Vector2:
	var scale_vec := Vector2(
		map_size.x / maxf(world_size.x, 1.0),
		map_size.y / maxf(world_size.y, 1.0)
	)
	var p := world_pos * scale_vec
	return Vector2(
		clampf(p.x, 2.5, map_size.x - 2.5),
		clampf(p.y, 2.5, map_size.y - 2.5)
	)


## Returns radar entries for living enemies:
##   - If `distance <= enemy_reveal_distance`: `revealed = true`, `exact_map_pos` holds true map coords.
##   - If `distance > enemy_reveal_distance`: `revealed = false`, `exact_map_pos = Vector2(-1, -1)`,
##     and ONLY a directional arrow (`direction`, `arrow_pos`) is shown!
func get_enemy_blips() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_inside_tree():
		return result

	var player_world := world_size * 0.5
	if player_ref != null and is_instance_valid(player_ref):
		player_world = player_ref.global_position
	var player_map := world_to_map(player_world)

	for node in get_tree().get_nodes_in_group("enemies"):
		if node == null or not is_instance_valid(node):
			continue
		if node.get("is_dead") == true:
			continue
		if not (node is Node2D):
			continue
		var enemy := node as Node2D
		var kind := "slime"
		if "is_enraged" in enemy:
			kind = "boss"
		elif "slam_trigger_range" in enemy:
			kind = "golem"
		elif "shooting_distance" in enemy:
			kind = "archer"

		var offset := enemy.global_position - player_world
		var dist := offset.length()
		var dir := offset / maxf(dist, 0.001) if dist > 0.01 else Vector2.RIGHT
		var is_revealed := dist <= enemy_reveal_distance

		var raw_arrow := player_map + dir * arrow_orbit_radius
		var arrow_pos := Vector2(
			clampf(raw_arrow.x, 4.5, map_size.x - 4.5),
			clampf(raw_arrow.y, 4.5, map_size.y - 4.5)
		)

		result.append({
			"enemy": enemy,
			"world_pos": enemy.global_position,
			"distance": dist,
			"direction": dir,
			"revealed": is_revealed,
			"exact_map_pos": world_to_map(enemy.global_position) if is_revealed else Vector2(-1.0, -1.0),
			"arrow_pos": arrow_pos,
			"kind": kind,
			# Null-safe: the boss (Colossus) has no `is_elite` property, and
			# `bool(null)` is a hard runtime error in this Godot version -
			# which crashed every _draw() frame on boss waves. Compare
			# against `true` instead so a missing property reads as false.
			"is_elite": enemy.get("is_elite") == true,
		})
	return result


func _process(delta: float) -> void:
	_pulse_time += delta
	if (player_ref == null or not is_instance_valid(player_ref)) and is_inside_tree():
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
	queue_redraw()


func _draw_direction_arrow(center: Vector2, dir: Vector2, col: Color, is_boss_or_elite: bool) -> void:
	var u := dir.normalized()
	var perp := Vector2(-u.y, u.x)
	var scale_k := 1.22 if is_boss_or_elite else 1.0

	var tip := center + u * (3.6 * scale_k)
	var wing_l := center - u * (1.8 * scale_k) + perp * (2.4 * scale_k)
	var wing_r := center - u * (1.8 * scale_k) - perp * (2.4 * scale_k)
	var stem_tail := center - u * (3.8 * scale_k)

	# Dark contrast outline + stem + sharp arrowhead (`➔`)
	draw_line(stem_tail, center, Color(0.03, 0.03, 0.05, 0.95), 2.6)
	draw_colored_polygon(PackedVector2Array([
		tip + u * 0.8,
		wing_l + (wing_l - center).normalized() * 0.8,
		wing_r + (wing_r - center).normalized() * 0.8,
	]), Color(0.03, 0.03, 0.05, 0.95))

	draw_line(stem_tail, center, col, 1.4)
	draw_colored_polygon(PackedVector2Array([tip, wing_l, wing_r]), col)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_pulse_time * 5.0)

	# 1. Drop shadow + dark slate background
	draw_rect(Rect2(Vector2(-2.0, -2.0), map_size + Vector2(4.0, 4.0)), Color(0.02, 0.03, 0.05, 0.90))
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.09, 0.11, 0.15, 0.88))

	# 2. Faint 4x3 tactical grid
	var grid_col := Color(0.70, 0.80, 0.95, 0.06)
	for gx in range(1, 4):
		var x := map_size.x * float(gx) / 4.0
		draw_line(Vector2(x, 1.0), Vector2(x, map_size.y - 1.0), grid_col, 1.0)
	for gy in range(1, 3):
		var y := map_size.y * float(gy) / 3.0
		draw_line(Vector2(1.0, y), Vector2(map_size.x - 1.0, y), grid_col, 1.0)

	# 3. Arena perimeter stone walls + obstacles (NO camera box!)
	draw_rect(Rect2(Vector2(1.0, 1.0), map_size - Vector2(2.0, 2.0)), Color(0.32, 0.35, 0.42, 0.85), false, 1.5)
	var scale_vec := Vector2(map_size.x / world_size.x, map_size.y / world_size.y)
	for obs in _obstacle_rects:
		var mrect := Rect2(obs.position * scale_vec, obs.size * scale_vec)
		draw_rect(mrect, Color(0.38, 0.41, 0.48, 0.95))
		draw_rect(mrect, Color(0.56, 0.60, 0.68, 0.85), false, 1.0)

	# 4. Enemies: directional arrow when far, exact position when close!
	var blips := get_enemy_blips()
	last_enemy_count = blips.size()
	var drawn_arrow_angles: Array[float] = []

	for b in blips:
		var kind: String = b["kind"]
		var elite: bool = b["is_elite"]

		if not bool(b["revealed"]):
			# Distant enemy -> DO NOT show exact spot; draw directional arrow (`➔`)!
			var dir: Vector2 = b["direction"]
			var ang := dir.angle()
			# Avoid stacking identical arrows if 2 far enemies share the exact same bearing
			var duplicate_bearing := false
			if kind != "boss" and not elite:
				for prev_a in drawn_arrow_angles:
					if absf( angle_difference(ang, prev_a) ) < deg_to_rad(13.0):
						duplicate_bearing = true
						break
			if duplicate_bearing:
				continue
			drawn_arrow_angles.append(ang)

			var arrow_col := Color(1.0, 0.86, 0.26, 0.96) if (elite or kind == "boss") \
				else Color(1.0, 0.38, 0.32, 0.94)
			_draw_direction_arrow(b["arrow_pos"], dir, arrow_col, elite or kind == "boss")
			continue

		# Close enemy (`distance <= enemy_reveal_distance`) -> exact position revealed!
		var mp: Vector2 = b["exact_map_pos"]
		if elite:
			draw_arc(mp, 3.8 + pulse * 0.6, 0.0, TAU, 16, Color(1.0, 0.86, 0.22, 0.95), 1.2)

		match kind:
			"boss":
				draw_arc(mp, 4.8 + pulse * 1.4, 0.0, TAU, 20, Color(1.0, 0.26, 0.18, 0.65), 1.2)
				draw_circle(mp, 3.6, Color(0.05, 0.02, 0.02, 0.95))
				draw_circle(mp, 2.8, Color(1.0, 0.28, 0.18, 1.0))
				draw_circle(mp, 1.2, Color(1.0, 0.92, 0.35, 1.0))
			"golem":
				var sq := Rect2(mp - Vector2(2.2, 2.2), Vector2(4.4, 4.4))
				draw_rect(Rect2(sq.position - Vector2(0.6, 0.6), sq.size + Vector2(1.2, 1.2)), Color(0.05, 0.03, 0.08, 0.95))
				draw_rect(sq, Color(0.86, 0.42, 0.98, 1.0))
			"archer":
				var pts := PackedVector2Array([
					mp + Vector2(0.0, -2.6),
					mp + Vector2(2.6, 0.0),
					mp + Vector2(0.0, 2.6),
					mp + Vector2(-2.6, 0.0),
				])
				draw_colored_polygon(pts, Color(1.0, 0.66, 0.16, 1.0))
			_:
				draw_circle(mp, 2.7, Color(0.06, 0.02, 0.03, 0.95))
				draw_circle(mp, 2.0, Color(1.0, 0.26, 0.30, 1.0))

	# 5. Player marker
	if player_ref != null and is_instance_valid(player_ref):
		var pp := world_to_map(player_ref.global_position)
		var face_x := 1.0
		if "facing" in player_ref:
			face_x = float(player_ref.facing)
		draw_circle(pp, 4.0 + pulse * 0.9, Color(player_accent.r, player_accent.g, player_accent.b, 0.26))
		draw_line(pp, pp + Vector2(face_x * 4.2, 0.0), player_accent.lightened(0.25), 1.3)
		draw_circle(pp, 3.1, Color(0.03, 0.05, 0.07, 0.98))
		draw_circle(pp, 2.2, player_accent.lightened(0.15))
		draw_circle(pp, 0.9, Color.WHITE)

	# 6. Crisp outer border
	draw_rect(Rect2(Vector2(-1.0, -1.0), map_size + Vector2(2.0, 2.0)), Color(0.56, 0.64, 0.76, 0.92), false, 1.0)

	# 7. Update caption
	if _caption != null:
		if is_in_menu:
			_caption.text = "ARENA MAP"
			_caption.add_theme_color_override("font_color", Color(0.78, 0.88, 0.98, 0.95))
		elif last_enemy_count > 0:
			_caption.text = "MAP • FOES: %d" % last_enemy_count
			_caption.add_theme_color_override("font_color", Color(1.0, 0.78, 0.68, 0.96))
		else:
			_caption.text = "MAP • CLEAR"
			_caption.add_theme_color_override("font_color", Color(0.66, 0.96, 0.76, 0.95))
