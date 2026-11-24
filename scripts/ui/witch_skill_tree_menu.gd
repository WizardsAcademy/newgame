extends Control
class_name WitchSkillTreeMenu
## Long Scrollable Exclusive-Pillar OP Skill Tree (`640x360` viewport, `640px`-tall scrollable graph):
##   - Row 0 (`solo_top`)    : 1 Solo Keystone OP Node at the top
##   - Rows 1..4 (`p0..p2`)  : 3 Vertical 4-Tier Pillars (` ONLY 1 Pillar may be chosen! `)
##   - Row 5 (`solo_bottom`) : All 3 Pillars converge back into 1 Ultimate OP Solo Node (`dovomin taki`)!
##   - Witch Alchemy Brewing : Shows collected Reagents (`🌿 X/3`) + `[⚗ Brew Majon]` button to turn
##                             monster/wave drops into Skill Points!

signal skill_leveled_up(hero_id: String, node_id: String, new_level: int)
signal potion_brewed(hero_id: String, new_points: int)
signal tree_reset(hero_id: String)
signal menu_closed

const ICONS_TEX_PATH := "res://assets/textures/skill_tree_icons.png"
const REAGENTS_TEX_PATH := "res://assets/textures/witch_reagents.png"

const SCROLL_VIEW_POS := Vector2(92.0, 45.0)
const SCROLL_VIEW_SIZE := Vector2(456.0, 219.0)
const CONTENT_SIZE := Vector2(456.0, 640.0)

const PILLAR_X: Array[float] = [88.0, 228.0, 368.0]
const ROW_Y: Array[float] = [44.0, 152.0, 250.0, 348.0, 446.0, 566.0]

var _is_open: bool = false
var _hero_id: String = "behemoth"
var _selected_node_id: String = "solo_top"
var _anim_time: float = 0.0
var _witch_offer_timer: float = 0.0

var _panel: Control = null
var _backdrop_canvas: Control = null
var _scroll: ScrollContainer = null
var _tree_content: Control = null
var _tree_lines_canvas: Control = null
var _pillar_labels: Array[Label] = []
var _scroll_hint_lbl: Label = null

var _gem_box: Panel = null
var _top_gem_icon: TextureRect = null
var _points_lbl: Label = null
var _reagent_box: Panel = null
var _reagent_icon: TextureRect = null
var _reagent_lbl: Label = null
var _brew_btn: Button = null

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
var _reagent_tex: AtlasTexture = null
var _node_buttons: Dictionary = {}   # node_id -> Button
var _node_centers: Dictionary = {}   # node_id -> Vector2 (in _tree_content local coords)
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
	if ResourceLoader.exists(REAGENTS_TEX_PATH):
		var rstrip: Texture2D = load(REAGENTS_TEX_PATH)
		if rstrip != null:
			_reagent_tex = AtlasTexture.new()
			_reagent_tex.atlas = rstrip
			_reagent_tex.region = Rect2(0.0, 0.0, 32.0, 32.0)


func get_skill_button(node_id: String) -> Button:
	return _node_buttons.get(node_id) as Button


