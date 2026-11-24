extends Control
class_name DevConsole
## In-Game Backtick (`` ` ``) Developer & Cheat Console!
##
## Keybind:
##   - Press `` ` `` (`KEY_QUOTELEFT` / unicode `96`) anytime to open/close!
## Commands:
##   - `wizard`   -> Grants `+10,000` Skill Points!
##   - `canoheil` -> Resets ALL heroes (skill trees, points, reagents, & live stats)!

signal command_wizard_triggered
signal command_canoheil_triggered
signal console_toggled(is_open_now: bool)

var _is_open: bool = false
var _box: Panel = null
var _log_lbl: Label = null
var _input_line: LineEdit = null
var _history_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	size = Vector2(640.0, 96.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 120
	visible = false
	_build_ui()


func _build_ui() -> void:
	_box = Panel.new()
	_box.name = "ConsolePanel"
	_box.position = Vector2(8.0, 6.0)
	_box.size = Vector2(624.0, 86.0)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.03, 0.04, 0.08, 0.94)
	st.border_color = Color(0.46, 0.82, 1.0, 0.92)
	st.set_border_width_all(2)
	st.set_corner_radius_all(5)
	_box.add_theme_stylebox_override("panel", st)
	add_child(_box)

	var header := Label.new()
	header.name = "HeaderLabel"
	header.text = "ARCANE DEV CONSOLE  [` to close]  —  Commands: wizard | canoheil"
	header.position = Vector2(10.0, 5.0)
	header.size = Vector2(604.0, 14.0)
	header.add_theme_font_size_override("font_size", 8)
	header.add_theme_color_override("font_color", Color(0.62, 0.90, 1.0))
	_box.add_child(header)

	_log_lbl = Label.new()
	_log_lbl.name = "LogLabel"
	_log_lbl.position = Vector2(10.0, 21.0)
	_log_lbl.size = Vector2(604.0, 34.0)
	_log_lbl.add_theme_font_size_override("font_size", 8)
	_log_lbl.add_theme_color_override("font_color", Color(0.84, 0.96, 0.88))
	_log_lbl.clip_text = true
	_box.add_child(_log_lbl)

	_input_line = LineEdit.new()
	_input_line.name = "CommandInput"
	_input_line.placeholder_text = "Type command (wizard = 10000 skill points | canoheil = reset heroes)..."
	_input_line.position = Vector2(10.0, 57.0)
	_input_line.size = Vector2(604.0, 22.0)
	_input_line.add_theme_font_size_override("font_size", 9)
	_input_line.text_submitted.connect(_on_text_submitted)
	_input_line.text_changed.connect(_on_text_changed)
	_box.add_child(_input_line)

	_append_log("Console ready. Type 'wizard' (+10000 Skill Points) or 'canoheil' (Reset All Heroes).")


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
	if cmd == "":
		return ""
	if cmd == "wizard":
		command_wizard_triggered.emit()
		var msg := "[WIZARD] Granted +10,000 Skill Points!"
		_append_log(msg)
		return msg
	elif cmd == "canoheil":
		command_canoheil_triggered.emit()
		var msg2 := "[CANOHEIL] Reset all heroes, skill trees, and points!"
		_append_log(msg2)
		return msg2
	elif cmd == "help":
		var hmsg := "Commands: wizard (+10000 Skill Points) | canoheil (Reset All Heroes)"
		_append_log(hmsg)
		return hmsg
	else:
		var umsg := "Unknown command '%s'. Try: wizard | canoheil" % cmd
		_append_log(umsg)
		return umsg


func _append_log(line: String) -> void:
	_history_lines.append(line)
	while _history_lines.size() > 3:
		_history_lines.pop_front()
	if _log_lbl != null:
		_log_lbl.text = "\n".join(_history_lines)


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
