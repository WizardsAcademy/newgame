extends Node2D
## Playable Medieval Castle Guild Hall Lobby + Attached Training Room (`LobbyHub`).
##
## Layout (`960 x 500`):
##   1. **Main Guild Hall (`x = 24..540, y = 24..468`)**:
##      - North Castle Gate (`DoorStages` at `280, 56`): walks out into Dungeon Stages!
##      - Oak Hero Wardrobe (`Wardrobe` at `96, 250`): walk up / press F or E or Click
##        to change your Hero right inside the Lobby!
##   2. **Connected East Training Room (`x = 540..920, y = 44..468`)**:
##      - Wide open stone archway connecting the two rooms (`y = 190..310`).
##      - `TrainingDummy` (`716, 260`): 100-HP target dummy to test combos, stuns,
##        bow charges, blood whips, and 30% Fang bursts!
##      - Corner `SANDBOX` Door (`DoorSandbox` at `854, 96`) with `"SANDBOX"` written
##        above it — takes you straight into the `1280x720` Arena Sandbox Map!

signal wardrobe_opened
signal enter_stages_requested
signal enter_sandbox_requested

const TrainingDummyScript := preload("res://scripts/enemies/training_dummy.gd")
const WARDROBE_TEX_PATH := "res://assets/textures/lobby_wardrobe.png"
const DOOR_TEX_PATH := "res://assets/textures/lobby_door.png"

const LOBBY_BOUNDS := Rect2(0.0, 0.0, 960.0, 500.0)
const SPAWN_POINT := Vector2(280.0, 265.0)
const WARDROBE_POS := Vector2(96.0, 252.0)
const STAGES_DOOR_POS := Vector2(280.0, 56.0)
const DUMMY_POS := Vector2(716.0, 264.0)
const SANDBOX_DOOR_POS := Vector2(854.0, 96.0)

var player_ref: Node2D = null
var interactions_enabled: bool = true
var dummy_instance: Node2D = null

var _wardrobe_sprite: Sprite2D = null
var _wardrobe_frames: Array[AtlasTexture] = []
var _wardrobe_prompt: Label = null
var _wardrobe_cooldown: float = 0.0
var _was_inside_wardrobe: bool = false
var _door_grace_timer: float = 0.45
var _torch_time: float = 0.0


func _ready() -> void:
	_build_collision_walls()
	_build_wardrobe()
	_build_doors()
	_spawn_training_dummy()


func activate_lobby(p: Node2D) -> void:
	visible = true
	player_ref = p
	interactions_enabled = true
	_door_grace_timer = 0.45
	_set_walls_enabled(true)
	if dummy_instance == null or not is_instance_valid(dummy_instance):
		_spawn_training_dummy()
	else:
		dummy_instance.visible = true
		if not dummy_instance.is_in_group("enemies"):
			dummy_instance.add_to_group("enemies")
	queue_redraw()


func deactivate_lobby() -> void:
	visible = false
	interactions_enabled = false
	_set_walls_enabled(false)
	if dummy_instance != null and is_instance_valid(dummy_instance):
		dummy_instance.visible = false
		if dummy_instance.is_in_group("enemies"):
			dummy_instance.remove_from_group("enemies")


func set_wardrobe_cooldown(sec: float = 0.65) -> void:
	_wardrobe_cooldown = sec
	_was_inside_wardrobe = true


func _set_walls_enabled(active: bool) -> void:
	var walls_root := get_node_or_null("Walls")
	if walls_root == null:
		return
	for child in walls_root.get_children():
		if child is StaticBody2D:
			var col := child.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if col != null:
				col.set_deferred("disabled", not active)


func _build_collision_walls() -> void:
	var walls := Node2D.new()
	walls.name = "Walls"
	add_child(walls)

	# Outer perimeter + partition wall between Main Hall & East Training Room
	# with a wide open archway from y=190 to y=310!
	var rects: Array[Rect2] = [
		Rect2(0, 0, 960, 28),          # North wall
		Rect2(0, 472, 960, 28),        # South wall
		Rect2(0, 0, 28, 500),          # West wall
		Rect2(932, 0, 28, 500),        # East wall
		Rect2(528, 28, 24, 162),       # Partition upper pillar (y=28..190)
		Rect2(528, 310, 24, 162),      # Partition lower pillar (y=310..472)
	]
	for i in rects.size():
		var r := rects[i]
		var sb := StaticBody2D.new()
		sb.name = "LobbyWall_%d" % i
		sb.collision_layer = 1
		sb.collision_mask = 0
		sb.position = r.position + r.size * 0.5
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		sb.add_child(cs)
		walls.add_child(sb)


