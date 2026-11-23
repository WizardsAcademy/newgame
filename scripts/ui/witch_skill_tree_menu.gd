extends Control
class_name WitchSkillTreeMenu
## Hierarchical 16-Node RPG Skill Tree (`640x360` base viewport) with Per-Hero Color Themes:
##   - `knight`   : Blue & Black (`نایت ابی مشکی`)
##   - `behemoth` : Orange & Red (`بهموث نارنجی قرمز`)
##   - `sylvara`  : Green & Gold (`الف سبز طلایی`)
##   - `noa`      : Red & White  (`نوا قرمز سفید`)
##
## Features:
##   - Top-left `[💎 points]` counter, ornate `"Skill Tree"` gothic crest header with
##     flickering hero-colored flames, and top-right `[X]` button.
##   - 4-row `1 -> 3 -> 6 -> 6` beveled square skill frames connected by orthogonal
##     glowing conduits & diamond junction gems, with padlocks on locked Tier-4 nodes.
##   - Bottom-left `[↻ Reset Tree]` button + bottom ornate Inspector Dock with large
##     skill icon, title, description, `Level: X / 5`, `💎 1`, and `[Upgrade]` button.

signal skill_leveled_up(hero_id: String, node_id: String, new_level: int)
signal tree_reset(hero_id: String)
signal menu_closed

const ICONS_TEX_PATH := "res://assets/textures/skill_tree_icons.png"

const COL_CENTERS_ROW1: Array[float] = [190.0, 320.0, 450.0]
const COL_CENTERS_ROW2: Array[float] = [154.0, 226.0, 284.0, 356.0, 414.0, 486.0]

var _is_open: bool = false
var _hero_id: String = "behemoth"
var _selected_node_id: String = "vitality"
var _anim_time: float = 0.0
var _witch_offer_timer: float = 0.0

var _panel: Control = null
var _backdrop_canvas: Control = null
var _tree_lines_canvas: Control = null

var _gem_box: Panel = null
var _top_gem_icon: TextureRect = null
var _points_lbl: Label = null
var _hero_badge_lbl: Label = null
var _title_lbl: Label = null
var _close_btn: Button = null
var _reset_btn: Button = null

var _inspector_panel: Panel = null
var _inspector_decor: Control = null
var _selected_icon_frame: Panel = null
var _selected_icon_rect: TextureRect = null
var _selected_title_lbl: Label = null
var _selected_desc_lbl: Label = null
var _selected_level_lbl: Label = null
var _cost_gem_icon: TextureRect = null
var _selected_cost_lbl: Label = null
var _upgrade_btn: Button = null

var _icon_frames: Array[AtlasTexture] = []
var _node_buttons: Dictionary = {}   # node_id -> Button
var _node_centers: Dictionary = {}   # node_id -> Vector2
var _node_sizes: Dictionary = {}     # node_id -> Vector2
var _gulp_sfx: AudioStreamPlayer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_load_icon_frames()
	_build_ui()

	_gulp_sfx = AudioStreamPlayer.new()
	_gulp_sfx.bus = &"SFX"
	_gulp_sfx.stream = SFXGenerator.create_potion_gulp_sfx()
	add_child(_gulp_sfx)


func _load_icon_frames() -> void:
	if ResourceLoader.exists(ICONS_TEX_PATH):
		var strip: Texture2D = load(ICONS_TEX_PATH)
		if strip != null:
			for i in range(18):
				var at := AtlasTexture.new()
				at.atlas = strip
				at.region = Rect2(float(i * 32), 0.0, 32.0, 32.0)
				_icon_frames.append(at)


