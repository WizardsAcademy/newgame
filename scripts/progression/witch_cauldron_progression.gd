extends RefCounted
class_name WitchCauldronProgression
## Persistent profile, hero memory, Witch Alchemy Reagents, & Scrollable Exclusive-Pillar OP Skill Tree!
##
## Topology (`1 -> 3 Exclusive 4-Tier Pillars -> 1 Converged Ultimate Solo Node`):
##   - Row 0 (`solo_top`)    : 1 Solo Keystone OP Skill (`max_level = 1`)
##   - Rows 1..4 (`p0..p2`)  : 3 Pillars x 4 Tiers (`max_level = 5`). Choosing ANY node in
##                             1 Pillar locks out the other 2 Pillars until Reset!
##   - Row 5 (`solo_bottom`) : All 3 Pillars converge into 1 Ultimate OP Solo Node (`max_level = 1`)!
##
## Economy & Console Cheats:
##   - Slaying monsters & clearing waves drops Alchemy Reagents (`REAGENTS_PER_POTION = 3` per Potion).
##   - Giving Reagents to the Witch at the Cauldron brews Potions (`Majon` = Skill Points).
##   - Backtick `` ` `` Console: `wizard` -> `+10000` Skill Points; `canoheil` -> resets ALL heroes!

const DEFAULT_SAVE_PATH := "user://witch_cottage_save.cfg"
const STARTING_BREW_POINTS: int = 0
const REAGENTS_PER_POTION: int = 3
const MAX_NODE_LEVEL: int = 5

const ALL_NODE_IDS: Array[String] = [
	"solo_top",
	"p0_t1", "p1_t1", "p2_t1",
	"p0_t2", "p1_t2", "p2_t2",
	"p0_t3", "p1_t3", "p2_t3",
	"p0_t4", "p1_t4", "p2_t4",
	"solo_bottom",
]

static var save_path: String = DEFAULT_SAVE_PATH
static var _loaded: bool = false
static var _reagents: int = 0
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


static func get_pillar_names(hero_id: String) -> Array[String]:
	match CharacterRegistry.normalize_id(hero_id):
		"sylvara":
			return ["I. Emerald Storm", "II. Gale Phantom", "III. Sun Executioner"]
		"knight":
			return ["I. Swordmaster", "II. Lion Bastion", "III. Sky Vanguard"]
		"noa":
			return ["I. Blood Empress", "II. Night Swarm", "III. White Sovereign"]
		_:
			return ["I. Earthshaker", "II. Blood Frenzy", "III. Volcanic Lord"]


static func get_skill_nodes_for_hero(hero_id: String) -> Array[Dictionary]:
	var norm := CharacterRegistry.normalize_id(hero_id)
	match norm:
		"sylvara":
			return _nodes_sylvara()
		"knight":
			return _nodes_knight()
		"noa":
			return _nodes_noa()
		_:
			return _nodes_behemoth()


static func _make_node(id_str: String, row: int, col: int, pillar: int, icon_idx: int,
		max_lv: int, title: String, desc: String, reqs: Array, purple: bool) -> Dictionary:
	return {
		"id": id_str,
		"row": row,
		"col": col,
		"pillar": pillar,
		"icon_idx": icon_idx,
		"max_level": max_lv,
		"title": title,
		"desc": desc,
		"requires": reqs,
		"purple_vial": purple,
	}


