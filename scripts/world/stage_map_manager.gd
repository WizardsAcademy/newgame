extends Node2D
class_name StageMapManager
## Builds and manages the 3 distinct named `1280 x 720` Stage Maps (`STAGES` mode ONLY;
## the classic `$Level` node is reserved strictly for `SANDBOX`!).
##
## Regions:
##   1. `Whispering Jungle`  — Overgrown emerald moss floor, winding sunlit dirt paths,
##                             Mayan/Elven Ruin Pillars & Vine Totem Walls (`collision_layer = 1`).
##   2. `Cursed Bone Crypt`  — Cold obsidian catacomb tiles, glowing violet necromantic sigils,
##                             Cursed Sarcophagi & Bone Obelisks (`collision_layer = 1`).
##   3. `Infernal Citadel`   — Scorched volcanic basalt floor, molten lava fissures & causeways,
##                             Brimstone Monoliths & Hellforge Bastions (`collision_layer = 1`).

const WORLD_SIZE := Vector2(1280.0, 720.0)
const WALL_THICKNESS: float = 36.0

var active_region_id: int = 1
var obstacle_rects: Array[Rect2] = []


class StageFloorCanvas extends Node2D:
	var region_id: int = 1
	var obs_rects: Array[Rect2] = []
	var anim_t: float = 0.0

	func _process(delta: float) -> void:
		anim_t += delta
		if region_id != 1:
			queue_redraw()

	func _draw() -> void:
		match region_id:
			1:
				_draw_jungle()
			2:
				_draw_crypt()
			_:
				_draw_citadel()

	func _draw_jungle() -> void:
		# Deep lush jungle floor + mossy clearing patches + golden dirt crossroads
		draw_rect(Rect2(Vector2(-160, -160), WORLD_SIZE + Vector2(320, 320)), Color(0.05, 0.13, 0.08))
		draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.10, 0.24, 0.14))
		for gx in range(0, 1280, 64):
			for gy in range(0, 720, 64):
				if ((gx / 64 + gy / 64) % 2) == 0:
					draw_rect(Rect2(float(gx), float(gy), 64.0, 64.0), Color(0.12, 0.27, 0.16, 0.55))

		# Winding sunlit dirt trails
		draw_rect(Rect2(60.0, 332.0, 1160.0, 56.0), Color(0.26, 0.21, 0.13, 0.78))
		draw_rect(Rect2(604.0, 48.0, 72.0, 624.0), Color(0.26, 0.21, 0.13, 0.78))
		draw_circle(Vector2(640.0, 360.0), 86.0, Color(0.22, 0.30, 0.18, 0.85))
		draw_arc(Vector2(640.0, 360.0), 84.0, 0.0, TAU, 40, Color(0.38, 0.68, 0.34, 0.55), 2.5)

		# Jungle fern & wildflower clusters
		for i in range(28):
			var fx := fmod(float(i * 173 + 90), 1140.0) + 70.0
			var fy := fmod(float(i * 251 + 80), 580.0) + 70.0
			draw_circle(Vector2(fx, fy), 7.0, Color(0.16, 0.42, 0.22, 0.75))
			draw_circle(Vector2(fx + 4.0, fy - 2.0), 4.0, Color(0.32, 0.72, 0.36, 0.70))
			if i % 3 == 0:
				draw_circle(Vector2(fx - 2.0, fy - 1.0), 2.0, Color(0.98, 0.84, 0.32, 0.85))

		# Vine-covered jungle stone border walls & mossy ruin obstacles
		_draw_border_frame(Color(0.14, 0.22, 0.14), Color(0.30, 0.52, 0.28))
		for r in obs_rects:
			draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0.03, 0.07, 0.04, 0.65))
			draw_rect(r, Color(0.24, 0.30, 0.24))
			draw_rect(r.grow(-3.0), Color(0.32, 0.42, 0.30))
			draw_rect(Rect2(r.position.x + 4.0, r.position.y + 3.0, r.size.x - 8.0, 7.0), Color(0.22, 0.62, 0.30, 0.88))
			draw_rect(r, Color(0.46, 0.66, 0.42), false, 2.0)

	func _draw_crypt() -> void:
		var pulse := 0.5 + 0.5 * sin(anim_t * 3.6)
		draw_rect(Rect2(Vector2(-160, -160), WORLD_SIZE + Vector2(320, 320)), Color(0.03, 0.02, 0.06))
		draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.09, 0.08, 0.15))

		# Checkerboard catacomb flagstones
		for gx in range(0, 1280, 48):
			for gy in range(0, 720, 48):
				var col := Color(0.12, 0.11, 0.20, 0.75) if ((gx / 48 + gy / 48) % 2 == 0) else Color(0.08, 0.07, 0.14, 0.75)
				draw_rect(Rect2(float(gx) + 1.0, float(gy) + 1.0, 46.0, 46.0), col)

		# Glowing Violet-Cyan Necromantic Ritual Circles
		for center in [Vector2(640.0, 360.0), Vector2(320.0, 220.0), Vector2(960.0, 500.0)]:
			var rad := 78.0 if center.x == 640.0 else 46.0
			draw_arc(center, rad, 0.0, TAU, 36, Color(0.58, 0.32, 0.98, 0.32 + pulse * 0.18), 2.2)
			draw_arc(center, rad * 0.68, 0.0, TAU, 28, Color(0.28, 0.88, 0.96, 0.26 + pulse * 0.14), 1.4)

		_draw_border_frame(Color(0.14, 0.12, 0.24), Color(0.52, 0.38, 0.86))
		for r in obs_rects:
			draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0.02, 0.01, 0.05, 0.78))
			draw_rect(r, Color(0.18, 0.15, 0.28))
			draw_rect(r.grow(-3.0), Color(0.25, 0.22, 0.38))
			draw_rect(r.grow(-7.0), Color(0.48, 0.88, 0.96, 0.22 + pulse * 0.16))
			draw_rect(r, Color(0.64, 0.48, 0.98), false, 2.0)

	func _draw_citadel() -> void:
		var pulse := 0.5 + 0.5 * sin(anim_t * 4.8)
		draw_rect(Rect2(Vector2(-160, -160), WORLD_SIZE + Vector2(320, 320)), Color(0.08, 0.02, 0.02))
		draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.15, 0.06, 0.06))

		# Scorched obsidian fortress slabs
		for gx in range(0, 1280, 64):
			for gy in range(0, 720, 64):
				if ((gx / 64 + gy / 64) % 2) == 0:
					draw_rect(Rect2(float(gx) + 1.0, float(gy) + 1.0, 62.0, 62.0), Color(0.19, 0.08, 0.07, 0.72))

		# Glowing molten lava cracks & central hellforge ring
		var lava_col := Color(1.0, 0.34, 0.08, 0.42 + pulse * 0.22)
		draw_line(Vector2(120, 140), Vector2(460, 250), lava_col, 4.0)
		draw_line(Vector2(820, 470), Vector2(1150, 580), lava_col, 4.0)
		draw_line(Vector2(180, 560), Vector2(500, 460), lava_col, 3.5)
		draw_line(Vector2(780, 240), Vector2(1110, 150), lava_col, 3.5)
		draw_arc(Vector2(640.0, 360.0), 86.0, 0.0, TAU, 40, lava_col, 3.0)

		_draw_border_frame(Color(0.24, 0.08, 0.07), Color(0.95, 0.36, 0.14))
		for r in obs_rects:
			draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0.05, 0.01, 0.01, 0.80))
			draw_rect(r, Color(0.22, 0.09, 0.08))
			draw_rect(r.grow(-3.0), Color(0.32, 0.12, 0.10))
			draw_rect(r.grow(-8.0), Color(1.0, 0.42, 0.10, 0.30 + pulse * 0.22))
			draw_rect(r, Color(1.0, 0.48, 0.16), false, 2.0)

	func _draw_border_frame(fill: Color, rim: Color) -> void:
		for br in [
			Rect2(0.0, 0.0, WORLD_SIZE.x, WALL_THICKNESS),
			Rect2(0.0, WORLD_SIZE.y - WALL_THICKNESS, WORLD_SIZE.x, WALL_THICKNESS),
			Rect2(0.0, 0.0, WALL_THICKNESS, WORLD_SIZE.y),
			Rect2(WORLD_SIZE.x - WALL_THICKNESS, 0.0, WALL_THICKNESS, WORLD_SIZE.y),
		]:
			draw_rect(br, fill, true)
			draw_rect(br, rim, false, 2.0)