func _build_ui() -> void:
	# Root full-screen container (keeps name `CauldronPanel` for node-path compatibility)
	_panel = Control.new()
	_panel.name = "CauldronPanel"
	_panel.position = Vector2.ZERO
	_panel.size = Vector2(640.0, 360.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	# 1. Atmospheric Gothic Chamber, Arcane Circle, Tattered Banners, Side Crystals & Header Crest
	_backdrop_canvas = Control.new()
	_backdrop_canvas.name = "BackdropCanvas"
	_backdrop_canvas.position = Vector2.ZERO
	_backdrop_canvas.size = Vector2(640.0, 360.0)
	_backdrop_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_canvas.draw.connect(_draw_backdrop_and_crest)
	_panel.add_child(_backdrop_canvas)

	# 2. Orthogonal Glowing Conduits & Diamond Junction Gems
	_tree_lines_canvas = Control.new()
	_tree_lines_canvas.name = "TreeConnectors"
	_tree_lines_canvas.position = Vector2.ZERO
	_tree_lines_canvas.size = Vector2(640.0, 360.0)
	_tree_lines_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tree_lines_canvas.draw.connect(_draw_tree_connectors)
	_panel.add_child(_tree_lines_canvas)

	# 3. Top-Left Skill Gem Counter Pill (`[💎 3]`)
	_gem_box = Panel.new()
	_gem_box.name = "GemCounterBox"
	_gem_box.position = Vector2(18.0, 11.0)
	_gem_box.size = Vector2(84.0, 26.0)
	_panel.add_child(_gem_box)

	_top_gem_icon = TextureRect.new()
	_top_gem_icon.name = "GemIcon"
	_top_gem_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_top_gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_top_gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_top_gem_icon.position = Vector2(7.0, 4.0)
	_top_gem_icon.size = Vector2(18.0, 18.0)
	if _icon_frames.size() >= 18:
		_top_gem_icon.texture = _icon_frames[17]
	_gem_box.add_child(_top_gem_icon)

	_points_lbl = Label.new()
	_points_lbl.name = "BrewPointsLabel"
	_points_lbl.position = Vector2(28.0, 3.0)
	_points_lbl.size = Vector2(48.0, 20.0)
	_points_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_points_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_points_lbl.add_theme_font_size_override("font_size", 12)
	_gem_box.add_child(_points_lbl)

	_hero_badge_lbl = Label.new()
	_hero_badge_lbl.name = "HeroBadgeLabel"
	_hero_badge_lbl.position = Vector2(18.0, 40.0)
	_hero_badge_lbl.size = Vector2(84.0, 16.0)
	_hero_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_badge_lbl.add_theme_font_size_override("font_size", 8)
	_panel.add_child(_hero_badge_lbl)

	# 4. Top-Center `"Skill Tree"` Header Label inside Ornate Crest Plaque
	_title_lbl = Label.new()
	_title_lbl.name = "TitleLabel"
	_title_lbl.text = "Skill Tree"
	_title_lbl.position = Vector2(190.0, 12.0)
	_title_lbl.size = Vector2(260.0, 26.0)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 15)
	_title_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	_title_lbl.add_theme_constant_override("outline_size", 3)
	_panel.add_child(_title_lbl)

	# 5. Top-Right `[X]` Close Button
	_close_btn = Button.new()
	_close_btn.name = "CloseButton"
	_close_btn.text = "X"
	_close_btn.position = Vector2(592.0, 11.0)
	_close_btn.size = Vector2(30.0, 26.0)
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.add_theme_font_size_override("font_size", 11)
	_close_btn.pressed.connect(hide_menu)
	_panel.add_child(_close_btn)

	# 6. 16-Node `1 -> 3 -> 6 -> 6` Square Skill Frames
	var defs := WitchCauldronProgression.get_skill_nodes_for_hero("behemoth")
	for meta in defs:
		var nid := String(meta["id"])
		var row := int(meta["row"])
		var col := int(meta["col"])
		var box_sz := Vector2(34.0, 34.0)
		var center := Vector2(320.0, 67.0)
		if row == 0:
			box_sz = Vector2(38.0, 38.0)
			center = Vector2(320.0, 67.0)
		elif row == 1:
			box_sz = Vector2(36.0, 36.0)
			center = Vector2(COL_CENTERS_ROW1[col], 122.0)
		elif row == 2:
			box_sz = Vector2(34.0, 34.0)
			center = Vector2(COL_CENTERS_ROW2[col], 177.0)
		else:
			box_sz = Vector2(34.0, 34.0)
			center = Vector2(COL_CENTERS_ROW2[col], 229.0)

		_node_centers[nid] = center
		_node_sizes[nid] = box_sz

		var btn := Button.new()
		btn.name = "SkillNode_%s" % nid
		btn.position = center - box_sz * 0.5
		btn.size = box_sz
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_skill_node_pressed.bind(nid))
		_panel.add_child(btn)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(4.0, 4.0)
		icon.size = box_sz - Vector2(8.0, 8.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)

		var badge := Label.new()
		badge.name = "LevelBadge"
		badge.position = Vector2(2.0, box_sz.y - 12.0)
		badge.size = Vector2(box_sz.x - 4.0, 11.0)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.add_theme_font_size_override("font_size", 7)
		badge.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.96))
		badge.add_theme_constant_override("outline_size", 2)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(badge)

		_node_buttons[nid] = btn

	# 7. Bottom-Left `[↻ Reset Tree]` Button
	_reset_btn = Button.new()
	_reset_btn.name = "ResetButton"
	_reset_btn.text = "↻ Reset Tree"
	_reset_btn.position = Vector2(16.0, 304.0)
	_reset_btn.size = Vector2(98.0, 30.0)
	_reset_btn.focus_mode = Control.FOCUS_NONE
	_reset_btn.add_theme_font_size_override("font_size", 9)
	_reset_btn.pressed.connect(_on_reset_tree_pressed)
	_panel.add_child(_reset_btn)

	# 8. Bottom Center-Right Ornate Inspector Panel (`Shadow Strike | Level: 1 / 5 | 💎 1 | [Upgrade]`)
	_inspector_panel = Panel.new()
	_inspector_panel.name = "InspectorPanel"
	_inspector_panel.position = Vector2(126.0, 274.0)
	_inspector_panel.size = Vector2(422.0, 76.0)
	_panel.add_child(_inspector_panel)

	_inspector_decor = Control.new()
	_inspector_decor.position = Vector2.ZERO
	_inspector_decor.size = _inspector_panel.size
	_inspector_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspector_decor.draw.connect(_draw_inspector_accents)
	_inspector_panel.add_child(_inspector_decor)

	_selected_icon_frame = Panel.new()
	_selected_icon_frame.name = "SelectedIconFrame"
	_selected_icon_frame.position = Vector2(12.0, 10.0)
	_selected_icon_frame.size = Vector2(56.0, 56.0)
	_inspector_panel.add_child(_selected_icon_frame)

	_selected_icon_rect = TextureRect.new()
	_selected_icon_rect.name = "SelectedIcon"
	_selected_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_selected_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_selected_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_selected_icon_rect.position = Vector2(6.0, 6.0)
	_selected_icon_rect.size = Vector2(44.0, 44.0)
	_selected_icon_frame.add_child(_selected_icon_rect)

	_selected_title_lbl = Label.new()
	_selected_title_lbl.name = "SelectedTitle"
	_selected_title_lbl.position = Vector2(78.0, 10.0)
	_selected_title_lbl.size = Vector2(214.0, 18.0)
	_selected_title_lbl.add_theme_font_size_override("font_size", 12)
	_selected_title_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	_selected_title_lbl.add_theme_constant_override("outline_size", 2)
	_inspector_panel.add_child(_selected_title_lbl)

	_selected_desc_lbl = Label.new()
	_selected_desc_lbl.name = "SelectedDesc"
	_selected_desc_lbl.position = Vector2(78.0, 31.0)
	_selected_desc_lbl.size = Vector2(214.0, 36.0)
	_selected_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_desc_lbl.add_theme_font_size_override("font_size", 9)
	_inspector_panel.add_child(_selected_desc_lbl)

	_selected_level_lbl = Label.new()
	_selected_level_lbl.name = "SelectedLevelLabel"
	_selected_level_lbl.position = Vector2(308.0, 7.0)
	_selected_level_lbl.size = Vector2(104.0, 16.0)
	_selected_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_level_lbl.add_theme_font_size_override("font_size", 10)
	_inspector_panel.add_child(_selected_level_lbl)

	_cost_gem_icon = TextureRect.new()
	_cost_gem_icon.name = "CostGemIcon"
	_cost_gem_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cost_gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cost_gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cost_gem_icon.position = Vector2(342.0, 25.0)
	_cost_gem_icon.size = Vector2(14.0, 14.0)
	if _icon_frames.size() >= 18:
		_cost_gem_icon.texture = _icon_frames[17]
	_inspector_panel.add_child(_cost_gem_icon)

	_selected_cost_lbl = Label.new()
	_selected_cost_lbl.name = "SelectedCostLabel"
	_selected_cost_lbl.text = "1"
	_selected_cost_lbl.position = Vector2(359.0, 24.0)
	_selected_cost_lbl.size = Vector2(28.0, 16.0)
	_selected_cost_lbl.add_theme_font_size_override("font_size", 10)
	_inspector_panel.add_child(_selected_cost_lbl)

	_upgrade_btn = Button.new()
	_upgrade_btn.name = "UpgradeButton"
	_upgrade_btn.text = "Upgrade"
	_upgrade_btn.position = Vector2(314.0, 44.0)
	_upgrade_btn.size = Vector2(92.0, 22.0)
	_upgrade_btn.focus_mode = Control.FOCUS_NONE
	_upgrade_btn.add_theme_font_size_override("font_size", 10)
	_upgrade_btn.pressed.connect(_try_upgrade_selected_node)
	_inspector_panel.add_child(_upgrade_btn)


