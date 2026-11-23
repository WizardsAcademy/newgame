extends Node2D
## Moody 64x64 Pixel-Art Witch's Cottage Hub (`LobbyHub`) — built 1:1 from the
## two-room cottage reference map:
##   1. **Main Square Cottage Room (`x = 48..320, y = 20..224`)**:
##      - Top-Left Corner (`کمد هیرو`): `WardrobeSprite` (`84, 56`)
##      - Top-Center Wall (`در`): Real Wooden Oak Door `DoorStages` (`184, 42`)
##      - Top-Right Corner (`ویچ بدی`): `WitchSprite` (`286, 68`) + `CauldronSprite` (`258, 78`)
##      - Middle-Left Wall (`آتیش و مبل`): `FireplaceSprite` (`80, 126`) + `SofaSprite` (`96, 156`)
##      - Center (`محل اسپاون`): `SPAWN_POINT` (`184, 152`) on woven medallion rug
##      - South-Center Doorway (`x = 156..212`) leading into the smaller South Room
##   2. **Attached Narrower South Room (`x = 108..260, y = 224..344`)**:
##      - Center (`دامی تارگت`): `TrainingDummy` (`184, 282`)
##      - Bottom-Left Corner (`سندباکس`): Wooden Cottage Door `DoorSandbox` (`136, 318`)
##   3. **Zero circular light overlays** — crisp pixel-art sprites & moody dim cottage tone!

signal wardrobe_opened
signal cauldron_opened
signal enter_stages_requested
signal enter_sandbox_requested

const TrainingDummyScript := preload("res://scripts/enemies/training_dummy.gd")
const FLOOR_TEX_PATH := "res://assets/textures/cottage_floor.png"
const RUGS_TEX_PATH := "res://assets/textures/cottage_rugs.png"
const WARDROBE_TEX_PATH := "res://assets/textures/lobby_wardrobe.png"
const DOOR_TEX_PATH := "res://assets/textures/lobby_door.png"
const WITCH_TEX_PATH := "res://assets/textures/lobby_witch.png"
const CAULDRON_TEX_PATH := "res://assets/textures/lobby_cauldron.png"
const POTION_TEX_PATH := "res://assets/textures/witch_potion.png"
const FIREPLACE_SOFA_TEX_PATH := "res://assets/textures/lobby_fireplace_sofa.png"

const LOBBY_BOUNDS := Rect2(0.0, 0.0, 368.0, 360.0)
const MAIN_ROOM_RECT := Rect2(48.0, 20.0, 272.0, 204.0)
const SOUTH_ROOM_RECT := Rect2(108.0, 224.0, 152.0, 120.0)

const SPAWN_POINT := Vector2(184.0, 152.0)
const WARDROBE_POS := Vector2(82.0, 54.0)
const WARDROBE_EXIT_POS := Vector2(104.0, 84.0)
const STAGES_DOOR_POS := Vector2(184.0, 38.0)
const CAULDRON_POS := Vector2(258.0, 76.0)
const WITCH_POS := Vector2(286.0, 66.0)
const FIREPLACE_POS := Vector2(78.0, 124.0)
const SOFA_POS := Vector2(96.0, 156.0)
const DUMMY_POS := Vector2(184.0, 280.0)
const SANDBOX_DOOR_POS := Vector2(134.0, 316.0)

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
var _fireplace_sprite: Sprite2D = null
var _sofa_sprite: Sprite2D = null

var _witch_frames: Array[AtlasTexture] = []
var _cauldron_frames: Array[AtlasTexture] = []
var _potion_frames: Array[AtlasTexture] = []
var _fireplace_frames: Array[AtlasTexture] = []

var _cauldron_prompt: Label = null
var _cauldron_cooldown: float = 0.0
var _witch_offer_timer: float = 0.0

var _door_grace_timer: float = 0.45
var _anim_time: float = 0.0


func _ready() -> void:
	_load_cottage_frames()
	_build_textured_floors_and_rugs()
	_build_collision_walls()
	_build_fireplace_and_sofa()
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


