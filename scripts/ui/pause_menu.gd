extends Control
class_name PauseMenu
## ESC Pause Menu (`process_mode = PROCESS_MODE_ALWAYS`) with:
##   - CONTINUE
##   - SETTINGS (Master Volume, SFX Volume, Screen Shake, Fullscreen)
##   - LOBBY
##   - QUIT

signal continue_requested
signal lobby_requested
signal quit_requested

var _is_open: bool = false
var _in_settings: bool = false

var _main_page: Panel = null
var _settings_page: Panel = null

var _master_slider: HSlider = null
var _master_val_lbl: Label = null
var _sfx_slider: HSlider = null
var _sfx_val_lbl: Label = null
var _shake_btn: Button = null
var _fullscreen_btn: Button = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# --- MAIN PAUSE PANEL ---
	_main_page = Panel.new()
	_main_page.name = "MainPausePanel"
	_main_page.position = Vector2(204.0, 56.0)
	_main_page.size = Vector2(232.0, 248.0)
	_main_page.add_theme_stylebox_override("panel", _panel_style())
	add_child(_main_page)

	var header := Label.new()
	header.name = "Title"
	header.text = "PAUSED"
	header.position = Vector2(0.0, 14.0)
	header.size = Vector2(232.0, 24.0)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.95, 0.84, 1.0))
	_main_page.add_child(header)

	var btn_specs := [
		{"name": "ContinueButton", "label": "CONTINUE", "cb": _on_continue_pressed, "accent": Color(0.42, 0.94, 0.64)},
		{"name": "SettingsButton", "label": "SETTINGS", "cb": _on_settings_pressed, "accent": Color(0.76, 0.56, 1.0)},
		{"name": "LobbyButton", "label": "LOBBY", "cb": _on_lobby_pressed, "accent": Color(1.0, 0.84, 0.44)},
		{"name": "QuitButton", "label": "QUIT", "cb": _on_quit_pressed, "accent": Color(0.96, 0.36, 0.48)},
	]

	for i in range(btn_specs.size()):
		var spec: Dictionary = btn_specs[i]
		var btn := Button.new()
		btn.name = String(spec["name"])
		btn.text = String(spec["label"])
		btn.position = Vector2(28.0, 52.0 + float(i) * 44.0)
		btn.size = Vector2(176.0, 34.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 12)
		var acc: Color = spec["accent"]
		btn.add_theme_color_override("font_color", Color(0.96, 0.95, 1.0))
		btn.add_theme_stylebox_override("normal", _button_style(Color(0.15, 0.11, 0.22), acc.darkened(0.35)))
		btn.add_theme_stylebox_override("hover", _button_style(Color(0.24, 0.17, 0.34), acc))
		btn.add_theme_stylebox_override("pressed", _button_style(Color(0.30, 0.21, 0.42), Color.WHITE))
		var cb: Callable = spec["cb"]
		btn.pressed.connect(cb)
		_main_page.add_child(btn)

	# --- SETTINGS SUB-PANEL ---
	_settings_page = Panel.new()
	_settings_page.name = "SettingsPanel"
	_settings_page.visible = false
	_settings_page.position = Vector2(170.0, 44.0)
	_settings_page.size = Vector2(300.0, 272.0)
	_settings_page.add_theme_stylebox_override("panel", _panel_style())
	add_child(_settings_page)

	var stitle := Label.new()
	stitle.text = "SETTINGS"
	stitle.position = Vector2(0.0, 12.0)
	stitle.size = Vector2(300.0, 22.0)
	stitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stitle.add_theme_font_size_override("font_size", 15)
	stitle.add_theme_color_override("font_color", Color(0.92, 0.78, 1.0))
	_settings_page.add_child(stitle)

	# Master Volume
	var m_lbl := _make_setting_label("Master Volume", Vector2(20.0, 48.0))
	_settings_page.add_child(m_lbl)
	_master_val_lbl = _make_setting_label("100%", Vector2(232.0, 48.0))
	_master_val_lbl.size = Vector2(48.0, 18.0)
	_master_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_settings_page.add_child(_master_val_lbl)

	_master_slider = HSlider.new()
	_master_slider.name = "MasterVolumeSlider"
	_master_slider.min_value = 0.0
	_master_slider.max_value = 100.0
	_master_slider.step = 5.0
	_master_slider.position = Vector2(20.0, 68.0)
	_master_slider.size = Vector2(260.0, 18.0)
	_master_slider.value_changed.connect(_on_master_volume_changed)
	_settings_page.add_child(_master_slider)

	# SFX Volume
	var s_lbl := _make_setting_label("SFX Volume", Vector2(20.0, 96.0))
	_settings_page.add_child(s_lbl)
	_sfx_val_lbl = _make_setting_label("100%", Vector2(232.0, 96.0))
	_sfx_val_lbl.size = Vector2(48.0, 18.0)
	_sfx_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_settings_page.add_child(_sfx_val_lbl)

	_sfx_slider = HSlider.new()
	_sfx_slider.name = "SFXVolumeSlider"
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 100.0
	_sfx_slider.step = 5.0
	_sfx_slider.position = Vector2(20.0, 116.0)
	_sfx_slider.size = Vector2(260.0, 18.0)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_settings_page.add_child(_sfx_slider)

	# Screen Shake toggle
	_shake_btn = Button.new()
	_shake_btn.name = "ScreenShakeButton"
	_shake_btn.position = Vector2(20.0, 148.0)
	_shake_btn.size = Vector2(260.0, 30.0)
	_shake_btn.focus_mode = Control.FOCUS_NONE
	_shake_btn.add_theme_font_size_override("font_size", 11)
	_shake_btn.add_theme_stylebox_override("normal", _button_style(Color(0.14, 0.11, 0.22), Color(0.48, 0.34, 0.68)))
	_shake_btn.add_theme_stylebox_override("hover", _button_style(Color(0.22, 0.16, 0.32), Color(0.76, 0.56, 1.0)))
	_shake_btn.pressed.connect(_on_shake_toggled)
	_settings_page.add_child(_shake_btn)

	# Fullscreen toggle
	_fullscreen_btn = Button.new()
	_fullscreen_btn.name = "FullscreenButton"
	_fullscreen_btn.position = Vector2(20.0, 186.0)
	_fullscreen_btn.size = Vector2(260.0, 30.0)
	_fullscreen_btn.focus_mode = Control.FOCUS_NONE
	_fullscreen_btn.add_theme_font_size_override("font_size", 11)
	_fullscreen_btn.add_theme_stylebox_override("normal", _button_style(Color(0.14, 0.11, 0.22), Color(0.48, 0.34, 0.68)))
	_fullscreen_btn.add_theme_stylebox_override("hover", _button_style(Color(0.22, 0.16, 0.32), Color(0.76, 0.56, 1.0)))
	_fullscreen_btn.pressed.connect(_on_fullscreen_toggled)
	_settings_page.add_child(_fullscreen_btn)

	var back_btn := Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "BACK"
	back_btn.position = Vector2(84.0, 228.0)
	back_btn.size = Vector2(132.0, 30.0)
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.add_theme_font_size_override("font_size", 11)
	back_btn.add_theme_stylebox_override("normal", _button_style(Color(0.18, 0.13, 0.26), Color(0.68, 0.48, 0.92)))
	back_btn.add_theme_stylebox_override("hover", _button_style(Color(0.28, 0.20, 0.40), Color(0.92, 0.72, 1.0)))
	back_btn.pressed.connect(_show_main_page)
	_settings_page.add_child(back_btn)