func _make_bevel_box(bg: Color, border: Color, radius: int = 4, bw: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	return s


func _draw_diamond(canvas: Control, center: Vector2, r: float, fill: Color, rim: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0.0, -r),
		center + Vector2(r, 0.0),
		center + Vector2(0.0, r),
		center + Vector2(-r, 0.0),
	])
	canvas.draw_colored_polygon(pts, fill)
	canvas.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), rim, 1.0)


func _draw_backdrop_and_crest() -> void:
	if _backdrop_canvas == null:
		return
	var th := WitchCauldronProgression.get_hero_theme(_hero_id)
	var bg_outer: Color = th["bg_outer"]
	var bg_inner: Color = th["bg_inner"]
	var stone_dark: Color = th["stone_dark"]
	var stone_mid: Color = th["stone_mid"]
	var stone_rim: Color = th["stone_rim"]
	var pri: Color = th["primary"]
	var sec: Color = th["secondary"]

	# Full-screen moody chamber backdrop + center arcane glow wash
	_backdrop_canvas.draw_rect(Rect2(0.0, 0.0, 640.0, 360.0), bg_outer, true)
	_backdrop_canvas.draw_rect(Rect2(88.0, 24.0, 464.0, 256.0), bg_inner, true)

	# Faint Arcane Rune Rings behind the Skill Tree (`image-17` background sigil)
	var rune_c := Vector2(320.0, 152.0)
	var rune_col := Color(pri.r, pri.g, pri.b, 0.13)
	var rune_col2 := Color(sec.r, sec.g, sec.b, 0.09)
	_backdrop_canvas.draw_arc(rune_c, 132.0, 0.0, TAU, 48, rune_col, 2.0)
	_backdrop_canvas.draw_arc(rune_c, 114.0, 0.0, TAU, 48, rune_col2, 1.0)
	_backdrop_canvas.draw_arc(rune_c, 78.0, 0.0, TAU, 36, rune_col, 1.0)
	for i in range(8):
		var ang := float(i) * PI * 0.25 + _anim_time * 0.04
		var p0 := rune_c + Vector2(cos(ang), sin(ang)) * 78.0
		var p1 := rune_c + Vector2(cos(ang), sin(ang)) * 132.0
		_backdrop_canvas.draw_line(p0, p1, rune_col2, 1.0)

	# Left & Right Hanging Tattered Banners (`image-17` side banners)
	for bx in [24.0, 582.0]:
		var bpoly := PackedVector2Array([
			Vector2(bx, 68.0),
			Vector2(bx + 34.0, 68.0),
			Vector2(bx + 34.0, 168.0),
			Vector2(bx + 17.0, 188.0),
			Vector2(bx, 168.0),
		])
		_backdrop_canvas.draw_colored_polygon(bpoly, Color(stone_mid.r, stone_mid.g, stone_mid.b, 0.92))
		_backdrop_canvas.draw_polyline(PackedVector2Array([bpoly[0], bpoly[1], bpoly[2], bpoly[3], bpoly[4], bpoly[0]]),
			Color(pri.r, pri.g, pri.b, 0.45), 1.2)
		_draw_diamond(_backdrop_canvas, Vector2(bx + 17.0, 128.0), 7.0,
			Color(pri.r, pri.g, pri.b, 0.38), Color(sec.r, sec.g, sec.b, 0.72))

	# Bottom-Left & Bottom-Right Glowing Crystal Clusters (`image-17` side crystals)
	for side in [-1.0, 1.0]:
		var cx := 58.0 if side < 0.0 else 582.0
		var c1 := PackedVector2Array([
			Vector2(cx - 10.0, 268.0), Vector2(cx - 4.0, 232.0),
			Vector2(cx + 4.0, 240.0), Vector2(cx + 6.0, 268.0),
		])
		var c2 := PackedVector2Array([
			Vector2(cx + 2.0, 268.0), Vector2(cx + 12.0, 242.0),
			Vector2(cx + 18.0, 250.0), Vector2(cx + 16.0, 268.0),
		])
		_backdrop_canvas.draw_colored_polygon(c1, Color(pri.r, pri.g, pri.b, 0.78))
		_backdrop_canvas.draw_colored_polygon(c2, Color(sec.r, sec.g, sec.b, 0.84))

	# Carved Stone Dais Platform along the bottom (`y = 266..360`)
	_backdrop_canvas.draw_rect(Rect2(0.0, 268.0, 640.0, 92.0), stone_dark, true)
	_backdrop_canvas.draw_rect(Rect2(96.0, 262.0, 448.0, 12.0), stone_mid, true)
	_backdrop_canvas.draw_line(Vector2(0.0, 268.0), Vector2(640.0, 268.0), stone_rim, 1.5)
	_backdrop_canvas.draw_line(Vector2(96.0, 262.0), Vector2(544.0, 262.0), Color(sec.r, sec.g, sec.b, 0.55), 1.2)

	# Ornate Top `"Skill Tree"` Crest Plaque + Flickering Hero-Themed Wing Flames!
	var sway := sin(_anim_time * 5.0) * 2.0
	for dir_s in [-1.0, 1.0]:
		var wx := 188.0 if dir_s < 0.0 else 452.0
		var flame_outer := PackedVector2Array([
			Vector2(wx, 16.0),
			Vector2(wx + dir_s * (26.0 + sway), 10.0),
			Vector2(wx + dir_s * 34.0, 24.0),
			Vector2(wx + dir_s * (22.0 - sway), 36.0),
			Vector2(wx, 34.0),
		])
		var flame_inner := PackedVector2Array([
			Vector2(wx, 20.0),
			Vector2(wx + dir_s * 18.0, 16.0),
			Vector2(wx + dir_s * 22.0, 25.0),
			Vector2(wx + dir_s * 14.0, 31.0),
			Vector2(wx, 30.0),
		])
		_backdrop_canvas.draw_colored_polygon(flame_outer, Color(pri.r, pri.g, pri.b, 0.85))
		_backdrop_canvas.draw_colored_polygon(flame_inner, Color(sec.r, sec.g, sec.b, 0.92))

	var plaque := Rect2(188.0, 10.0, 264.0, 30.0)
	_backdrop_canvas.draw_rect(plaque, stone_mid, true)
	_backdrop_canvas.draw_rect(plaque, stone_rim, false, 2.0)
	_backdrop_canvas.draw_rect(plaque.grow(-3.0), stone_dark, true)
	_draw_diamond(_backdrop_canvas, Vector2(188.0, 25.0), 5.0, pri, sec)
	_draw_diamond(_backdrop_canvas, Vector2(452.0, 25.0), 5.0, pri, sec)
	_draw_diamond(_backdrop_canvas, Vector2(320.0, 9.0), 6.5, sec, Color.WHITE)
	_draw_diamond(_backdrop_canvas, Vector2(320.0, 41.0), 4.0, pri, sec)


