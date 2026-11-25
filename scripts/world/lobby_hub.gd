extends Node2D
## Moody 64x64 Pixel-Art Witch's Cottage + Large Outdoor Woodland Yard (`LobbyHub`):
##   1. **Upper Witch's Cottage (`x = 184..456, y = 20..224`)**:
##      - Top-Left Corner (`کمد هیرو`): `WardrobeSprite` (`218, 54`)
##      - Top-Center Wall (`در`): Wooden Oak Cottage Door `DoorStages` (`320, 38`)
##      - Top-Right Corner (`ویچ بدی`): `WitchSprite` (`422, 66`) + `CauldronSprite` (`394, 76`)
##      - Middle-Left Wall (`آتیش و مبل`): `LobbyFireplace` (`214, 124`) + `LobbySofa` (`232, 156`)
##      - Center (`محل اسپاون`): `SPAWN_POINT` (`320, 152`) on woven medallion rug
##      - South-Center Doorway (`x = 296..344`) opening straight into the Outdoor Yard!
##   2. **Large Outdoor Woodland Yard (`hayat` — `640x560` world, `y = 224..560`)**:
##      - **ZERO walls in the yard (`divar nazar ja divar derakht bezar`)**: dense pixel-art
##        Pine & Ancient Oak forest trees surround the cottage and step inward to carve a
##        cozy woodland clearing (`x ≈ 202..438, y ≈ 224..446`).
##      - **Upgraded 64x64 `TrainingDummy`** (`320, 338`) on a mossy stone courtyard ring.
##      - **Wooden Fence Gate (`DoorSandbox`)** (`236, 426`) flanked by rustic rail fences
##        & a wooden lantern post in the southwest corner of the clearing!
##   3. **Zero circular light overlays** — crisp pixel-art sprites & moody nocturnal atmosphere!

signal wardrobe_opened
signal cauldron_opened
signal potion_brewed_in_world(brewed_count: int)
signal enter_stages_requested
signal enter_sandbox_requested

const TrainingDummyScript := preload("res://scripts/enemies/training_dummy.gd")
const FLOOR_TEX_PATH := "res://assets/textures/cottage_floor.png"
const GRASS_TEX_PATH := "res://assets/textures/cottage_grass.png"
const TREES_TEX_PATH := "res://assets/textures/cottage_trees.png"
const FENCE_TEX_PATH := "res://assets/textures/cottage_fence_gate.png"
const RUGS_TEX_PATH := "res://assets/textures/cottage_rugs.png"
const WARDROBE_TEX_PATH := "res://assets/textures/lobby_wardrobe.png"
const DOOR_TEX_PATH := "res://assets/textures/lobby_door.png"
const WITCH_TEX_PATH := "res://assets/textures/lobby_witch.png"
const CAULDRON_TEX_PATH := "res://assets/textures/lobby_cauldron.png"
const POTION_TEX_PATH := "res://assets/textures/witch_potion.png"
const FIREPLACE_SOFA_TEX_PATH := "res://assets/textures/lobby_fireplace_sofa.png"

const LOBBY_BOUNDS := Rect2(0.0, 0.0, 640.0, 560.0)
const MAIN_ROOM_RECT := Rect2(184.0, 20.0, 272.0, 204.0)
const YARD_CLEARING_RECT := Rect2(202.0, 224.0, 236.0, 222.0)

const SPAWN_POINT := Vector2(320.0, 152.0)
const WARDROBE_POS := Vector2(218.0, 54.0)
const WARDROBE_EXIT_POS := Vector2(240.0, 84.0)
const STAGES_DOOR_POS := Vector2(320.0, 38.0)
const CAULDRON_POS := Vector2(394.0, 76.0)
const WITCH_POS := Vector2(422.0, 66.0)
const FIREPLACE_POS := Vector2(214.0, 124.0)
const SOFA_POS := Vector2(232.0, 156.0)
const DUMMY_POS := Vector2(320.0, 338.0)
const SANDBOX_DOOR_POS := Vector2(236.0, 426.0)
const SANDBOX_HOLD_DURATION: float = 3.0
const REAGENT_TEX_PATH := "res://assets/textures/witch_reagents.png"

