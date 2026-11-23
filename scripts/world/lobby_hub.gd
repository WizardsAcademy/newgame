extends Node2D
## Cozy Textured Witch's Cottage Hub (`LobbyHub` — compact `480 x 280` layout!).
##
## Features:
##   - Tiled warm oak-plank floor (`cottage_floor.png`), timber walls, fireplace hearth,
##     potion shelves, and plush violet-crimson Witch's Rug!
##   - Pretty "Baddie" Witch (`WitchSprite`) beside her bubbling Cauldron (`CauldronSprite`)
##     whose emerald-green brew periodically flashes & swirls bright purple!
##   - Interacting with the Cauldron (`F` / `E` / Click) opens the Hero's Skill Tree,
##     and leveling up makes the Witch toss a glowing potion for your hero to drink!
##   - Hero Wardrobe (`WardrobeSprite`), `DoorStages`, `DoorSandbox`, and `TrainingDummy`.

signal wardrobe_opened
signal cauldron_opened
signal enter_stages_requested
signal enter_sandbox_requested

const TrainingDummyScript := preload("res://scripts/enemies/training_dummy.gd")
const FLOOR_TEX_PATH := "res://assets/textures/cottage_floor.png"
const WARDROBE_TEX_PATH := "res://assets/textures/lobby_wardrobe.png"
const DOOR_TEX_PATH := "res://assets/textures/lobby_door.png"
const WITCH_TEX_PATH := "res://assets/textures/lobby_witch.png"
const CAULDRON_TEX_PATH := "res://assets/textures/lobby_cauldron.png"
const POTION_TEX_PATH := "res://assets/textures/witch_potion.png"

const LOBBY_BOUNDS := Rect2(0.0, 0.0, 480.0, 280.0)
const SPAWN_POINT := Vector2(214.0, 204.0)
const WARDROBE_POS := Vector2(68.0, 140.0)
const WARDROBE_EXIT_POS := Vector2(114.0, 156.0)
const CAULDRON_POS := Vector2(236.0, 142.0)
const WITCH_POS := Vector2(284.0, 128.0)
const STAGES_DOOR_POS := Vector2(174.0, 46.0)
const SANDBOX_DOOR_POS := Vector2(396.0, 46.0)
const DUMMY_POS := Vector2(394.0, 204.0)

var player_ref: Node2D = null
var interactions_enabled: bool = true
var dummy_instance: Node2D = null

var _wardrobe_sprite: Sprite2D = null
var _wardrobe_frames: Array[AtlasTexture] = []
var _wardrobe_prompt: Label = null
var _wardrobe_cooldown: float = 0.0
var _was_inside_wardrobe: bool = false

var _witch_sprite: Sprite2D = null
var _cauldron_sprite: Sprite2D = null
var _witch_frames: Array[AtlasTexture] = []
var _cauldron_frames: Array[AtlasTexture] = []
var _potion_frames: Array[AtlasTexture] = []
var _cauldron_prompt: Label = null
var _cauldron_cooldown: float = 0.0
var _witch_offer_timer: float = 0.0
var _cauldron_is_purple: bool = false

var _door_grace_timer: float = 0.45
var _torch_time: float = 0.0


func _ready() -> void:
	_load_witch_and_cauldron_frames()
	_build_textured_floor()
	_build_collision_walls()
	_build_wardrobe()
	_build_cauldron_and_witch()
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


func set_cauldron_cooldown(sec: float = 0.55) -> void:
	_cauldron_cooldown = sec