static func _nodes_sylvara() -> Array[Dictionary]:
	return [
		_make_node("solo_top", 0, 1, -1, 5, 1, "Windveil Mirage (OP)",
			"After Shift ends, dodge 100% of ALL enemy projectiles for 1.0 full second!", [], false),
		# Pillar 0: Emerald Storm (Multi-arrow & Starburst)
		_make_node("p0_t1", 1, 0, 0, 1, 5, "Split-Tempest Volley",
			"EVERY shot fires a multi-arrow fan (+2 arrows, +5 DMG/lv)!", ["solo_top"], true),
		_make_node("p0_t2", 2, 0, 0, 10, 5, "Piercing Thorn-Flight",
			"All quick & fan arrows PIERCE through every enemy (+4 DMG/lv)!", ["p0_t1"], false),
		_make_node("p0_t3", 3, 0, 0, 8, 5, "Emerald Starburst",
			"Arrows detonate on impact in a 56px AoE blast for +55% (+12%/lv) DMG!", ["p0_t2"], true),
		_make_node("p0_t4", 4, 0, 0, 14, 5, "Zero-Draw Stormbow",
			"Cut bow charge & fire cooldown by 55% and gain +10 Attack DMG/lv!", ["p0_t3"], true),
		# Pillar 1: Gale Phantom (Mobility, Poison Snare & Twin Shadow)
		_make_node("p1_t1", 1, 1, 1, 11, 5, "Zephyr Vault",
			"-12% Shift cooldown/lv, +18 Move Speed/lv, & Shift restores 12 HP!", ["solo_top"], false),
		_make_node("p1_t2", 2, 1, 1, 2, 5, "Briar Root-Venom",
			"Arrows snare foes by 55% and inflict 12 (+5/lv) Venom burst damage!", ["p1_t1"], false),
		_make_node("p1_t3", 3, 1, 1, 3, 5, "Twin Phantom Bow",
			"Every bow shot fires a second Shadow Great-Arrow for 60% (+10%/lv) DMG!", ["p1_t2"], true),
		_make_node("p1_t4", 4, 1, 1, 12, 5, "Immortal Windrunner",
			"+22 Max HP/lv, +20% Energy Regen/lv, and kills instantly reset Shift!", ["p1_t3"], false),
		# Pillar 2: Sun Executioner (Crit & Instant Execute)
		_make_node("p2_t1", 1, 2, 2, 4, 5, "Heartseeker Critical",
			"Arrows gain 35% (+10%/lv) Crit Chance to strike for 2.5x DAMAGE!", ["solo_top"], true),
		_make_node("p2_t2", 2, 2, 2, 0, 5, "Solar Great-Arrow",
			"Charged Great-Arrows deal +14 DMG/lv and stun enemies for 0.8s!", ["p2_t1"], true),
		_make_node("p2_t3", 3, 2, 2, 9, 5, "Verdant Executioner",
			"Instantly EXECUTE non-boss enemies below 30% (+4%/lv) HP on hit!", ["p2_t2"], true),
		_make_node("p2_t4", 4, 2, 2, 15, 5, "Avatar of the Sunwood",
			"+12 Attack DMG/lv & +25% total bow damage multiplier!", ["p2_t3"], true),
		# Converged Bottom Solo Ultimate (`dovomin taki`)
		_make_node("solo_bottom", 5, 1, -1, 14, 1, "Starlight Auto-Barrage (OP)",
			"ULTIMATE: Auto-aims at nearby foes and fires at blazing speed for 30% Attack DMG per arrow!",
			["p0_t4", "p1_t4", "p2_t4"], true),
	]


static func _nodes_behemoth() -> Array[Dictionary]:
	return [
		_make_node("solo_top", 0, 1, -1, 0, 1, "Unstoppable Savage (OP)",
			"After Shift ends, dodge 100% of projectiles & attacks for 1.0s + ground-slam!", [], false),
		# Pillar 0: Earthshaker
		_make_node("p0_t1", 1, 0, 0, 1, 5, "Seismic Bare-Knuckles",
			"Every punch unleashes a 72px Earth Shockwave (+6 Attack DMG/lv)!", ["solo_top"], true),
		_make_node("p0_t2", 2, 0, 0, 9, 5, "Skullcrusher Concussion",
			"Punches & Charge stun +0.35s longer/lv and deal +35% bonus stun DMG!", ["p0_t1"], true),
		_make_node("p0_t3", 3, 0, 0, 8, 5, "Meteor Shoulder-Slam",
			"Shift Charge detonates a 96px molten crater for 40 (+15/lv) AoE DMG!", ["p0_t2"], true),
		_make_node("p0_t4", 4, 0, 0, 13, 5, "Titan Worldbreaker",
			"+14 Attack DMG/lv, +25 Max HP/lv, and 2x Uppercut shockwave size!", ["p0_t3"], true),
		# Pillar 1: Blood Frenzy
		_make_node("p1_t1", 1, 1, 1, 5, 5, "Primal Berserk Speed",
			"+12% faster Punch Speed/lv and +14 Move Speed/lv!", ["solo_top"], false),
		_make_node("p1_t2", 2, 1, 1, 6, 5, "Savage Feast",
			"Every punch heals +4 (+2/lv) HP and kills restore 18% Max HP!", ["p1_t1"], false),
		_make_node("p1_t3", 3, 1, 1, 10, 5, "Deathless Rampage",
			"Deal +60% (+15%/lv) bonus DMG when below 60% HP & halve Shift cooldown!", ["p1_t2"], true),
		_make_node("p1_t4", 4, 1, 1, 15, 5, "Chieftain's Bloodbath",
			"+30 Max HP/lv, +10 Attack DMG/lv, & kills reset Shift cooldown!", ["p1_t3"], true),
		# Pillar 2: Volcanic Lord
		_make_node("p2_t1", 1, 2, 2, 3, 5, "Magma Fists",
			"Punches hurl a piercing FireWave forward for 22 (+8/lv) DMG!", ["solo_top"], true),
		_make_node("p2_t2", 2, 2, 2, 7, 5, "Obsidian Muscle Hide",
			"+24 Max HP/lv & attackers suffer 20 (+8/lv) volcanic thorns DMG!", ["p2_t1"], false),
		_make_node("p2_t3", 3, 2, 2, 14, 5, "Inferno Eruption",
			"Every 3rd combo hit calls down a Volcanic Pillar for 45 (+12/lv) DMG!", ["p2_t2"], true),
		_make_node("p2_t4", 4, 2, 2, 4, 5, "Avatar of Ragnarok",
			"+15 Attack DMG/lv & slain enemies explode in a 80px Fireball!", ["p2_t3"], true),
		# Converged Bottom Solo Ultimate
		_make_node("solo_bottom", 5, 1, -1, 14, 1, "Cataclysmic Tremor Aura (OP)",
			"ULTIMATE: Auto-slams nearby enemies at blistering speed for 40% Attack DMG per tremor!",
			["p0_t4", "p1_t4", "p2_t4"], true),
	]


