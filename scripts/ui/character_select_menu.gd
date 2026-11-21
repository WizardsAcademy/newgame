extends Control
## CharacterSelectMenu - Showcase + 4-Hero Picker + Live Arena & Mini-Map View.
##
## Designed specifically for the 640x360 base viewport (scaled 2x to 1280x720):
##   - Translucent backdrop (`alpha = 0.34`) keeps the live stone Arena & your
##     highlighted hero visible right behind the UI!
##   - Leaves top-right (`x = 500..630, y = 8..92`) completely open for `MiniMap`.
##   - Large 608x138 **Hero Showcase Panel** displays a 64x64 animated sprite,
##     4 graphical stat bars (HP / ATK / SPD / DASH), and full Attack, Passive,
##     & Shift-Dash descriptions at crisp outlined font sizes.
##   - Bottom row of 4 interactive hero cards (`Behemoth`, `Knight`, `Sylvara`,
##     `Velmira`) + glowing `PLAY AS <HERO>` launch button.

signal character_highlighted(character_id: String)
signal character_selected(character_id: String)

const SHOWCASE_W := 608.0
const SHOWCASE_H := 138.0
const SHOWCASE_TOP := 94.0

const CARD_WIDTH := 144.0
const CARD_HEIGHT := 76.0
const CARD_GAP := 10.0
const CARD_TOP := 238.0

const START_BTN_W := 268.0
const START_BTN_H := 30.0
const START_BTN_TOP := 321.0

var _is_open: bool = false
var _selected_index: int = 0
var _cards: Array[Button] = []
var _card_portraits: Array[TextureRect] = []
var _atlas_frames: Array = []   # per hero: Array[AtlasTexture] (6 frames)
var _anim_timer: float = 0.0
var _anim_step: int = 0

var _showcase_panel: Panel = null
var _pedestal: HeroPedestal = null
var _showcase_portrait: TextureRect = null
var _showcase_role: Label = null
var _showcase_name: Label = null
var _showcase_sub: Label = null
var _stat_bars: StatBarsWidget = null
var _atk_desc: Label = null
var _pas_desc: Label = null
var _dsh_desc: Label = null
var _start_btn: Button = null


## Custom glowing circular pedestal drawn under the 64x64 showcase sprite.
class HeroPedestal extends Control:
	var accent: Color = Color(0.98, 0.68, 0.26)
	var pulse: float = 0.0

	func _draw() -> void:
		var c := size * 0.5 + Vector2(0.0, 14.0)
		var r := 28.0 + 2.0 * sin(pulse * 4.0)
		draw_circle(c, r, Color(accent.r, accent.g, accent.b, 0.14))
		draw_circle(c, r * 0.68, Color(accent.r, accent.g, accent.b, 0.20))
		draw_arc(c, r, 0.0, TAU, 32, Color(accent.r, accent.g, accent.b, 0.55), 1.5)