func _load_witch_and_cauldron_frames() -> void:
	if ResourceLoader.exists(WITCH_TEX_PATH):
		var wt: Texture2D = load(WITCH_TEX_PATH)
		if wt != null:
			for i in range(4):
				var at := AtlasTexture.new()
				at.atlas = wt
				at.region = Rect2(float(i * 96), 0.0, 96.0, 96.0)
				_witch_frames.append(at)

	if ResourceLoader.exists(CAULDRON_TEX_PATH):
		var ct: Texture2D = load(CAULDRON_TEX_PATH)
		if ct != null:
			for i in range(6):
				var atc := AtlasTexture.new()
				atc.atlas = ct
				atc.region = Rect2(float(i * 64), 0.0, 64.0, 64.0)
				_cauldron_frames.append(atc)

	if ResourceLoader.exists(POTION_TEX_PATH):
		var pt: Texture2D = load(POTION_TEX_PATH)
		if pt != null:
			for i in range(2):
				var atp := AtlasTexture.new()
				atp.atlas = pt
				atp.region = Rect2(float(i * 32), 0.0, 32.0, 32.0)
				_potion_frames.append(atp)


func _build_textured_floor() -> void:
	var outer := ColorRect.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.position = Vector2(-200.0, -140.0)
	outer.size = LOBBY_BOUNDS.size + Vector2(400.0, 280.0)
	outer.color = Color(0.04, 0.03, 0.07, 1.0)
	outer.z_index = -12
	add_child(outer)

	if ResourceLoader.exists(FLOOR_TEX_PATH):
		var floor_rect := TextureRect.new()
		floor_rect.name = "CottageFloor"
		floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		floor_rect.texture = load(FLOOR_TEX_PATH)
		floor_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		floor_rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		floor_rect.stretch_mode = TextureRect.STRETCH_TILE
		floor_rect.position = Vector2(18.0, 18.0)
		floor_rect.size = LOBBY_BOUNDS.size - Vector2(36.0, 36.0)
		floor_rect.z_index = -10
		add_child(floor_rect)


func _set_walls_enabled(active: bool) -> void:
	var walls_root := get_node_or_null("Walls")
	if walls_root == null:
		return
	for child in walls_root.get_children():
		if child is StaticBody2D:
			(child as StaticBody2D).collision_layer = 1 if active else 0
			for sub in child.get_children():
				if sub is CollisionShape2D:
					(sub as CollisionShape2D).set_deferred("disabled", not active)


func _build_collision_walls() -> void:
	var walls := Node2D.new()
	walls.name = "Walls"
	add_child(walls)

	var rects: Array[Rect2] = [
		Rect2(0.0, 0.0, 480.0, 20.0),      # North timber wall
		Rect2(0.0, 260.0, 480.0, 20.0),    # South timber wall
		Rect2(0.0, 0.0, 20.0, 280.0),      # West timber wall
		Rect2(460.0, 0.0, 20.0, 280.0),    # East timber wall
		Rect2(220.0, 140.0, 32.0, 18.0),   # Cauldron solid base
	]
	for i in rects.size():
		var r := rects[i]
		var sb := StaticBody2D.new()
		sb.name = "LobbyWall_%d" % i
		sb.collision_layer = 1
		sb.collision_mask = 0
		sb.position = r.position + r.size * 0.5
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		sb.add_child(cs)
		walls.add_child(sb)


func _build_wardrobe() -> void:
	_wardrobe_sprite = Sprite2D.new()
	_wardrobe_sprite.name = "WardrobeSprite"
	_wardrobe_sprite.position = WARDROBE_POS
	_wardrobe_sprite.scale = Vector2(0.76, 0.76)
	_wardrobe_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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

	var title := _make_sign_label("HEROES", Color(1.0, 0.88, 0.48), 8)
	title.position = WARDROBE_POS + Vector2(-40.0, -42.0)
	title.size = Vector2(80.0, 14.0)
	add_child(title)

	_wardrobe_prompt = _make_sign_label("[F / Click] Wardrobe", Color(0.72, 0.98, 0.82), 8)
	_wardrobe_prompt.position = WARDROBE_POS + Vector2(-56.0, 28.0)
	_wardrobe_prompt.size = Vector2(112.0, 14.0)
	_wardrobe_prompt.visible = false
	add_child(_wardrobe_prompt)


