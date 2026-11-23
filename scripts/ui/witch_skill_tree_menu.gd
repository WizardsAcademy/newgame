extends Control
class_name WitchSkillTreeMenu
## Witch's Cauldron Skill Tree Overlay (`640x360` base viewport).
##
## Opens for the CURRENTLY ACTIVE HERO (`CharacterRegistry.selected_id`).
## Whenever a skill is leveled up, the pretty Baddie Witch hands a glowing
## emerald/violet potion across the cauldron and your hero drinks it!

signal skill_leveled_up(hero_id: String, node_id: String, new_level: int)
signal menu_closed

const WITCH_TEX_PATH := "res://assets/textures/lobby_witch.png"
const CAULDRON_TEX_PATH := "res://assets/textures/lobby_cauldron.png"
const POTION_TEX_PATH := "res://assets/textures/witch_potion.png"

var _is_open: bool = false
var _hero_id: String = "behemoth"
var _anim_time: float = 0.0
var _witch_offer_timer: float = 0.0

var _panel: Panel = null
var _title_lbl: Label = null
var _points_lbl: Label = null
var _hero_name_lbl: Label = null
var _witch_speech_lbl: Label = null

var _hero_tex_rect: TextureRect = null
var _witch_tex_rect: TextureRect = null
var _cauldron_tex_rect: TextureRect = null
var _flying_potion: TextureRect = null
var _tree_lines_canvas: Control = null

var _witch_frames: Array[AtlasTexture] = []
var _cauldron_frames: Array[AtlasTexture] = []
var _potion_frames: Array[AtlasTexture] = []

var _node_buttons: Dictionary = {} # node_id -> Button
var _gulp_sfx: AudioStreamPlayer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_load_atlas_frames()
	_build_ui()

	_gulp_sfx = AudioStreamPlayer.new()
	_gulp_sfx.bus = &"SFX"
	_gulp_sfx.stream = SFXGenerator.create_potion_gulp_sfx()
	add_child(_gulp_sfx)


