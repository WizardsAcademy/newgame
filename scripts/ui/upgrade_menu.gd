extends Control
## UpgradeMenu - the "pick 1 of 3" overlay between waves.
##
## Built entirely in code (no .tscn nodes to keep in sync): _ready()
## constructs the dim backdrop, the title and three cards. Main only has
## to: show_menu(options) -> listen for upgrade_chosen(id) -> hide().
##
## Input: mouse click on a card, or keyboard 1 / 2 / 3.

## Picked one of the shown options. Connect BEFORE show_menu() so the
## very first pick is heard.
signal upgrade_chosen(id: String)

# =====================================================================
# STATE
# =====================================================================

## The 3 (or fewer) options currently on screen, in card order.
var _current_options: Array[Dictionary] = []
var _buttons: Array[Button] = []

## True while the overlay is visible - guards keyboard input.
var _is_open: bool = false

# Card layout constants (used by _relayout). ALL in base-viewport
# pixels: the project is 640x360 and the window only SCALES it 2x
# (project.godot: canvas_items stretch), so code written for 1280
# coordinates ended up half off screen.
const CARD_WIDTH := 185.0
const CARD_HEIGHT := 160.0
const CARD_GAP := 16.0
const CARD_TOP := 150.0


# =====================================================================
# SETUP (everything in code - see class doc)
# =====================================================================

func _ready() -> void:
	# Full-screen dim layer: blocks clicks AND makes it obvious the
	# world is "on hold" while you think.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP  # eat world clicks
	add_child(backdrop)

	var title := Label.new()
	title.name = "Title"
	title.text = "Wave cleared! One upgrade:"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# Three cards. Positions are set in _relayout(): the project viewport
	# is small and scaled up by the window, so hardcoding pixel positions
	# for one window size pushed cards half off screen. Laying out from
	# the REAL viewport size works at any zoom.
	for i in range(3):
		var card := Button.new()
		# Card look: dark panel; the label sits inside as a child.
		card.add_theme_stylebox_override("normal", _card_style(Color(0.13, 0.13, 0.16)))
		card.add_theme_stylebox_override("hover", _card_style(Color(0.22, 0.2, 0.16)))
		card.add_theme_stylebox_override("pressed", _card_style(Color(0.3, 0.26, 0.18)))
		card.focus_mode = Control.FOCUS_NONE  # keyboard 1/2/3 instead
		add_child(card)

		var key_label := Label.new()
		key_label.text = str(i + 1)
		key_label.add_theme_font_size_override("font_size", 14)
		key_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		key_label.position = Vector2(8, 6)
		card.add_child(key_label)

		var name_label := Label.new()
		name_label.name = "Name"
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.anchor_left = 0.0
		name_label.anchor_right = 1.0
		name_label.offset_top = 24
		name_label.offset_bottom = 52
		card.add_child(name_label)

		var desc_label := Label.new()
		desc_label.name = "Desc"
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		desc_label.anchor_left = 0.0
		desc_label.anchor_right = 1.0
		desc_label.offset_top = 58
		desc_label.offset_bottom = 140
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(desc_label)

		# Bind by VALUE: the default-arg trick captures i per card
		# (connecting a bare method would keep the LAST loop value).
		card.pressed.connect(_on_card_pressed.bind(i))
		_buttons.append(card)

	# Re-center on every window resize.
	if not get_viewport().size_changed.is_connected(_relayout):
		get_viewport().size_changed.connect(_relayout)
	_relayout()


## Centre the title and the card row inside the CURRENT viewport size.
func _relayout() -> void:
	var vp := get_viewport_rect().size
	var title := get_node_or_null("Title") as Label
	if title:
		title.position = Vector2(0, 100)
		title.size = Vector2(vp.x, 30)
	var shown := 0
	for card in _buttons:
		if not card.visible:
			continue
		shown += 1
	if shown == 0:
		shown = 3  # _ready(): nothing shown yet, still reserve the row
	var row_width := CARD_WIDTH * shown + CARD_GAP * (shown - 1)
	var start_x := (vp.x - row_width) / 2.0
	var placed := 0
	for card in _buttons:
		if not card.visible:
			continue
		card.position = Vector2(start_x + placed * (CARD_WIDTH + CARD_GAP), CARD_TOP)
		card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		placed += 1


## Panel style helper - a flat rounded panel is enough for now.
func _card_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.45, 0.4, 0.3)
	style.set_content_margin_all(8)
	return style


# =====================================================================
# PUBLIC API
# =====================================================================

## Fill the cards and show the overlay. `options` comes from
## UpgradePool.roll(): [{id, title, desc}, ...] - 3 normally.
func show_menu(options: Array[Dictionary]) -> void:
	_current_options = options
	for i in range(_buttons.size()):
		if i < options.size():
			var option := options[i]
			var card := _buttons[i]
			card.get_node("Name").text = option["title"]
			card.get_node("Desc").text = option["desc"]
			card.visible = true
		else:
			_buttons[i].visible = false  # late game: pool can shrink below 3
	_is_open = true
	visible = true
	_relayout()


func hide_menu() -> void:
	_is_open = false
	current_options_reset()
	visible = false


func current_options_reset() -> void:
	_current_options = []


func is_open() -> bool:
	return _is_open


# =====================================================================
# INPUT
# =====================================================================

## 1 / 2 / 3 on the keyboard - arcade-style, matching the cards order.
func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_1: _choose(0)
			KEY_2: _choose(1)
			KEY_3: _choose(2)
			_: pass


func _on_card_pressed(index: int) -> void:
	_choose(index)


func _choose(index: int) -> void:
	if not _is_open or index >= _current_options.size():
		return
	var option := _current_options[index]
	hide_menu()
	# Emit LAST, after the menu is closed: handlers may show the next
	# banner and must not see a stale open menu.
	upgrade_chosen.emit(option["id"])