func _build_wardrobe() -> void:
	_wardrobe_sprite = Sprite2D.new()
	_wardrobe_sprite.name = "WardrobeSprite"
	_wardrobe_sprite.position = WARDROBE_POS
	_wardrobe_sprite.scale = Vector2(0.88, 0.88)
	add_child(_wardrobe_sprite)

	if ResourceLoader.exists(WARDROBE_TEX_PATH):
		var sheet: Texture2D = load(WARDROBE_TEX_PATH)
		if sheet != null:
			for i in range(2):
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(float(i * 64), 0.0, 64.0, 80.0)
				_wardrobe_frames.append(at)
			if not _wardrobe_frames.is_empty():
				_wardrobe_sprite.texture = _wardrobe_frames[0]

	var title := _make_sign_label("HEROES", Color(1.0, 0.88, 0.48), 9)
	title.position = WARDROBE_POS + Vector2(-40.0, -48.0)
	title.size = Vector2(80.0, 14.0)
	add_child(title)

	_wardrobe_prompt = _make_sign_label("[F / Click] Wardrobe", Color(0.72, 0.98, 0.82), 8)
	_wardrobe_prompt.position = WARDROBE_POS + Vector2(-56.0, 32.0)
	_wardrobe_prompt.size = Vector2(112.0, 14.0)
	_wardrobe_prompt.visible = false
	add_child(_wardrobe_prompt)


func _build_doors() -> void:
	var door_tex: Texture2D = load(DOOR_TEX_PATH) if ResourceLoader.exists(DOOR_TEX_PATH) else null

	# 1. Main Hall North Gate -> STAGES
	var stages_sp := Sprite2D.new()
	stages_sp.name = "DoorStages"
	stages_sp.position = STAGES_DOOR_POS
	stages_sp.scale = Vector2(0.88, 0.88)
	if door_tex != null:
		var at0 := AtlasTexture.new()
		at0.atlas = door_tex
		at0.region = Rect2(0.0, 0.0, 80.0, 80.0)
		stages_sp.texture = at0
	add_child(stages_sp)

	var stages_lbl := _make_sign_label("STAGES", Color(1.0, 0.86, 0.44), 10)
	stages_lbl.position = STAGES_DOOR_POS + Vector2(-45.0, -46.0)
	stages_lbl.size = Vector2(90.0, 16.0)
	add_child(stages_lbl)

	# 2. Training Room Corner Door -> SANDBOX (`balash benevis sand box`)
	var sb_sp := Sprite2D.new()
	sb_sp.name = "DoorSandbox"
	sb_sp.position = SANDBOX_DOOR_POS
	sb_sp.scale = Vector2(0.82, 0.82)
	if door_tex != null:
		var at1 := AtlasTexture.new()
		at1.atlas = door_tex
		at1.region = Rect2(80.0, 0.0, 80.0, 80.0)
		sb_sp.texture = at1
	add_child(sb_sp)

	var sb_lbl := _make_sign_label("SANDBOX", Color(0.52, 1.0, 0.88), 10)
	sb_lbl.name = "SandboxSign"
	sb_lbl.position = SANDBOX_DOOR_POS + Vector2(-50.0, -45.0)
	sb_lbl.size = Vector2(100.0, 16.0)
	add_child(sb_lbl)


func _spawn_training_dummy() -> void:
	if dummy_instance != null and is_instance_valid(dummy_instance):
		dummy_instance.queue_free()
	dummy_instance = TrainingDummyScript.new()
	dummy_instance.name = "TrainingDummy"
	dummy_instance.position = DUMMY_POS
	add_child(dummy_instance)


func _make_sign_label(txt: String, col: Color, fsize: int) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.06, 0.96))
	lbl.add_theme_constant_override("outline_size", 2)
	return lbl


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not interactions_enabled or player_ref == null or not is_instance_valid(player_ref):
		return

	var near_wardrobe := player_ref.global_position.distance_to(WARDROBE_POS) <= 58.0
	if near_wardrobe and _wardrobe_cooldown <= 0.0:
		if event is InputEventKey and event.pressed and not event.echo:
			var k := (event as InputEventKey).keycode
			if k in [KEY_F, KEY_C, KEY_ENTER]:
				wardrobe_opened.emit()
				get_viewport().set_input_as_handled()
				return
		if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if get_global_mouse_position().distance_to(WARDROBE_POS) <= 36.0:
				wardrobe_opened.emit()
				get_viewport().set_input_as_handled()
				return