func _build_ui() -> void:
	_panel = Control.new()
	_panel.name = "CauldronPanel"
	_panel.position = Vector2.ZERO
	_panel.size = Vector2(640.0, 360.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	# 1. Atmospheric Gothic Chamber, Arcane Circle, Side Banners & Header Crest
	_backdrop_canvas = Control.new()
	_backdrop_canvas.name = "BackdropCanvas"
	_backdrop_canvas.position = Vector2.ZERO
	_backdrop_canvas.size = Vector2(640.0, 360.0)
	_backdrop_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_canvas.draw.connect(_draw_backdrop_and_crest)
	_panel.add_child(_backdrop_canvas)

	# 2. Scrollable Vertical Skill Tree Viewport (`beshe scroll kard payin tar`)!
	_scroll = ScrollContainer.new()
	_scroll.name = "TreeScroll"
	_scroll.position = SCROLL_VIEW_POS
	_scroll.size = SCROLL_VIEW_SIZE
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_panel.add_child(_scroll)

	_tree_content = Control.new()
	_tree_content.name = "TreeContent"
	_tree_content.custom_minimum_size = CONTENT_SIZE
	_tree_content.size = CONTENT_SIZE
	_scroll.add_child(_tree_content)

	_tree_lines_canvas = Control.new()
	_tree_lines_canvas.name = "TreeConnectors"
	_tree_lines_canvas.position = Vector2.ZERO
	_tree_lines_canvas.size = CONTENT_SIZE
	_tree_lines_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tree_lines_canvas.draw.connect(_draw_tree_connectors)
	_tree_content.add_child(_tree_lines_canvas)

	# 3 Pillar Header Titles (`ONLY 1 PILLAR ALLOWED!`)
	for p in range(3):
		var plbl := Label.new()
		plbl.name = "PillarHeader_%d" % p
		plbl.position = Vector2(PILLAR_X[p] - 64.0, 98.0)
		plbl.size = Vector2(128.0, 22.0)
		plbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plbl.add_theme_font_size_override("font_size", 8)
		plbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.96))
		plbl.add_theme_constant_override("outline_size", 2)
		plbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tree_content.add_child(plbl)
		_pillar_labels.append(plbl)

	# Build 14 Skill Node Buttons (`solo_top` -> `3 x 4 Pillars` -> `solo_bottom`)
	var defs := WitchCauldronProgression.get_skill_nodes_for_hero("behemoth")
	for meta in defs:
		var nid: String = String(meta["id"])
		var row: int = int(meta["row"])
		var col: int = int(meta["col"])
		var box_sz := Vector2(38.0, 38.0)
		if row == 0 or row == 5:
			box_sz = Vector2(46.0, 46.0)
		var cx: float = PILLAR_X[clampi(col, 0, 2)]
		var cy: float = ROW_Y[clampi(row, 0, ROW_Y.size() - 1)]
		var center := Vector2(cx, cy)

		_node_centers[nid] = center
		_node_sizes[nid] = box_sz

		var btn := Button.new()
		btn.name = "SkillNode_%s" % nid
		btn.position = center - box_sz * 0.5
		btn.size = box_sz
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		btn.pressed.connect(_on_skill_node_pressed.bind(nid))
		_tree_content.add_child(btn)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(5.0, 5.0)
		icon.size = box_sz - Vector2(10.0, 10.0)
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

	# Scroll Hint Badge above the bottom stone dais
	_scroll_hint_lbl = Label.new()
	_scroll_hint_lbl.name = "ScrollDownHint"
	_scroll_hint_lbl.text = "▼ Scroll Down to Ultimate Solo Skill ▼"
	_scroll_hint_lbl.position = Vector2(200.0, 249.0)
	_scroll_hint_lbl.size = Vector2(240.0, 14.0)
	_scroll_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scroll_hint_lbl.add_theme_font_size_override("font_size", 8)
	_scroll_hint_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 0.96))
	_scroll_hint_lbl.add_theme_constant_override("outline_size", 2)
	_scroll_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_scroll_hint_lbl)

	# 3. Top-Left Skill Gem Counter (`[💎 pts]`) + Witch Reagent Counter & `[⚗ Brew Majon]` Button!
	_gem_box = Panel.new()
	_gem_box.name = "GemCounterBox"
	_gem_box.position = Vector2(12.0, 9.0)
	_gem_box.size = Vector2(78.0, 24.0)
	_panel.add_child(_gem_box)

	_top_gem_icon = TextureRect.new()
	_top_gem_icon.name = "GemIcon"
	_top_gem_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_top_gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_top_gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_top_gem_icon.position = Vector2(5.0, 3.0)
	_top_gem_icon.size = Vector2(18.0, 18.0)
	if _icon_frames.size() >= 18:
		_top_gem_icon.texture = _icon_frames[17]
	_gem_box.add_child(_top_gem_icon)

	_points_lbl = Label.new()
	_points_lbl.name = "BrewPointsLabel"
	_points_lbl.position = Vector2(24.0, 2.0)
	_points_lbl.size = Vector2(50.0, 20.0)
	_points_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_points_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_points_lbl.add_theme_font_size_override("font_size", 10)
	_gem_box.add_child(_points_lbl)

	_reagent_box = Panel.new()
	_reagent_box.name = "ReagentCounterBox"
	_reagent_box.position = Vector2(94.0, 9.0)
	_reagent_box.size = Vector2(78.0, 24.0)
	_panel.add_child(_reagent_box)

	_reagent_icon = TextureRect.new()
	_reagent_icon.name = "ReagentIcon"
	_reagent_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_reagent_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reagent_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reagent_icon.position = Vector2(4.0, 3.0)
	_reagent_icon.size = Vector2(18.0, 18.0)
	if _reagent_tex != null:
		_reagent_icon.texture = _reagent_tex
	_reagent_box.add_child(_reagent_icon)

	_reagent_lbl = Label.new()
	_reagent_lbl.name = "ReagentCountLabel"
	_reagent_lbl.position = Vector2(22.0, 2.0)
	_reagent_lbl.size = Vector2(52.0, 20.0)
	_reagent_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reagent_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reagent_lbl.add_theme_font_size_override("font_size", 9)
	_reagent_box.add_child(_reagent_lbl)

	_hero_badge_lbl = Label.new()
	_hero_badge_lbl.name = "HeroBadgeLabel"
	_hero_badge_lbl.position = Vector2(12.0, 36.0)
	_hero_badge_lbl.size = Vector2(78.0, 14.0)
	_hero_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_badge_lbl.add_theme_font_size_override("font_size", 8)
	_panel.add_child(_hero_badge_lbl)

	# 4. Top-Center `"Skill Tree"` Header Label inside Ornate Crest Plaque
	_title_lbl = Label.new()
	_title_lbl.name = "TitleLabel"
	_title_lbl.text = "Skill Tree"
	_title_lbl.position = Vector2(190.0, 10.0)
	_title_lbl.size = Vector2(260.0, 26.0)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 14)
	_title_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	_title_lbl.add_theme_constant_override("outline_size", 3)
	_panel.add_child(_title_lbl)

	# 5. Top-Right `[X]` Close Button
	_close_btn = Button.new()
	_close_btn.name = "CloseButton"
	_close_btn.text = "X"
	_close_btn.position = Vector2(596.0, 10.0)
	_close_btn.size = Vector2(30.0, 25.0)
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.add_theme_font_size_override("font_size", 11)
	_close_btn.pressed.connect(hide_menu)
	_panel.add_child(_close_btn)

	# 6. Bottom-Left `[⚗ Brew Majon]` + `[↻ Reset Tree]` Buttons
	_brew_btn = Button.new()
	_brew_btn.name = "BrewPotionButton"
	_brew_btn.text = "⚗ Brew Majon (3)"
	_brew_btn.position = Vector2(12.0, 276.0)
	_brew_btn.size = Vector2(106.0, 34.0)
	_brew_btn.focus_mode = Control.FOCUS_NONE
	_brew_btn.add_theme_font_size_override("font_size", 8)
	_brew_btn.pressed.connect(_on_brew_potion_pressed)
	_panel.add_child(_brew_btn)

	_reset_btn = Button.new()
	_reset_btn.name = "ResetButton"
	_reset_btn.text = "↻ Reset Tree"
	_reset_btn.position = Vector2(12.0, 316.0)
	_reset_btn.size = Vector2(106.0, 30.0)
	_reset_btn.focus_mode = Control.FOCUS_NONE
	_reset_btn.add_theme_font_size_override("font_size", 9)
	_reset_btn.pressed.connect(_on_reset_tree_pressed)
	_panel.add_child(_reset_btn)

	# 7. Bottom Ornate Inspector Panel
	_inspector_panel = Panel.new()
	_inspector_panel.name = "InspectorPanel"
	_inspector_panel.position = Vector2(126.0, 274.0)
	_inspector_panel.size = Vector2(498.0, 76.0)
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
	_selected_title_lbl.position = Vector2(78.0, 8.0)
	_selected_title_lbl.size = Vector2(284.0, 18.0)
	_selected_title_lbl.add_theme_font_size_override("font_size", 11)
	_selected_title_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	_selected_title_lbl.add_theme_constant_override("outline_size", 2)
	_inspector_panel.add_child(_selected_title_lbl)

	_selected_desc_lbl = Label.new()
	_selected_desc_lbl.name = "SelectedDesc"
	_selected_desc_lbl.position = Vector2(78.0, 28.0)
	_selected_desc_lbl.size = Vector2(284.0, 40.0)
	_selected_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_desc_lbl.add_theme_font_size_override("font_size", 9)
	_inspector_panel.add_child(_selected_desc_lbl)

	_selected_level_lbl = Label.new()
	_selected_level_lbl.name = "SelectedLevelLabel"
	_selected_level_lbl.position = Vector2(376.0, 7.0)
	_selected_level_lbl.size = Vector2(112.0, 16.0)
	_selected_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_level_lbl.add_theme_font_size_override("font_size", 10)
	_inspector_panel.add_child(_selected_level_lbl)

	_cost_gem_icon = TextureRect.new()
	_cost_gem_icon.name = "CostGemIcon"
	_cost_gem_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cost_gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cost_gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cost_gem_icon.position = Vector2(414.0, 25.0)
	_cost_gem_icon.size = Vector2(14.0, 14.0)
	if _icon_frames.size() >= 18:
		_cost_gem_icon.texture = _icon_frames[17]
	_inspector_panel.add_child(_cost_gem_icon)

	_selected_cost_lbl = Label.new()
	_selected_cost_lbl.name = "SelectedCostLabel"
	_selected_cost_lbl.text = "1"
	_selected_cost_lbl.position = Vector2(432.0, 24.0)
	_selected_cost_lbl.size = Vector2(34.0, 16.0)
	_selected_cost_lbl.add_theme_font_size_override("font_size", 10)
	_inspector_panel.add_child(_selected_cost_lbl)

	_upgrade_btn = Button.new()
	_upgrade_btn.name = "UpgradeButton"
	_upgrade_btn.text = "Upgrade"
	_upgrade_btn.position = Vector2(382.0, 44.0)
	_upgrade_btn.size = Vector2(102.0, 22.0)
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

	_backdrop_canvas.draw_rect(Rect2(0.0, 0.0, 640.0, 360.0), bg_outer, true)
	_backdrop_canvas.draw_rect(Rect2(88.0, 42.0, 464.0, 224.0), bg_inner, true)
	_backdrop_canvas.draw_rect(Rect2(88.0, 42.0, 464.0, 224.0), Color(stone_rim.r, stone_rim.g, stone_rim.b, 0.65), false, 1.5)

	var rune_c := Vector2(320.0, 152.0)
	var rune_col := Color(pri.r, pri.g, pri.b, 0.13)
	var rune_col2 := Color(sec.r, sec.g, sec.b, 0.09)
	_backdrop_canvas.draw_arc(rune_c, 102.0, 0.0, TAU, 48, rune_col, 2.0)
	_backdrop_canvas.draw_arc(rune_c, 74.0, 0.0, TAU, 36, rune_col2, 1.0)

	for bx in [24.0, 582.0]:
		var bpoly := PackedVector2Array([
			Vector2(bx, 68.0), Vector2(bx + 34.0, 68.0),
			Vector2(bx + 34.0, 168.0), Vector2(bx + 17.0, 188.0), Vector2(bx, 168.0),
		])
		_backdrop_canvas.draw_colored_polygon(bpoly, Color(stone_mid.r, stone_mid.g, stone_mid.b, 0.92))
		_backdrop_canvas.draw_polyline(PackedVector2Array([bpoly[0], bpoly[1], bpoly[2], bpoly[3], bpoly[4], bpoly[0]]),
			Color(pri.r, pri.g, pri.b, 0.45), 1.2)
		_draw_diamond(_backdrop_canvas, Vector2(bx + 17.0, 128.0), 7.0,
			Color(pri.r, pri.g, pri.b, 0.38), Color(sec.r, sec.g, sec.b, 0.72))

	_backdrop_canvas.draw_rect(Rect2(0.0, 268.0, 640.0, 92.0), stone_dark, true)
	_backdrop_canvas.draw_line(Vector2(0.0, 268.0), Vector2(640.0, 268.0), stone_rim, 1.5)

	var sway := sin(_anim_time * 5.0) * 2.0
	for dir_s in [-1.0, 1.0]:
		var wx := 188.0 if dir_s < 0.0 else 452.0
		var flame_outer := PackedVector2Array([
			Vector2(wx, 14.0), Vector2(wx + dir_s * (24.0 + sway), 9.0),
			Vector2(wx + dir_s * 30.0, 22.0), Vector2(wx + dir_s * (20.0 - sway), 33.0), Vector2(wx, 31.0),
		])
		_backdrop_canvas.draw_colored_polygon(flame_outer, Color(pri.r, pri.g, pri.b, 0.85))

	var plaque := Rect2(188.0, 8.0, 264.0, 28.0)
	_backdrop_canvas.draw_rect(plaque, stone_mid, true)
	_backdrop_canvas.draw_rect(plaque, stone_rim, false, 2.0)
	_backdrop_canvas.draw_rect(plaque.grow(-3.0), stone_dark, true)