func _draw_inspector_accents() -> void:
	if _inspector_decor == null:
		return
	var th := WitchCauldronProgression.get_hero_theme(_hero_id)
	var pri: Color = th["primary"]
	var sec: Color = th["secondary"]
	var rim: Color = th["stone_rim"]

	# Vertical divider line between description & Upgrade controls (`x = 300`)
	_inspector_decor.draw_line(Vector2(300.0, 11.0), Vector2(300.0, 65.0), Color(rim.r, rim.g, rim.b, 0.72), 1.2)
	_draw_diamond(_inspector_decor, Vector2(300.0, 11.0), 2.6, pri, sec)
	_draw_diamond(_inspector_decor, Vector2(300.0, 65.0), 2.6, pri, sec)

	# Corner rivets matching `image-17`
	for pt in [Vector2(4.0, 4.0), Vector2(418.0, 4.0), Vector2(4.0, 72.0), Vector2(418.0, 72.0)]:
		_draw_diamond(_inspector_decor, pt, 3.2, pri, sec)


func _draw_conduit(p0: Vector2, p1: Vector2, active: bool, pri: Color, sec: Color, locked_col: Color) -> void:
	if active:
		_tree_lines_canvas.draw_line(p0, p1, Color(pri.r, pri.g, pri.b, 0.36), 5.0)
		_tree_lines_canvas.draw_line(p0, p1, sec, 2.0)
	else:
		_tree_lines_canvas.draw_line(p0, p1, locked_col, 2.0)