func _load_atlas_frames() -> void:
	if ResourceLoader.exists(WITCH_TEX_PATH):
		var wt: Texture2D = load(WITCH_TEX_PATH)
		if wt != null:
			for i in range(4):
				var at := AtlasTexture.new()
				at.atlas = wt
				at.region = Rect2(float(i * 64), 0.0, 64.0, 64.0)
				_witch_frames.append(at)

	if ResourceLoader.exists(CAULDRON_TEX_PATH):
		var ct: Texture2D = load(CAULDRON_TEX_PATH)
		if ct != null:
			for i in range(6):
				var atc := AtlasTexture.new()
				atc.atlas = ct
				atc.region = Rect2(float(i * 48), 0.0, 48.0, 48.0)
				_cauldron_frames.append(atc)

	if ResourceLoader.exists(POTION_TEX_PATH):
		var pt: Texture2D = load(POTION_TEX_PATH)
		if pt != null:
			for i in range(2):
				var atp := AtlasTexture.new()
				atp.atlas = pt
				atp.region = Rect2(float(i * 32), 0.0, 32.0, 32.0)
				_potion_frames.append(atp)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.08, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = Panel.new()
	_panel.name = "CauldronPanel"
	_panel.position = Vector2(46.0, 22.0)
	_panel.size = Vector2(548.0, 316.0)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.10, 0.07, 0.15, 0.97)
	pstyle.border_color = Color(0.56, 0.30, 0.78, 0.95)
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", pstyle)
	add_child(_panel)

	_title_lbl = Label.new()
	_title_lbl.name = "TitleLabel"
	_title_lbl.position = Vector2(14.0, 8.0)
	_title_lbl.size = Vector2(360.0, 20.0)
	_title_lbl.add_theme_font_size_override("font_size", 13)
	_title_lbl.add_theme_color_override("font_color", Color(0.90, 0.74, 1.0))
	_panel.add_child(_title_lbl)

	_points_lbl = Label.new()
	_points_lbl.name = "BrewPointsLabel"
	_points_lbl.position = Vector2(350.0, 8.0)
	_points_lbl.size = Vector2(138.0, 20.0)
	_points_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_points_lbl.add_theme_font_size_override("font_size", 11)
	_points_lbl.add_theme_color_override("font_color", Color(0.46, 1.0, 0.68))
	_panel.add_child(_points_lbl)

	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "X"
	close_btn.position = Vector2(514.0, 6.0)
	close_btn.size = Vector2(26.0, 22.0)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.add_theme_stylebox_override("normal", _btn_style(Color(0.22, 0.12, 0.28), Color(0.62, 0.36, 0.78)))
	close_btn.add_theme_stylebox_override("hover", _btn_style(Color(0.36, 0.18, 0.44), Color(0.88, 0.56, 1.0)))
	close_btn.pressed.connect(hide_menu)
	_panel.add_child(close_btn)

	# --- LEFT STAGE: ACTIVE HERO ---
	var left_box := Panel.new()
	left_box.position = Vector2(12.0, 36.0)
	left_box.size = Vector2(108.0, 266.0)
	left_box.add_theme_stylebox_override("panel", _btn_style(Color(0.07, 0.05, 0.11), Color(0.30, 0.22, 0.44)))
	_panel.add_child(left_box)

	_hero_name_lbl = Label.new()
	_hero_name_lbl.position = Vector2(4.0, 8.0)
	_hero_name_lbl.size = Vector2(100.0, 18.0)
	_hero_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_name_lbl.add_theme_font_size_override("font_size", 11)
	_hero_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	left_box.add_child(_hero_name_lbl)

	_hero_tex_rect = TextureRect.new()
	_hero_tex_rect.name = "HeroStageSprite"
	_hero_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_tex_rect.position = Vector2(6.0, 56.0)
	_hero_tex_rect.size = Vector2(96.0, 96.0)
	left_box.add_child(_hero_tex_rect)

	var cauldron_sub := Label.new()
	cauldron_sub.text = "Bubbling Brew"
	cauldron_sub.position = Vector2(4.0, 166.0)
	cauldron_sub.size = Vector2(100.0, 14.0)
	cauldron_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cauldron_sub.add_theme_font_size_override("font_size", 8)
	cauldron_sub.add_theme_color_override("font_color", Color(0.62, 0.96, 0.74))
	left_box.add_child(cauldron_sub)

	_cauldron_tex_rect = TextureRect.new()
	_cauldron_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cauldron_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cauldron_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cauldron_tex_rect.position = Vector2(22.0, 182.0)
	_cauldron_tex_rect.size = Vector2(64.0, 64.0)
	if not _cauldron_frames.is_empty():
		_cauldron_tex_rect.texture = _cauldron_frames[0]
	left_box.add_child(_cauldron_tex_rect)

	# --- CENTER STAGE: 4-NODE CAULDRON SKILL TREE ---
	_tree_lines_canvas = Control.new()
	_tree_lines_canvas.position = Vector2(128.0, 36.0)
	_tree_lines_canvas.size = Vector2(292.0, 266.0)
	_tree_lines_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tree_lines_canvas.draw.connect(_draw_tree_connectors)
	_panel.add_child(_tree_lines_canvas)

	var node_coords := {
		"essence": Vector2(204.0, 42.0),
		"wrath": Vector2(132.0, 130.0),
		"swiftness": Vector2(276.0, 130.0),
		"vitality": Vector2(204.0, 218.0),
	}

	for nid in ["vitality", "wrath", "swiftness", "essence"]:
		var btn := Button.new()
		btn.name = "SkillNode_%s" % nid
		btn.position = node_coords[nid]
		btn.size = Vector2(138.0, 74.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_skill_node_pressed.bind(nid))
		_panel.add_child(btn)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(4.0, 4.0)
		icon.size = Vector2(24.0, 24.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)

		var ntitle := Label.new()
		ntitle.name = "NodeTitle"
		ntitle.position = Vector2(30.0, 4.0)
		ntitle.size = Vector2(104.0, 15.0)
		ntitle.add_theme_font_size_override("font_size", 9)
		ntitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(ntitle)

		var nlvl := Label.new()
		nlvl.name = "NodeLevel"
		nlvl.position = Vector2(30.0, 18.0)
		nlvl.size = Vector2(104.0, 13.0)
		nlvl.add_theme_font_size_override("font_size", 8)
		nlvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(nlvl)

		var ndesc := Label.new()
		ndesc.name = "NodeDesc"
		ndesc.position = Vector2(6.0, 34.0)
		ndesc.size = Vector2(126.0, 36.0)
		ndesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ndesc.add_theme_font_size_override("font_size", 8)
		ndesc.add_theme_color_override("font_color", Color(0.84, 0.82, 0.90))
		ndesc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(ndesc)

		_node_buttons[nid] = btn

	# --- RIGHT STAGE: PRETTY BADDIE WITCH ---
	var right_box := Panel.new()
	right_box.position = Vector2(424.0, 36.0)
	right_box.size = Vector2(112.0, 266.0)
	right_box.add_theme_stylebox_override("panel", _btn_style(Color(0.08, 0.05, 0.13), Color(0.46, 0.24, 0.68)))
	_panel.add_child(right_box)

	var witch_title := Label.new()
	witch_title.text = "Cottage Witch"
	witch_title.position = Vector2(4.0, 8.0)
	witch_title.size = Vector2(104.0, 16.0)
	witch_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	witch_title.add_theme_font_size_override("font_size", 10)
	witch_title.add_theme_color_override("font_color", Color(0.94, 0.66, 1.0))
	right_box.add_child(witch_title)

	_witch_tex_rect = TextureRect.new()
	_witch_tex_rect.name = "WitchStageSprite"
	_witch_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_witch_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_witch_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_witch_tex_rect.position = Vector2(8.0, 52.0)
	_witch_tex_rect.size = Vector2(96.0, 96.0)
	if not _witch_frames.is_empty():
		_witch_tex_rect.texture = _witch_frames[0]
	right_box.add_child(_witch_tex_rect)

	_witch_speech_lbl = Label.new()
	_witch_speech_lbl.name = "WitchSpeech"
	_witch_speech_lbl.text = "\"Pick a brew, darling~\nI'll pour it fresh!\""
	_witch_speech_lbl.position = Vector2(6.0, 164.0)
	_witch_speech_lbl.size = Vector2(100.0, 88.0)
	_witch_speech_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_witch_speech_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_witch_speech_lbl.add_theme_font_size_override("font_size", 9)
	_witch_speech_lbl.add_theme_color_override("font_color", Color(0.95, 0.84, 1.0))
	right_box.add_child(_witch_speech_lbl)

	# Flying Potion Vial used during level-up handoff animation!
	_flying_potion = TextureRect.new()
	_flying_potion.name = "FlyingPotionVial"
	_flying_potion.visible = false
	_flying_potion.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flying_potion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flying_potion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_flying_potion.size = Vector2(32.0, 32.0)
	_flying_potion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_flying_potion)