func _draw_inspector_accents() -> void:
	if _inspector_decor == null:
		return
	var th := WitchCauldronProgression.get_hero_theme(_hero_id)
	var pri: Color = th["primary"]
	var sec: Color = th["secondary"]
	var rim: Color = th["stone_rim"]

	_inspector_decor.draw_line(Vector2(370.0, 11.0), Vector2(370.0, 65.0), Color(rim.r, rim.g, rim.b, 0.72), 1.2)
	_draw_diamond(_inspector_decor, Vector2(370.0, 11.0), 2.6, pri, sec)
	_draw_diamond(_inspector_decor, Vector2(370.0, 65.0), 2.6, pri, sec)


func _draw_conduit(p0: Vector2, p1: Vector2, active: bool, blocked: bool, pri: Color, sec: Color) -> void:
	if active:
		_tree_lines_canvas.draw_line(p0, p1, Color(pri.r, pri.g, pri.b, 0.38), 6.0)
		_tree_lines_canvas.draw_line(p0, p1, sec, 2.2)
	elif blocked:
		_tree_lines_canvas.draw_line(p0, p1, Color(0.24, 0.14, 0.18, 0.55), 2.0)
	else:
		_tree_lines_canvas.draw_line(p0, p1, Color(0.34, 0.36, 0.46, 0.85), 2.0)