func _load_cottage_frames() -> void:
	if ResourceLoader.exists(WITCH_TEX_PATH):
		var wt: Texture2D = load(WITCH_TEX_PATH)
		if wt != null:
			for i in range(4):
				var at := AtlasTexture.new()
				at.atlas = wt
				at.region = Rect2(float(i * 64), 0.0, 64.0, 64.0)
				_witch_frames.append(at)

	if ResourceLoader.exists(CAULDRON_TEX_PATH):
		var ct: Texture2D = load(CAULDRON_TEX_PATH)
		if ct != null:
			for i in range(6):
				var atc := AtlasTexture.new()
				atc.atlas = ct
				atc.region = Rect2(float(i * 48), 0.0, 48.0, 48.0)
				_cauldron_frames.append(atc)

	if ResourceLoader.exists(POTION_TEX_PATH):
		var pt: Texture2D = load(POTION_TEX_PATH)
		if pt != null:
			for i in range(2):
				var atp := AtlasTexture.new()
				atp.atlas = pt
				atp.region = Rect2(float(i * 32), 0.0, 32.0, 32.0)
				_potion_frames.append(atp)

	if ResourceLoader.exists(FIREPLACE_SOFA_TEX_PATH):
		var fst: Texture2D = load(FIREPLACE_SOFA_TEX_PATH)
		if fst != null:
			for i in range(3):
				var atf := AtlasTexture.new()
				atf.atlas = fst
				atf.region = Rect2(float(i * 64), 0.0, 64.0, 64.0)
				_fireplace_frames.append(atf)