func _process(delta: float) -> void:
	if not visible:
		return
	_torch_time += delta
	if _wardrobe_cooldown > 0.0:
		_wardrobe_cooldown = maxf(_wardrobe_cooldown - delta, 0.0)
	if _door_grace_timer > 0.0:
		_door_grace_timer = maxf(_door_grace_timer - delta, 0.0)

	if player_ref != null and is_instance_valid(player_ref) and interactions_enabled:
		var ppos := player_ref.global_position
		var dist_w := ppos.distance_to(WARDROBE_POS)
		var near_w := dist_w <= 56.0
		if _wardrobe_prompt != null:
			_wardrobe_prompt.visible = near_w
		if _wardrobe_sprite != null and _wardrobe_frames.size() >= 2:
			_wardrobe_sprite.texture = _wardrobe_frames[1 if near_w else 0]

		# Stepping directly into the Wardrobe rug (`<= 28 px`) also opens it once!
		if dist_w <= 28.0:
			if not _was_inside_wardrobe and _wardrobe_cooldown <= 0.0:
				_was_inside_wardrobe = true
				wardrobe_opened.emit()
				return
		elif dist_w > 40.0:
			_was_inside_wardrobe = false

		if _door_grace_timer <= 0.0:
			if ppos.distance_to(STAGES_DOOR_POS + Vector2(0.0, 12.0)) <= 28.0:
				_door_grace_timer = 0.8
				enter_stages_requested.emit()
				return
			if ppos.distance_to(SANDBOX_DOOR_POS + Vector2(0.0, 12.0)) <= 28.0:
				_door_grace_timer = 0.8
				enter_sandbox_requested.emit()
				return

	queue_redraw()


func _draw() -> void:
	# 1. Medieval Castle Flagstone Floor (Main Guild Hall + East Training Wing)
	draw_rect(LOBBY_BOUNDS, Color(0.11, 0.11, 0.14), true)
	draw_rect(Rect2(28, 28, 500, 444), Color(0.16, 0.16, 0.20), true)
	draw_rect(Rect2(552, 28, 380, 444), Color(0.15, 0.14, 0.17), true)
	# Archway threshold floor connecting Main Hall <-> Training Room
	draw_rect(Rect2(524, 190, 32, 120), Color(0.20, 0.18, 0.22), true)

	# Subtle stone flagstone grid seams
	var seam := Color(0.12, 0.12, 0.15, 0.85)
	for x in range(60, 920, 36):
		draw_line(Vector2(x, 28), Vector2(x, 472), seam, 1.0)
	for y in range(60, 470, 36):
		draw_line(Vector2(28, y), Vector2(932, y), seam, 1.0)

	# 2. Royal Crimson Carpet leading from Guild Center up to the STAGES Gate!
	draw_rect(Rect2(246, 82, 68, 236), Color(0.46, 0.09, 0.16), true)
	draw_rect(Rect2(250, 82, 60, 232), Color(0.62, 0.13, 0.22), false, 2.0)
	draw_rect(Rect2(254, 86, 52, 224), Color(0.86, 0.68, 0.30, 0.65), false, 1.0)

	# Crimson & Gold Rug in front of the Hero Wardrobe (`Komod`)
	draw_rect(Rect2(68, 272, 58, 34), Color(0.48, 0.12, 0.22), true)
	draw_rect(Rect2(68, 272, 58, 34), Color(0.86, 0.68, 0.32, 0.80), false, 1.5)

	# 3. Wooden Sparring Circle under the Training Dummy in the East Room!
	draw_circle(DUMMY_POS + Vector2(0, 6), 56.0, Color(0.24, 0.17, 0.12, 0.88))
	draw_arc(DUMMY_POS + Vector2(0, 6), 56.0, 0.0, TAU, 36, Color(0.62, 0.46, 0.26, 0.85), 2.0)
	draw_arc(DUMMY_POS + Vector2(0, 6), 36.0, 0.0, TAU, 28, Color(0.48, 0.34, 0.20, 0.65), 1.2)

	# Arcane Cyan-Emerald Runic Mat in front of the SANDBOX corner door
	draw_circle(SANDBOX_DOOR_POS + Vector2(0, 28), 22.0, Color(0.12, 0.36, 0.34, 0.55))
	draw_arc(SANDBOX_DOOR_POS + Vector2(0, 28), 22.0, 0.0, TAU, 24, Color(0.45, 0.96, 0.84, 0.72), 1.4)

	# 4. Castle Stone Perimeter & Partition Walls
	var wall_fill := Color(0.26, 0.27, 0.33)
	var wall_trim := Color(0.38, 0.40, 0.48)
	for r in [
		Rect2(0, 0, 960, 28),
		Rect2(0, 472, 960, 28),
		Rect2(0, 0, 28, 500),
		Rect2(932, 0, 28, 500),
		Rect2(528, 28, 24, 162),
		Rect2(528, 310, 24, 162),
	]:
		draw_rect(r, wall_fill, true)
		draw_rect(r, wall_trim, false, 1.5)

	# Warm flickering torchlight pools!
	var flicker := 0.88 + 0.12 * sin(_torch_time * 8.5)
	for tpos in [STAGES_DOOR_POS + Vector2(0, 18), WARDROBE_POS + Vector2(18, 12), DUMMY_POS, SANDBOX_DOOR_POS + Vector2(0, 20)]:
		var col := Color(0.35, 0.95, 0.82, 0.08 * flicker) if tpos.distance_to(SANDBOX_DOOR_POS) < 40.0 else Color(1.0, 0.68, 0.28, 0.08 * flicker)
		draw_circle(tpos, 68.0 * flicker, col)