## Custom graphical 4-row stat bar widget (HP / ATK / SPD / DASH).
class StatBarsWidget extends Control:
	var ratios: Array[float] = [0.8, 0.8, 0.7, 0.8]
	var colors: Array[Color] = [
		Color(0.38, 0.90, 0.48),
		Color(0.98, 0.74, 0.28),
		Color(0.42, 0.86, 1.0),
		Color(0.76, 0.56, 1.0),
	]

	func _draw() -> void:
		var bar_x := 36.0
		var bar_w := 86.0
		var bar_h := 7.0
		var row_step := 18.0
		for i in range(4):
			var y := 4.0 + float(i) * row_step
			var bg_rect := Rect2(Vector2(bar_x, y), Vector2(bar_w, bar_h))
			draw_rect(Rect2(bg_rect.position - Vector2.ONE, bg_rect.size + Vector2(2, 2)), Color(0.04, 0.05, 0.08, 0.95))
			draw_rect(bg_rect, Color(0.14, 0.16, 0.22, 0.95))
			var fill_w := bar_w * clampf(ratios[i], 0.08, 1.0)
			draw_rect(Rect2(bg_rect.position, Vector2(fill_w, bar_h)), colors[i])


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	# Subtle translucent glass backdrop so the live Arena & hero remain visible!
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.03, 0.04, 0.08, 0.34)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# Header banner on top-left (leaves x=500..630 free for the Mini-Map!)
	var header_bg := Panel.new()
	header_bg.name = "HeaderPanel"
	header_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_bg.add_theme_stylebox_override("panel", _panel_style(
		Color(0.07, 0.09, 0.14, 0.84), Color(0.46, 0.52, 0.66, 0.75), 1, 8
	))
	add_child(header_bg)

	var title := _make_label("HERO WARDROBE", 19, Color(1.0, 0.94, 0.72), 3)
	title.name = "Title"
	add_child(title)

	var subtitle := _make_label(
		"Hover or A/D to inspect   •   Click hero or 1-4 / Enter to Equip   •   [ESC] Close",
		9, Color(0.82, 0.88, 0.96), 2
	)
	subtitle.name = "Subtitle"
	add_child(subtitle)

	# Slice hero spritesheets once for all 4 heroes. The frame width is
	# derived from the sheet itself, so heroes may mix frame sizes
	# (e.g. Velmira is 6 x 96 px while the others are 6 x 32 px).
	for i in CharacterRegistry.CHARACTERS.size():
		var entry: Dictionary = CharacterRegistry.CHARACTERS[i]
		var sheet: Texture2D = load(entry["sheet_path"])
		var fcount: int = int(entry.get("frame_count", 6))
		var fw: float = float(sheet.get_width()) / float(maxi(fcount, 1))
		var fh: float = float(sheet.get_height())
		var frames: Array[AtlasTexture] = []
		for f in range(fcount):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(float(f) * fw, 0.0, fw, fh)
			frames.append(at)
		_atlas_frames.append(frames)

	_build_showcase_panel()

	for i in CharacterRegistry.CHARACTERS.size():
		_build_hero_card(i, CharacterRegistry.CHARACTERS[i])

	_build_start_button()

	if not get_viewport().size_changed.is_connected(_relayout):
		get_viewport().size_changed.connect(_relayout)
	_relayout()
	_refresh_selection_visuals(false)


func _make_label(txt: String, fsize: int, col: Color, outline: int = 2) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.94))
	lbl.add_theme_constant_override("outline_size", outline)
	return lbl


func _panel_style(bg: Color, border: Color, border_px: int = 2, radius: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border_px)
	s.border_color = border
	s.set_content_margin_all(6)
	return s