func _draw_tree_connectors() -> void:
	if _tree_lines_canvas == null:
		return
	var th := WitchCauldronProgression.get_hero_theme(_hero_id)
	var pri: Color = th["primary"]
	var sec: Color = th["secondary"]
	var chosen := WitchCauldronProgression.get_chosen_pillar(_hero_id)
	var top_active := WitchCauldronProgression.get_node_level(_hero_id, "solo_top") >= 1
	var bot_active := WitchCauldronProgression.get_node_level(_hero_id, "solo_bottom") >= 1

	var top_c: Vector2 = _node_centers["solo_top"]
	var bot_c: Vector2 = _node_centers["solo_bottom"]

	# 1. Top Solo (`solo_top`) -> Split Bar (`y = 88`) -> 3 Exclusive Pillars (`p0_t1..p2_t1`)
	var split_y := 88.0
	_draw_conduit(top_c + Vector2(0.0, 23.0), Vector2(top_c.x, split_y), top_active, false, pri, sec)
	_draw_diamond(_tree_lines_canvas, Vector2(top_c.x, split_y), 3.4, pri if top_active else Color(0.3, 0.3, 0.4), sec)

	for p in range(3):
		var px: float = PILLAR_X[p]
		var pil_blocked := (chosen != -1 and chosen != p)
		var p_t1_lv := WitchCauldronProgression.get_node_level(_hero_id, "p%d_t1" % p)
		var branch_lit := top_active and (not pil_blocked) and (chosen == p or chosen == -1)

		_draw_conduit(Vector2(top_c.x, split_y), Vector2(px, split_y), p_t1_lv >= 1, pil_blocked, pri, sec)
		_draw_conduit(Vector2(px, split_y), Vector2(px, ROW_Y[1] - 19.0), branch_lit and p_t1_lv >= 1, pil_blocked, pri, sec)

		# Vertical Pillar Spine (`t1 -> t2 -> t3 -> t4`)
		for t in range(1, 4):
			var cur_lv := WitchCauldronProgression.get_node_level(_hero_id, "p%d_t%d" % [p, t])
			var y0: float = ROW_Y[t] + 19.0
			var y1: float = ROW_Y[t + 1] - 19.0
			_draw_conduit(Vector2(px, y0), Vector2(px, y1), cur_lv >= 1 and not pil_blocked, pil_blocked, pri, sec)
			_draw_diamond(_tree_lines_canvas, Vector2(px, (y0 + y1) * 0.5), 2.8,
				pri if (cur_lv >= 1 and not pil_blocked) else Color(0.24, 0.26, 0.34), sec)

		# 2. Convergence Bar (`y = 508`) where ALL 3 Pillars reconnect into `solo_bottom` (`dovomin taki`)!
		var t4_lv := WitchCauldronProgression.get_node_level(_hero_id, "p%d_t4" % p)
		var merge_y := 508.0
		_draw_conduit(Vector2(px, ROW_Y[4] + 19.0), Vector2(px, merge_y), t4_lv >= 1, pil_blocked, pri, sec)
		_draw_conduit(Vector2(px, merge_y), Vector2(bot_c.x, merge_y), t4_lv >= 1, pil_blocked, pri, sec)

	var any_t4: bool = (
		WitchCauldronProgression.get_node_level(_hero_id, "p0_t4") >= 1
		or WitchCauldronProgression.get_node_level(_hero_id, "p1_t4") >= 1
		or WitchCauldronProgression.get_node_level(_hero_id, "p2_t4") >= 1
	)
	_draw_conduit(Vector2(bot_c.x, 508.0), bot_c - Vector2(0.0, 23.0), any_t4 or bot_active, false, pri, sec)
	_draw_diamond(_tree_lines_canvas, Vector2(bot_c.x, 508.0), 4.0,
		sec if (any_t4 or bot_active) else Color(0.28, 0.30, 0.38), Color.WHITE)


