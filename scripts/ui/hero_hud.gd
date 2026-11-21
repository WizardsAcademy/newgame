extends Control
class_name HeroHUD
## Ornate Medieval Bottom-Left Hero HUD (`UI/HeroHUD`).
##
## Layout (`payin samt chap`):
##   - **Left (`samt chap`):** Circular Gold & Dark-Iron Medallion showing ONLY
##     the chosen hero's 64x64 close-up pixel-art FACE (`portrait_*.png`):
##       * Animated living idle (gentle motion between frame 0 & 1 + random blink 2),
##       * Automatic **Low-HP Face** (`frame 3`) when HP <= 35%,
##       * Expressive **Hit-Reaction `"AKH!"` Face** (`frame 4`) + shake when hurt!
##   - **Right (`samt rast` of the circle):**
##       * Crimson Blood HP Bar (`current_health / max_health` + lag trail),
##       * Emerald Green Energy Bar (`current_energy / max_energy` + Knight
##         shield exhaustion indicator).

const LOW_HP_THRESHOLD: float = 0.35

var current_hp: int = 120
var max_hp: int = 120
var current_energy: float = 100.0
var max_energy: float = 100.0
var shield_exhausted: bool = false

var hero_name_str: String = "Behemoth"
var accent_color: Color = Color(0.98, 0.68, 0.26)

var _portrait_frames: Array[AtlasTexture] = []
var _active_frame_index: int = 0
var _lag_hp_ratio: float = 1.0
var _anim_time: float = 0.0
var _hurt_react_left: float = 0.0
var _blink_timer: float = 2.6
var _blink_hold_left: float = 0.0

var _portrait_rect: TextureRect = null
var _rim_overlay: MedallionRim = null
var _ouch_label: Label = null


class MedallionRim extends Control:
	var rim_color: Color = Color(0.88, 0.72, 0.34, 0.98)
	var inner_accent: Color = Color(1, 1, 1, 0.5)

	func _draw() -> void:
		var c := Vector2(30.0, 30.0)
		draw_arc(c, 26.8, 0.0, TAU, 36, Color(0.07, 0.05, 0.08, 0.98), 4.0)
		draw_arc(c, 25.4, 0.0, TAU, 36, rim_color, 2.2)
		draw_arc(c, 23.8, 0.0, TAU, 36, inner_accent, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(226.0, 62.0)

	_portrait_rect = TextureRect.new()
	_portrait_rect.name = "FacePortrait"
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.position = Vector2(5.0, 5.0)
	_portrait_rect.size = Vector2(50.0, 50.0)
	add_child(_portrait_rect)

	_rim_overlay = MedallionRim.new()
	_rim_overlay.name = "MedallionRim"
	_rim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rim_overlay.size = Vector2(62.0, 62.0)
	add_child(_rim_overlay)

	_ouch_label = Label.new()
	_ouch_label.name = "OuchBadge"
	_ouch_label.text = "AKH!"
	_ouch_label.visible = false
	_ouch_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ouch_label.add_theme_font_size_override("font_size", 8)
	_ouch_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.36))
	_ouch_label.add_theme_color_override("font_outline_color", Color(0.35, 0.02, 0.05, 0.96))
	_ouch_label.add_theme_constant_override("outline_size", 2)
	_ouch_label.position = Vector2(38.0, -2.0)
	add_child(_ouch_label)

	if not get_viewport().size_changed.is_connected(_relayout):
		get_viewport().size_changed.connect(_relayout)
	_relayout()


func _relayout() -> void:
	var vp := get_viewport_rect().size
	position = Vector2(10.0, vp.y - 68.0)


