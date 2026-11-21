extends Control
class_name GameOverOverlay
## Dark-Fantasy Game Over Screen (`UI/GameOver`).
##
## Displays:
##   - Moody obsidian & blood-crimson vignette + gothic filigree rules
##   - Engraved Dark-Fantasy serif header:  `DEAD AGAIN?`
##   - Interactive Dark-Fantasy rune button: `NOT YET`
##
## Emits `not_yet_pressed` when the player clicks `NOT YET` (or presses Enter/R)
## to trigger the Celestial Light-Beam + Magic-Circle Revival back to the Lobby!

signal not_yet_pressed

const DARK_FONT_PATH: String = "res://assets/fonts/dark_fantasy.ttf"

var title_label: Label = null
var not_yet_button: Button = null
var _bg_dim: ColorRect = null
var _ornament: GothicOrnament = null
var _dark_font: Font = null
var _can_accept_input: bool = false


class GothicOrnament extends Control:
	func _draw() -> void:
		var vp := size
		var cx := vp.x * 0.5
		var cy := vp.y * 0.5

		# Deep crimson radial aura behind `DEAD AGAIN?`
		draw_circle(Vector2(cx, cy - 22.0), 110.0, Color(0.28, 0.02, 0.06, 0.22))
		draw_circle(Vector2(cx, cy - 22.0), 68.0, Color(0.45, 0.04, 0.09, 0.18))

		# Upper & lower gothic crimson-gold horizontal rules + central diamond sigils
		var line_col := Color(0.68, 0.16, 0.22, 0.85)
		var gold_col := Color(0.86, 0.68, 0.34, 0.92)
		for y_off in [-62.0, 14.0]:
			var y: float = cy + float(y_off)
			draw_line(Vector2(cx - 170.0, y), Vector2(cx - 10.0, y), line_col, 1.4)
			draw_line(Vector2(cx + 10.0, y), Vector2(cx + 170.0, y), line_col, 1.4)
			# Center gothic diamond
			var pts := PackedVector2Array([
				Vector2(cx, y - 4.5),
				Vector2(cx + 6.0, y),
				Vector2(cx, y + 4.5),
				Vector2(cx - 6.0, y),
			])
			draw_colored_polygon(pts, gold_col)
			# Sword-tip end finials
			draw_circle(Vector2(cx - 172.0, y), 2.0, gold_col)
			draw_circle(Vector2(cx + 172.0, y), 2.0, gold_col)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	if ResourceLoader.exists(DARK_FONT_PATH):
		_dark_font = load(DARK_FONT_PATH)

	# Immediately detach any legacy static scene children (`Title`, `Subtitle`, `Backdrop`)
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()

	_bg_dim = ColorRect.new()
	_bg_dim.name = "Dim"
	_bg_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_dim.color = Color(0.03, 0.01, 0.02, 0.82)
	add_child(_bg_dim)

	_ornament = GothicOrnament.new()
	_ornament.name = "GothicOrnament"
	_ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ornament)

	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "DEAD AGAIN?"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _dark_font != null:
		title_label.add_theme_font_override("font", _dark_font)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(0.86, 0.14, 0.20, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	title_label.add_theme_constant_override("shadow_offset_x", 0)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	title_label.add_theme_color_override("font_outline_color", Color(0.14, 0.01, 0.03, 0.98))
	title_label.add_theme_constant_override("outline_size", 4)
	add_child(title_label)

	not_yet_button = Button.new()
	not_yet_button.name = "NotYetButton"
	not_yet_button.text = "NOT YET"
	not_yet_button.focus_mode = Control.FOCUS_NONE
	not_yet_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _dark_font != null:
		not_yet_button.add_theme_font_override("font", _dark_font)
	not_yet_button.add_theme_font_size_override("font_size", 14)
	not_yet_button.add_theme_color_override("font_color", Color(0.96, 0.89, 0.72))
	not_yet_button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.88))
	not_yet_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.82, 0.45))
	not_yet_button.add_theme_color_override("font_outline_color", Color(0.05, 0.01, 0.02, 0.96))
	not_yet_button.add_theme_constant_override("outline_size", 2)

	var normal_sb := _make_btn_style(Color(0.11, 0.05, 0.08, 0.96), Color(0.82, 0.64, 0.32, 0.95), 2)
	var hover_sb := _make_btn_style(Color(0.22, 0.07, 0.11, 0.98), Color(1.0, 0.86, 0.48, 1.0), 2)
	var press_sb := _make_btn_style(Color(0.30, 0.09, 0.14, 1.0), Color(1.0, 0.94, 0.68, 1.0), 2)
	not_yet_button.add_theme_stylebox_override("normal", normal_sb)
	not_yet_button.add_theme_stylebox_override("hover", hover_sb)
	not_yet_button.add_theme_stylebox_override("pressed", press_sb)
	not_yet_button.pressed.connect(_trigger_not_yet)
	add_child(not_yet_button)

	if not get_viewport().size_changed.is_connected(_relayout):
		get_viewport().size_changed.connect(_relayout)
	_relayout()


func _make_btn_style(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _relayout() -> void:
	var vp := get_viewport_rect().size
	if title_label != null:
		title_label.size = Vector2(420.0, 56.0)
		title_label.position = Vector2((vp.x - 420.0) * 0.5, vp.y * 0.5 - 52.0)
		title_label.pivot_offset = title_label.size * 0.5
	if not_yet_button != null:
		not_yet_button.size = Vector2(154.0, 34.0)
		not_yet_button.position = Vector2((vp.x - 154.0) * 0.5, vp.y * 0.5 + 30.0)
	if _ornament != null:
		_ornament.queue_redraw()


func present_game_over(delay_sec: float = 0.72) -> void:
	_can_accept_input = false
	visible = true
	modulate.a = 0.0
	_relayout()
	if title_label != null:
		title_label.scale = Vector2(1.16, 1.16)

	var tw := create_tween()
	if delay_sec > 0.01:
		tw.tween_interval(delay_sec)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if title_label != null:
		tw.tween_property(title_label, "scale", Vector2.ONE, 0.44).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		_can_accept_input = true
	)


func dismiss_for_revival() -> void:
	_can_accept_input = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		visible = false
	)


func _trigger_not_yet() -> void:
	if not visible:
		return
	_can_accept_input = false
	not_yet_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _can_accept_input:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		_trigger_not_yet()