var player_ref: Node2D = null
var interactions_enabled: bool = true
var dummy_instance: Node2D = null
var sandbox_hold_progress: float = 0.0

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
var _tree_frames: Array[AtlasTexture] = []
var _fence_frames: Array[AtlasTexture] = []
var _reagent_tex: Texture2D = null

var _cauldron_prompt: Label = null
var _cauldron_cooldown: float = 0.0
var _witch_offer_timer: float = 0.0
var _cauldron_fly_triggered_for_count: int = 0
var _sandbox_ring_fx: SandboxDoorRingFX = null

var _door_grace_timer: float = 0.45
var _anim_time: float = 0.0


class SandboxDoorRingFX extends Node2D:
	var ratio: float = 0.0
	var anim_t: float = 0.0

	func _process(delta: float) -> void:
		anim_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(anim_t * 4.5)
		draw_arc(Vector2.ZERO, 18.0 + pulse * 1.2, 0.0, TAU, 24, Color(0.45, 0.92, 0.80, 0.25), 1.3)
		if ratio <= 0.001:
			return
		draw_circle(Vector2.ZERO, 20.0, Color(0.03, 0.08, 0.14, 0.58))
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, Color(0.18, 0.34, 0.44, 0.82), 3.2)
		var end_ang := -PI * 0.5 + TAU * clampf(ratio, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 20.0, -PI * 0.5, end_ang, 36, Color(0.38, 1.0, 0.84, 0.98), 3.6)
		var font := ThemeDB.fallback_font
		if font != null:
			var secs_left := maxf(SANDBOX_HOLD_DURATION * (1.0 - ratio), 0.0)
			draw_string(font, Vector2(-18.0, 3.0), "%.1fs" % secs_left, HORIZONTAL_ALIGNMENT_CENTER, 36.0, 7, Color(0.94, 1.0, 0.96, 0.98))


class FlyingCauldronItemFX extends Node2D:
	var start_pos: Vector2 = Vector2.ZERO
	var target_pos: Vector2 = Vector2.ZERO
	var duration: float = 0.48
	var delay: float = 0.0
	var elapsed: float = 0.0
	var on_landed: Callable = Callable()

	func _ready() -> void:
		add_to_group("cauldron_flying_items")
		global_position = start_pos

	func _process(delta: float) -> void:
		if delay > 0.0:
			delay -= delta
			visible = false
			return
		visible = true
		elapsed += delta
		var t := clampf(elapsed / maxf(duration, 0.05), 0.0, 1.0)
		var mid := (start_pos + target_pos) * 0.5 + Vector2(0.0, -48.0)
		var p0 := start_pos.lerp(mid, t)
		var p1 := mid.lerp(target_pos, t)
		global_position = p0.lerp(p1, t)
		rotation = t * TAU * 1.2
		var sc := lerpf(0.95, 0.42, t * t)
		scale = Vector2(sc, sc)
		if t >= 1.0:
			if on_landed.is_valid():
				on_landed.call(target_pos)
			queue_free()


func _ready() -> void:
	if ResourceLoader.exists(REAGENT_TEX_PATH):
		_reagent_tex = load(REAGENT_TEX_PATH)
	_load_cottage_frames()
	_build_ground_and_rugs()
	_build_collision_bounds()
	_build_fireplace_and_sofa()
	_build_wardrobe()
	_build_cauldron_and_witch()
	_build_doors_and_yard_fence()
	_sandbox_ring_fx = SandboxDoorRingFX.new()
	_sandbox_ring_fx.name = "SandboxDoorRingFX"
	_sandbox_ring_fx.position = SANDBOX_DOOR_POS + Vector2(0.0, 2.0)
	_sandbox_ring_fx.z_index = 8
	add_child(_sandbox_ring_fx)
	_build_forest_trees()
	_spawn_training_dummy()


