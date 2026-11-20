extends Control
## CharacterSelectMenu - full-screen hero picker shown when the game opens.
##
## Built in code using base-viewport coordinates (640x360 scaled 2x by
## project.godot's `canvas_items` stretch mode, matching `UpgradeMenu`).
##
## Controls:
##   - Click any of the 4 hero cards, OR
##   - Press 1 / 2 / 3 / 4 to pick directly, OR
##   - Use A/D or Left/Right arrows to highlight + Space/Enter to start!

signal character_selected(character_id: String)

const CARD_WIDTH := 142.0
const CARD_HEIGHT := 242.0
const CARD_GAP := 10.0
const CARD_TOP := 68.0

var _is_open: bool = false
var _selected_index: int = 0
var _cards: Array[Button] = []
var _portraits: Array[TextureRect] = []
var _atlas_frames: Array = []   # per card: Array[AtlasTexture] of the 6 frames
var _anim_timer: float = 0.0
var _anim_step: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.05, 0.05, 0.08, 0.88)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var title := Label.new()
	title.name = "Title"
	title.text = "CHOOSE YOUR HERO"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "WASD: Move   •   Space / Click: Attack   •   Shift: Dash (1s CD + Damage)"
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", Color(0.76, 0.82, 0.88))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	var footer := Label.new()
	footer.name = "Footer"
	footer.text = "Click a hero card  •  Press 1 - 4  •  Arrows + Enter / Space"
	footer.add_theme_font_size_override("font_size", 9)
	footer.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(footer)

	for i in CharacterRegistry.CHARACTERS.size():
		var entry: Dictionary = CharacterRegistry.CHARACTERS[i]
		_build_card(i, entry)

	if not get_viewport().size_changed.is_connected(_relayout):
		get_viewport().size_changed.connect(_relayout)
	_relayout()
	_refresh_card_highlights()


func _build_card(index: int, entry: Dictionary) -> void:
	var accent: Color = entry["accent"]
	var card := Button.new()
	card.name = "HeroCard_%d" % index
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(card)

	# Key shortcut badge [1]..[4]
	var key_lbl := Label.new()
	key_lbl.text = "[%d]" % (index + 1)
	key_lbl.add_theme_font_size_override("font_size", 10)
	key_lbl.add_theme_color_override("font_color", accent)
	key_lbl.position = Vector2(8, 6)
	card.add_child(key_lbl)

	# Role tag top-right (BRAWLER / KNIGHT / ELF / VAMPIRE)
	var role_lbl := Label.new()
	role_lbl.text = String(entry["role"])
	role_lbl.add_theme_font_size_override("font_size", 8)
	role_lbl.add_theme_color_override("font_color", accent.lightened(0.18))
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	role_lbl.position = Vector2(44, 7)
	role_lbl.size = Vector2(CARD_WIDTH - 52, 14)
	card.add_child(role_lbl)

	# Portrait frame backdrop
	var portrait_bg := Panel.new()
	portrait_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.08, 0.08, 0.11, 0.95)
	pstyle.set_corner_radius_all(6)
	pstyle.set_border_width_all(1)
	pstyle.border_color = accent.darkened(0.35)
	portrait_bg.add_theme_stylebox_override("panel", pstyle)
	portrait_bg.position = Vector2((CARD_WIDTH - 54.0) * 0.5, 24.0)
	portrait_bg.size = Vector2(54.0, 54.0)
	card.add_child(portrait_bg)

	# Slice 6 frames (24x24 each) from the character's spritesheet
	var sheet: Texture2D = load(entry["sheet_path"])
	var frames: Array[AtlasTexture] = []
	for f in range(6):
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(float(f * 24), 0.0, 24.0, 24.0)
		frames.append(at)
	_atlas_frames.append(frames)

	var portrait := TextureRect.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = frames[0]
	portrait.position = Vector2(3.0, 3.0)
	portrait.size = Vector2(48.0, 48.0)
	portrait_bg.add_child(portrait)
	_portraits.append(portrait)

	# Character Name
	var name_lbl := Label.new()
	name_lbl.text = String(entry["name"])
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(4, 82)
	name_lbl.size = Vector2(CARD_WIDTH - 8, 20)
	card.add_child(name_lbl)

	# Archetype subtitle
	var sub_lbl := Label.new()
	sub_lbl.text = String(entry["subtitle"])
	sub_lbl.add_theme_font_size_override("font_size", 9)
	sub_lbl.add_theme_color_override("font_color", accent)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.position = Vector2(4, 100)
	sub_lbl.size = Vector2(CARD_WIDTH - 8, 14)
	card.add_child(sub_lbl)

	# Stats pill line
	var stats_lbl := Label.new()
	stats_lbl.text = String(entry["stats_line"])
	stats_lbl.add_theme_font_size_override("font_size", 8)
	stats_lbl.add_theme_color_override("font_color", Color(0.84, 0.90, 0.94))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.position = Vector2(4, 118)
	stats_lbl.size = Vector2(CARD_WIDTH - 8, 14)
	card.add_child(stats_lbl)

	# Kit description
	var desc_lbl := Label.new()
	desc_lbl.text = String(entry["desc"])
	desc_lbl.add_theme_font_size_override("font_size", 8)
	desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.80, 0.84))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.position = Vector2(8, 137)
	desc_lbl.size = Vector2(CARD_WIDTH - 16, 74)
	card.add_child(desc_lbl)

	# Action prompt at bottom of card
	var play_lbl := Label.new()
	play_lbl.name = "PlayPrompt"
	play_lbl.text = "PLAY  [%d]" % (index + 1)
	play_lbl.add_theme_font_size_override("font_size", 10)
	play_lbl.add_theme_color_override("font_color", accent)
	play_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_lbl.position = Vector2(6, CARD_HEIGHT - 26)
	play_lbl.size = Vector2(CARD_WIDTH - 12, 18)
	card.add_child(play_lbl)

	card.mouse_entered.connect(_on_card_hovered.bind(index))
	card.pressed.connect(_on_card_pressed.bind(index))
	_cards.append(card)