func _build_showcase_panel() -> void:
	_showcase_panel = Panel.new()
	_showcase_panel.name = "ShowcasePanel"
	_showcase_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_showcase_panel)

	# --- Left column: Glowing Pedestal + 64x64 Animated Hero Sprite ---
	var stage_box := Panel.new()
	stage_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_box.add_theme_stylebox_override("panel", _panel_style(
		Color(0.05, 0.06, 0.10, 0.92), Color(0.30, 0.34, 0.44, 0.8), 1, 6
	))
	stage_box.position = Vector2(12, 10)
	stage_box.size = Vector2(106, 118)
	_showcase_panel.add_child(stage_box)

	_pedestal = HeroPedestal.new()
	_pedestal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pedestal.position = Vector2.ZERO
	_pedestal.size = stage_box.size
	stage_box.add_child(_pedestal)

	_showcase_portrait = TextureRect.new()
	_showcase_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_showcase_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_showcase_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_showcase_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_showcase_portrait.position = Vector2(21, 12)
	_showcase_portrait.size = Vector2(64, 64)
	stage_box.add_child(_showcase_portrait)

	_showcase_role = _make_label("BRAWLER", 10, Color.WHITE, 2)
	_showcase_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_showcase_role.position = Vector2(4, 92)
	_showcase_role.size = Vector2(98, 18)
	stage_box.add_child(_showcase_role)

	# --- Middle column: Big Hero Name + 4 Graphical Stat Bars ---------
	_showcase_name = _make_label("Behemoth", 18, Color(1.0, 0.97, 0.88), 3)
	_showcase_name.position = Vector2(130, 8)
	_showcase_name.size = Vector2(204, 24)
	_showcase_panel.add_child(_showcase_name)

	_showcase_sub = _make_label("Iron-Fist Brawler", 10, Color(0.95, 0.72, 0.34), 2)
	_showcase_sub.position = Vector2(130, 31)
	_showcase_sub.size = Vector2(204, 16)
	_showcase_panel.add_child(_showcase_sub)

	_stat_bars = StatBarsWidget.new()
	_stat_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stat_bars.position = Vector2(130, 54)
	_stat_bars.size = Vector2(204, 74)
	_showcase_panel.add_child(_stat_bars)

	var stat_titles := ["HP", "ATK", "SPD", "DASH"]
	for i in range(4):
		var st := _make_label(stat_titles[i], 9, Color(0.78, 0.84, 0.92), 2)
		st.position = Vector2(0, float(i) * 18.0)
		st.size = Vector2(34, 14)
		_stat_bars.add_child(st)

		var sv := _make_label("", 9, Color(0.96, 0.98, 1.0), 2)
		sv.name = "StatVal_%d" % i
		sv.position = Vector2(128, float(i) * 18.0)
		sv.size = Vector2(80, 14)
		_stat_bars.add_child(sv)

	# Vertical divider between stats & abilities
	var div := ColorRect.new()
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	div.color = Color(0.45, 0.50, 0.62, 0.35)
	div.position = Vector2(338, 12)
	div.size = Vector2(1, 114)
	_showcase_panel.add_child(div)

	# --- Right column: Full Weapon, Signature Passive & Shift-Dash ----
	var atk_hdr := _make_label("ATTACK  [Space / Click]", 9, Color(1.0, 0.86, 0.42), 2)
	atk_hdr.position = Vector2(348, 8)
	atk_hdr.size = Vector2(250, 13)
	_showcase_panel.add_child(atk_hdr)

	_atk_desc = _make_label("", 9, Color(0.92, 0.94, 0.98), 2)
	_atk_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_atk_desc.position = Vector2(348, 22)
	_atk_desc.size = Vector2(250, 28)
	_showcase_panel.add_child(_atk_desc)

	var pas_hdr := _make_label("SIGNATURE PASSIVE", 9, Color(0.58, 0.96, 0.72), 2)
	pas_hdr.name = "PassiveHeader"
	pas_hdr.position = Vector2(348, 52)
	pas_hdr.size = Vector2(250, 13)
	_showcase_panel.add_child(pas_hdr)

	_pas_desc = _make_label("", 9, Color(0.92, 0.94, 0.98), 2)
	_pas_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pas_desc.position = Vector2(348, 66)
	_pas_desc.size = Vector2(250, 28)
	_showcase_panel.add_child(_pas_desc)

	var dsh_hdr := _make_label("SHIFT DASH  [1.0s Cooldown]", 9, Color(0.48, 0.90, 1.0), 2)
	dsh_hdr.position = Vector2(348, 96)
	dsh_hdr.size = Vector2(250, 13)
	_showcase_panel.add_child(dsh_hdr)

	_dsh_desc = _make_label("", 9, Color(0.92, 0.94, 0.98), 2)
	_dsh_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dsh_desc.position = Vector2(348, 110)
	_dsh_desc.size = Vector2(250, 24)
	_showcase_panel.add_child(_dsh_desc)


func _build_hero_card(index: int, entry: Dictionary) -> void:
	var accent: Color = entry["accent"]
	var card := Button.new()
	card.name = "HeroCard_%d" % index
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(card)

	var key_lbl := _make_label("[%d]" % (index + 1), 10, accent, 2)
	key_lbl.position = Vector2(7, 5)
	card.add_child(key_lbl)

	var p_bg := Panel.new()
	p_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_bg.add_theme_stylebox_override("panel", _panel_style(
		Color(0.06, 0.07, 0.11, 0.95), accent.darkened(0.35), 1, 5
	))
	p_bg.position = Vector2(8, 23)
	p_bg.size = Vector2(44, 44)
	card.add_child(p_bg)

	var portrait := TextureRect.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = _atlas_frames[index][0]
	portrait.position = Vector2(4, 4)
	portrait.size = Vector2(36, 36)
	p_bg.add_child(portrait)
	_card_portraits.append(portrait)

	var name_lbl := _make_label(String(entry["name"]), 13, Color(1.0, 0.98, 0.90), 2)
	name_lbl.position = Vector2(58, 12)
	name_lbl.size = Vector2(82, 20)
	card.add_child(name_lbl)

	var role_lbl := _make_label(String(entry["role"]), 9, accent.lightened(0.15), 2)
	role_lbl.position = Vector2(58, 33)
	role_lbl.size = Vector2(82, 14)
	card.add_child(role_lbl)

	var hp_lbl := _make_label("HP %d" % int(entry["hp"]), 9, Color(0.78, 0.88, 0.94), 2)
	hp_lbl.position = Vector2(58, 49)
	hp_lbl.size = Vector2(82, 14)
	card.add_child(hp_lbl)

	card.mouse_entered.connect(_on_card_hovered.bind(index))
	card.pressed.connect(_on_card_pressed.bind(index))
	_cards.append(card)