func activate_lobby(p: Node2D) -> void:
	visible = true
	player_ref = p
	interactions_enabled = true
	_door_grace_timer = 0.45
	sandbox_hold_progress = 0.0
	_cauldron_fly_triggered_for_count = 0
	if _sandbox_ring_fx != null:
		_sandbox_ring_fx.ratio = 0.0
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

	if ResourceLoader.exists(TREES_TEX_PATH):
		var tt: Texture2D = load(TREES_TEX_PATH)
		if tt != null:
			for i in range(2):
				var att := AtlasTexture.new()
				att.atlas = tt
				att.region = Rect2(float(i * 64), 0.0, 64.0, 96.0)
				_tree_frames.append(att)

	if ResourceLoader.exists(FENCE_TEX_PATH):
		var ft: Texture2D = load(FENCE_TEX_PATH)
		if ft != null:
			for i in range(2):
				var atfn := AtlasTexture.new()
				atfn.atlas = ft
				atfn.region = Rect2(float(i * 64), 0.0, 64.0, 48.0)
				_fence_frames.append(atfn)


func _build_ground_and_rugs() -> void:
	# Deep nocturnal woodland backdrop beyond camera edges
	var outer := ColorRect.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.position = Vector2(-240.0, -180.0)
	outer.size = LOBBY_BOUNDS.size + Vector2(480.0, 360.0)
	outer.color = Color(0.05, 0.09, 0.07, 1.0)
	outer.z_index = -16
	add_child(outer)

	# Large Outdoor Forest Yard Grass (`hayat`) spanning the entire 640x560 grounds!
	if ResourceLoader.exists(GRASS_TEX_PATH):
		var gtex: Texture2D = load(GRASS_TEX_PATH)
		if gtex != null:
			var yard_grass := TextureRect.new()
			yard_grass.name = "OutdoorYardGrass"
			yard_grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
			yard_grass.texture = gtex
			yard_grass.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			yard_grass.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			yard_grass.stretch_mode = TextureRect.STRETCH_TILE
			yard_grass.position = Vector2(-64.0, -32.0)
			yard_grass.size = LOBBY_BOUNDS.size + Vector2(128.0, 96.0)
			yard_grass.modulate = Color(0.88, 0.92, 0.90, 1.0)
			yard_grass.z_index = -14
			add_child(yard_grass)

	# Upper Witch's Cottage indoor oak plank floor ONLY (south area is open outdoor yard!)
	if ResourceLoader.exists(FLOOR_TEX_PATH):
		var ftex: Texture2D = load(FLOOR_TEX_PATH)
		if ftex != null:
			var floor_main := TextureRect.new()
			floor_main.name = "CottageFloor"
			floor_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
			floor_main.texture = ftex
			floor_main.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			floor_main.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			floor_main.stretch_mode = TextureRect.STRETCH_TILE
			floor_main.position = Vector2(196.0, 32.0)
			floor_main.size = Vector2(248.0, 180.0)
			floor_main.modulate = Color(0.84, 0.80, 0.88, 1.0)
			floor_main.z_index = -10
			add_child(floor_main)

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
			witch_rug.position = Vector2(412.0, 86.0)
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