static func _nodes_knight() -> Array[Dictionary]:
	return [
		_make_node("solo_top", 0, 1, -1, 7, 1, "Crusader's Holy Aegis (OP)",
			"After Shift ends, reflect & dodge 100% of projectiles for 1.0s in golden light!", [], false),
		# Pillar 0: Swordmaster
		_make_node("p0_t1", 1, 0, 0, 4, 5, "Sacred Sword-Beam",
			"Every Greatsword swing fires a piercing Holy Crescent Beam (+6 DMG/lv)!", ["solo_top"], true),
		_make_node("p0_t2", 2, 0, 0, 1, 5, "Grandmaster Cleave",
			"+45% Spin Slash AoE radius & +7 Attack DMG/lv!", ["p0_t1"], true),
		_make_node("p0_t3", 3, 0, 0, 8, 5, "Templar Verdict Crit",
			"40% (+10%/lv) Crit Chance for 2.5x Holy Greatsword Damage!", ["p0_t2"], true),
		_make_node("p0_t4", 4, 0, 0, 10, 5, "Excalibur Awakened",
			"-35% attack cooldown & +14 Attack DMG/lv!", ["p0_t3"], true),
		# Pillar 1: Lion Bastion
		_make_node("p1_t1", 1, 1, 1, 6, 5, "Golden Lion Plate",
			"+30 Max HP/lv, +2 Flat Armor/lv, & -50% Shield Energy drain!", ["solo_top"], false),
		_make_node("p1_t2", 2, 1, 1, 13, 5, "Roar of Retribution",
			"Blocking any hit blasts nearby foes for 35 (+12/lv) Holy Lion DMG!", ["p1_t1"], false),
		_make_node("p1_t3", 3, 1, 1, 12, 5, "Consecrated Crusader",
			"Regenerate 6 (+3/lv) HP every second & burn nearby enemies!", ["p1_t2"], false),
		_make_node("p1_t4", 4, 1, 1, 7, 5, "Unbreakable Citadel",
			"Shield NEVER exhausts, +35 Max HP/lv, & +8 Attack DMG/lv!", ["p1_t3"], false),
		# Pillar 2: Sky Vanguard
		_make_node("p2_t1", 1, 2, 2, 11, 5, "Thunder Shield-Ram",
			"+14 Move Speed/lv, -12% Shift cooldown/lv, & +12 Shift Ram DMG/lv!", ["solo_top"], false),
		_make_node("p2_t2", 2, 2, 2, 3, 5, "Heavensfall Smite",
			"Shift arrival strikes foes with Celestial Lightning for 42 (+14/lv) DMG!", ["p2_t1"], true),
		_make_node("p2_t3", 3, 2, 2, 9, 5, "Crusader's Judgment",
			"Stun hit foes during Shift for 1.5s & execute foes under 28% HP!", ["p2_t2"], true),
		_make_node("p2_t4", 4, 2, 2, 14, 5, "Solaris Grand Paladin",
			"+12 Attack DMG/lv, +100% Energy Regen, & kills reset Shift!", ["p2_t3"], true),
		# Converged Bottom Solo Ultimate
		_make_node("solo_bottom", 5, 1, -1, 14, 1, "Storm of Sacred Blades (OP)",
			"ULTIMATE: Auto-fires radiant judgment blades at nearby foes at high speed for 35% Attack DMG!",
			["p0_t4", "p1_t4", "p2_t4"], true),
	]