func build_region(region_id: int) -> void:
	active_region_id = clampi(region_id, 1, 3)
	clear_map()
	visible = true

	obstacle_rects = _get_obstacle_layout_for_region(active_region_id)

	var floor_canvas := StageFloorCanvas.new()
	floor_canvas.name = "StageFloorCanvas"
	floor_canvas.region_id = active_region_id
	floor_canvas.obs_rects = obstacle_rects.duplicate()
	floor_canvas.z_index = -10
	add_child(floor_canvas)

	# Perimeter `BoundaryWalls` on `collision_layer = 1` (stops heroes, enemies, AND projectiles!)
	var border_specs := [
		Rect2(0.0, 0.0, WORLD_SIZE.x, WALL_THICKNESS),
		Rect2(0.0, WORLD_SIZE.y - WALL_THICKNESS, WORLD_SIZE.x, WALL_THICKNESS),
		Rect2(0.0, 0.0, WALL_THICKNESS, WORLD_SIZE.y),
		Rect2(WORLD_SIZE.x - WALL_THICKNESS, 0.0, WALL_THICKNESS, WORLD_SIZE.y),
	]
	for i in range(border_specs.size()):
		var br: Rect2 = border_specs[i]
		_spawn_static_box("StageWall_%d" % i, br)

	# Distinct interior `Obstacle_*` `StaticBody2D` walls (`MiniMap` automatically scans `Obstacle*`!)
	for idx in range(obstacle_rects.size()):
		var orect: Rect2 = obstacle_rects[idx]
		_spawn_static_box("Obstacle_%d" % idx, orect)