func _build_cauldron_and_witch() -> void:
	_witch_sprite = Sprite2D.new()
	_witch_sprite.name = "WitchSprite"
	_witch_sprite.position = WITCH_POS
	_witch_sprite.scale = Vector2(0.56, 0.56)
	_witch_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not _witch_frames.is_empty():
		_witch_sprite.texture = _witch_frames[0]
	add_child(_witch_sprite)

	_cauldron_sprite = Sprite2D.new()
	_cauldron_sprite.name = "CauldronSprite"
	_cauldron_sprite.position = CAULDRON_POS
	_cauldron_sprite.scale = Vector2(0.72, 0.72)
	_cauldron_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not _cauldron_frames.is_empty():
		_cauldron_sprite.texture = _cauldron_frames[0]
	add_child(_cauldron_sprite)

	var ctitle := _make_sign_label("CAULDRON", Color(0.90, 0.68, 1.0), 8)
	ctitle.position = CAULDRON_POS + Vector2(-34.0, -34.0)
	ctitle.size = Vector2(88.0, 14.0)
	add_child(ctitle)

	_cauldron_prompt = _make_sign_label("[F / Click] Brew Skills", Color(0.55, 1.0, 0.74), 8)
	_cauldron_prompt.position = CAULDRON_POS + Vector2(-52.0, 22.0)
	_cauldron_prompt.size = Vector2(116.0, 14.0)
	_cauldron_prompt.visible = false
	add_child(_cauldron_prompt)


func _build_doors() -> void:
	var door_tex: Texture2D = load(DOOR_TEX_PATH) if ResourceLoader.exists(DOOR_TEX_PATH) else null

	# 1. Cottage North-West Gate -> STAGES
	var stages_sp := Sprite2D.new()
	stages_sp.name = "DoorStages"
	stages_sp.position = STAGES_DOOR_POS
	stages_sp.scale = Vector2(0.70, 0.70)
	stages_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if door_tex != null:
		var at0 := AtlasTexture.new()
		at0.atlas = door_tex
		at0.region = Rect2(0.0, 0.0, 80.0, 80.0)
		stages_sp.texture = at0
	add_child(stages_sp)

	var stages_lbl := _make_sign_label("STAGES", Color(1.0, 0.86, 0.44), 9)
	stages_lbl.position = STAGES_DOOR_POS + Vector2(-45.0, -36.0)
	stages_lbl.size = Vector2(90.0, 14.0)
	add_child(stages_lbl)

	# 2. Cottage North-East Gate -> SANDBOX
	var sb_sp := Sprite2D.new()
	sb_sp.name = "DoorSandbox"
	sb_sp.position = SANDBOX_DOOR_POS
	sb_sp.scale = Vector2(0.70, 0.70)
	sb_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if door_tex != null:
		var at1 := AtlasTexture.new()
		at1.atlas = door_tex
		at1.region = Rect2(80.0, 0.0, 80.0, 80.0)
		sb_sp.texture = at1
	add_child(sb_sp)

	var sb_lbl := _make_sign_label("SANDBOX", Color(0.52, 1.0, 0.88), 9)
	sb_lbl.name = "SandboxSign"
	sb_lbl.position = SANDBOX_DOOR_POS + Vector2(-50.0, -36.0)
	sb_lbl.size = Vector2(100.0, 14.0)
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


