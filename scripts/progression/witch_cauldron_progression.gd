extends RefCounted
class_name WitchCauldronProgression
## Persistent profile, hero selection memory, settings, & 16-Node Per-Hero RPG Skill Tree!
##
## Saves to `user://witch_cottage_save.cfg`:
##   - `profile/selected_hero` -> remembers which hero you picked across game launches!
##   - `skills_<hero_id>/*`    -> 16-node (`1 -> 3 -> 6 -> 6`, Lv `0..5`) Skill Tree + points!
##   - `settings/*`            -> Master/SFX volume, Screen Shake, and Fullscreen!

const DEFAULT_SAVE_PATH := "user://witch_cottage_save.cfg"
const STARTING_BREW_POINTS: int = 3
const MAX_NODE_LEVEL: int = 5

const ALL_NODE_IDS: Array[String] = [
	"vitality",
	"wrath", "focus", "essence",
	"blade", "swiftness", "heart", "ward", "burst", "reaper",
	"mastery_0", "mastery_1", "mastery_2", "mastery_3", "mastery_4", "mastery_5",
]

static var save_path: String = DEFAULT_SAVE_PATH
static var _loaded: bool = false
static var _hero_points: Dictionary = {}
static var _hero_nodes: Dictionary = {}

static var master_volume: float = 1.0
static var sfx_volume: float = 1.0
static var screen_shake_enabled: bool = true
static var fullscreen_enabled: bool = false


