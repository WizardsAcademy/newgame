extends Control
class_name HeroHUD
## Ornate Medieval Bottom-Left Hero HUD + **Bottom-Right Ability Bar** + **Stage Door Pointer** (`UI/HeroHUD`).
##
## Layout:
##   - **Bottom-Left**: Circular Gold & Dark-Iron Medallion (`FacePortrait` with circular shader),
##     Crimson HP Bar, Emerald Energy Bar, and Herbs/SP counter.
##   - **Bottom-Right (`AbilityBar`)**: Renders the active hero's abilities (`[LMB]`, `[RMB]`,
##     `[SHIFT]`, `[R]`) at the bottom-right corner of the screen with skill icons, cooldown
##     sweeps, active glows, & `[LOCK]` state!
##   - **Stage Door Pointer (`StageDoorIndicator`)**: Shows on-screen directional arrow &
##     chevron whenever Stage Exit / Next-Region doors spawn at the end of a round!

const LOW_HP_THRESHOLD: float = 0.35
const SKILL_ICONS_PATH := "res://assets/textures/skill_tree_icons.png"

var current_hp: int = 120
var max_hp: int = 120
var current_energy: float = 100.0
var max_energy: float = 100.0
var shield_exhausted: bool = false

var hero_name_str: String = "Behemoth"
var accent_color: Color = Color(0.98, 0.68, 0.26)
var hero_ref: Node = null

var _portrait_frames: Array[Texture2D] = []
var _using_atlas_uv: bool = false
var _active_frame_index: int = 0
var _lag_hp_ratio: float = 1.0
var _anim_time: float = 0.0
var _hurt_react_left: float = 0.0
var _blink_timer: float = 2.6
var _blink_hold_left: float = 0.0

var _portrait_rect: TextureRect = null
var _rim_overlay: MedallionRim = null
var _ouch_label: Label = null
var _skill_icons_tex: Texture2D = null
var _ability_bar: HBoxContainer = null
var _ability_slots: Array[Dictionary] = []
var _door_indicator: StageDoorScreenPointer = null


const PORTRAIT_CIRCLE_SHADER_CODE: String = """
shader_type canvas_item;
uniform float frame_count = 1.0;
uniform float frame_index = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 local_uv = vec2((UV.x * frame_count) - frame_index, UV.y);
	float d = distance(local_uv, vec2(0.5, 0.5));
	float mask = 1.0 - smoothstep(0.468, 0.490, d);
	COLOR = vec4(tex.rgb, tex.a * mask) * COLOR;
}
"""


class MedallionRim extends Control:
	var rim_color: Color = Color(0.88, 0.72, 0.34, 0.98)
	var inner_accent: Color = Color(1, 1, 1, 0.5)
	var is_bg: bool = false

	func _draw() -> void:
		var c := Vector2(30.0, 30.0)
		if is_bg:
			draw_circle(c, 25.0, Color(0.08, 0.06, 0.10, 0.96))
			return
		draw_arc(c, 26.8, 0.0, TAU, 40, Color(0.07, 0.05, 0.08, 0.98), 4.0)
		draw_arc(c, 25.4, 0.0, TAU, 40, rim_color, 2.2)
		draw_arc(c, 23.8, 0.0, TAU, 40, inner_accent, 1.0)