func _build_textured_floors_and_rugs() -> void:
	# Deep nocturnal twilight outside the two-room cottage
	var outer := ColorRect.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.position = Vector2(-240.0, -180.0)
	outer.size = LOBBY_BOUNDS.size + Vector2(480.0, 360.0)
	outer.color = Color(0.03, 0.025, 0.05, 1.0)
	outer.z_index = -14
	add_child(outer)

	if ResourceLoader.exists(FLOOR_TEX_PATH):
		var ftex: Texture2D = load(FLOOR_TEX_PATH)

		# Main Square Room oak floor (moody dim cottage tone!)
		var floor_main := TextureRect.new()
		floor_main.name = "CottageFloor"
		floor_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
		floor_main.texture = ftex
		floor_main.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		floor_main.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		floor_main.stretch_mode = TextureRect.STRETCH_TILE
		floor_main.position = Vector2(60.0, 32.0)
		floor_main.size = Vector2(248.0, 180.0)
		floor_main.modulate = Color(0.84, 0.80, 0.88, 1.0)
		floor_main.z_index = -10
		add_child(floor_main)

		# Threshold + Narrower South Dummy Room oak floor
		var floor_south := TextureRect.new()
		floor_south.name = "CottageFloorSouth"
		floor_south.mouse_filter = Control.MOUSE_FILTER_IGNORE
		floor_south.texture = ftex
		floor_south.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		floor_south.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		floor_south.stretch_mode = TextureRect.STRETCH_TILE
		floor_south.position = Vector2(120.0, 212.0)
		floor_south.size = Vector2(128.0, 120.0)
		floor_south.modulate = Color(0.78, 0.75, 0.84, 1.0)
		floor_south.z_index = -10
		add_child(floor_south)

	if ResourceLoader.exists(RUGS_TEX_PATH):
		var rtex: Texture2D = load(RUGS_TEX_PATH)
		if rtex != null:
			# Spawn Medallion Rug (`محل اسپاون`)
			var spawn_rug := Sprite2D.new()
			spawn_rug.name = "SpawnRug"
			var ar0 := AtlasTexture.new()
			ar0.atlas = rtex
			ar0.region = Rect2(0.0, 0.0, 64.0, 64.0)
			spawn_rug.texture = ar0
			spawn_rug.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spawn_rug.position = SPAWN_POINT + Vector2(0.0, 4.0)
			spawn_rug.scale = Vector2(0.75, 0.75)
			spawn_rug.modulate = Color(0.86, 0.82, 0.90, 1.0)
			spawn_rug.z_index = -8
			add_child(spawn_rug)

			# Top-Right Witch Alchemy Corner Rug (`ویچ بدی`)
			var witch_rug := Sprite2D.new()
			witch_rug.name = "WitchCornerRug"
			var ar1 := AtlasTexture.new()
			ar1.atlas = rtex
			ar1.region = Rect2(64.0, 0.0, 64.0, 64.0)
			witch_rug.texture = ar1
			witch_rug.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			witch_rug.flip_h = true
			witch_rug.position = Vector2(276.0, 86.0)
			witch_rug.scale = Vector2(1.0, 1.0)
			witch_rug.modulate = Color(0.86, 0.82, 0.92, 1.0)
			witch_rug.z_index = -8
			add_child(witch_rug)


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

	# Exact two-room T-shaped cottage walls matching the hand-drawn blueprint:
	#   Main Room:  x=48..320, y=20..224 (doorway gap x=160..208 at y=212..224)
	#   South Room: x=108..260, y=224..344
	var rects: Array[Rect2] = [
		Rect2(48.0, 20.0, 272.0, 14.0),    # Main North wall
		Rect2(48.0, 20.0, 12.0, 204.0),    # Main West wall
		Rect2(308.0, 20.0, 12.0, 204.0),   # Main East wall
		Rect2(48.0, 212.0, 112.0, 12.0),   # Main South-Left wall (x=48..160)
		Rect2(208.0, 212.0, 112.0, 12.0),  # Main South-Right wall (x=208..320)
		Rect2(108.0, 224.0, 12.0, 120.0),  # South Room West wall
		Rect2(248.0, 224.0, 12.0, 120.0),  # South Room East wall
		Rect2(108.0, 332.0, 152.0, 12.0),  # South Room Bottom wall
		Rect2(248.0, 74.0, 20.0, 12.0),    # Cauldron solid pot base
		Rect2(68.0, 122.0, 22.0, 18.0),    # Stone fireplace solid base
		Rect2(84.0, 152.0, 24.0, 14.0),    # Sofa solid base
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


func _build_fireplace_and_sofa() -> void:
	# Middle-Left Wall: Stone Fireplace (`آتیش`) + Cozy Sofa (`مبل`)!
	_fireplace_sprite = Sprite2D.new()
	_fireplace_sprite.name = "LobbyFireplace"
	_fireplace_sprite.position = FIREPLACE_POS
	_fireplace_sprite.scale = Vector2(0.55, 0.55)
	_fireplace_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not _fireplace_frames.is_empty():
		_fireplace_sprite.texture = _fireplace_frames[0]
	add_child(_fireplace_sprite)

	_sofa_sprite = Sprite2D.new()
	_sofa_sprite.name = "LobbySofa"
	_sofa_sprite.position = SOFA_POS
	_sofa_sprite.scale = Vector2(0.52, 0.52)
	_sofa_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _fireplace_frames.size() >= 3:
		_sofa_sprite.texture = _fireplace_frames[2]
	add_child(_sofa_sprite)


func _build_wardrobe() -> void:
	# Top-Left Corner (`کمد هیرو`)
	_wardrobe_sprite = Sprite2D.new()
	_wardrobe_sprite.name = "WardrobeSprite"
	_wardrobe_sprite.position = WARDROBE_POS
	_wardrobe_sprite.scale = Vector2(0.54, 0.54)
	_wardrobe_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_wardrobe_sprite)

	if ResourceLoader.exists(WARDROBE_TEX_PATH):
		var sheet: Texture2D = load(WARDROBE_TEX_PATH)
		if sheet != null:
			for i in range(2):
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(float(i * 64), 0.0, 64.0, 64.0)
				_wardrobe_frames.append(at)
			if not _wardrobe_frames.is_empty():
				_wardrobe_sprite.texture = _wardrobe_frames[0]

	var title := _make_sign_label("HEROES", Color(0.94, 0.84, 0.54), 7)
	title.position = WARDROBE_POS + Vector2(-36.0, -26.0)
	title.size = Vector2(72.0, 12.0)
	add_child(title)

	_wardrobe_prompt = _make_sign_label("[F] Heroes", Color(0.72, 0.98, 0.82), 7)
	_wardrobe_prompt.position = WARDROBE_POS + Vector2(-40.0, 18.0)
	_wardrobe_prompt.size = Vector2(80.0, 12.0)
	_wardrobe_prompt.visible = false
	add_child(_wardrobe_prompt)