func _build_start_button() -> void:
	_start_btn = Button.new()
	_start_btn.name = "StartButton"
	_start_btn.focus_mode = Control.FOCUS_NONE
	_start_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_start_btn.add_theme_font_size_override("font_size", 12)
	_start_btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90))
	_start_btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_start_btn.add_theme_constant_override("outline_size", 2)
	_start_btn.pressed.connect(_on_start_pressed)
	add_child(_start_btn)


func _refresh_selection_visuals(emit_highlight: bool = true) -> void:
	var entry: Dictionary = CharacterRegistry.CHARACTERS[_selected_index]
	var accent: Color = entry["accent"]

	# Update Showcase Panel
	if _showcase_panel != null:
		_showcase_panel.add_theme_stylebox_override("panel", _panel_style(
			Color(0.08, 0.10, 0.15, 0.88), accent, 2, 9
		))
	if _pedestal != null:
		_pedestal.accent = accent
		_pedestal.queue_redraw()
	if _showcase_portrait != null:
		var f0: AtlasTexture = _atlas_frames[_selected_index][0]
		_showcase_portrait.texture = f0
		_showcase_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if f0.region.size.y > 96.0 else CanvasItem.TEXTURE_FILTER_NEAREST
	if _showcase_role != null:
		_showcase_role.text = String(entry["role"])
		_showcase_role.add_theme_color_override("font_color", accent.lightened(0.2))
	if _showcase_name != null:
		_showcase_name.text = String(entry["name"])
	if _showcase_sub != null:
		_showcase_sub.text = String(entry["subtitle"])
		_showcase_sub.add_theme_color_override("font_color", accent)

	if _stat_bars != null:
		_stat_bars.ratios = [
			float(entry["hp_ratio"]),
			float(entry["atk_ratio"]),
			float(entry["spd_ratio"]),
			float(entry["dash_ratio"]),
		]
		(_stat_bars.get_node("StatVal_0") as Label).text = str(entry["hp"])
		(_stat_bars.get_node("StatVal_1") as Label).text = String(entry["atk_text"])
		(_stat_bars.get_node("StatVal_2") as Label).text = String(entry["spd_text"])
		(_stat_bars.get_node("StatVal_3") as Label).text = String(entry["dash_text"])
		_stat_bars.queue_redraw()

	var pas_hdr := _showcase_panel.get_node_or_null("PassiveHeader") as Label
	if pas_hdr != null:
		pas_hdr.add_theme_color_override("font_color", accent.lightened(0.2))

	if _atk_desc != null:
		_atk_desc.text = String(entry["attack_info"])
	if _pas_desc != null:
		_pas_desc.text = String(entry["passive_info"])
	if _dsh_desc != null:
		_dsh_desc.text = String(entry["dash_info"])

	# Update 4 Hero Cards
	for i in _cards.size():
		var c_entry: Dictionary = CharacterRegistry.CHARACTERS[i]
		var c_accent: Color = c_entry["accent"]
		var is_sel := (i == _selected_index)
		var bg := Color(0.16, 0.18, 0.26, 0.94) if is_sel else Color(0.09, 0.10, 0.15, 0.86)
		var border := c_accent if is_sel else Color(0.32, 0.35, 0.44, 0.85)
		var b_px := 2 if is_sel else 1
		_cards[i].add_theme_stylebox_override("normal", _panel_style(bg, border, b_px, 7))
		_cards[i].add_theme_stylebox_override("hover", _panel_style(Color(0.19, 0.21, 0.30, 0.96), c_accent, 2, 7))
		_cards[i].add_theme_stylebox_override("pressed", _panel_style(Color(0.24, 0.25, 0.35, 0.98), c_accent.lightened(0.25), 2, 7))

	# Update Start Button
	if _start_btn != null:
		_start_btn.text = "►  EQUIP %s   [ENTER]  ◄" % String(entry["name"]).to_upper()
		_start_btn.add_theme_stylebox_override("normal", _panel_style(
			accent.darkened(0.55), accent, 2, 7
		))
		_start_btn.add_theme_stylebox_override("hover", _panel_style(
			accent.darkened(0.40), accent.lightened(0.22), 2, 7
		))
		_start_btn.add_theme_stylebox_override("pressed", _panel_style(
			accent.darkened(0.30), Color.WHITE, 2, 7
		))

	if emit_highlight and _is_open:
		character_highlighted.emit(String(entry["id"]))