func is_open() -> bool:
	return _is_open


func show_for_hero(hero_id: String) -> void:
	WitchCauldronProgression.ensure_loaded()
	var entry := CharacterRegistry.get_entry(hero_id)
	_hero_id = String(entry["id"])
	_selected_node_id = "solo_top"
	_is_open = true
	visible = true
	_witch_offer_timer = 0.0
	if _scroll != null:
		_scroll.scroll_vertical = 0
	_refresh_nodes()


func hide_menu() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	menu_closed.emit()


func refresh_if_open() -> void:
	if _is_open:
		_refresh_nodes()


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

	var reagents := WitchCauldronProgression.get_reagents()
	_reagent_lbl.text = "%d / %d" % [reagents, WitchCauldronProgression.REAGENTS_PER_POTION]
	_reagent_lbl.add_theme_color_override("font_color",
		Color(0.62, 1.0, 0.74) if reagents >= WitchCauldronProgression.REAGENTS_PER_POTION else Color(0.84, 0.86, 0.92))
	_reagent_box.add_theme_stylebox_override("panel", _make_bevel_box(stone_dark, stone_rim, 5, 2))

	var can_brew := WitchCauldronProgression.can_brew_potion()
	_brew_btn.disabled = not can_brew
	_brew_btn.text = "⚗ Brew Majon (%d)" % WitchCauldronProgression.REAGENTS_PER_POTION
	_brew_btn.add_theme_stylebox_override("normal", _make_bevel_box(Color(0.18, 0.52, 0.28), Color(0.58, 1.0, 0.72), 5, 2))
	_brew_btn.add_theme_stylebox_override("hover", _make_bevel_box(Color(0.24, 0.68, 0.38), Color.WHITE, 5, 2))
	_brew_btn.add_theme_stylebox_override("disabled", _make_bevel_box(stone_dark, Color(0.24, 0.26, 0.32), 5, 1))

	_hero_badge_lbl.text = String(entry["name"]).to_upper()
	_hero_badge_lbl.add_theme_color_override("font_color", sec)
	_title_lbl.add_theme_color_override("font_color", Color(0.97, 0.96, 1.0))
	_scroll_hint_lbl.add_theme_color_override("font_color", sec)

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

	var pnames := WitchCauldronProgression.get_pillar_names(_hero_id)
	var chosen := WitchCauldronProgression.get_chosen_pillar(_hero_id)
	for p in range(3):
		var plbl := _pillar_labels[p]
		if chosen == p:
			plbl.text = "★ %s" % pnames[p]
			plbl.add_theme_color_override("font_color", sec)
		elif chosen != -1:
			plbl.text = "🔒 %s" % pnames[p]
			plbl.add_theme_color_override("font_color", Color(0.52, 0.44, 0.48, 0.85))
		else:
			plbl.text = pnames[p]
			plbl.add_theme_color_override("font_color", Color(0.86, 0.88, 0.96))

	var defs := WitchCauldronProgression.get_skill_nodes_for_hero(_hero_id)
	for meta in defs:
		var nid: String = String(meta["id"])
		var btn: Button = _node_buttons.get(nid)
		if btn == null:
			continue

		var icon_idx: int = int(meta["icon_idx"])
		var max_lv: int = int(meta.get("max_level", WitchCauldronProgression.MAX_NODE_LEVEL))
		var lv := WitchCauldronProgression.get_node_level(_hero_id, nid)
		var unlocked := WitchCauldronProgression.is_node_unlocked(_hero_id, nid)
		var locked_other := WitchCauldronProgression.is_node_locked_by_other_pillar(_hero_id, nid)
		var is_sel := (nid == _selected_node_id)

		var icon := btn.get_node("Icon") as TextureRect
		if not _icon_frames.is_empty():
			if locked_other or (not unlocked and nid != "solo_top"):
				icon.texture = _icon_frames[16]
				icon.modulate = Color(0.52, 0.36, 0.40, 0.85) if locked_other else Color(0.62, 0.64, 0.74, 0.88)
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
			badge.text = "%d/%d" % [lv, max_lv]
			badge.add_theme_color_override("font_color", sec)
		else:
			badge.text = ""

		var bg_col: Color = th["node_active_bg"] if lv > 0 else th["node_bg"]
		var rim_col := Color(0.30, 0.32, 0.42, 0.95)
		var bw := 3 if (nid == "solo_top" or nid == "solo_bottom") else 2
		if is_sel:
			rim_col = sec
			bg_col = bg_col.lightened(0.14)
		elif lv >= max_lv:
			rim_col = sec
		elif lv > 0:
			rim_col = pri
		elif locked_other:
			rim_col = Color(0.32, 0.18, 0.22, 0.85)
		elif unlocked:
			rim_col = stone_rim

		btn.add_theme_stylebox_override("normal", _make_bevel_box(bg_col, rim_col, 6 if bw == 3 else 5, bw))
		btn.add_theme_stylebox_override("hover", _make_bevel_box(bg_col.lightened(0.10), sec, 6 if bw == 3 else 5, bw))
		btn.add_theme_stylebox_override("pressed", _make_bevel_box(th["node_active_bg"], Color.WHITE, 6 if bw == 3 else 5, bw))

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
	var max_lv: int = int(meta.get("max_level", WitchCauldronProgression.MAX_NODE_LEVEL))
	var lv := WitchCauldronProgression.get_node_level(_hero_id, _selected_node_id)
	var unlocked := WitchCauldronProgression.is_node_unlocked(_hero_id, _selected_node_id)
	var locked_other := WitchCauldronProgression.is_node_locked_by_other_pillar(_hero_id, _selected_node_id)
	var can_up := WitchCauldronProgression.can_upgrade_node(_hero_id, _selected_node_id)
	var icon_idx := int(meta["icon_idx"])

	if not _icon_frames.is_empty():
		_selected_icon_rect.texture = _icon_frames[clampi(icon_idx, 0, _icon_frames.size() - 1)]
		_selected_icon_rect.modulate = sec.lerp(Color.WHITE, 0.25) if unlocked else Color(0.62, 0.64, 0.74, 0.88)

	_selected_title_lbl.text = String(meta["title"])
	_selected_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.97, 1.0))

	var desc_txt := String(meta["desc"])
	if locked_other:
		desc_txt = "[LOCKED: Only 1 Pillar allowed! Reset Tree to switch] " + desc_txt
	_selected_desc_lbl.text = desc_txt
	_selected_desc_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.56, 0.62) if locked_other else (th["stat_highlight"] if lv > 0 else Color(0.84, 0.86, 0.92)))

	_selected_level_lbl.text = "Level: %d / %d" % [lv, max_lv]
	_selected_level_lbl.add_theme_color_override("font_color", Color(0.96, 0.96, 1.0))

	if lv >= max_lv:
		_selected_cost_lbl.text = "-"
		_upgrade_btn.text = "MAXED"
		_upgrade_btn.disabled = true
	elif locked_other:
		_selected_cost_lbl.text = "🔒"
		_upgrade_btn.text = "Other Pillar"
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