func _draw_tree_connectors() -> void:
	if _tree_lines_canvas == null:
		return
	var th := WitchCauldronProgression.get_hero_theme(_hero_id)
	var pri: Color = th["primary"]
	var sec: Color = th["secondary"]
	var glow_rim := Color(sec.r, sec.g, sec.b, 0.95)
	var locked_line := Color(0.32, 0.34, 0.42, 0.85)
	var locked_gem := Color(0.24, 0.26, 0.34, 1.0)

	var root_lv := WitchCauldronProgression.get_node_level(_hero_id, "vitality")
	var root_active := root_lv >= 1

	# Crest -> Root conduit
	_draw_conduit(Vector2(320.0, 41.0), Vector2(320.0, 48.0), true, pri, sec, locked_line)

	# Row 0 (`vitality`, bottom=86) -> Horizontal bar `y=95` -> Row 1 (`top=104`)
	var y_bar0 := 95.0
	_draw_conduit(Vector2(320.0, 86.0), Vector2(320.0, y_bar0), root_active, pri, sec, locked_line)
	for idx in range(3):
		var nid1 := ["wrath", "focus", "essence"][idx]
		var cx1: float = COL_CENTERS_ROW1[idx]
		var br_active := root_active and (WitchCauldronProgression.get_node_level(_hero_id, nid1) >= 1 or root_active)
		_draw_conduit(Vector2(320.0, y_bar0), Vector2(cx1, y_bar0), br_active, pri, sec, locked_line)
		_draw_conduit(Vector2(cx1, y_bar0), Vector2(cx1, 104.0), br_active, pri, sec, locked_line)
		_draw_diamond(_tree_lines_canvas, Vector2(cx1, 104.0), 2.8, pri if br_active else locked_gem, glow_rim if br_active else locked_line)
	_draw_diamond(_tree_lines_canvas, Vector2(320.0, 86.0), 3.2, pri if root_active else locked_gem, glow_rim)
	_draw_diamond(_tree_lines_canvas, Vector2(320.0, y_bar0), 2.8, pri if root_active else locked_gem, glow_rim)

	# Row 1 (`bottom=140`) -> Horizontal split bars `y=150` -> Row 2 (`top=160`)
	var row1_ids := ["wrath", "focus", "essence"]
	var row2_ids := ["blade", "swiftness", "heart", "ward", "burst", "reaper"]
	var row3_ids := ["mastery_0", "mastery_1", "mastery_2", "mastery_3", "mastery_4", "mastery_5"]
	var y_bar1 := 150.0

	for b in range(3):
		var p_id: String = row1_ids[b]
		var p_cx: float = COL_CENTERS_ROW1[b]
		var p_active := WitchCauldronProgression.get_node_level(_hero_id, p_id) >= 1
		_draw_conduit(Vector2(p_cx, 140.0), Vector2(p_cx, y_bar1), p_active, pri, sec, locked_line)
		_draw_diamond(_tree_lines_canvas, Vector2(p_cx, y_bar1), 3.0,
			pri if p_active else locked_gem, glow_rim if p_active else locked_line)

		for sub in range(2):
			var c_idx := b * 2 + sub
			var cx2: float = COL_CENTERS_ROW2[c_idx]
			_draw_conduit(Vector2(p_cx, y_bar1), Vector2(cx2, y_bar1), p_active, pri, sec, locked_line)
			_draw_conduit(Vector2(cx2, y_bar1), Vector2(cx2, 160.0), p_active, pri, sec, locked_line)
			_draw_diamond(_tree_lines_canvas, Vector2(cx2, 160.0), 2.6,
				pri if p_active else locked_gem, glow_rim if p_active else locked_line)

	# Row 2 (`bottom=194`) -> Row 3 (`top=212`) + Stone dais pedestals (`246..262`)
	for c in range(6):
		var cx: float = COL_CENTERS_ROW2[c]
		var r2_active := WitchCauldronProgression.get_node_level(_hero_id, row2_ids[c]) >= 1
		var r3_active := WitchCauldronProgression.get_node_level(_hero_id, row3_ids[c]) >= 1
		_draw_conduit(Vector2(cx, 194.0), Vector2(cx, 212.0), r2_active, pri, sec, locked_line)
		_draw_diamond(_tree_lines_canvas, Vector2(cx, 203.0), 2.6,
			pri if r2_active else locked_gem, glow_rim if r2_active else locked_line)
		_draw_conduit(Vector2(cx, 246.0), Vector2(cx, 262.0), r3_active, pri, sec, locked_line)
		_draw_diamond(_tree_lines_canvas, Vector2(cx, 255.0), 2.4,
			pri if r3_active else locked_gem, glow_rim if r3_active else locked_line)