func _relayout() -> void:
	var vp := get_viewport_rect().size
	var header_bg := get_node_or_null("HeaderPanel") as Panel
	if header_bg != null:
		header_bg.position = Vector2(16, 8)
		header_bg.size = Vector2(minf(vp.x - 156.0, 476.0), 54)

	var title := get_node_or_null("Title") as Label
	if title != null:
		title.position = Vector2(28, 12)
		title.size = Vector2(452, 24)

	var subtitle := get_node_or_null("Subtitle") as Label
	if subtitle != null:
		subtitle.position = Vector2(28, 38)
		subtitle.size = Vector2(456, 18)

	if _showcase_panel != null:
		_showcase_panel.position = Vector2((vp.x - SHOWCASE_W) * 0.5, SHOWCASE_TOP)
		_showcase_panel.size = Vector2(SHOWCASE_W, SHOWCASE_H)

	var count := _cards.size()
	if count > 0:
		var row_w := CARD_WIDTH * count + CARD_GAP * (count - 1)
		var start_x := (vp.x - row_w) * 0.5
		for i in count:
			_cards[i].position = Vector2(start_x + i * (CARD_WIDTH + CARD_GAP), CARD_TOP)
			_cards[i].size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	if _start_btn != null:
		_start_btn.position = Vector2((vp.x - START_BTN_W) * 0.5, START_BTN_TOP)
		_start_btn.size = Vector2(START_BTN_W, START_BTN_H)


func _process(delta: float) -> void:
	if not _is_open:
		return
	if _pedestal != null:
		_pedestal.pulse += delta
		_pedestal.queue_redraw()

	_anim_timer += delta
	if _anim_timer >= 0.20:
		_anim_timer = 0.0
		var hero_frames: Array = _atlas_frames[_selected_index]
		var seq := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9] if hero_frames.size() >= 15 else [0, 1, 2, 3, 4, 5]
		_anim_step = (_anim_step + 1) % seq.size()
		var frame_idx: int = mini(int(seq[_anim_step]), hero_frames.size() - 1)
		if _showcase_portrait != null:
			_showcase_portrait.texture = hero_frames[frame_idx]
		for i in _card_portraits.size():
			var cf: Array = _atlas_frames[i]
			if cf[0].region.size.y > 96.0:
				_card_portraits[i].texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			_card_portraits[i].texture = cf[mini(frame_idx, cf.size() - 1) if i == _selected_index else 0]


# =====================================================================
# PUBLIC API
# =====================================================================

func show_menu(default_id: String = "behemoth") -> void:
	_selected_index = CharacterRegistry.get_index(default_id)
	_anim_timer = 0.0
	_anim_step = 0
	_is_open = true
	visible = true
	_relayout()
	_refresh_selection_visuals(true)


func hide_menu() -> void:
	_is_open = false
	visible = false


func is_open() -> bool:
	return _is_open


# =====================================================================
# INPUT
# =====================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_1, KEY_KP_1:
				_confirm_index(0)
				get_viewport().set_input_as_handled()
			KEY_2, KEY_KP_2:
				_confirm_index(1)
				get_viewport().set_input_as_handled()
			KEY_3, KEY_KP_3:
				_confirm_index(2)
				get_viewport().set_input_as_handled()
			KEY_4, KEY_KP_4:
				_confirm_index(3)
				get_viewport().set_input_as_handled()
			KEY_LEFT, KEY_A:
				_selected_index = posmod(_selected_index - 1, _cards.size())
				_refresh_selection_visuals(true)
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_D:
				_selected_index = posmod(_selected_index + 1, _cards.size())
				_refresh_selection_visuals(true)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_confirm_index(_selected_index)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_confirm_index(_selected_index)
				get_viewport().set_input_as_handled()
			_:
				pass


func _on_card_hovered(index: int) -> void:
	if _selected_index != index:
		_selected_index = index
		_refresh_selection_visuals(true)


func _on_card_pressed(index: int) -> void:
	_selected_index = index
	_confirm_index(index)


func _on_start_pressed() -> void:
	_confirm_index(_selected_index)


func _confirm_index(index: int) -> void:
	if not _is_open or index < 0 or index >= CharacterRegistry.CHARACTERS.size():
		return
	var chosen_id := String(CharacterRegistry.CHARACTERS[index]["id"])
	CharacterRegistry.selected_id = chosen_id
	hide_menu()
	character_selected.emit(chosen_id)