static func get_hero_theme(hero_id: String) -> Dictionary:
	var norm := CharacterRegistry.normalize_id(hero_id)
	match norm:
		"knight":
			# Knight: Blue & Black (`نایت ابی مشکی`)
			return {
				"id": "knight",
				"label": "Blue & Obsidian",
				"bg_outer": Color(0.02, 0.03, 0.06, 0.96),
				"bg_inner": Color(0.04, 0.07, 0.14, 0.98),
				"stone_dark": Color(0.05, 0.07, 0.12, 1.0),
				"stone_mid": Color(0.09, 0.13, 0.22, 1.0),
				"stone_rim": Color(0.20, 0.34, 0.58, 1.0),
				"primary": Color(0.16, 0.52, 1.0, 1.0),
				"secondary": Color(0.46, 0.78, 1.0, 1.0),
				"glow": Color(0.24, 0.62, 1.0, 0.36),
				"node_bg": Color(0.04, 0.06, 0.11, 1.0),
				"node_active_bg": Color(0.07, 0.18, 0.38, 1.0),
				"btn_bg": Color(0.10, 0.34, 0.74, 1.0),
				"btn_hover": Color(0.16, 0.46, 0.92, 1.0),
				"btn_border": Color(0.52, 0.82, 1.0, 1.0),
				"gem_tint": Color(0.38, 0.74, 1.0, 1.0),
				"stat_highlight": Color(0.46, 0.82, 1.0, 1.0),
			}
		"behemoth":
			# Behemoth: Orange & Red (`بهموث نارنجی قرمز`)
			return {
				"id": "behemoth",
				"label": "Molten Orange & Crimson",
				"bg_outer": Color(0.07, 0.02, 0.02, 0.96),
				"bg_inner": Color(0.15, 0.05, 0.03, 0.98),
				"stone_dark": Color(0.13, 0.05, 0.04, 1.0),
				"stone_mid": Color(0.22, 0.09, 0.07, 1.0),
				"stone_rim": Color(0.62, 0.24, 0.14, 1.0),
				"primary": Color(0.94, 0.26, 0.14, 1.0),
				"secondary": Color(1.0, 0.62, 0.16, 1.0),
				"glow": Color(1.0, 0.40, 0.12, 0.36),
				"node_bg": Color(0.11, 0.04, 0.04, 1.0),
				"node_active_bg": Color(0.36, 0.10, 0.06, 1.0),
				"btn_bg": Color(0.76, 0.20, 0.10, 1.0),
				"btn_hover": Color(0.92, 0.34, 0.14, 1.0),
				"btn_border": Color(1.0, 0.68, 0.24, 1.0),
				"gem_tint": Color(1.0, 0.52, 0.18, 1.0),
				"stat_highlight": Color(1.0, 0.68, 0.26, 1.0),
			}
		"sylvara":
			# Elf (Sylvara): Green & Gold (`الف سبز طلایی`)
			return {
				"id": "sylvara",
				"label": "Emerald & Elven Gold",
				"bg_outer": Color(0.02, 0.06, 0.04, 0.96),
				"bg_inner": Color(0.05, 0.14, 0.09, 0.98),
				"stone_dark": Color(0.05, 0.11, 0.08, 1.0),
				"stone_mid": Color(0.10, 0.20, 0.14, 1.0),
				"stone_rim": Color(0.56, 0.48, 0.18, 1.0),
				"primary": Color(0.18, 0.78, 0.44, 1.0),
				"secondary": Color(0.98, 0.82, 0.28, 1.0),
				"glow": Color(0.28, 0.88, 0.48, 0.34),
				"node_bg": Color(0.04, 0.10, 0.07, 1.0),
				"node_active_bg": Color(0.09, 0.28, 0.17, 1.0),
				"btn_bg": Color(0.14, 0.56, 0.32, 1.0),
				"btn_hover": Color(0.20, 0.70, 0.40, 1.0),
				"btn_border": Color(0.98, 0.84, 0.32, 1.0),
				"gem_tint": Color(0.98, 0.84, 0.30, 1.0),
				"stat_highlight": Color(0.98, 0.86, 0.36, 1.0),
			}
		_:
			# Noa: Red & White (`نوا قرمز سفید`)
			return {
				"id": "noa",
				"label": "Crimson & Ivory White",
				"bg_outer": Color(0.07, 0.02, 0.04, 0.96),
				"bg_inner": Color(0.15, 0.04, 0.07, 0.98),
				"stone_dark": Color(0.14, 0.06, 0.08, 1.0),
				"stone_mid": Color(0.24, 0.11, 0.14, 1.0),
				"stone_rim": Color(0.86, 0.82, 0.86, 1.0),
				"primary": Color(0.92, 0.14, 0.26, 1.0),
				"secondary": Color(0.98, 0.96, 0.98, 1.0),
				"glow": Color(0.96, 0.20, 0.34, 0.36),
				"node_bg": Color(0.12, 0.04, 0.06, 1.0),
				"node_active_bg": Color(0.40, 0.08, 0.15, 1.0),
				"btn_bg": Color(0.78, 0.12, 0.22, 1.0),
				"btn_hover": Color(0.94, 0.20, 0.32, 1.0),
				"btn_border": Color(0.98, 0.96, 0.98, 1.0),
				"gem_tint": Color(0.98, 0.95, 0.98, 1.0),
				"stat_highlight": Color(1.0, 0.94, 0.96, 1.0),
			}


static func _hero_flavor_names(hero_id: String) -> Dictionary:
	match CharacterRegistry.normalize_id(hero_id):
		"knight":
			return {
				"root": "Oathbound Core",
				"wrath": "Vanguard Slash",
				"essence": "Aegis Flame",
				"essence_desc": "Increase Shield Ram DMG by +4 and Armor by +1 per level.",
			}
		"sylvara":
			return {
				"root": "Sylvan Heartseed",
				"wrath": "Windpiercer Strike",
				"essence": "Sunleaf Aura",
				"essence_desc": "Increase Charged Arrow DMG by +5 and Max Energy by +12 per level.",
			}
		"noa":
			return {
				"root": "Sanguine Awakening",
				"wrath": "Crimson Strike",
				"essence": "White Rose Bloodfire",
				"essence_desc": "Increase Drain Heal by +1/hit and Blood Slash reach by +8 per level.",
			}
		_:
			return {
				"root": "Titan Core",
				"wrath": "Crushing Strike",
				"essence": "Inferno Rage",
				"essence_desc": "Increase Shoulder Charge & Uppercut damage by +4 per level.",
			}