func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	return s


func _draw_tree_connectors() -> void:
	if _tree_lines_canvas == null:
		return
	var off := _tree_lines_canvas.position
	var c_vit := Vector2(204.0 + 69.0, 218.0 + 10.0) - off
	var c_wra := Vector2(132.0 + 69.0, 130.0 + 68.0) - off
	var c_swi := Vector2(276.0 + 69.0, 130.0 + 68.0) - off
	var c_wra_top := Vector2(132.0 + 69.0, 130.0 + 6.0) - off
	var c_swi_top := Vector2(276.0 + 69.0, 130.0 + 6.0) - off
	var c_ess := Vector2(204.0 + 69.0, 42.0 + 70.0) - off

	var vit_lv := WitchCauldronProgression.get_node_level(_hero_id, "vitality")
	var wra_lv := WitchCauldronProgression.get_node_level(_hero_id, "wrath")
	var swi_lv := WitchCauldronProgression.get_node_level(_hero_id, "swiftness")

	var col_locked := Color(0.28, 0.24, 0.36, 0.85)
	var col_green := Color(0.32, 0.95, 0.58, 0.95)
	var col_purple := Color(0.82, 0.42, 1.0, 0.95)

	_tree_lines_canvas.draw_line(c_vit, c_wra, col_green if vit_lv >= 1 else col_locked, 2.5)
	_tree_lines_canvas.draw_line(c_vit, c_swi, col_green if vit_lv >= 1 else col_locked, 2.5)
	_tree_lines_canvas.draw_line(c_wra_top, c_ess, col_purple if wra_lv >= 1 else col_locked, 2.5)
	_tree_lines_canvas.draw_line(c_swi_top, c_ess, col_purple if swi_lv >= 1 else col_locked, 2.5)


func is_open() -> bool:
	return _is_open