func is_open() -> bool:
	return _is_open


func show_for_hero(hero_id: String) -> void:
	WitchCauldronProgression.ensure_loaded()
	var entry := CharacterRegistry.get_entry(hero_id)
	_hero_id = String(entry["id"])
	_selected_node_id = "vitality"
	_is_open = true
	visible = true
	_witch_offer_timer = 0.0
	_refresh_nodes()


func hide_menu() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	menu_closed.emit()


func _refresh_nodes() -> void:
	var entry := CharacterRegistry.get_entry(_hero_id)
	var th := WitchCauldronProgression.get_hero_theme(_hero_id)
	var pri: Color = th["primary"]
	var sec: Color = th["secondary"]
	var stone_dark: Color = th["stone_dark"]
	var stone_mid: Color = th["stone_mid"]
	var stone_rim: Color = th["stone_rim"]
	var gem_col: Color = th["gem_tint"]

	var pts := WitchCauldronProgression.get_brew_points(_hero_id)
	_points_lbl.text = "%d" % pts
	_points_lbl.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
	_top_gem_icon.modulate = gem_col
	_cost_gem_icon.modulate = gem_col

	_hero_badge_lbl.text = String(entry["name"]).to_upper()
	_hero_badge_lbl.add_theme_color_override("font_color", sec)
	_title_lbl.add_theme_color_override("font_color", Color(0.97, 0.96, 1.0))

	_gem_box.add_theme_stylebox_override("panel", _make_bevel_box(stone_dark, stone_rim, 5, 2))
	_close_btn.add_theme_stylebox_override("normal", _make_bevel_box(stone_mid, stone_rim, 4, 2))
	_close_btn.add_theme_stylebox_override("hover", _make_bevel_box(pri.darkened(0.45), sec, 4, 2))

	var has_spent := WitchCauldronProgression.get_spent_points(_hero_id) > 0
	_reset_btn.disabled = not has_spent
	_reset_btn.add_theme_stylebox_override("normal", _make_bevel_box(stone_mid, stone_rim, 5, 2))
	_reset_btn.add_theme_stylebox_override("hover", _make_bevel_box(pri.darkened(0.45), sec, 5, 2))
	_reset_btn.add_theme_stylebox_override("disabled", _make_bevel_box(stone_dark, Color(0.24, 0.24, 0.30), 5, 2))

	_inspector_panel.add_theme_stylebox_override("panel", _make_bevel_box(stone_dark, stone_rim, 5, 2))
	_selected_icon_frame.add_theme_stylebox_override("panel", _make_bevel_box(th["node_active_bg"], sec, 4, 2))

	var defs := WitchCauldronProgression.get_skill_nodes_for_hero(_hero_id)
	for meta in defs:
		var nid := String(meta["id"])
		var btn: Button = _node_buttons.get(nid)
		if btn == null:
			continue

		var row := int(meta["row"])
		var icon_idx := int(meta["icon_idx"])
		var lv := WitchCauldronProgression.get_node_level(_hero_id, nid)
		var unlocked := WitchCauldronProgression.is_node_unlocked(_hero_id, nid)
		var is_sel := (nid == _selected_node_id)

		var icon := btn.get_node("Icon") as TextureRect
		if not _icon_frames.is_empty():
			# Locked Row-3 Mastery nodes show the crisp Padlock icon (#16) just like `image-17.png`!
			if row == 3 and not unlocked:
				icon.texture = _icon_frames[16]
				icon.modulate = Color(0.62, 0.64, 0.74, 0.90)
			else:
				icon.texture = _icon_frames[clampi(icon_idx, 0, _icon_frames.size() - 1)]
				if lv > 0:
					icon.modulate = sec.lerp(Color.WHITE, 0.35)
				elif unlocked:
					icon.modulate = pri.lerp(Color.WHITE, 0.45)
				else:
					icon.modulate = Color(0.54, 0.56, 0.66, 0.78)

		var badge := btn.get_node("LevelBadge") as Label
		if lv > 0:
			badge.text = "%d/%d" % [lv, WitchCauldronProgression.MAX_NODE_LEVEL]
			badge.add_theme_color_override("font_color", sec)
		else:
			badge.text = ""

		var bg_col: Color = th["node_active_bg"] if lv > 0 else th["node_bg"]
		var rim_col := Color(0.32, 0.34, 0.44, 0.95)
		var bw := 2
		if is_sel:
			rim_col = sec
			bw = 2
			bg_col = bg_col.lightened(0.12)
		elif lv >= WitchCauldronProgression.MAX_NODE_LEVEL:
			rim_col = sec
		elif lv > 0:
			rim_col = pri
		elif unlocked:
			rim_col = stone_rim

		btn.add_theme_stylebox_override("normal", _make_bevel_box(bg_col, rim_col, 5, bw))
		btn.add_theme_stylebox_override("hover", _make_bevel_box(bg_col.lightened(0.10), sec, 5, bw))
		btn.add_theme_stylebox_override("pressed", _make_bevel_box(th["node_active_bg"], Color.WHITE, 5, bw))

	_refresh_inspector(th)
	if _backdrop_canvas != null:
		_backdrop_canvas.queue_redraw()
	if _tree_lines_canvas != null:
		_tree_lines_canvas.queue_redraw()
	if _inspector_decor != null:
		_inspector_decor.queue_redraw()