func _build_collision_bounds() -> void:
	var walls := Node2D.new()
	walls.name = "Walls"
	add_child(walls)

	# Upper Cottage timber walls + Outdoor Forest Tree-Line & Fence-Line collision!
	# (ZERO walls in the yard — the yard is enclosed purely by dense forest trees & the rustic fence!)
	var rects: Array[Rect2] = [
		# Upper Cottage Room (`x = 184..456, y = 20..224`, south doorway gap `x = 296..344`)
		Rect2(184.0, 20.0, 272.0, 14.0),    # Cottage North wall
		Rect2(184.0, 20.0, 12.0, 204.0),    # Cottage West wall
		Rect2(444.0, 20.0, 12.0, 204.0),    # Cottage East wall
		Rect2(184.0, 212.0, 112.0, 12.0),   # Cottage South-Left wall (x=184..296)
		Rect2(344.0, 212.0, 112.0, 12.0),   # Cottage South-Right wall (x=344..456)
		# Cottage indoor furniture bases
		Rect2(384.0, 74.0, 20.0, 12.0),     # Cauldron solid pot base
		Rect2(204.0, 122.0, 22.0, 18.0),    # Fireplace solid base
		Rect2(220.0, 152.0, 24.0, 14.0),    # Sofa solid base
		# Outdoor Forest Tree-Line & Fence-Line natural bounds (`ba derakht mohavate ro kochik kon`)
		Rect2(0.0, 216.0, 202.0, 344.0),    # West woodland tree-line narrowing the yard
		Rect2(438.0, 216.0, 202.0, 344.0),  # East woodland tree-line narrowing the yard
		Rect2(198.0, 444.0, 244.0, 116.0),  # South woodland tree-line & fence boundary
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

	_cauldron_prompt = _make_sign_label("[F] Skill Tree", Color(0.55, 1.0, 0.74), 7)
	_cauldron_prompt.position = CAULDRON_POS + Vector2(-62.0, 14.0)
	_cauldron_prompt.size = Vector2(126.0, 12.0)
	_cauldron_prompt.visible = false
	add_child(_cauldron_prompt)


func _build_doors_and_yard_fence() -> void:
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

	# 2. Southwest Yard Wooden Fence Gate (`سندباکس` -> SANDBOX, `shabih fence gate`!)
	if not _fence_frames.is_empty():
		var fence_l := Sprite2D.new()
		fence_l.name = "SandboxFenceLeft"
		fence_l.texture = _fence_frames[0]
		fence_l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fence_l.position = SANDBOX_DOOR_POS + Vector2(-32.0, 3.0)
		fence_l.scale = Vector2(0.54, 0.54)
		add_child(fence_l)

		var fence_r := Sprite2D.new()
		fence_r.name = "SandboxFenceRight"
		fence_r.texture = _fence_frames[0]
		fence_r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fence_r.position = SANDBOX_DOOR_POS + Vector2(32.0, 3.0)
		fence_r.scale = Vector2(0.54, 0.54)
		add_child(fence_r)

		if _fence_frames.size() >= 2:
			var lamp := Sprite2D.new()
			lamp.name = "YardLanternPost"
			lamp.texture = _fence_frames[1]
			lamp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			lamp.position = SANDBOX_DOOR_POS + Vector2(54.0, -4.0)
			lamp.scale = Vector2(0.62, 0.62)
			add_child(lamp)

	var sb_sp := Sprite2D.new()
	sb_sp.name = "DoorSandbox"
	sb_sp.position = SANDBOX_DOOR_POS
	sb_sp.scale = Vector2(0.62, 0.62)
	sb_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if door_tex != null:
		var at1 := AtlasTexture.new()
		at1.atlas = door_tex
		at1.region = Rect2(64.0, 0.0, 64.0, 64.0)
		sb_sp.texture = at1
	add_child(sb_sp)

	var sb_lbl := _make_sign_label("SANDBOX", Color(0.66, 0.96, 0.84), 7)
	sb_lbl.name = "SandboxSign"
	sb_lbl.position = SANDBOX_DOOR_POS + Vector2(-38.0, -25.0)
	sb_lbl.size = Vector2(76.0, 12.0)
	add_child(sb_lbl)


func _build_forest_trees() -> void:
	var forest := Node2D.new()
	forest.name = "ForestTrees"
	forest.y_sort_enabled = true
	add_child(forest)

	if _tree_frames.is_empty():
		return

	# Dense pixel-art woodland surrounding the Witch's Cottage and stepping inward
	# (`ba derakht mohavate ro kochik kon divar nazar ja divar derakht bezar`)
	# to frame the outdoor yard clearing (`x ≈ 202..438, y ≈ 224..446`)!
	var tree_spots: Array[Vector3] = [
		# Outer woods flanking the upper Cottage (x < 174 and x > 466)
		Vector3(38, 62, 0), Vector3(96, 48, 1), Vector3(148, 72, 0),
		Vector3(492, 68, 1), Vector3(546, 50, 0), Vector3(602, 66, 1),
		Vector3(28, 132, 1), Vector3(84, 124, 0), Vector3(142, 144, 1),
		Vector3(496, 138, 0), Vector3(556, 126, 1), Vector3(610, 142, 0),
		Vector3(42, 198, 0), Vector3(102, 192, 1), Vector3(154, 206, 0),
		Vector3(486, 204, 1), Vector3(544, 194, 0), Vector3(604, 202, 1),

		# West forest wall stepping inward to narrow the Outdoor Yard (`x <= 186`)
		Vector3(32, 258, 1), Vector3(92, 250, 0), Vector3(146, 246, 1), Vector3(184, 252, 0),
		Vector3(26, 316, 0), Vector3(82, 310, 1), Vector3(138, 304, 0), Vector3(182, 308, 1),
		Vector3(36, 376, 1), Vector3(94, 372, 0), Vector3(144, 366, 1), Vector3(184, 370, 0),
		Vector3(28, 438, 0), Vector3(86, 434, 1), Vector3(140, 428, 0), Vector3(180, 430, 1),

		# East forest wall stepping inward to narrow the Outdoor Yard (`x >= 454`)
		Vector3(456, 250, 1), Vector3(500, 246, 0), Vector3(556, 254, 1), Vector3(610, 260, 0),
		Vector3(458, 308, 0), Vector3(506, 304, 1), Vector3(562, 312, 0), Vector3(614, 318, 1),
		Vector3(456, 368, 1), Vector3(502, 366, 0), Vector3(558, 374, 1), Vector3(608, 380, 0),
		Vector3(454, 428, 0), Vector3(500, 432, 1), Vector3(554, 438, 0), Vector3(612, 442, 1),

		# South deep forest canopy below the Fence Gate & Clearing (`y >= 468`)
		Vector3(44, 496, 1), Vector3(104, 490, 0), Vector3(164, 486, 1),
		Vector3(222, 492, 0), Vector3(294, 492, 1), Vector3(346, 480, 0), Vector3(398, 482, 1), Vector3(448, 486, 0),
		Vector3(504, 490, 1), Vector3(562, 494, 0), Vector3(614, 498, 1),
		Vector3(72, 542, 0), Vector3(142, 538, 1), Vector3(210, 544, 1), Vector3(276, 536, 0),
		Vector3(344, 540, 1), Vector3(412, 536, 0), Vector3(480, 542, 1), Vector3(548, 538, 0),
	]

	for idx in tree_spots.size():
		var info := tree_spots[idx]
		var sp := Sprite2D.new()
		sp.name = "Tree_%d" % idx
		var frame_idx := int(info.z) % _tree_frames.size()
		sp.texture = _tree_frames[frame_idx]
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.position = Vector2(info.x, info.y)
		sp.offset = Vector2(0.0, -34.0) # anchor at trunk roots for clean y-sorting
		var sc := 0.80 if (idx % 3 == 0) else (0.72 if (idx % 2 == 0) else 0.76)
		sp.scale = Vector2(sc * (-1.0 if (idx % 4 == 1) else 1.0), sc)
		sp.modulate = Color(0.90, 0.95, 0.92, 1.0) if (idx % 2 == 0) else Color(0.80, 0.88, 0.86, 1.0)
		if info.y > 460.0:
			sp.z_index = 6
		forest.add_child(sp)


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


func trigger_cauldron_item_fly_animation(from_world_pos: Vector2, visual_count: int = -1) -> int:
	var held := WitchCauldronProgression.get_reagents()
	var count := visual_count if visual_count > 0 else mini(held, 12)
	if count <= 0:
		return 0
	var target := CAULDRON_POS + Vector2(0.0, -4.0)
	for i in range(count):
		var flyer := FlyingCauldronItemFX.new()
		flyer.start_pos = from_world_pos + Vector2(randf_range(-5.0, 5.0), -10.0)
		flyer.target_pos = target + Vector2(randf_range(-4.0, 4.0), 0.0)
		flyer.delay = float(i) * 0.06
		flyer.duration = 0.44
		flyer.z_index = 26
		if i == count - 1:
			flyer.on_landed = Callable(self, "_on_last_reagent_landed_in_cauldron")
		else:
			flyer.on_landed = Callable(self, "_spawn_cauldron_splash")

		var sp := Sprite2D.new()
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.scale = Vector2(0.55, 0.55)
		if _reagent_tex != null:
			var at := AtlasTexture.new()
			at.atlas = _reagent_tex
			at.region = Rect2(float((i % 3) * 32), 0.0, 32.0, 32.0)
			sp.texture = at
		flyer.add_child(sp)
		add_child(flyer)
	return count


func _spawn_cauldron_splash(at_pos: Vector2) -> void:
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(0.56, 1.0, 0.72, 0.92)
	var pts := PackedVector2Array()
	for i in range(13):
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a) * 8.0, sin(a) * 4.5))
	ring.points = pts
	ring.z_index = 24
	add_child(ring)
	ring.global_position = at_pos
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(2.1, 2.1), 0.20)
	tw.tween_property(ring, "modulate:a", 0.0, 0.20)
	tw.chain().tween_callback(ring.queue_free)