func show_for_hero(hero_id: String) -> void:
	WitchCauldronProgression.ensure_loaded()
	var entry := CharacterRegistry.get_entry(hero_id)
	_hero_id = String(entry["id"])
	_is_open = true
	visible = true
	_witch_offer_timer = 0.0

	if ResourceLoader.exists(String(entry["sheet_path"])):
		var htex: Texture2D = load(String(entry["sheet_path"]))
		if htex != null:
			var hat := AtlasTexture.new()
			hat.atlas = htex
			hat.region = Rect2(0.0, 0.0, 64.0, 64.0)
			_hero_tex_rect.texture = hat

	_hero_name_lbl.text = String(entry["name"])
	_witch_speech_lbl.text = "\"Step closer, %s~\nMy cauldron is ready!\"" % String(entry["name"])
	_refresh_nodes()


func hide_menu() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	menu_closed.emit()


func _refresh_nodes() -> void:
	var entry := CharacterRegistry.get_entry(_hero_id)
	var pts := WitchCauldronProgression.get_brew_points(_hero_id)
	_title_lbl.text = "WITCH'S CAULDRON  •  %s" % String(entry["name"]).to_upper()
	_points_lbl.text = "Brew Points: %d" % pts

	var defs := WitchCauldronProgression.get_skill_nodes_for_hero(_hero_id)
	for meta in defs:
		var nid := String(meta["id"])
		var btn: Button = _node_buttons.get(nid)
		if btn == null:
			continue
		var lv := WitchCauldronProgression.get_node_level(_hero_id, nid)
		var unlocked := WitchCauldronProgression.is_node_unlocked(_hero_id, nid)
		var can_up := WitchCauldronProgression.can_upgrade_node(_hero_id, nid)
		var is_purple := bool(meta["purple_vial"])

		var icon := btn.get_node("Icon") as TextureRect
		if not _potion_frames.is_empty():
			icon.texture = _potion_frames[1 if is_purple else 0]
			icon.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.45, 0.45, 0.5, 0.7)

		var ntitle := btn.get_node("NodeTitle") as Label
		ntitle.text = String(meta["title"])
		ntitle.add_theme_color_override("font_color",
			Color(0.95, 0.76, 1.0) if is_purple else Color(0.62, 1.0, 0.78))

		var nlvl := btn.get_node("NodeLevel") as Label
		if lv >= WitchCauldronProgression.MAX_NODE_LEVEL:
			nlvl.text = "MAX  (%d/%d)" % [lv, WitchCauldronProgression.MAX_NODE_LEVEL]
			nlvl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
		elif not unlocked:
			nlvl.text = "LOCKED  (0/%d)" % WitchCauldronProgression.MAX_NODE_LEVEL
			nlvl.add_theme_color_override("font_color", Color(0.58, 0.54, 0.66))
		else:
			nlvl.text = "Lv %d/%d  [Click: Brew]" % [lv, WitchCauldronProgression.MAX_NODE_LEVEL]
			nlvl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.72) if can_up else Color(0.76, 0.74, 0.84))

		(btn.get_node("NodeDesc") as Label).text = String(meta["desc"])

		if lv >= WitchCauldronProgression.MAX_NODE_LEVEL:
			btn.add_theme_stylebox_override("normal", _btn_style(Color(0.18, 0.14, 0.26), Color(0.94, 0.78, 0.34)))
			btn.add_theme_stylebox_override("hover", _btn_style(Color(0.22, 0.18, 0.30), Color(1.0, 0.86, 0.46)))
		elif can_up:
			var bcol := Color(0.78, 0.38, 1.0) if is_purple else Color(0.32, 0.94, 0.58)
			btn.add_theme_stylebox_override("normal", _btn_style(Color(0.15, 0.11, 0.24), bcol))
			btn.add_theme_stylebox_override("hover", _btn_style(Color(0.24, 0.16, 0.36), Color(1.0, 0.92, 0.62)))
		else:
			btn.add_theme_stylebox_override("normal", _btn_style(Color(0.09, 0.07, 0.13), Color(0.28, 0.24, 0.36)))
			btn.add_theme_stylebox_override("hover", _btn_style(Color(0.11, 0.09, 0.16), Color(0.36, 0.30, 0.46)))

	if _tree_lines_canvas != null:
		_tree_lines_canvas.queue_redraw()