class StageDoorScreenPointer extends Control:
	var hud_owner: HeroHUD = null
	var anim_t: float = 0.0

	func _process(delta: float) -> void:
		anim_t += delta
		queue_redraw()

	func _draw() -> void:
		if hud_owner == null or hud_owner.hero_ref == null or not is_instance_valid(hud_owner.hero_ref):
			return
		var portals := get_tree().get_nodes_in_group("stage_portals")
		if portals.is_empty():
			return

		var hero_node := hud_owner.hero_ref as Node2D
		if hero_node == null:
			return
		var hero_world := hero_node.global_position
		var vp_size := get_viewport_rect().size
		var screen_center := vp_size * 0.5
		var cam := get_viewport().get_camera_2d()
		var cam_pos := cam.get_screen_center_position() if cam != null else hero_world
		var cam_zoom := cam.zoom if cam != null else Vector2(2.0, 2.0)
		# Note: viewport is 640x360; convert world offset cleanly to viewport coords
		var hud_offset := hud_owner.position
		var pulse := 0.5 + 0.5 * sin(anim_t * 7.5)
		var margin_rect := Rect2(Vector2(38.0, 34.0), vp_size - Vector2(76.0, 96.0))

		for p in portals:
			if p == null or not is_instance_valid(p) or not (p is Node2D):
				continue
			var pnode := p as Node2D
			if pnode.get("is_sandbox_return_only") == true:
				continue
			var door_world := pnode.global_position
			var dist_px := hero_world.distance_to(door_world)
			var gate_tag := String(pnode.get_meta("gate_tag", "NEXT STAGE"))
			var col: Color = pnode.get_meta("gate_color", Color(1.0, 0.88, 0.36, 0.96))

			var screen_pos := screen_center + (door_world - cam_pos)
			if cam_zoom.x > 0.01 and vp_size.x > 700.0:
				screen_pos = screen_center + (door_world - cam_pos) * cam_zoom

			if margin_rect.has_point(screen_pos):
				var local_tip := (screen_pos - hud_offset) + Vector2(0.0, -34.0 - 4.0 * sin(anim_t * 6.5))
				var tri := PackedVector2Array([
					local_tip,
					local_tip + Vector2(-7.0, -10.0),
					local_tip + Vector2(7.0, -10.0),
				])
				draw_colored_polygon(tri, col)
				draw_polyline(tri, Color(0.03, 0.04, 0.08, 0.95), 1.4)
			else:
				var dir := (screen_pos - screen_center).normalized()
				var clamped := Vector2(
					clampf(screen_pos.x, margin_rect.position.x, margin_rect.end.x),
					clampf(screen_pos.y, margin_rect.position.y, margin_rect.end.y)
				)
				var local_pt := clamped - hud_offset
				var tip2 := local_pt + dir * (4.0 + pulse * 3.0)
				var perp := Vector2(-dir.y, dir.x)
				var arrow_poly := PackedVector2Array([
					tip2,
					tip2 - dir * 13.0 + perp * 6.5,
					tip2 - dir * 10.0,
					tip2 - dir * 13.0 - perp * 6.5,
				])
				draw_circle(tip2 - dir * 7.0, 12.0, Color(0.03, 0.05, 0.10, 0.84))
				draw_colored_polygon(arrow_poly, col)
				var font2 := ThemeDB.fallback_font
				if font2 != null:
					var m_dist := maxi(int(roundf(dist_px / 10.0)), 1)
					var txt := "%s %dm" % [gate_tag, m_dist]
					draw_string(font2, local_pt - dir * 24.0 + Vector2(-34.0, 3.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 68.0, 7, col)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(226.0, 62.0)
	if ResourceLoader.exists(SKILL_ICONS_PATH):
		_skill_icons_tex = load(SKILL_ICONS_PATH)

	_door_indicator = StageDoorScreenPointer.new()
	_door_indicator.name = "StageDoorIndicator"
	_door_indicator.hud_owner = self
	_door_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_door_indicator)

	var bg_disc := MedallionRim.new()
	bg_disc.name = "MedallionBacking"
	bg_disc.is_bg = true
	bg_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_disc.size = Vector2(62.0, 62.0)
	add_child(bg_disc)

	_portrait_rect = TextureRect.new()
	_portrait_rect.name = "FacePortrait"
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.position = Vector2(5.0, 5.0)
	_portrait_rect.size = Vector2(50.0, 50.0)
	var clip_shader := Shader.new()
	clip_shader.code = PORTRAIT_CIRCLE_SHADER_CODE
	var clip_mat := ShaderMaterial.new()
	clip_mat.shader = clip_shader
	_portrait_rect.material = clip_mat
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

	# Bottom-Right Ability Bar (`ui ability haro samte raste paen safhe bechin`)!
	_ability_bar = HBoxContainer.new()
	_ability_bar.name = "AbilityBar"
	_ability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_bar.alignment = BoxContainer.ALIGNMENT_END
	_ability_bar.add_theme_constant_override("separation", 5)
	_ability_bar.size = Vector2(220.0, 46.0)
	add_child(_ability_bar)

	if not get_viewport().size_changed.is_connected(_relayout):
		get_viewport().size_changed.connect(_relayout)
	_relayout()