func _on_last_reagent_landed_in_cauldron(at_pos: Vector2) -> void:
	_spawn_cauldron_splash(at_pos)
	var brewed := WitchCauldronProgression.brew_all_potions_for_hero(CharacterRegistry.selected_id)
	if brewed > 0 and player_ref != null and is_instance_valid(player_ref):
		play_world_potion_handoff(player_ref, true)
		potion_brewed_in_world.emit(brewed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not interactions_enabled or player_ref == null or not is_instance_valid(player_ref):
		return

	var ppos := player_ref.global_position
	var near_cauldron := ppos.distance_to(CAULDRON_POS) <= 44.0
	var near_wardrobe := ppos.distance_to(WARDROBE_POS) <= 42.0

	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_B and near_cauldron:
			if WitchCauldronProgression.brew_potion_for_hero(CharacterRegistry.selected_id):
				play_world_potion_handoff(player_ref, true)
				potion_brewed_in_world.emit(1)
				get_viewport().set_input_as_handled()
				return
		if k in [KEY_F, KEY_E, KEY_C, KEY_ENTER]:
			if near_cauldron and _cauldron_cooldown <= 0.0:
				var brewed := WitchCauldronProgression.brew_all_potions_for_hero(CharacterRegistry.selected_id)
				if brewed > 0:
					play_world_potion_handoff(player_ref, true)
					potion_brewed_in_world.emit(brewed)
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
		var cur_herbs := WitchCauldronProgression.get_reagents()
		if dist_c > 76.0:
			_cauldron_fly_triggered_for_count = 0
		elif dist_c <= 54.0 and cur_herbs > 0 and _cauldron_fly_triggered_for_count != cur_herbs:
			_cauldron_fly_triggered_for_count = cur_herbs
			trigger_cauldron_item_fly_animation(ppos)

		if _cauldron_prompt != null:
			var near_c := (dist_c <= 46.0)
			_cauldron_prompt.visible = near_c
			if near_c:
				var herbs := WitchCauldronProgression.get_reagents()
				if herbs >= WitchCauldronProgression.REAGENTS_PER_POTION:
					_cauldron_prompt.text = "[B] Brew Majon | [F] Tree"
					_cauldron_prompt.add_theme_color_override("font_color", Color(0.92, 0.68, 1.0))
				else:
					_cauldron_prompt.text = "[F] Tree (%d/%d Herbs)" % [herbs, WitchCauldronProgression.REAGENTS_PER_POTION]
					_cauldron_prompt.add_theme_color_override("font_color", Color(0.55, 1.0, 0.74))

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
				sandbox_hold_progress = 0.0
				if _sandbox_ring_fx != null:
					_sandbox_ring_fx.ratio = 0.0
				enter_stages_requested.emit()
				return
			if ppos.distance_to(SANDBOX_DOOR_POS + Vector2(0.0, 2.0)) <= 26.0:
				sandbox_hold_progress = minf(sandbox_hold_progress + delta, SANDBOX_HOLD_DURATION)
				if _sandbox_ring_fx != null:
					_sandbox_ring_fx.ratio = sandbox_hold_progress / SANDBOX_HOLD_DURATION
				if sandbox_hold_progress >= SANDBOX_HOLD_DURATION:
					sandbox_hold_progress = 0.0
					if _sandbox_ring_fx != null:
						_sandbox_ring_fx.ratio = 0.0
					_door_grace_timer = 0.8
					enter_sandbox_requested.emit()
					return
			else:
				sandbox_hold_progress = maxf(sandbox_hold_progress - delta * 2.2, 0.0)
				if _sandbox_ring_fx != null:
					_sandbox_ring_fx.ratio = sandbox_hold_progress / SANDBOX_HOLD_DURATION
		else:
			sandbox_hold_progress = 0.0
			if _sandbox_ring_fx != null:
				_sandbox_ring_fx.ratio = 0.0


func _draw() -> void:
	# North stone wainscoting strip along top wall of the Witch's Cottage
	draw_rect(Rect2(196, 34, 248, 20), Color(0.14, 0.11, 0.18, 0.96), true)
	draw_line(Vector2(196, 54), Vector2(444, 54), Color(0.28, 0.17, 0.12), 2.0)

	# Dark timber perimeter walls ONLY for the upper Witch's Cottage (`y = 20..224`)!
	# (The south area is an open outdoor woodland yard with trees instead of walls!)
	var wall_fill := Color(0.18, 0.11, 0.08)
	var wall_trim := Color(0.30, 0.19, 0.13)
	for r in [
		Rect2(184, 20, 272, 14),    # Cottage North wall
		Rect2(184, 20, 12, 204),    # Cottage West wall
		Rect2(444, 20, 12, 204),    # Cottage East wall
		Rect2(184, 212, 112, 12),   # Cottage South-Left wall
		Rect2(344, 212, 112, 12),   # Cottage South-Right wall
	]:
		draw_rect(r, wall_fill, true)
		draw_rect(r, wall_trim, false, 1.0)

	# Cottage front porch timber threshold + mossy flagstone garden path into the Outdoor Yard!
	draw_rect(Rect2(296, 213, 48, 11), Color(0.24, 0.15, 0.10), true)
	draw_rect(Rect2(296, 213, 48, 11), wall_trim, false, 1.0)

	var stone_dark := Color(0.16, 0.18, 0.19, 0.92)
	var stone_mid := Color(0.25, 0.28, 0.29, 0.92)
	for stone in [
		Rect2(304, 228, 32, 10),
		Rect2(308, 244, 24, 9),
		Rect2(306, 260, 26, 9),
		Rect2(310, 276, 22, 9),
		Rect2(307, 293, 25, 9),
		Rect2(309, 310, 22, 8),
		# Sparring stone slab pad under the Training Dummy
		Rect2(298, 328, 44, 22),
		# Stepping stones branching SW to the Sandbox Wooden Fence Gate
		Rect2(288, 360, 20, 8),
		Rect2(270, 376, 18, 8),
		Rect2(252, 392, 18, 8),
		Rect2(236, 408, 20, 8),
	]:
		draw_rect(stone, stone_dark, true)
		draw_rect(stone.grow(-1.0), stone_mid, true)