static func get_skill_nodes_for_hero(hero_id: String) -> Array[Dictionary]:
	var fl := _hero_flavor_names(hero_id)
	return [
		# --- ROW 0: 1 ROOT NODE ---
		{
			"id": "vitality",
			"row": 0, "col": 0, "icon_idx": 0,
			"title": String(fl["root"]),
			"desc": "Increase your Max HP by +12 per level.",
			"requires": [],
			"purple_vial": false,
		},
		# --- ROW 1: 3 CORE BRANCHES ---
		{
			"id": "wrath",
			"row": 1, "col": 0, "icon_idx": 1,
			"title": String(fl["wrath"]),
			"desc": "Increase your attack damage by +3 (+15% power) per level.",
			"requires": ["vitality"],
			"purple_vial": true,
		},
		{
			"id": "focus",
			"row": 1, "col": 1, "icon_idx": 2,
			"title": "Inner Focus",
			"desc": "Increase Energy Regen by +15% and Max Energy by +8 per level.",
			"requires": ["vitality"],
			"purple_vial": false,
		},
		{
			"id": "essence",
			"row": 1, "col": 2, "icon_idx": 3,
			"title": String(fl["essence"]),
			"desc": String(fl["essence_desc"]),
			"requires": ["vitality"],
			"purple_vial": true,
		},
		# --- ROW 2: 6 SPECIALIZATION NODES (2 PER BRANCH) ---
		{
			"id": "blade",
			"row": 2, "col": 0, "icon_idx": 4,
			"title": "Keen Edge",
			"desc": "Increase weapon & projectile damage by +2 per level.",
			"requires": ["wrath"],
			"purple_vial": true,
		},
		{
			"id": "swiftness",
			"row": 2, "col": 1, "icon_idx": 5,
			"title": "Fleet Step",
			"desc": "Increase Move Speed by +7 and Shift Dash speed by +14 per level.",
			"requires": ["wrath"],
			"purple_vial": false,
		},
		{
			"id": "heart",
			"row": 2, "col": 2, "icon_idx": 6,
			"title": "Vitality Vessel",
			"desc": "Increase your Max HP by +10 per level.",
			"requires": ["focus"],
			"purple_vial": false,
		},
		{
			"id": "ward",
			"row": 2, "col": 3, "icon_idx": 7,
			"title": "Bastion Ward",
			"desc": "Reduce incoming hit damage & boost toughness (+6 Max HP / lv).",
			"requires": ["focus"],
			"purple_vial": false,
		},
		{
			"id": "burst",
			"row": 2, "col": 4, "icon_idx": 8,
			"title": "Astral Surge",
			"desc": "Increase Shift & Special skill damage by +3 per level.",
			"requires": ["essence"],
			"purple_vial": true,
		},
		{
			"id": "reaper",
			"row": 2, "col": 5, "icon_idx": 9,
			"title": "Grim Harvest",
			"desc": "Increase Attack DMG by +2 and Max Energy by +6 per level.",
			"requires": ["essence"],
			"purple_vial": true,
		},
		# --- ROW 3: 6 TIER-4 MASTERY NODES (PADLOCKED UNTIL ROW-2 PARENT >= 1) ---
		{
			"id": "mastery_0",
			"row": 3, "col": 0, "icon_idx": 10,
			"title": "Twin Fang Mastery",
			"desc": "Mastery: Increase all attack damage by +3 per level.",
			"requires": ["blade"],
			"purple_vial": true,
		},
		{
			"id": "mastery_1",
			"row": 3, "col": 1, "icon_idx": 11,
			"title": "Tempest Stride",
			"desc": "Mastery: +5 Move Speed & faster Shift recovery per level.",
			"requires": ["swiftness"],
			"purple_vial": false,
		},
		{
			"id": "mastery_2",
			"row": 3, "col": 2, "icon_idx": 12,
			"title": "Immortal Chalice",
			"desc": "Mastery: Increase Max HP by +14 per level.",
			"requires": ["heart"],
			"purple_vial": false,
		},
		{
			"id": "mastery_3",
			"row": 3, "col": 3, "icon_idx": 13,
			"title": "Sovereign Crown",
			"desc": "Mastery: +8 Max HP and +10 Max Energy per level.",
			"requires": ["ward"],
			"purple_vial": false,
		},
		{
			"id": "mastery_4",
			"row": 3, "col": 4, "icon_idx": 14,
			"title": "All-Seeing Apex",
			"desc": "Mastery: +4 Special & Charged attack damage per level.",
			"requires": ["burst"],
			"purple_vial": true,
		},
		{
			"id": "mastery_5",
			"row": 3, "col": 5, "icon_idx": 15,
			"title": "Reaper's Verdict",
			"desc": "Mastery: +2 Attack DMG, +2 Dash DMG & +6 Max HP per level.",
			"requires": ["reaper"],
			"purple_vial": true,
		},
	]