func _make_setting_label(txt: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.size = Vector2(180.0, 18.0)
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(0.90, 0.88, 0.96))
	return l


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.06, 0.14, 0.97)
	s.border_color = Color(0.58, 0.34, 0.84, 0.95)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	return s


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	return s


func is_open() -> bool:
	return _is_open


func open_menu() -> void:
	WitchCauldronProgression.ensure_loaded()
	_is_open = true
	visible = true
	_show_main_page()
	_sync_settings_controls()
	get_tree().paused = true


func close_menu() -> void:
	_is_open = false
	_in_settings = false
	visible = false
	get_tree().paused = false


func _show_main_page() -> void:
	_in_settings = false
	_main_page.visible = true
	_settings_page.visible = false


func _sync_settings_controls() -> void:
	_master_slider.set_value_no_signal(roundf(WitchCauldronProgression.master_volume * 100.0))
	_master_val_lbl.text = "%d%%" % int(roundf(WitchCauldronProgression.master_volume * 100.0))
	_sfx_slider.set_value_no_signal(roundf(WitchCauldronProgression.sfx_volume * 100.0))
	_sfx_val_lbl.text = "%d%%" % int(roundf(WitchCauldronProgression.sfx_volume * 100.0))
	_shake_btn.text = "Screen Shake: %s" % ("ON" if WitchCauldronProgression.screen_shake_enabled else "OFF")
	_fullscreen_btn.text = "Window Mode: %s" % ("FULLSCREEN" if WitchCauldronProgression.fullscreen_enabled else "WINDOWED")


func _on_continue_pressed() -> void:
	close_menu()
	continue_requested.emit()


func _on_settings_pressed() -> void:
	_in_settings = true
	_main_page.visible = false
	_settings_page.visible = true
	_sync_settings_controls()


func _on_lobby_pressed() -> void:
	close_menu()
	lobby_requested.emit()


func _on_quit_pressed() -> void:
	WitchCauldronProgression.save_to_disk()
	close_menu()
	quit_requested.emit()
	get_tree().quit()


func _on_master_volume_changed(val: float) -> void:
	WitchCauldronProgression.master_volume = clampf(val / 100.0, 0.0, 1.0)
	WitchCauldronProgression.apply_runtime_settings()
	WitchCauldronProgression.save_to_disk()
	_master_val_lbl.text = "%d%%" % int(roundf(val))


func _on_sfx_volume_changed(val: float) -> void:
	WitchCauldronProgression.sfx_volume = clampf(val / 100.0, 0.0, 1.0)
	WitchCauldronProgression.apply_runtime_settings()
	WitchCauldronProgression.save_to_disk()
	_sfx_val_lbl.text = "%d%%" % int(roundf(val))


func _on_shake_toggled() -> void:
	WitchCauldronProgression.screen_shake_enabled = not WitchCauldronProgression.screen_shake_enabled
	WitchCauldronProgression.apply_runtime_settings()
	WitchCauldronProgression.save_to_disk()
	_sync_settings_controls()


func _on_fullscreen_toggled() -> void:
	WitchCauldronProgression.fullscreen_enabled = not WitchCauldronProgression.fullscreen_enabled
	WitchCauldronProgression.apply_runtime_settings()
	WitchCauldronProgression.save_to_disk()
	_sync_settings_controls()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			if _in_settings:
				_show_main_page()
			else:
				_on_continue_pressed()
			get_viewport().set_input_as_handled()