func play_world_potion_handoff(hero: Node2D, is_purple: bool) -> void:
	_witch_offer_timer = 1.15
	if _witch_sprite != null and _witch_frames.size() >= 4:
		_witch_sprite.texture = _witch_frames[3]
	if hero == null or not is_instance_valid(hero) or _potion_frames.is_empty():
		return

	var vial := Sprite2D.new()
	vial.name = "WorldPotionVial"
	vial.texture = _potion_frames[1 if is_purple else 0]
	vial.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vial.scale = Vector2(0.75, 0.75)
	vial.z_index = 25
	vial.global_position = WITCH_POS + Vector2(-10.0, -4.0)
	add_child(vial)

	var target := hero.global_position + Vector2(0.0, -14.0)
	var mid := (vial.global_position + target) * 0.5 + Vector2(0.0, -24.0)

	var tw := create_tween()
	tw.tween_property(vial, "global_position", mid, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(vial, "global_position", target, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if is_instance_valid(vial):
			vial.queue_free()
		if is_instance_valid(hero) and "visuals" in hero and hero.visuals != null:
			var glow := Color(1.35, 0.82, 1.55, 1.0) if is_purple else Color(0.82, 1.45, 1.05, 1.0)
			hero.visuals.modulate = glow
			var htw := hero.create_tween()
			htw.tween_property(hero.visuals, "modulate", Color.WHITE, 0.35)
	)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not interactions_enabled or player_ref == null or not is_instance_valid(player_ref):
		return

	var ppos := player_ref.global_position
	var near_cauldron := ppos.distance_to(CAULDRON_POS) <= 56.0
	var near_wardrobe := ppos.distance_to(WARDROBE_POS) <= 52.0

	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k in [KEY_F, KEY_E, KEY_C, KEY_ENTER]:
			if near_cauldron and _cauldron_cooldown <= 0.0:
				cauldron_opened.emit()
				get_viewport().set_input_as_handled()
				return
			if near_wardrobe and _wardrobe_cooldown <= 0.0:
				wardrobe_opened.emit()
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mpos := get_global_mouse_position()
		if mpos.distance_to(CAULDRON_POS) <= 36.0 and _cauldron_cooldown <= 0.0:
			cauldron_opened.emit()
			get_viewport().set_input_as_handled()
			return
		if mpos.distance_to(WARDROBE_POS) <= 36.0 and _wardrobe_cooldown <= 0.0:
			wardrobe_opened.emit()
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	if not visible:
		return
	_torch_time += delta
	if _wardrobe_cooldown > 0.0:
		_wardrobe_cooldown = maxf(_wardrobe_cooldown - delta, 0.0)
	if _cauldron_cooldown > 0.0:
		_cauldron_cooldown = maxf(_cauldron_cooldown - delta, 0.0)
	if _door_grace_timer > 0.0:
		_door_grace_timer = maxf(_door_grace_timer - delta, 0.0)

	# Pretty Baddie Witch idle / wink / magic stir / potion offer!
	if _witch_sprite != null and _witch_frames.size() >= 4:
		if _witch_offer_timer > 0.0:
			_witch_offer_timer = maxf(_witch_offer_timer - delta, 0.0)
			_witch_sprite.texture = _witch_frames[3]
		else:
			var cyc := fmod(_torch_time, 4.4)
			var widx := 0
			if cyc > 3.9:
				widx = 1
			elif cyc > 2.2 and cyc < 2.85:
				widx = 2
			_witch_sprite.texture = _witch_frames[widx]

	# Cauldron: green bubbling liquid -> SUDDENLY turns purple (`sabz -> yeho banafsh`)!
	if _cauldron_sprite != null and _cauldron_frames.size() >= 6:
		var seq: Array[int] = [0, 1, 2, 0, 1, 2, 1, 3, 4, 4, 5]
		var step := int(_torch_time * 3.5) % seq.size()
		var fidx := seq[step]
		_cauldron_sprite.texture = _cauldron_frames[fidx]
		_cauldron_is_purple = (fidx >= 3)

	if player_ref != null and is_instance_valid(player_ref) and interactions_enabled:
		var ppos := player_ref.global_position
		var dist_w := ppos.distance_to(WARDROBE_POS)
		var near_w := dist_w <= 52.0
		if _wardrobe_prompt != null:
			_wardrobe_prompt.visible = near_w
		if _wardrobe_sprite != null and _wardrobe_frames.size() >= 2:
			_wardrobe_sprite.texture = _wardrobe_frames[1 if near_w else 0]

		var dist_c := ppos.distance_to(CAULDRON_POS)
		if _cauldron_prompt != null:
			_cauldron_prompt.visible = (dist_c <= 56.0)

		if dist_w <= 24.0:
			if not _was_inside_wardrobe and _wardrobe_cooldown <= 0.0:
				_was_inside_wardrobe = true
				wardrobe_opened.emit()
				return
		elif dist_w > 36.0:
			_was_inside_wardrobe = false

		if _door_grace_timer <= 0.0:
			if ppos.distance_to(STAGES_DOOR_POS + Vector2(0.0, 12.0)) <= 24.0:
				_door_grace_timer = 0.8
				enter_stages_requested.emit()
				return
			if ppos.distance_to(SANDBOX_DOOR_POS + Vector2(0.0, 12.0)) <= 24.0:
				_door_grace_timer = 0.8
				enter_sandbox_requested.emit()
				return

	queue_redraw()


func _draw() -> void:
	# North stone cottage wainscoting + warm fireplace hearth between the two doors
	draw_rect(Rect2(20, 20, 440, 38), Color(0.18, 0.13, 0.22, 0.96), true)
	draw_line(Vector2(20, 58), Vector2(460, 58), Color(0.36, 0.22, 0.14), 3.0)

	# Fireplace hearth (`x = 258..314`)
	draw_rect(Rect2(258, 18, 56, 38), Color(0.26, 0.23, 0.30), true)
	draw_rect(Rect2(268, 30, 36, 24), Color(0.10, 0.06, 0.08), true)
	var flicker := 0.88 + 0.12 * sin(_torch_time * 8.5)
	draw_rect(Rect2(274, 40, 24, 12), Color(1.0, 0.48, 0.16, 0.92 * flicker), true)

	# Plush Arcane Violet-Crimson Rug beneath the Witch & Cauldron!
	draw_rect(Rect2(158, 108, 176, 118), Color(0.30, 0.11, 0.28, 0.94), true)
	draw_rect(Rect2(162, 112, 168, 110), Color(0.68, 0.38, 0.92, 0.82), false, 2.0)
	draw_rect(Rect2(166, 116, 160, 102), Color(0.90, 0.72, 0.38, 0.55), false, 1.0)

	# Small crimson mat in front of Wardrobe
	draw_rect(Rect2(44, 156, 48, 28), Color(0.46, 0.12, 0.22, 0.92), true)
	draw_rect(Rect2(44, 156, 48, 28), Color(0.86, 0.68, 0.32, 0.80), false, 1.5)

	# Woven wooden sparring circle under TrainingDummy (`394, 204`)
	draw_circle(DUMMY_POS + Vector2(0, 6), 38.0, Color(0.24, 0.16, 0.11, 0.88))
	draw_arc(DUMMY_POS + Vector2(0, 6), 38.0, 0.0, TAU, 32, Color(0.62, 0.46, 0.26, 0.85), 1.8)

	# Timber cottage perimeter walls
	var wall_fill := Color(0.24, 0.15, 0.10)
	var wall_trim := Color(0.38, 0.24, 0.16)
	for r in [
		Rect2(0, 0, 480, 20),
		Rect2(0, 260, 480, 20),
		Rect2(0, 0, 20, 280),
		Rect2(460, 0, 20, 280),
	]:
		draw_rect(r, wall_fill, true)
		draw_rect(r, wall_trim, false, 1.5)

	# Dynamic Green -> Purple Cauldron glow + warm hearth & door pools!
	var cauldron_col := Color(0.78, 0.30, 1.0, 0.22 * flicker) if _cauldron_is_purple else Color(0.26, 0.98, 0.54, 0.18 * flicker)
	draw_circle(CAULDRON_POS + Vector2(0, 10), 54.0 * flicker, cauldron_col)
	draw_circle(Vector2(286, 62), 56.0 * flicker, Color(1.0, 0.58, 0.22, 0.12 * flicker))
	draw_circle(SANDBOX_DOOR_POS + Vector2(0, 18), 46.0 * flicker, Color(0.35, 0.95, 0.82, 0.10 * flicker))