func bind_hero_entry(entry: Dictionary) -> void:
	hero_name_str = String(entry.get("name", "Hero"))
	accent_color = entry.get("accent", Color(0.95, 0.75, 0.35))
	_portrait_frames.clear()

	var p_path := String(entry.get("portrait_path", ""))
	if p_path != "" and ResourceLoader.exists(p_path):
		var sheet: Texture2D = load(p_path)
		if sheet != null:
			var cell := maxi(sheet.get_height(), 1)
			var count := maxi(int(sheet.get_width() / cell), 1)
			if _portrait_rect != null:
				_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if cell > 64 else CanvasItem.TEXTURE_FILTER_NEAREST
			for i in range(count):
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(float(i * cell), 0.0, float(cell), float(cell))
				_portrait_frames.append(at)

	_hurt_react_left = 0.0
	if _ouch_label != null:
		_ouch_label.visible = false
	_update_portrait_frame()
	queue_redraw()


func set_health_values(cur: int, mx: int) -> void:
	current_hp = maxi(cur, 0)
	max_hp = maxi(mx, 1)
	_update_portrait_frame()
	queue_redraw()


func set_energy_values(cur: float, mx: float, exhausted: bool = false) -> void:
	current_energy = clampf(cur, 0.0, maxf(mx, 1.0))
	max_energy = maxf(mx, 1.0)
	shield_exhausted = exhausted
	queue_redraw()


func trigger_hurt_reaction() -> void:
	_hurt_react_left = 0.48
	if _ouch_label != null:
		_ouch_label.visible = true
	_update_portrait_frame()
	queue_redraw()


func get_active_portrait_frame() -> int:
	return _active_frame_index


func is_showing_low_hp_face() -> bool:
	return _active_frame_index == 3


func is_showing_hurt_face() -> bool:
	return _active_frame_index == 4