func _relayout() -> void:
	var vp := get_viewport_rect().size
	position = Vector2(10.0, vp.y - 68.0)
	if _ability_bar != null:
		# Place AbilityBar flush at the bottom-right corner of the viewport!
		_ability_bar.position = Vector2(vp.x - position.x - 228.0, 14.0)
		_ability_bar.size = Vector2(220.0, 46.0)


func bind_hero_node(hero: Node) -> void:
	hero_ref = hero
	_ability_slots.clear()
	_update_ability_bar()


func bind_hero_entry(entry: Dictionary) -> void:
	hero_name_str = String(entry.get("name", "Hero"))
	accent_color = entry.get("accent", Color(0.95, 0.75, 0.35))
	_portrait_frames.clear()
	_using_atlas_uv = false

	var p_path := String(entry.get("portrait_path", ""))
	if p_path != "" and ResourceLoader.exists(p_path):
		var sheet: Texture2D = load(p_path)
		if sheet != null:
			var cell := maxi(sheet.get_height(), 1)
			var count := maxi(int(sheet.get_width() / cell), 1)
			if _portrait_rect != null:
				_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var src_img: Image = sheet.get_image()
			if src_img != null and not src_img.is_empty():
				for i in range(count):
					var sub: Image = src_img.get_region(Rect2i(i * cell, 0, cell, cell))
					_portrait_frames.append(ImageTexture.create_from_image(sub))
			else:
				_using_atlas_uv = true
				for i in range(count):
					var at := AtlasTexture.new()
					at.atlas = sheet
					at.region = Rect2(float(i * cell), 0.0, float(cell), float(cell))
					_portrait_frames.append(at)

	_hurt_react_left = 0.0
	if _ouch_label != null:
		_ouch_label.visible = false
	_ability_slots.clear()
	_update_portrait_frame()
	queue_redraw()


func _rebuild_ability_slots(info_list: Array[Dictionary]) -> void:
	if _ability_bar == null:
		return
	for child in _ability_bar.get_children():
		child.queue_free()
	_ability_slots.clear()

	for i in range(info_list.size()):
		var entry: Dictionary = info_list[i]
		var card := Panel.new()
		card.name = "AbilitySlot_%d" % i
		card.custom_minimum_size = Vector2(46.0, 46.0)
		card.size = Vector2(46.0, 46.0)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var base_st := StyleBoxFlat.new()
		base_st.bg_color = Color(0.06, 0.06, 0.10, 0.92)
		base_st.border_color = accent_color.darkened(0.15)
		base_st.set_border_width_all(2)
		base_st.set_corner_radius_all(5)
		card.add_theme_stylebox_override("panel", base_st)
		_ability_bar.add_child(card)

		var icon_rect := TextureRect.new()
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.position = Vector2(11.0, 5.0)
		icon_rect.size = Vector2(24.0, 24.0)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if _skill_icons_tex != null:
			var at := AtlasTexture.new()
			at.atlas = _skill_icons_tex
			var icon_idx := clampi(int(entry.get("icon_idx", 1)), 0, 15)
			at.region = Rect2(float(icon_idx * 32), 0.0, 32.0, 32.0)
			icon_rect.texture = at
		card.add_child(icon_rect)

		var cd_shade := ColorRect.new()
		cd_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd_shade.position = Vector2(2.0, 2.0)
		cd_shade.size = Vector2(42.0, 0.0)
		cd_shade.color = Color(0.02, 0.02, 0.05, 0.78)
		card.add_child(cd_shade)

		var key_lbl := Label.new()
		key_lbl.position = Vector2(3.0, 1.0)
		key_lbl.size = Vector2(40.0, 11.0)
		key_lbl.text = String(entry.get("key", ""))
		key_lbl.add_theme_font_size_override("font_size", 7)
		key_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.56))
		key_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
		key_lbl.add_theme_constant_override("outline_size", 2)
		card.add_child(key_lbl)

		var title_lbl := Label.new()
		title_lbl.position = Vector2(1.0, 31.0)
		title_lbl.size = Vector2(44.0, 13.0)
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.text = String(entry.get("title", ""))
		title_lbl.add_theme_font_size_override("font_size", 7)
		title_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
		title_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
		title_lbl.add_theme_constant_override("outline_size", 2)
		card.add_child(title_lbl)

		var cd_lbl := Label.new()
		cd_lbl.position = Vector2(2.0, 12.0)
		cd_lbl.size = Vector2(42.0, 18.0)
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_font_size_override("font_size", 8)
		cd_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
		cd_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
		cd_lbl.add_theme_constant_override("outline_size", 3)
		card.add_child(cd_lbl)

		_ability_slots.append({
			"card": card,
			"style": base_st,
			"icon": icon_rect,
			"cd_shade": cd_shade,
			"title_lbl": title_lbl,
			"cd_lbl": cd_lbl,
		})


