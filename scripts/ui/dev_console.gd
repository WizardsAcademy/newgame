extends Control
class_name DevConsole
## Blank Developer Console toggled via `` ` `` (`KEY_QUOTELEFT` / unicode `96`).
## Intentionally shows ZERO hints, ZERO command names, and ZERO help text!

signal command_wizard_triggered
signal command_canoheil_triggered
signal console_toggled(is_open_now: bool)

var _is_open: bool = false
var _box: Panel = null
var _log_lbl: Label = null
var _input_line: LineEdit = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	size = Vector2(640.0, 44.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 120
	visible = false
	_build_ui()


func _build_ui() -> void:
	_box = Panel.new()
	_box.name = "ConsolePanel"
	_box.position = Vector2(8.0, 6.0)
	_box.size = Vector2(624.0, 34.0)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.02, 0.03, 0.06, 0.94)
	st.border_color = Color(0.32, 0.42, 0.56, 0.88)
	st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	_box.add_theme_stylebox_override("panel", st)
	add_child(_box)

	_log_lbl = Label.new()
	_log_lbl.name = "LogLabel"
	_log_lbl.text = ""
	_log_lbl.visible = false
	_box.add_child(_log_lbl)

	_input_line = LineEdit.new()
	_input_line.name = "CommandInput"
	_input_line.placeholder_text = ""
	_input_line.text = ""
	_input_line.position = Vector2(6.0, 5.0)
	_input_line.size = Vector2(612.0, 24.0)
	_input_line.add_theme_font_size_override("font_size", 9)
	_input_line.text_submitted.connect(_on_text_submitted)
	_input_line.text_changed.connect(_on_text_changed)
	_box.add_child(_input_line)


func is_open() -> bool:
	return _is_open


func open_console() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	if _input_line != null:
		_input_line.text = ""
		_input_line.call_deferred("grab_focus")
	console_toggled.emit(true)


func close_console() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	if _input_line != null:
		_input_line.release_focus()
	console_toggled.emit(false)


func toggle_console() -> void:
	if _is_open:
		close_console()
	else:
		open_console()


func _on_text_changed(new_txt: String) -> void:
	if new_txt.find("`") != -1 or new_txt.find("~") != -1:
		var cleaned := new_txt.replace("`", "").replace("~", "")
		_input_line.text = cleaned
		_input_line.caret_column = cleaned.length()


func _on_text_submitted(raw_text: String) -> void:
	submit_command(raw_text)
	if _input_line != null:
		_input_line.text = ""


func submit_command(raw_text: String) -> String:
	var cmd := raw_text.strip_edges().to_lower()
	if cmd == "wizard":
		command_wizard_triggered.emit()
		return "ok"
	elif cmd == "canoheil":
		command_canoheil_triggered.emit()
		return "ok"
	return ""


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		var is_backtick: bool = (
			ke.keycode == KEY_QUOTELEFT
			or ke.physical_keycode == KEY_QUOTELEFT
			or ke.keycode == KEY_ASCIITILDE
			or ke.unicode == 96
			or ke.unicode == 126
		)
		if is_backtick:
			toggle_console()
			get_viewport().set_input_as_handled()
			return
		if _is_open and ke.keycode == KEY_ESCAPE:
			close_console()
			get_viewport().set_input_as_handled()
			return