func _process(delta: float) -> void:
	_anim_time += delta
	var target_hp_ratio := clampf(float(current_hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	if _lag_hp_ratio > target_hp_ratio:
		_lag_hp_ratio = move_toward(_lag_hp_ratio, target_hp_ratio, delta * 0.65)
	else:
		_lag_hp_ratio = target_hp_ratio

	if _hurt_react_left > 0.0:
		_hurt_react_left = maxf(_hurt_react_left - delta, 0.0)
		if _hurt_react_left <= 0.0 and _ouch_label != null:
			_ouch_label.visible = false

	if _blink_hold_left > 0.0:
		_blink_hold_left = maxf(_blink_hold_left - delta, 0.0)
	else:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blink_hold_left = 0.11
			_blink_timer = randf_range(2.4, 5.2)

	_update_portrait_frame()

	if _portrait_rect != null:
		if _hurt_react_left > 0.0:
			var jx := sin(_anim_time * 54.0) * 2.2
			var jy := cos(_anim_time * 43.0) * 1.4
			_portrait_rect.position = Vector2(5.0 + jx, 5.0 + jy)
		else:
			var bob := sin(_anim_time * 2.4) * 0.8
			_portrait_rect.position = Vector2(5.0, 5.0 + bob)

	if _rim_overlay != null:
		var is_low := target_hp_ratio <= LOW_HP_THRESHOLD
		if _hurt_react_left > 0.0:
			_rim_overlay.rim_color = Color(1.0, 0.22, 0.28, 1.0)
		elif is_low:
			_rim_overlay.rim_color = Color(0.96, 0.22, 0.26, 0.98).lerp(
				Color(0.88, 0.72, 0.34, 0.98), 0.5 + 0.5 * sin(_anim_time * 7.0))
		else:
			_rim_overlay.rim_color = Color(0.88, 0.72, 0.34, 0.98)
		_rim_overlay.inner_accent = accent_color.lerp(Color.WHITE, 0.22) * Color(1, 1, 1, 0.55)
		_rim_overlay.queue_redraw()

	queue_redraw()


func _update_portrait_frame() -> void:
	if _portrait_frames.is_empty():
		return
	var hp_ratio := float(current_hp) / float(maxi(max_hp, 1))
	if _hurt_react_left > 0.0 and _portrait_frames.size() > 4:
		_active_frame_index = 4
	elif hp_ratio <= LOW_HP_THRESHOLD and _portrait_frames.size() > 3:
		_active_frame_index = 3
	elif _blink_hold_left > 0.0 and _portrait_frames.size() > 2:
		_active_frame_index = 2
	elif _portrait_frames.size() > 1:
		_active_frame_index = 1 if int(_anim_time * 1.8) % 2 == 1 else 0
	else:
		_active_frame_index = 0

	if _portrait_rect != null:
		_portrait_rect.texture = _portrait_frames[_active_frame_index]


func _draw() -> void:
	var c_center := Vector2(30.0, 30.0)
	var hp_ratio := clampf(float(current_hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	var en_ratio := clampf(current_energy / maxf(max_energy, 1.0), 0.0, 1.0)
	var is_low := hp_ratio <= LOW_HP_THRESHOLD

	var plaque := Rect2(44.0, 13.0, 168.0, 38.0)
	draw_rect(plaque, Color(0.07, 0.07, 0.11, 0.90), true)
	draw_rect(plaque, Color(0.36, 0.32, 0.26, 0.92), false, 1.5)

	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(64.0, 11.0), hero_name_str.to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.96, 0.90, 0.76, 0.96))

	# TOP BAR — Crimson HP Bar
	var hp_bg := Rect2(62.0, 18.0, 142.0, 11.0)
	draw_rect(hp_bg, Color(0.14, 0.04, 0.06, 0.96), true)
	if _lag_hp_ratio > hp_ratio:
		draw_rect(Rect2(hp_bg.position.x + 1.0, hp_bg.position.y + 1.0,
			(hp_bg.size.x - 2.0) * _lag_hp_ratio, hp_bg.size.y - 2.0),
			Color(1.0, 0.88, 0.82, 0.85), true)
	if hp_ratio > 0.0:
		var hp_w := (hp_bg.size.x - 2.0) * hp_ratio
		var hp_col := Color(0.92, 0.18, 0.26) if not is_low else Color(1.0, 0.24, 0.18).lerp(
			Color(1.0, 0.62, 0.22), 0.5 + 0.5 * sin(_anim_time * 9.0))
		draw_rect(Rect2(hp_bg.position.x + 1.0, hp_bg.position.y + 1.0, hp_w, hp_bg.size.y - 2.0), hp_col, true)
		draw_rect(Rect2(hp_bg.position.x + 1.0, hp_bg.position.y + 1.0, hp_w, 3.0), Color(1.0, 0.62, 0.68, 0.45), true)
	draw_rect(hp_bg, Color(0.68, 0.54, 0.34, 0.95), false, 1.0)

	if font != null:
		draw_string(font, Vector2(66.0, 26.5), "%d / %d" % [current_hp, max_hp],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1.0, 0.97, 0.95, 0.96))

	# BOTTOM BAR — Emerald Green Energy Bar
	var en_bg := Rect2(62.0, 34.0, 142.0, 9.0)
	draw_rect(en_bg, Color(0.04, 0.12, 0.07, 0.96), true)
	if en_ratio > 0.0:
		var en_w := (en_bg.size.x - 2.0) * en_ratio
		var en_col := Color(0.24, 0.88, 0.46)
		if shield_exhausted:
			en_col = Color(0.96, 0.58, 0.20).lerp(Color(0.55, 0.32, 0.14), 0.5 + 0.5 * sin(_anim_time * 10.0))
		draw_rect(Rect2(en_bg.position.x + 1.0, en_bg.position.y + 1.0, en_w, en_bg.size.y - 2.0), en_col, true)
		draw_rect(Rect2(en_bg.position.x + 1.0, en_bg.position.y + 1.0, en_w, 2.0), Color(0.75, 1.0, 0.82, 0.48), true)
	draw_rect(en_bg, Color(0.42, 0.62, 0.46, 0.92), false, 1.0)

	if shield_exhausted and font != null:
		draw_string(font, Vector2(66.0, 41.5), "RECOVERING SHIELD...",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1.0, 0.86, 0.55, 0.96))

	draw_circle(c_center, 27.2, Color(0.06, 0.06, 0.10, 0.98))