func _refresh_inspector(th: Dictionary) -> void:
	var meta := WitchCauldronProgression.get_node_meta(_hero_id, _selected_node_id)
	if meta.is_empty():
		return

	var pri: Color = th["primary"]
	var sec: Color = th["secondary"]
	var lv := WitchCauldronProgression.get_node_level(_hero_id, _selected_node_id)
	var unlocked := WitchCauldronProgression.is_node_unlocked(_hero_id, _selected_node_id)
	var can_up := WitchCauldronProgression.can_upgrade_node(_hero_id, _selected_node_id)
	var icon_idx := int(meta["icon_idx"])

	if not _icon_frames.is_empty():
		_selected_icon_rect.texture = _icon_frames[clampi(icon_idx, 0, _icon_frames.size() - 1)]
		_selected_icon_rect.modulate = sec.lerp(Color.WHITE, 0.25) if unlocked else Color(0.62, 0.64, 0.74, 0.88)

	_selected_title_lbl.text = String(meta["title"])
	_selected_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.97, 1.0))

	_selected_desc_lbl.text = String(meta["desc"])
	_selected_desc_lbl.add_theme_color_override("font_color",
		th["stat_highlight"] if lv > 0 else Color(0.84, 0.86, 0.92))

	_selected_level_lbl.text = "Level: %d / %d" % [lv, WitchCauldronProgression.MAX_NODE_LEVEL]
	_selected_level_lbl.add_theme_color_override("font_color", Color(0.96, 0.96, 1.0))

	if lv >= WitchCauldronProgression.MAX_NODE_LEVEL:
		_selected_cost_lbl.text = "-"
		_upgrade_btn.text = "MAXED"
		_upgrade_btn.disabled = true
	elif not unlocked:
		_selected_cost_lbl.text = "1"
		_upgrade_btn.text = "Locked"
		_upgrade_btn.disabled = true
	else:
		_selected_cost_lbl.text = "1"
		_upgrade_btn.text = "Upgrade"
		_upgrade_btn.disabled = not can_up

	_upgrade_btn.add_theme_stylebox_override("normal", _make_bevel_box(th["btn_bg"], th["btn_border"], 4, 2))
	_upgrade_btn.add_theme_stylebox_override("hover", _make_bevel_box(th["btn_hover"], Color.WHITE, 4, 2))
	_upgrade_btn.add_theme_stylebox_override("pressed", _make_bevel_box(pri, Color.WHITE, 4, 2))
	_upgrade_btn.add_theme_stylebox_override("disabled", _make_bevel_box(Color(0.14, 0.14, 0.18), Color(0.30, 0.30, 0.38), 4, 1))