static func _nodes_noa() -> Array[Dictionary]:
	return [
		_make_node("solo_top", 0, 1, -1, 2, 1, "Aristocrat's Mist Veil (OP)",
			"After Bat-Swarm Shift ends, dodge 100% of projectiles & hits for 1.0s!", [], false),
		# Pillar 0: Blood Empress
		_make_node("p0_t1", 1, 0, 0, 6, 5, "Royal Blood-Pact",
			"Blood-Splash costs ZERO self-HP and heals +3 (+2/lv) extra HP per hit!", ["solo_top"], true),
		_make_node("p0_t2", 2, 0, 0, 3, 5, "Crimson Fountain Mastery",
			"30% Max-HP Blood Fountain erupts in HALF the hits (every 2nd hit)!", ["p0_t1"], true),
		_make_node("p0_t3", 3, 0, 0, 1, 5, "Tidal Scarlet Arc",
			"+22px Blood-Splash reach/lv & +7 Attack DMG/lv!", ["p0_t2"], true),
		_make_node("p0_t4", 4, 0, 0, 12, 5, "Empress of Eternal Vitae",
			"+24 Max HP/lv & +14 Attack DMG/lv!", ["p0_t3"], true),
		# Pillar 1: Night Swarm
		_make_node("p1_t1", 1, 1, 1, 5, 5, "Ravenous Nightwings",
			"Bat-Swarm Shift bites enemies along your path for 26 (+10/lv) DMG + heals!", ["solo_top"], true),
		_make_node("p1_t2", 2, 1, 1, 11, 5, "Velvet Gale Steps",
			"+16 Move Speed/lv & -12% Bat-Swarm Shift cooldown/lv!", ["p1_t1"], false),
		_make_node("p1_t3", 3, 1, 1, 10, 5, "Seeker Bat Familiars",
			"Every attack unleashes homing Vampire Bats dealing +50% (+12%/lv) DMG!", ["p1_t2"], true),
		_make_node("p1_t4", 4, 1, 1, 15, 5, "Sovereign of Midnight",
			"Kills instantly reset Bat-Swarm Shift & +12 Attack DMG/lv!", ["p1_t3"], true),
		# Pillar 2: White Sovereign
		_make_node("p2_t1", 1, 2, 2, 13, 5, "Ruby Tiara Decree",
			"+35% faster Blood-Splash speed & +6 Attack DMG/lv!", ["solo_top"], true),
		_make_node("p2_t2", 2, 2, 2, 8, 5, "White-Rose Blood Crit",
			"40% (+10%/lv) Crit Chance for 2.5x Crimson Damage!", ["p2_t1"], true),
		_make_node("p2_t3", 3, 2, 2, 9, 5, "Noble Execution",
			"Slain enemies explode in a 85px Crimson Rose Nova for 42 (+12/lv) DMG!", ["p2_t2"], true),
		_make_node("p2_t4", 4, 2, 2, 14, 5, "Immortal Royal Vampire",
			"+25 Max HP/lv, +14 Attack DMG/lv, & +4 Drain Heal/hit!", ["p2_t3"], true),
		# Converged Bottom Solo Ultimate
		_make_node("solo_bottom", 5, 1, -1, 14, 1, "Royal Crimson Cataclysm (OP)",
			"ULTIMATE: Ruby Crown auto-fires rapid Blood Lances at nearby foes for 30% Attack DMG + Life Drain!",
			["p0_t4", "p1_t4", "p2_t4"], true),
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
	_reagents = 0
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
	_reagents = maxi(int(cfg.get_value("profile", "reagents", 0)), 0)

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
				var max_lv := get_node_max_level(hid, nid)
				map[nid] = clampi(int(cfg.get_value(sec, nid, 0)), 0, max_lv)
			_hero_nodes[hid] = map

	apply_runtime_settings()


static func save_to_disk() -> void:
	ensure_loaded()
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "selected_hero", CharacterRegistry.selected_id)
	cfg.set_value("profile", "reagents", _reagents)

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


# =====================================================================
# WITCH ALCHEMY REAGENTS & POTION BREWING (`Majon` -> Skill Points)
# =====================================================================

static func get_reagents() -> int:
	ensure_loaded()
	return _reagents


static func add_reagents(amount: int) -> int:
	ensure_loaded()
	if amount <= 0:
		return _reagents
	_reagents += amount
	save_to_disk()
	return _reagents