func _on_skill_node_pressed(node_id: String) -> void:
	if not WitchCauldronProgression.can_upgrade_node(_hero_id, node_id):
		if not WitchCauldronProgression.is_node_unlocked(_hero_id, node_id):
			_witch_speech_lbl.text = "\"Brew Vitality first,\nsweetheart~\""
		elif WitchCauldronProgression.get_brew_points(_hero_id) <= 0:
			_witch_speech_lbl.text = "\"Clear more waves for\nfresh Brew Points~\""
		return

	var is_purple := (node_id in ["wrath", "essence"])
	if WitchCauldronProgression.upgrade_node(_hero_id, node_id):
		var new_lv := WitchCauldronProgression.get_node_level(_hero_id, node_id)
		_refresh_nodes()
		_play_potion_handoff_animation(is_purple)
		skill_leveled_up.emit(_hero_id, node_id, new_lv)


func _play_potion_handoff_animation(is_purple: bool) -> void:
	_witch_offer_timer = 1.05
	if not _witch_frames.is_empty() and _witch_frames.size() >= 4:
		_witch_tex_rect.texture = _witch_frames[3]
	_witch_speech_lbl.text = "\"Here, drink every\ndrop for me~!\""

	if _gulp_sfx != null:
		_gulp_sfx.pitch_scale = randf_range(0.96, 1.06)
		_gulp_sfx.play()

	if _flying_potion != null and not _potion_frames.is_empty():
		_flying_potion.texture = _potion_frames[1 if is_purple else 0]
		_flying_potion.visible = true
		var start_p := Vector2(430.0, 96.0)
		var mid_p := Vector2(250.0, 48.0)
		var end_p := Vector2(54.0, 92.0)
		_flying_potion.position = start_p
		_flying_potion.scale = Vector2.ONE
		_flying_potion.modulate = Color(1, 1, 1, 1)

		var tw := create_tween()
		tw.tween_property(_flying_potion, "position", mid_p, 0.22)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_flying_potion, "position", end_p, 0.22)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(_on_hero_drank_ui_potion.bind(is_purple))


func _on_hero_drank_ui_potion(is_purple: bool) -> void:
	if _flying_potion != null:
		_flying_potion.visible = false
	if _hero_tex_rect != null:
		var glow := Color(1.35, 0.85, 1.5, 1.0) if is_purple else Color(0.85, 1.45, 1.05, 1.0)
		_hero_tex_rect.modulate = glow
		_hero_tex_rect.position = Vector2(6.0, 48.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_hero_tex_rect, "position:y", 56.0, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_hero_tex_rect, "modulate", Color.WHITE, 0.32)

	var pop := Label.new()
	pop.text = "GULP! +LEVEL UP!"
	pop.position = Vector2(14.0, 74.0)
	pop.add_theme_font_size_override("font_size", 9)
	pop.add_theme_color_override("font_color", Color(0.95, 0.65, 1.0) if is_purple else Color(0.52, 1.0, 0.72))
	pop.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.08, 0.95))
	pop.add_theme_constant_override("outline_size", 2)
	_panel.add_child(pop)
	var ptw := create_tween()
	ptw.set_parallel(true)
	ptw.tween_property(pop, "position:y", 50.0, 0.55)
	ptw.tween_property(pop, "modulate:a", 0.0, 0.55)
	ptw.chain().tween_callback(pop.queue_free)


func _process(delta: float) -> void:
	if not _is_open:
		return
	_anim_time += delta
	if _witch_offer_timer > 0.0:
		_witch_offer_timer = maxf(_witch_offer_timer - delta, 0.0)
		if _witch_frames.size() >= 4:
			_witch_tex_rect.texture = _witch_frames[3]
	elif _witch_frames.size() >= 3:
		# Calm cycle: mostly idle, occasional wink & magic stir!
		var cyc := fmod(_anim_time, 4.2)
		var widx := 0
		if cyc > 3.7:
			widx = 1
		elif cyc > 2.2 and cyc < 2.9:
			widx = 2
		_witch_tex_rect.texture = _witch_frames[widx]

	if _cauldron_frames.size() >= 6:
		# Bubbles green (0,1,2,0,1,2) then SUDDENLY flashes purple (3,4,5)!
		var seq: Array[int] = [0, 1, 2, 0, 1, 2, 1, 3, 4, 4, 5]
		var step := int(_anim_time * 3.6) % seq.size()
		_cauldron_tex_rect.texture = _cauldron_frames[seq[step]]


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			hide_menu()
			get_viewport().set_input_as_handled()
