extends RefCounted
class_name CharacterRegistry
## Central data-driven roster of the 4 playable heroes.
##
## Order matches the Character Select cards [1]..[4]:
##   1. Behemoth - Iron-Fist Brawler  (3-hit iron-gauntlet combo + 16-DMG Shoulder Dash)
##   2. Knight   - Shield & Greatsword (60% Damage-Reduction Shield + 14-DMG Charge Dash)
##   3. Sylvara  - Elven Ranger       (swift/piercing bow + 0-DMG enemy-phasing Windstep)
##   4. Velmira  - Crimson Vampire    (Blood Splash: -6 self HP, +8 heal on hit, 0-DMG Dash)

const CHARACTERS: Array[Dictionary] = [
	{
		"id": "behemoth",
		"name": "Behemoth",
		"role": "BRAWLER",
		"subtitle": "Iron-Fist Brawler",
		"scene_path": "res://scenes/player/Player.tscn",
		"sheet_path": "res://assets/textures/player_borzo.png",
		"frame_count": 6,
		"accent": Color(0.98, 0.68, 0.26),
		"hp": 100,
		"hp_ratio": 0.83,
		"atk_text": "18 -> 29",
		"atk_ratio": 0.82,
		"spd_text": "90",
		"spd_ratio": 0.72,
		"dash_text": "16 DMG",
		"dash_ratio": 1.00,
		"stats_line": "HP 100  •  ATK 18-29  •  DASH 16",
		"attack_info": "3-Hit Iron Gauntlets: Jab (18) -> Cross (21) -> Uppercut (29 DMG + Launch).",
		"passive_info": "Shockwave Finisher: Every 3rd punch blasts foes back with a golden wave.",
		"dash_info": "Shoulder Smash (Shift, 1s CD): Deals 16 damage as you smash through foes!",
		"hud_hint": "WASD: Move   Space/Click: Combo   Shift: Smash Dash (16 DMG)   Esc: Heroes",
		"desc": "3-hit iron-gauntlet combo + heavy 16-damage Shoulder-Smash Shift Dash.",
		"death_line": "Behemoth will crush them next time.",
	},
	{
		"id": "knight",
		"name": "Knight",
		"role": "KNIGHT",
		"subtitle": "Shield & Greatsword",
		"scene_path": "res://scenes/player/Bahman.tscn",
		"sheet_path": "res://assets/textures/player_bahman.png",
		"frame_count": 7,
		"accent": Color(0.42, 0.80, 1.0),
		"hp": 120,
		"hp_ratio": 1.00,
		"atk_text": "24 Wide",
		"atk_ratio": 0.92,
		"spd_text": "78",
		"spd_ratio": 0.60,
		"dash_text": "14 DMG",
		"dash_ratio": 0.88,
		"stats_line": "HP 120  •  SHIELD 60%  •  DASH 14",
		"attack_info": "Greatsword Cleave: Wide 24-DMG steel sweep hitting multiple foes.",
		"passive_info": "Kite Shield [Right-Click / E]: Reduces damage by 60% (10 DMG -> takes 4)!",
		"dash_info": "Shield Charge (Shift, 1s CD): Armored rush dealing 14 damage.",
		"hud_hint": "WASD: Move   Click/Space: Cleave   Right-Click/E: Shield (60%)   Shift: Charge",
		"desc": "Hold Right-Click/E to raise Kite Shield (60% DMG reduction) + 14-DMG Charge.",
		"death_line": "Even the Knight's shield bends beneath the horde.",
	},
	{
		"id": "sylvara",
		"name": "Sylvara",
		"role": "ELF",
		"subtitle": "Elven Ranger",
		"scene_path": "res://scenes/player/Pari.tscn",
		"sheet_path": "res://assets/textures/player_pari.png",
		"frame_count": 6,
		"accent": Color(0.40, 0.94, 0.58),
		"hp": 75,
		"hp_ratio": 0.63,
		"atk_text": "14 / 28",
		"atk_ratio": 0.84,
		"spd_text": "118 Fast",
		"spd_ratio": 1.00,
		"dash_text": "Phase (0 DMG)",
		"dash_ratio": 0.72,
		"stats_line": "HP 75  •  ATK 14/28  •  PHASE",
		"attack_info": "Recurve Bow: Rapid 14-DMG shots; every 4th quick shot fires a 3-arrow fan.",
		"passive_info": "Hunter's Charge: Hold Attack (0.35s) for a 28-DMG piercing Great-Arrow!",
		"dash_info": "Phantom Windstep (Shift, 1s CD): 0 DMG, phases cleanly THROUGH enemies!",
		"hud_hint": "WASD: Move   Tap/Hold Click or Space: Bow   Shift: Phase Through Enemies",
		"desc": "Fastest ranger! Piercing charged arrows + Shift phases right through enemies.",
		"death_line": "Sylvara dances away on the wind.",
	},
	{
		"id": "velmira",
		"name": "Velmira",
		"role": "VAMPIRE",
		"subtitle": "Crimson Hemomancer",
		"scene_path": "res://scenes/player/Shabnam.tscn",
		"sheet_path": "res://assets/textures/player_shabnam.png",
		"frame_count": 6,
		"accent": Color(0.98, 0.30, 0.45),
		"hp": 85,
		"hp_ratio": 0.71,
		"atk_text": "17 Splash",
		"atk_ratio": 0.86,
		"spd_text": "104",
		"spd_ratio": 0.88,
		"dash_text": "Evade (0 DMG)",
		"dash_ratio": 0.62,
		"stats_line": "HP 85  •  -6/+8 HP  •  SPLASH",
		"attack_info": "Crimson Blood Splash: Cone burst dealing 17 DMG to foes in front.",
		"passive_info": "Blood Pact: Casting costs -6 HP; hitting an enemy heals +8 HP (+2 net)!",
		"dash_info": "Crimson Evade (Shift, 1s CD): Quick mist dodge (0 damage, no phasing).",
		"hud_hint": "WASD: Move   Space/Click: Blood Splash (-6 HP / +8 Hit)   Shift: Evade",
		"desc": "Blood Splash costs 6 HP to cast and heals 8 HP on hit — don't miss!",
		"death_line": "Velmira hungers for another drop.",
	},
]

const LEGACY_ALIASES: Dictionary = {
	"borzo": "behemoth",
	"bahman": "knight",
	"pari": "sylvara",
	"shabnam": "velmira",
}

static var selected_id: String = "behemoth"
static var quick_retry_same_hero: bool = false


static func normalize_id(id: String) -> String:
	var key := id.to_lower()
	if LEGACY_ALIASES.has(key):
		return String(LEGACY_ALIASES[key])
	return key


static func get_entry(id: String) -> Dictionary:
	var norm := normalize_id(id)
	for entry in CHARACTERS:
		if entry["id"] == norm:
			return entry
	return CHARACTERS[0]


static func get_index(id: String) -> int:
	var norm := normalize_id(id)
	for i in CHARACTERS.size():
		if CHARACTERS[i]["id"] == norm:
			return i
	return 0


static func instantiate_hero(id: String) -> CharacterBody2D:
	var entry := get_entry(id)
	var packed: PackedScene = load(entry["scene_path"])
	return packed.instantiate() as CharacterBody2D