func _card_style(bg: Color, border: Color, border_px: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(8)
	s.set_border_width_all(border_px)
	s.border_color = border
	s.set_content_margin_all(6)
	return s


func _refresh_card_highlights() -> void:
	for i in _cards.size():
		var entry: Dictionary = CharacterRegistry.CHARACTERS[i]
		var accent: Color = entry["accent"]
		var selected := (i == _selected_index)
		var bg := Color(0.17, 0.17, 0.23, 0.98) if selected else Color(0.11, 0.11, 0.15, 0.95)
		var border := accent if selected else Color(0.32, 0.32, 0.38)
		var width := 2 if selected else 1
		var card := _cards[i]
		card.add_theme_stylebox_override("normal", _card_style(bg, border, width))
		card.add_theme_stylebox_override("hover", _card_style(Color(0.19, 0.19, 0.26, 0.98), accent, 2))
		card.add_theme_stylebox_override("pressed", _card_style(Color(0.24, 0.23, 0.30, 1.0), accent.lightened(0.25), 2))
		var prompt := card.get_node_or_null("PlayPrompt") as Label
		if prompt != null:
			prompt.text = "► PLAY [%d] ◄" % (i + 1) if selected else "PLAY [%d]" % (i + 1)


func _relayout() -> void:
	var vp := get_viewport_rect().size
	var title := get_node_or_null("Title") as Label
	if title != null:
		title.position = Vector2(0, 14)
		title.size = Vector2(vp.x, 26)
	var subtitle := get_node_or_null("Subtitle") as Label
	if subtitle != null:
		subtitle.position = Vector2(0, 40)
		subtitle.size = Vector2(vp.x, 18)
	var footer := get_node_or_null("Footer") as Label
	if footer != null:
		footer.position = Vector2(0, vp.y - 28.0)
		footer.size = Vector2(vp.x, 18)

	var count := _cards.size()
	if count == 0:
		return
	var row_w := CARD_WIDTH * count + CARD_GAP * (count - 1)
	var start_x := (vp.x - row_w) * 0.5
	for i in count:
		_cards[i].position = Vector2(start_x + i * (CARD_WIDTH + CARD_GAP), CARD_TOP)
		_cards[i].size = Vector2(CARD_WIDTH, CARD_HEIGHT)


func _process(delta: float) -> void:
	if not _is_open:
		return
	# Animate the highlighted hero's pixel portrait (walk -> windup -> strike -> idle)!
	_anim_timer += delta
	if _anim_timer >= 0.24:
		_anim_timer = 0.0
		_anim_step = (_anim_step + 1) % 6
		var preview_seq := [0, 1, 2, 1, 3, 4]
		for i in _portraits.size():
			var frames: Array = _atlas_frames[i]
			if i == _selected_index:
				_portraits[i].texture = frames[preview_seq[_anim_step]]
			else:
				_portraits[i].texture = frames[0]


# =====================================================================
# PUBLIC API
# =====================================================================

func show_menu(default_id: String = "borzo") -> void:
	_selected_index = CharacterRegistry.get_index(default_id)
	_anim_timer = 0.0
	_anim_step = 0
	_is_open = true
	visible = true
	_relayout()
	_refresh_card_highlights()


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
				_refresh_card_highlights()
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_D:
				_selected_index = posmod(_selected_index + 1, _cards.size())
				_refresh_card_highlights()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_confirm_index(_selected_index)
				get_viewport().set_input_as_handled()
			_:
				pass


func _on_card_hovered(index: int) -> void:
	if _selected_index != index:
		_selected_index = index
		_refresh_card_highlights()


func _on_card_pressed(index: int) -> void:
	_confirm_index(index)


func _confirm_index(index: int) -> void:
	if not _is_open or index < 0 or index >= CharacterRegistry.CHARACTERS.size():
		return
	var chosen_id := String(CharacterRegistry.CHARACTERS[index]["id"])
	CharacterRegistry.selected_id = chosen_id
	hide_menu()
	character_selected.emit(chosen_id)