func _build_cauldron_and_witch() -> void:
	# Top-Right Corner (`ویچ بدی`): 64x64 Witch Baddie + 48x48 Green->Purple Cauldron!
	_witch_sprite = Sprite2D.new()
	_witch_sprite.name = "WitchSprite"
	_witch_sprite.position = WITCH_POS
	_witch_sprite.scale = Vector2(0.5, 0.5)
	_witch_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not _witch_frames.is_empty():
		_witch_sprite.texture = _witch_frames[0]
	add_child(_witch_sprite)

	_cauldron_sprite = Sprite2D.new()
	_cauldron_sprite.name = "CauldronSprite"
	_cauldron_sprite.position = CAULDRON_POS
	_cauldron_sprite.scale = Vector2(0.5, 0.5)
	_cauldron_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not _cauldron_frames.is_empty():
		_cauldron_sprite.texture = _cauldron_frames[0]
	add_child(_cauldron_sprite)

	var ctitle := _make_sign_label("WITCH", Color(0.88, 0.68, 1.0), 7)
	ctitle.position = WITCH_POS + Vector2(-42.0, -28.0)
	ctitle.size = Vector2(68.0, 12.0)
	add_child(ctitle)

	_cauldron_prompt = _make_sign_label("[F] Brew", Color(0.55, 1.0, 0.74), 7)
	_cauldron_prompt.position = CAULDRON_POS + Vector2(-36.0, 14.0)
	_cauldron_prompt.size = Vector2(76.0, 12.0)
	_cauldron_prompt.visible = false
	add_child(_cauldron_prompt)


func _build_doors() -> void:
	var door_tex: Texture2D = load(DOOR_TEX_PATH) if ResourceLoader.exists(DOOR_TEX_PATH) else null

	# 1. Top-Center Wooden Cottage Door (`در` -> STAGES)
	var stages_sp := Sprite2D.new()
	stages_sp.name = "DoorStages"
	stages_sp.position = STAGES_DOOR_POS
	stages_sp.scale = Vector2(0.56, 0.56)
	stages_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if door_tex != null:
		var at0 := AtlasTexture.new()
		at0.atlas = door_tex
		at0.region = Rect2(0.0, 0.0, 64.0, 64.0)
		stages_sp.texture = at0
	add_child(stages_sp)

	var stages_lbl := _make_sign_label("STAGES", Color(0.96, 0.84, 0.48), 7)
	stages_lbl.position = STAGES_DOOR_POS + Vector2(-36.0, -26.0)
	stages_lbl.size = Vector2(72.0, 12.0)
	add_child(stages_lbl)

	# 2. South-Room Bottom-Left Corner Wooden Cottage Door (`سندباکس` -> SANDBOX)
	var sb_sp := Sprite2D.new()
	sb_sp.name = "DoorSandbox"
	sb_sp.position = SANDBOX_DOOR_POS
	sb_sp.scale = Vector2(0.52, 0.52)
	sb_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if door_tex != null:
		var at1 := AtlasTexture.new()
		at1.atlas = door_tex
		at1.region = Rect2(64.0, 0.0, 64.0, 64.0)
		sb_sp.texture = at1
	add_child(sb_sp)

	var sb_lbl := _make_sign_label("SANDBOX", Color(0.62, 0.94, 0.84), 7)
	sb_lbl.name = "SandboxSign"
	sb_lbl.position = SANDBOX_DOOR_POS + Vector2(-38.0, -25.0)
	sb_lbl.size = Vector2(76.0, 12.0)
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
	vial.scale = Vector2(0.5, 0.5)
	vial.z_index = 25
	vial.global_position = WITCH_POS + Vector2(-8.0, -2.0)
	add_child(vial)

	var target := hero.global_position + Vector2(0.0, -10.0)
	var mid := (vial.global_position + target) * 0.5 + Vector2(0.0, -18.0)

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
	var near_cauldron := ppos.distance_to(CAULDRON_POS) <= 44.0
	var near_wardrobe := ppos.distance_to(WARDROBE_POS) <= 42.0

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
		if mpos.distance_to(CAULDRON_POS) <= 28.0 and _cauldron_cooldown <= 0.0:
			cauldron_opened.emit()
			get_viewport().set_input_as_handled()
			return
		if mpos.distance_to(WARDROBE_POS) <= 28.0 and _wardrobe_cooldown <= 0.0:
			wardrobe_opened.emit()
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	if not visible:
		return
	_anim_time += delta
	if _wardrobe_cooldown > 0.0:
		_wardrobe_cooldown = maxf(_wardrobe_cooldown - delta, 0.0)
	if _cauldron_cooldown > 0.0:
		_cauldron_cooldown = maxf(_cauldron_cooldown - delta, 0.0)
	if _door_grace_timer > 0.0:
		_door_grace_timer = maxf(_door_grace_timer - delta, 0.0)

	# 1. Crackling Pixel-Art Fireplace (2-frame toggle, ZERO circular light!)
	if _fireplace_sprite != null and _fireplace_frames.size() >= 2:
		var fstep := int(_anim_time * 5.0) % 2
		_fireplace_sprite.texture = _fireplace_frames[fstep]

	# 2. 64x64 Pretty Baddie Witch (idle, wink, magic, potion offer)
	if _witch_sprite != null and _witch_frames.size() >= 4:
		if _witch_offer_timer > 0.0:
			_witch_offer_timer = maxf(_witch_offer_timer - delta, 0.0)
			_witch_sprite.texture = _witch_frames[3]
		else:
			var cyc := fmod(_anim_time, 4.4)
			var widx := 0
			if cyc > 3.9:
				widx = 1
			elif cyc > 2.2 and cyc < 2.85:
				widx = 2
			_witch_sprite.texture = _witch_frames[widx]

	# 3. 48x48 Cauldron: green bubbling liquid -> SUDDENLY turns purple!
	if _cauldron_sprite != null and _cauldron_frames.size() >= 6:
		var seq: Array[int] = [0, 1, 2, 0, 1, 2, 1, 3, 4, 4, 5]
		var step := int(_anim_time * 3.5) % seq.size()
		_cauldron_sprite.texture = _cauldron_frames[seq[step]]

	if player_ref != null and is_instance_valid(player_ref) and interactions_enabled:
		var ppos := player_ref.global_position
		var dist_w := ppos.distance_to(WARDROBE_POS)
		var near_w := dist_w <= 42.0
		if _wardrobe_prompt != null:
			_wardrobe_prompt.visible = near_w
		if _wardrobe_sprite != null and _wardrobe_frames.size() >= 2:
			_wardrobe_sprite.texture = _wardrobe_frames[1 if near_w else 0]

		var dist_c := ppos.distance_to(CAULDRON_POS)
		if _cauldron_prompt != null:
			_cauldron_prompt.visible = (dist_c <= 44.0)

		if dist_w <= 20.0:
			if not _was_inside_wardrobe and _wardrobe_cooldown <= 0.0:
				_was_inside_wardrobe = true
				wardrobe_opened.emit()
				return
		elif dist_w > 30.0:
			_was_inside_wardrobe = false

		if _door_grace_timer <= 0.0:
			if ppos.distance_to(STAGES_DOOR_POS + Vector2(0.0, 10.0)) <= 20.0:
				_door_grace_timer = 0.8
				enter_stages_requested.emit()
				return
			if ppos.distance_to(SANDBOX_DOOR_POS + Vector2(0.0, 4.0)) <= 20.0:
				_door_grace_timer = 0.8
				enter_sandbox_requested.emit()
				return