func _update_ability_bar() -> void:
	if hero_ref == null or not is_instance_valid(hero_ref) or not hero_ref.has_method("get_ability_hud_info"):
		return
	var info_list: Array[Dictionary] = hero_ref.get_ability_hud_info()
	if _ability_slots.size() != info_list.size():
		_rebuild_ability_slots(info_list)

	for i in range(info_list.size()):
		var entry: Dictionary = info_list[i]
		var slot: Dictionary = _ability_slots[i]
		var st: StyleBoxFlat = slot["style"]
		var icon_rect: TextureRect = slot["icon"]
		var cd_shade: ColorRect = slot["cd_shade"]
		var title_lbl: Label = slot["title_lbl"]
		var cd_lbl: Label = slot["cd_lbl"]

		var unlocked: bool = bool(entry.get("unlocked", true))
		var is_act: bool = bool(entry.get("active", false))
		var cd_left: float = float(entry.get("cd_left", 0.0))
		var cd_max: float = maxf(float(entry.get("cd_max", 1.0)), 0.05)

		title_lbl.text = String(entry.get("title", ""))

		if not unlocked:
			icon_rect.modulate = Color(0.35, 0.35, 0.42, 0.75)
			cd_shade.size.y = 42.0
			cd_lbl.text = "LOCK"
			st.border_color = Color(0.28, 0.28, 0.36, 0.85)
			st.bg_color = Color(0.04, 0.04, 0.07, 0.92)
		elif is_act:
			icon_rect.modulate = Color.WHITE
			cd_shade.size.y = 0.0
			cd_lbl.text = ""
			st.border_color = Color(1.0, 0.94, 0.44, 1.0)
			st.bg_color = accent_color.darkened(0.55)
		elif cd_left > 0.05:
			icon_rect.modulate = Color(0.58, 0.60, 0.68, 0.90)
			var frac := clampf(cd_left / cd_max, 0.0, 1.0)
			cd_shade.size.y = 42.0 * frac
			cd_lbl.text = ("%ds" % int(ceilf(cd_left))) if cd_left >= 2.0 else ("%.1f" % cd_left)
			st.border_color = Color(0.36, 0.38, 0.48, 0.92)
			st.bg_color = Color(0.06, 0.06, 0.10, 0.92)
		else:
			icon_rect.modulate = Color.WHITE
			cd_shade.size.y = 0.0
			cd_lbl.text = ""
			st.border_color = accent_color
			st.bg_color = Color(0.07, 0.07, 0.12, 0.92)


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
	if (hero_ref == null or not is_instance_valid(hero_ref)) and is_inside_tree():
		hero_ref = get_tree().get_first_node_in_group("player")
	_update_ability_bar()

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
		var sm := _portrait_rect.material as ShaderMaterial
		if sm != null:
			if _using_atlas_uv:
				sm.set_shader_parameter("frame_count", float(_portrait_frames.size()))
				sm.set_shader_parameter("frame_index", float(_active_frame_index))
			else:
				sm.set_shader_parameter("frame_count", 1.0)
				sm.set_shader_parameter("frame_index", 0.0)


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
		var herbs := WitchCauldronProgression.get_reagents()
		var pts := WitchCauldronProgression.get_brew_points(CharacterRegistry.selected_id)
		var herb_col := Color(0.55, 1.0, 0.72, 0.96) if herbs >= WitchCauldronProgression.REAGENTS_PER_POTION else Color(0.76, 0.88, 0.82, 0.90)
		draw_string(font, Vector2(124.0, 11.0), "Herbs %d/%d  SP %d" % [herbs, WitchCauldronProgression.REAGENTS_PER_POTION, pts],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, herb_col)

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
		var hp_txt := "INF" if WitchCauldronProgression.wizard_cheat_active else ("%d / %d" % [current_hp, max_hp])
		draw_string(font, Vector2(66.0, 26.5), hp_txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1.0, 0.97, 0.95, 0.96))

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