static func _make_empty_node_map() -> Dictionary:
	var d: Dictionary = {}
	for nid in ALL_NODE_IDS:
		d[nid] = 0
	return d


static func ensure_loaded() -> void:
	if _loaded:
		return
	load_from_disk()


static func load_from_disk(custom_path: String = "") -> void:
	if custom_path != "":
		save_path = custom_path
	_loaded = true
	_hero_points.clear()
	_hero_nodes.clear()

	for entry in CharacterRegistry.CHARACTERS:
		var hid := String(entry["id"])
		_hero_points[hid] = STARTING_BREW_POINTS
		_hero_nodes[hid] = _make_empty_node_map()

	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		apply_runtime_settings()
		return

	var saved_hero := String(cfg.get_value("profile", "selected_hero", CharacterRegistry.selected_id))
	CharacterRegistry.selected_id = String(CharacterRegistry.get_entry(saved_hero)["id"])

	master_volume = clampf(float(cfg.get_value("settings", "master_volume", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("settings", "sfx_volume", 1.0)), 0.0, 1.0)
	screen_shake_enabled = bool(cfg.get_value("settings", "screen_shake", true))
	fullscreen_enabled = bool(cfg.get_value("settings", "fullscreen", false))

	for entry in CharacterRegistry.CHARACTERS:
		var hid := String(entry["id"])
		var sec := "skills_%s" % hid
		if cfg.has_section(sec):
			_hero_points[hid] = maxi(int(cfg.get_value(sec, "points", STARTING_BREW_POINTS)), 0)
			var map: Dictionary = _hero_nodes[hid]
			for nid in ALL_NODE_IDS:
				map[nid] = clampi(int(cfg.get_value(sec, nid, 0)), 0, MAX_NODE_LEVEL)
			_hero_nodes[hid] = map

	apply_runtime_settings()


static func save_to_disk() -> void:
	ensure_loaded()
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "selected_hero", CharacterRegistry.selected_id)

	cfg.set_value("settings", "master_volume", master_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "screen_shake", screen_shake_enabled)
	cfg.set_value("settings", "fullscreen", fullscreen_enabled)

	for entry in CharacterRegistry.CHARACTERS:
		var hid := String(entry["id"])
		var sec := "skills_%s" % hid
		cfg.set_value(sec, "points", int(_hero_points.get(hid, STARTING_BREW_POINTS)))
		var map: Dictionary = _hero_nodes.get(hid, {})
		for nid in ALL_NODE_IDS:
			cfg.set_value(sec, nid, int(map.get(nid, 0)))

	cfg.save(save_path)


static func save_selected_hero(hero_id: String) -> String:
	ensure_loaded()
	var valid_id := String(CharacterRegistry.get_entry(hero_id)["id"])
	CharacterRegistry.selected_id = valid_id
	save_to_disk()
	return valid_id


