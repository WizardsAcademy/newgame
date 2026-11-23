extends RefCounted
class_name WitchCauldronProgression
## Persistent profile, hero selection memory, settings, & per-hero Cauldron Skill Tree!
##
## Saves to `user://witch_cottage_save.cfg`:
##   - `profile/selected_hero` -> remembers which hero you picked across game launches!
##   - `skills_<hero_id>/*`    -> simple 4-node Cauldron Skill Tree per hero + brew points!
##   - `settings/*`            -> Master/SFX volume, Screen Shake, and Fullscreen!

const DEFAULT_SAVE_PATH := "user://witch_cottage_save.cfg"
const STARTING_BREW_POINTS: int = 3
const MAX_NODE_LEVEL: int = 3

static var save_path: String = DEFAULT_SAVE_PATH
static var _loaded: bool = false
static var _hero_points: Dictionary = {}
static var _hero_nodes: Dictionary = {}

static var master_volume: float = 1.0
static var sfx_volume: float = 1.0
static var screen_shake_enabled: bool = true
static var fullscreen_enabled: bool = false


static func _hero_capstone_meta(hero_id: String) -> Dictionary:
	match hero_id:
		"knight":
			return {
				"title": "Bulwark Brew",
				"desc": "+1 Plate Armor & +4 Shield Ram DMG / lv",
			}
		"sylvara":
			return {
				"title": "Moonbow Brew",
				"desc": "+5 Charged Arrow DMG & +12 Energy / lv",
			}
		"noa":
			return {
				"title": "Crimson Rose Brew",
				"desc": "+1 Drain Heal/hit & +8 Blood Reach / lv",
			}
		_:
			return {
				"title": "Pit Titan Brew",
				"desc": "+4 Shoulder Charge & Uppercut DMG / lv",
			}


static func get_skill_nodes_for_hero(hero_id: String) -> Array[Dictionary]:
	var norm := CharacterRegistry.normalize_id(hero_id)
	var cap := _hero_capstone_meta(norm)
	return [
		{
			"id": "vitality",
			"title": "Vitality Brew",
			"desc": "+12 Max HP per level",
			"requires": [],
			"purple_vial": false,
		},
		{
			"id": "wrath",
			"title": "Wrath Elixir",
			"desc": "+3 Attack DMG per level",
			"requires": ["vitality"],
			"purple_vial": true,
		},
		{
			"id": "swiftness",
			"title": "Swiftness Draught",
			"desc": "+7 Move SPD & +15% Energy Regen / lv",
			"requires": ["vitality"],
			"purple_vial": false,
		},
		{
			"id": "essence",
			"title": String(cap["title"]),
			"desc": String(cap["desc"]),
			"requires": ["wrath", "swiftness"], # unlocks when ANY parent >= 1
			"purple_vial": true,
		},
	]


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
		_hero_nodes[hid] = {
			"vitality": 0,
			"wrath": 0,
			"swiftness": 0,
			"essence": 0,
		}

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
			for nid in map.keys():
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
		for nid in ["vitality", "wrath", "swiftness", "essence"]:
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


static func get_node_level(hero_id: String, node_id: String) -> int:
	ensure_loaded()
	var hid := String(CharacterRegistry.get_entry(hero_id)["id"])
	var map: Dictionary = _hero_nodes.get(hid, {})
	return int(map.get(node_id, 0))


static func is_node_unlocked(hero_id: String, node_id: String) -> bool:
	ensure_loaded()
	for meta in get_skill_nodes_for_hero(hero_id):
		if String(meta["id"]) == node_id:
			var reqs: Array = meta["requires"]
			if reqs.is_empty():
				return true
			for r in reqs:
				if get_node_level(hero_id, String(r)) >= 1:
					return true
			return false
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
	var map: Dictionary = _hero_nodes.get(hid, {})
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

	var vit := get_node_level(hid, "vitality")
	var wra := get_node_level(hid, "wrath")
	var swi := get_node_level(hid, "swiftness")
	var ess := get_node_level(hid, "essence")
	if vit == 0 and wra == 0 and swi == 0 and ess == 0:
		return

	if vit > 0 and "max_health" in hero and "current_health" in hero:
		var bonus_hp := vit * 12
		hero.max_health += bonus_hp
		hero.current_health = mini(hero.current_health + bonus_hp, hero.max_health)

	if wra > 0 and "attack_damage" in hero:
		hero.attack_damage += wra * 3
		if "charged_arrow_damage" in hero:
			hero.charged_arrow_damage += wra * 4

	if swi > 0:
		if "move_speed" in hero:
			hero.move_speed += float(swi * 7)
		if "energy_regen_per_sec" in hero:
			hero.energy_regen_per_sec *= (1.0 + 0.15 * float(swi))

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