static func can_brew_potion() -> bool:
	ensure_loaded()
	return _reagents >= REAGENTS_PER_POTION


static func brew_potion_for_hero(hero_id: String) -> bool:
	ensure_loaded()
	if _reagents < REAGENTS_PER_POTION:
		return false
	_reagents -= REAGENTS_PER_POTION
	var hid := String(CharacterRegistry.get_entry(hero_id)["id"])
	_hero_points[hid] = int(_hero_points.get(hid, STARTING_BREW_POINTS)) + 1
	save_to_disk()
	return true


static func brew_all_potions_for_hero(hero_id: String) -> int:
	ensure_loaded()
	var count: int = int(_reagents / REAGENTS_PER_POTION)
	if count <= 0:
		return 0
	_reagents -= count * REAGENTS_PER_POTION
	var hid := String(CharacterRegistry.get_entry(hero_id)["id"])
	_hero_points[hid] = int(_hero_points.get(hid, STARTING_BREW_POINTS)) + count
	save_to_disk()
	return count


# =====================================================================
# SKILL POINTS, EXCLUSIVE PILLARS, & CHEAT CONSOLE (`wizard` / `canoheil`)
# =====================================================================

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


static func grant_wizard_points(amount: int = 10000) -> void:
	ensure_loaded()
	for entry in CharacterRegistry.CHARACTERS:
		var hid := String(entry["id"])
		_hero_points[hid] = int(_hero_points.get(hid, 0)) + maxi(amount, 0)
	save_to_disk()


static func reset_all_heroes() -> void:
	ensure_loaded()
	_reagents = 0
	for entry in CharacterRegistry.CHARACTERS:
		var hid := String(entry["id"])
		_hero_points[hid] = STARTING_BREW_POINTS
		_hero_nodes[hid] = _make_empty_node_map()
	save_to_disk()


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


static func get_node_max_level(hero_id: String, node_id: String) -> int:
	var meta := get_node_meta(hero_id, node_id)
	if meta.is_empty():
		return MAX_NODE_LEVEL
	return int(meta.get("max_level", MAX_NODE_LEVEL))


## Returns `0`, `1`, or `2` once the hero has invested in one of the 3 Pillars, or `-1` if none chosen yet.
static func get_chosen_pillar(hero_id: String) -> int:
	ensure_loaded()
	for p in range(3):
		for t in range(1, 5):
			var nid := "p%d_t%d" % [p, t]
			if get_node_level(hero_id, nid) >= 1:
				return p
	return -1


static func is_node_locked_by_other_pillar(hero_id: String, node_id: String) -> bool:
	var meta := get_node_meta(hero_id, node_id)
	if meta.is_empty():
		return false
	var pil := int(meta.get("pillar", -1))
	if pil < 0:
		return false
	var chosen := get_chosen_pillar(hero_id)
	return chosen != -1 and chosen != pil


static func is_node_unlocked(hero_id: String, node_id: String) -> bool:
	ensure_loaded()
	var meta := get_node_meta(hero_id, node_id)
	if meta.is_empty():
		return false
	if is_node_locked_by_other_pillar(hero_id, node_id):
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
	if get_node_level(hero_id, node_id) >= get_node_max_level(hero_id, node_id):
		return false
	return is_node_unlocked(hero_id, node_id)


static func upgrade_node(hero_id: String, node_id: String) -> bool:
	if not can_upgrade_node(hero_id, node_id):
		return false
	var hid := String(CharacterRegistry.get_entry(hero_id)["id"])
	_hero_points[hid] = maxi(int(_hero_points.get(hid, 0)) - 1, 0)
	var map: Dictionary = _hero_nodes.get(hid, _make_empty_node_map())
	var max_lv := get_node_max_level(hid, node_id)
	map[node_id] = clampi(int(map.get(node_id, 0)) + 1, 0, max_lv)
	_hero_nodes[hid] = map
	save_to_disk()
	return true


# =====================================================================
# APPLY OP SKILLS & STAT MODIFIERS TO LIVE HERO INSTANCE
# =====================================================================

static func apply_to_hero_instance(hero: Node) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	ensure_loaded()
	var hid := String(hero.get("character_id")) if "character_id" in hero else CharacterRegistry.selected_id
	hid = String(CharacterRegistry.get_entry(hid)["id"])

	var map: Dictionary = _hero_nodes.get(hid, _make_empty_node_map()).duplicate()
	if hero.has_method("apply_skill_tree_ranks"):
		hero.apply_skill_tree_ranks(map)


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