static func get_brew_points(hero_id: String) -> int:
	ensure_loaded()
	var hid := String(CharacterRegistry.get_entry(hero_id)["id"])
	return int(_hero_points.get(hid, STARTING_BREW_POINTS))


static func add_brew_points(hero_id: String, amount: int = 1) -> int:
	ensure_loaded()
	if amount <= 0:
		return get_brew_points(hero_id)
	var hid := String(CharacterRegistry.get_entry(hero_id)["id"])
	_hero_points[hid] = int(_hero_points.get(hid, STARTING_BREW_POINTS)) + amount
	save_to_disk()
	return int(_hero_points[hid])


static func get_spent_points(hero_id: String) -> int:
	ensure_loaded()
	var hid := String(CharacterRegistry.get_entry(hero_id)["id"])
	var map: Dictionary = _hero_nodes.get(hid, {})
	var spent: int = 0
	for nid in ALL_NODE_IDS:
		spent += int(map.get(nid, 0))
	return spent


static func reset_hero_tree(hero_id: String) -> int:
	ensure_loaded()
	var hid := String(CharacterRegistry.get_entry(hero_id)["id"])
	var refund := get_spent_points(hid)
	if refund <= 0:
		return 0
	_hero_points[hid] = int(_hero_points.get(hid, 0)) + refund
	_hero_nodes[hid] = _make_empty_node_map()
	save_to_disk()
	return refund


static func get_node_level(hero_id: String, node_id: String) -> int:
	ensure_loaded()
	var hid := String(CharacterRegistry.get_entry(hero_id)["id"])
	var map: Dictionary = _hero_nodes.get(hid, {})
	return int(map.get(node_id, 0))


static func get_node_meta(hero_id: String, node_id: String) -> Dictionary:
	for meta in get_skill_nodes_for_hero(hero_id):
		if String(meta["id"]) == node_id:
			return meta
	return {}


static func is_node_unlocked(hero_id: String, node_id: String) -> bool:
	ensure_loaded()
	var meta := get_node_meta(hero_id, node_id)
	if meta.is_empty():
		return false
	var reqs: Array = meta["requires"]
	if reqs.is_empty():
		return true
	for r in reqs:
		if get_node_level(hero_id, String(r)) >= 1:
			return true
	return false


static func can_upgrade_node(hero_id: String, node_id: String) -> bool:
	ensure_loaded()
	if get_brew_points(hero_id) <= 0:
		return false
	if get_node_level(hero_id, node_id) >= MAX_NODE_LEVEL:
		return false
	return is_node_unlocked(hero_id, node_id)


static func upgrade_node(hero_id: String, node_id: String) -> bool:
	if not can_upgrade_node(hero_id, node_id):
		return false
	var hid := String(CharacterRegistry.get_entry(hero_id)["id"])
	_hero_points[hid] = maxi(int(_hero_points.get(hid, 0)) - 1, 0)
	var map: Dictionary = _hero_nodes.get(hid, _make_empty_node_map())
	map[node_id] = clampi(int(map.get(node_id, 0)) + 1, 0, MAX_NODE_LEVEL)
	_hero_nodes[hid] = map
	save_to_disk()
	return true


