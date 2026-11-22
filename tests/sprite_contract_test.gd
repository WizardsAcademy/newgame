extends Node
## Headless sprite & art-contract verification suite for all playable heroes.
##
## Run from the repo root with:
##
##   godot --headless --path . tests/sprite_contract_test.tscn
##
## Verifies per hero in CharacterRegistry:
##   - sheet height == 96 and sheet width % 96 == 0
##   - sheet frame count matches registry `frame_count`
##   - `Visuals` uses NEAREST texture filtering (never linear / mipmap)
##   - `Visuals.texture` AtlasTexture cell size == 96x96
##   - every 96x96 frame has visible pixels and <= 2.0% semi-transparent alpha
##   - standing body height (`frame 0`) is in [70, 74] px (target 72 px)
##   - every frame lands on `GROUND_Y = 80` (`bottom_y == 80`, single ground line)
##   - palette count <= 24 colours per hero sheet
##   - no `.png.import` file in `assets/textures/` enables `mipmaps/generate=true`

const CELL_SIZE: int = 96
const TARGET_GROUND_Y: int = 80
const MIN_STANDING_H: int = 70
const MAX_STANDING_H: int = 74
const MAX_COLOURS_PER_HERO: int = 24
const MAX_SEMI_ALPHA_PCT: float = 2.0

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	print("=== Hero Sprite Art Contract Suite ===")
	_run()