func deactivate_map() -> void:
	clear_map()
	visible = false


func clear_map() -> void:
	obstacle_rects.clear()
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()


func is_point_clear(pt: Vector2, pad: float = 54.0) -> bool:
	if pt.x < WALL_THICKNESS + pad or pt.x > WORLD_SIZE.x - WALL_THICKNESS - pad:
		return false
	if pt.y < WALL_THICKNESS + pad or pt.y > WORLD_SIZE.y - WALL_THICKNESS - pad:
		return false
	for r in obstacle_rects:
		if r.grow(pad).has_point(pt):
			return false
	return true


func _spawn_static_box(node_name: String, rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.position + rect.size * 0.5
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	cs.shape = rs
	body.add_child(cs)
	add_child(body)
	return body


func _get_obstacle_layout_for_region(region_id: int) -> Array[Rect2]:
	match region_id:
		1:
			# Region 1 — Whispering Jungle: 6 Mossy Ruin Pillars framing natural jungle lanes
			# (keeps spawn `(220, 360)` and gate `(640, 56)` / `(64, 360)` completely open!)
			return [
				Rect2(370.0, 170.0, 68.0, 52.0),
				Rect2(842.0, 170.0, 68.0, 52.0),
				Rect2(370.0, 498.0, 68.0, 52.0),
				Rect2(842.0, 498.0, 68.0, 52.0),
				Rect2(588.0, 210.0, 104.0, 36.0),
				Rect2(588.0, 474.0, 104.0, 36.0),
			]
		2:
			# Region 2 — Cursed Bone Crypt: Long Sarcophagi Corridors & Bone Obelisk Chokepoints!
			return [
				Rect2(320.0, 140.0, 44.0, 136.0),
				Rect2(320.0, 444.0, 44.0, 136.0),
				Rect2(916.0, 140.0, 44.0, 136.0),
				Rect2(916.0, 444.0, 44.0, 136.0),
				Rect2(520.0, 292.0, 52.0, 136.0),
				Rect2(708.0, 292.0, 52.0, 136.0),
			]
		_:
			# Region 3 — Infernal Citadel: Jagged Brimstone Bastions & Hellforge Monoliths!
			return [
				Rect2(340.0, 224.0, 96.0, 44.0),
				Rect2(844.0, 224.0, 96.0, 44.0),
				Rect2(340.0, 452.0, 96.0, 44.0),
				Rect2(844.0, 452.0, 96.0, 44.0),
				Rect2(614.0, 148.0, 52.0, 88.0),
				Rect2(614.0, 484.0, 52.0, 88.0),
				Rect2(1030.0, 324.0, 64.0, 72.0),
			]
