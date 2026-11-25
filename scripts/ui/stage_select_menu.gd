extends Control
class_name StageSelectMenu
## Named Stage Region Selector (`UI/StageSelectMenu`) opened at the Lobby `STAGES` Door!
##
## Shows all 3 distinct Stage Maps:
##   1. `Whispering Jungle`  — Unlocked from start
##   2. `Cursed Bone Crypt`  — Unlocks after defeating Region 1 Boss (`Forest Colossus`)
##   3. `Infernal Citadel`   — Unlocks after defeating Region 2 Boss (`Malakor, Arch-Lich`)

signal region_chosen(region_id: int)
signal menu_closed

var _open: bool = false
var _cards_box: VBoxContainer = null
var _region_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 95
	visible = false
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.05, 0.80)
	add_child(dim)

	var panel := Panel.new()
	panel.name = "StageSelectPanel"
	panel.position = Vector2(96.0, 34.0)
	panel.size = Vector2(448.0, 292.0)
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.06, 0.06, 0.11, 0.98)
	pst.border_color = Color(0.86, 0.70, 0.34, 1.0)
	pst.set_border_width_all(2)
	pst.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", pst)
	add_child(panel)

	var title := Label.new()
	title.name = "HeaderLabel"
	title.text = "SELECT STAGE REGION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(16.0, 10.0)
	title.size = Vector2(416.0, 22.0)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.52))
	panel.add_child(title)

	var sub := Label.new()
	sub.text = "Defeat each Region's Boss (Stage 5) to unlock the next Region!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(16.0, 31.0)
	sub.size = Vector2(416.0, 14.0)
	sub.add_theme_font_size_override("font_size", 8)
	sub.add_theme_color_override("font_color", Color(0.76, 0.82, 0.90))
	panel.add_child(sub)

	_cards_box = VBoxContainer.new()
	_cards_box.name = "RegionCards"
	_cards_box.position = Vector2(18.0, 52.0)
	_cards_box.size = Vector2(412.0, 198.0)
	_cards_box.add_theme_constant_override("separation", 8)
	panel.add_child(_cards_box)

	var close_btn := Button.new()
	close_btn.name = "CancelButton"
	close_btn.text = "Back to Cottage [ESC]"
	close_btn.position = Vector2(148.0, 256.0)
	close_btn.size = Vector2(152.0, 26.0)
	close_btn.add_theme_font_size_override("font_size", 9)
	close_btn.pressed.connect(close_menu)
	panel.add_child(close_btn)


func is_open() -> bool:
	return _open


func open_menu() -> void:
	_rebuild_cards()
	_open = true
	visible = true


func close_menu() -> void:
	if not _open:
		return
	_open = false
	visible = false
	menu_closed.emit()


func _rebuild_cards() -> void:
	if _cards_box == null:
		return
	for ch in _cards_box.get_children():
		ch.queue_free()
	_region_buttons.clear()

	for reg in WitchCauldronProgression.REGIONS:
		var rid := int(reg["id"])
		var rname := String(reg["name"])
		var rsub := String(reg["subtitle"])
		var accent: Color = reg["accent"]
		var unlocked := WitchCauldronProgression.is_region_unlocked(rid)

		var row := Panel.new()
		row.name = "RegionCard_%d" % rid
		row.custom_minimum_size = Vector2(412.0, 58.0)
		var rst := StyleBoxFlat.new()
		rst.bg_color = accent.darkened(0.78) if unlocked else Color(0.05, 0.05, 0.08, 0.95)
		rst.border_color = accent if unlocked else Color(0.28, 0.28, 0.36, 0.85)
		rst.set_border_width_all(2)
		rst.set_corner_radius_all(5)
		row.add_theme_stylebox_override("panel", rst)
		_cards_box.add_child(row)

		var name_lbl := Label.new()
		name_lbl.name = "RegionTitle"
		name_lbl.text = "Map %d: %s" % [rid, rname]
		name_lbl.position = Vector2(12.0, 7.0)
		name_lbl.size = Vector2(276.0, 18.0)
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", accent.lightened(0.25) if unlocked else Color(0.52, 0.54, 0.62))
		row.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.position = Vector2(12.0, 28.0)
		desc_lbl.size = Vector2(280.0, 22.0)
		desc_lbl.add_theme_font_size_override("font_size", 8)
		if unlocked:
			desc_lbl.text = rsub
			desc_lbl.add_theme_color_override("font_color", Color(0.86, 0.90, 0.94))
		else:
			var prev_boss := String(WitchCauldronProgression.get_region_info(rid - 1)["boss_name"])
			desc_lbl.text = "LOCKED — Defeat %s in Map %d first!" % [prev_boss, rid - 1]
			desc_lbl.add_theme_color_override("font_color", Color(0.92, 0.46, 0.46))
		row.add_child(desc_lbl)

		var enter_btn := Button.new()
		enter_btn.name = "EnterRegion_%d" % rid
		enter_btn.position = Vector2(304.0, 13.0)
		enter_btn.size = Vector2(96.0, 32.0)
		enter_btn.disabled = not unlocked
		enter_btn.text = "ENTER ->" if unlocked else "LOCKED"
		enter_btn.add_theme_font_size_override("font_size", 9)
		enter_btn.pressed.connect(_on_region_pressed.bind(rid))
		row.add_child(enter_btn)
		_region_buttons[rid] = enter_btn


func _on_region_pressed(rid: int) -> void:
	if not WitchCauldronProgression.is_region_unlocked(rid):
		return
	_open = false
	visible = false
	region_chosen.emit(rid)


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			close_menu()
			get_viewport().set_input_as_handled()