static func apply_to_hero_instance(hero: Node) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	ensure_loaded()
	var hid := String(hero.get("character_id")) if "character_id" in hero else CharacterRegistry.selected_id
	hid = String(CharacterRegistry.get_entry(hid)["id"])
	if get_spent_points(hid) <= 0:
		return

	var vit := get_node_level(hid, "vitality")
	var wra := get_node_level(hid, "wrath")
	var foc := get_node_level(hid, "focus")
	var ess := get_node_level(hid, "essence")
	var bld := get_node_level(hid, "blade")
	var swi := get_node_level(hid, "swiftness")
	var hrt := get_node_level(hid, "heart")
	var wrd := get_node_level(hid, "ward")
	var brs := get_node_level(hid, "burst")
	var rpr := get_node_level(hid, "reaper")
	var m0 := get_node_level(hid, "mastery_0")
	var m1 := get_node_level(hid, "mastery_1")
	var m2 := get_node_level(hid, "mastery_2")
	var m3 := get_node_level(hid, "mastery_3")
	var m4 := get_node_level(hid, "mastery_4")
	var m5 := get_node_level(hid, "mastery_5")

	var bonus_hp := vit * 12 + hrt * 10 + wrd * 6 + m2 * 14 + m3 * 8 + m5 * 6
	if bonus_hp > 0 and "max_health" in hero and "current_health" in hero:
		hero.max_health += bonus_hp
		hero.current_health = mini(hero.current_health + bonus_hp, hero.max_health)

	var bonus_atk := wra * 3 + bld * 2 + rpr * 2 + m0 * 3 + m5 * 2
	if bonus_atk > 0 and "attack_damage" in hero:
		hero.attack_damage += bonus_atk
		if "charged_arrow_damage" in hero:
			hero.charged_arrow_damage += wra * 4 + bld * 3 + m0 * 4

	var bonus_spd := float(swi * 7 + m1 * 5)
	if bonus_spd > 0.0 and "move_speed" in hero:
		hero.move_speed += bonus_spd
	if (swi > 0 or m1 > 0) and "dash_speed" in hero:
		hero.dash_speed += float(swi * 14 + m1 * 10)
	if m1 > 0 and "dash_cooldown" in hero:
		hero.dash_cooldown = maxf(0.45, float(hero.dash_cooldown) * pow(0.96, float(m1)))

	var bonus_en := float(foc * 8 + rpr * 6 + m3 * 10)
	if bonus_en > 0.0 and "max_energy" in hero and "current_energy" in hero:
		hero.max_energy += bonus_en
		hero.current_energy = hero.max_energy
	if foc > 0 and "energy_regen_per_sec" in hero:
		hero.energy_regen_per_sec *= (1.0 + 0.15 * float(foc))

	if wrd > 0 and "armor_flat_reduction" in hero:
		hero.armor_flat_reduction += wrd

	var bonus_spec := brs * 3 + m4 * 4 + m5 * 2
	if bonus_spec > 0:
		if "dash_damage" in hero:
			hero.dash_damage += bonus_spec
		if "charged_arrow_damage" in hero:
			hero.charged_arrow_damage += bonus_spec

	if ess > 0:
		match hid:
			"knight":
				if "armor_flat_reduction" in hero:
					hero.armor_flat_reduction += ess * 1
				if "dash_damage" in hero:
					hero.dash_damage += ess * 4
			"sylvara":
				if "charged_arrow_damage" in hero:
					hero.charged_arrow_damage += ess * 5
				if "max_energy" in hero and "current_energy" in hero:
					hero.max_energy += float(ess * 12)
					hero.current_energy = hero.max_energy
			"noa":
				if "heal_per_enemy_hit" in hero:
					hero.heal_per_enemy_hit += ess * 1
				if "splash_range" in hero:
					hero.splash_range += float(ess * 8)
			_:
				if "dash_damage" in hero:
					hero.dash_damage += ess * 4


static func apply_runtime_settings() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, master_volume <= 0.001)
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(maxf(master_volume, 0.0001)))

	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_mute(sfx_idx, sfx_volume <= 0.001)
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(maxf(sfx_volume, 0.0001)))

	if Engine.get_main_loop() is SceneTree:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null:
			var ss := tree.root.get_node_or_null("ScreenShake")
			if ss != null and "enabled" in ss:
				ss.enabled = screen_shake_enabled

	if DisplayServer.get_name() != "headless":
		var cur_mode := DisplayServer.window_get_mode()
		if fullscreen_enabled and cur_mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not fullscreen_enabled and cur_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