func _check(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("PASS  ", label, ("  (" + detail + ")") if detail != "" else "")
	else:
		_failures += 1
		print("FAIL  ", label, ("  (" + detail + ")") if detail != "" else "")


func _check_eq(label: String, actual: Variant, expected: Variant) -> void:
	_check(label, actual == expected, "got %s, expected %s" % [str(actual), str(expected)])


func _tick(frames: int = 1) -> void:
	for i in frames:
		await get_tree().physics_frame


func _measure_cell(img: Image, frame_idx: int) -> Dictionary:
	var x_off: int = frame_idx * CELL_SIZE
	var min_x: int = CELL_SIZE
	var min_y: int = CELL_SIZE
	var max_x: int = -1
	var max_y: int = -1
	var non_empty: int = 0

	for y in range(CELL_SIZE):
		for x in range(CELL_SIZE):
			var c: Color = img.get_pixel(x_off + x, y)
			if c.a > 0.0:
				non_empty += 1
				if x < min_x:
					min_x = x
				if x > max_x:
					max_x = x
				if y < min_y:
					min_y = y
				if y > max_y:
					max_y = y

	if non_empty == 0:
		return {"empty": true, "body_h": 0, "top_y": -1, "bottom_y": -1}

	var top_y: int = min_y
	var bottom_y: int = max_y + 1
	return {
		"empty": false,
		"top_y": top_y,
		"bottom_y": bottom_y,
		"body_h": bottom_y - top_y,
		"width": (max_x - min_x + 1),
	}


func _check_no_texture_mipmaps(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	_check("Opened %s to audit .png.import mipmaps" % dir_path, dir != null)
	if dir == null:
		return

	var offenders: Array[String] = []
	var scanned: int = 0
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".png.import"):
			scanned += 1
			var full_path := dir_path.path_join(fname)
			var txt := FileAccess.get_file_as_string(full_path)
			if txt.find("mipmaps/generate=true") != -1:
				offenders.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()

	_check("Scanned %d .png.import files with zero mipmaps/generate=true" % scanned,
		scanned > 0 and offenders.is_empty(),
		"offenders=%s" % str(offenders))


func _run() -> void:
	var default_filter: int = int(ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter", 1
	))
	_check_eq("Project default canvas texture filter is NEAREST (0)", default_filter, 0)
	_check_no_texture_mipmaps("res://assets/textures")

	var world := Node2D.new()
	add_child(world)

	for entry in CharacterRegistry.CHARACTERS:
		var hero_id := String(entry["id"])
		var hero_name := String(entry["name"])
		var sheet_path := String(entry["sheet_path"])
		var expected_frames := int(entry["frame_count"])

		print("\n--- Hero: %s (%s) ---" % [hero_name, sheet_path])
		var tex: Texture2D = load(sheet_path)
		_check("%s sheet loads cleanly" % hero_name, tex != null)
		if tex == null:
			continue

		var w: int = tex.get_width()
		var h: int = tex.get_height()
		_check_eq("%s sheet height is %d" % [hero_name, CELL_SIZE], h, CELL_SIZE)
		_check("%s sheet width (%d) is a multiple of %d" % [hero_name, w, CELL_SIZE],
			w > 0 and (w % CELL_SIZE) == 0)
		var actual_frames: int = w / CELL_SIZE
		_check_eq("%s frame count matches CharacterRegistry (%d)" % [hero_name, expected_frames],
			actual_frames, expected_frames)

		var hero := CharacterRegistry.instantiate_hero(hero_id)
		hero.input_enabled = false
		world.add_child(hero)
		await _tick(1)

		var visuals := hero.get_node_or_null("Visuals") as Sprite2D
		_check("%s has Visuals Sprite2D" % hero_name, visuals != null)
		if visuals != null:
			var is_nearest: bool = (
				visuals.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
				or (visuals.texture_filter == CanvasItem.TEXTURE_FILTER_INHERIT and default_filter == 0)
			)
			_check("%s Visuals.texture_filter resolves to NEAREST" % hero_name,
				is_nearest, "texture_filter=%d" % visuals.texture_filter)
			var atlas_tex := visuals.texture as AtlasTexture
			_check("%s Visuals.texture is a 96x96 AtlasTexture" % hero_name,
				atlas_tex != null and atlas_tex.region.size == Vector2(CELL_SIZE, CELL_SIZE),
				str(atlas_tex.region.size if atlas_tex != null else Vector2.ZERO))

		var img: Image = tex.get_image()
		_check("%s sheet Image data is readable" % hero_name, img != null and not img.is_empty())
		if img != null and not img.is_empty():
			var colours: Dictionary = {}
			var semi_alpha: int = 0
			var total_px: int = w * h
			for y in range(h):
				for x in range(w):
					var c: Color = img.get_pixel(x, y)
					var a8: int = int(roundf(c.a * 255.0))
					if a8 > 0:
						var key: int = (int(roundf(c.r * 255.0)) << 16) | (int(roundf(c.g * 255.0)) << 8) | int(roundf(c.b * 255.0))
						colours[key] = true
						if a8 < 255:
							semi_alpha += 1

			var semi_pct: float = 100.0 * float(semi_alpha) / float(maxi(total_px, 1))
			_check("%s semi-alpha <= %.1f%%" % [hero_name, MAX_SEMI_ALPHA_PCT],
				semi_pct <= MAX_SEMI_ALPHA_PCT, "%.2f%%" % semi_pct)
			_check("%s colour count <= %d" % [hero_name, MAX_COLOURS_PER_HERO],
				colours.size() <= MAX_COLOURS_PER_HERO, "colours=%d" % colours.size())

			var empty_frames: Array[int] = []
			var ground_set: Dictionary = {}
			var f0_h: int = 0
			for f in range(actual_frames):
				var m := _measure_cell(img, f)
				if bool(m["empty"]):
					empty_frames.append(f)
				else:
					ground_set[int(m["bottom_y"])] = true
					if f == 0:
						f0_h = int(m["body_h"])

			_check("%s has zero empty frames" % hero_name, empty_frames.is_empty(),
				"empty=%s" % str(empty_frames))
			_check("%s standing body height (frame 0) in [%d, %d]" % [hero_name, MIN_STANDING_H, MAX_STANDING_H],
				f0_h >= MIN_STANDING_H and f0_h <= MAX_STANDING_H,
				"f0_body_h=%d" % f0_h)
			var grounds: Array = ground_set.keys()
			grounds.sort()
			_check("%s every frame grounded at GROUND_Y=%d" % [hero_name, TARGET_GROUND_Y],
				grounds.size() == 1 and int(grounds[0]) == TARGET_GROUND_Y,
				"ground_y_set=%s" % str(grounds))

		hero.queue_free()
		await _tick(1)

	world.queue_free()
	print("\n=== %d checks, %d failed ===" % [_checks, _failures])
	if _failures == 0:
		print("RESULT: ALL TESTS PASSED")
	else:
		print("RESULT: FAILURES PRESENT")
	get_tree().quit(0 if _failures == 0 else 1)