func _on_brew_potion_pressed() -> void:
	if WitchCauldronProgression.brew_potion_for_hero(_hero_id):
		_witch_offer_timer = 1.05
		if _gulp_sfx != null:
			_gulp_sfx.pitch_scale = randf_range(0.92, 1.06)
			_gulp_sfx.play()
		_refresh_nodes()
		potion_brewed.emit(_hero_id, WitchCauldronProgression.get_brew_points(_hero_id))


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
		_selected_node_id = "solo_top"
		_refresh_nodes()
		tree_reset.emit(_hero_id)


func _spawn_upgrade_flash(node_id: String) -> void:
	var th := WitchCauldronProgression.get_hero_theme(_hero_id)
	var sec: Color = th["secondary"]
	var center: Vector2 = _node_centers.get(node_id, Vector2(228.0, 44.0))

	var pop := Label.new()
	pop.text = "+1 LEVEL!"
	pop.position = center + Vector2(-28.0, -28.0)
	pop.size = Vector2(56.0, 14.0)
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop.add_theme_font_size_override("font_size", 8)
	pop.add_theme_color_override("font_color", sec)
	pop.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.96))
	pop.add_theme_constant_override("outline_size", 2)
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tree_content.add_child(pop)

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
	if _scroll_hint_lbl != null and _scroll != null:
		_scroll_hint_lbl.visible = (_scroll.scroll_vertical < 140)
	if _backdrop_canvas != null:
		_backdrop_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			hide_menu()
			get_viewport().set_input_as_handled()