func _on_skill_node_pressed(node_id: String) -> void:
	var already_selected := (_selected_node_id == node_id)
	_selected_node_id = node_id
	_refresh_nodes()
	if already_selected and WitchCauldronProgression.can_upgrade_node(_hero_id, node_id):
		_try_upgrade_selected_node()


func _try_upgrade_selected_node() -> void:
	if not WitchCauldronProgression.can_upgrade_node(_hero_id, _selected_node_id):
		return
	if WitchCauldronProgression.upgrade_node(_hero_id, _selected_node_id):
		_witch_offer_timer = 1.05
		if _gulp_sfx != null:
			_gulp_sfx.pitch_scale = randf_range(0.96, 1.08)
			_gulp_sfx.play()
		var new_lv := WitchCauldronProgression.get_node_level(_hero_id, _selected_node_id)
		_refresh_nodes()
		_spawn_upgrade_flash(_selected_node_id)
		skill_leveled_up.emit(_hero_id, _selected_node_id, new_lv)


func _on_reset_tree_pressed() -> void:
	var refunded := WitchCauldronProgression.reset_hero_tree(_hero_id)
	if refunded > 0:
		_selected_node_id = "vitality"
		_refresh_nodes()
		tree_reset.emit(_hero_id)


func _spawn_upgrade_flash(node_id: String) -> void:
	var th := WitchCauldronProgression.get_hero_theme(_hero_id)
	var sec: Color = th["secondary"]
	var center: Vector2 = _node_centers.get(node_id, Vector2(320.0, 120.0))

	var pop := Label.new()
	pop.text = "+1 LEVEL!"
	pop.position = center + Vector2(-28.0, -26.0)
	pop.size = Vector2(56.0, 14.0)
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop.add_theme_font_size_override("font_size", 8)
	pop.add_theme_color_override("font_color", sec)
	pop.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.96))
	pop.add_theme_constant_override("outline_size", 2)
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(pop)

	var ptw := create_tween()
	ptw.set_parallel(true)
	ptw.tween_property(pop, "position:y", pop.position.y - 14.0, 0.48)
	ptw.tween_property(pop, "modulate:a", 0.0, 0.48)
	ptw.chain().tween_callback(pop.queue_free)


func _process(delta: float) -> void:
	if not _is_open:
		return
	_anim_time += delta
	if _witch_offer_timer > 0.0:
		_witch_offer_timer = maxf(_witch_offer_timer - delta, 0.0)
	if _backdrop_canvas != null:
		_backdrop_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			hide_menu()
			get_viewport().set_input_as_handled()