func _draw() -> void:
	# North stone wainscoting strip along top wall of Main Cottage Room
	draw_rect(Rect2(60, 34, 248, 20), Color(0.14, 0.11, 0.18, 0.96), true)
	draw_line(Vector2(60, 54), Vector2(308, 54), Color(0.28, 0.17, 0.12), 2.0)

	# Dark timber cottage perimeter beams for the two-room T-shaped Cottage
	# (ZERO draw_circle light halos!)
	var wall_fill := Color(0.18, 0.11, 0.08)
	var wall_trim := Color(0.30, 0.19, 0.13)
	for r in [
		Rect2(48, 20, 272, 14),    # Main North wall
		Rect2(48, 20, 12, 204),    # Main West wall
		Rect2(308, 20, 12, 204),   # Main East wall
		Rect2(48, 212, 112, 12),   # Main South-Left wall
		Rect2(208, 212, 112, 12),  # Main South-Right wall
		Rect2(108, 224, 12, 120),  # South Room West wall
		Rect2(248, 224, 12, 120),  # South Room East wall
		Rect2(108, 332, 152, 12),  # South Room Bottom wall
	]:
		draw_rect(r, wall_fill, true)
		draw_rect(r, wall_trim, false, 1.0)

	# Timber threshold step between Main Cottage Room & South Dummy Room (`160..208`)
	draw_rect(Rect2(160, 213, 48, 10), Color(0.24, 0.15, 0.10), true)
	draw_line(Vector2(160, 213), Vector2(208, 213), wall_trim, 1.0)
	draw_line(Vector2(160, 223), Vector2(208, 223), wall_trim, 1.0)
