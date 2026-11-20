extends RefCounted
class_name CharacterRegistry
## Central data-driven roster of the 4 playable heroes.
##
## Order matches the Character Select cards [1]..[4]:
##   1. Behemoth - Iron-Fist Brawler  (melee 3-hit combo + heavy Shoulder Dash)
##   2. Knight   - Frost Knight       (wide greatsword + Winter Aura chill field)
##   3. Sylvara  - Elf Ranger         (swift bow + hold for piercing Great-Arrow)
##   4. Velmira  - Crimson Vampire    (boomerang Blood Blade + Life Leech & Nova)

const CHARACTERS: Array[Dictionary] = [
	{
		"id": "behemoth",
		"name": "Behemoth",
		"role": "BRAWLER",
		"subtitle": "Iron-Fist Brawler",
		"scene_path": "res://scenes/player/Player.tscn",
		"sheet_path": "res://assets/textures/player_borzo.png",
		"accent": Color(0.98, 0.68, 0.26),
		"hp": 100,
		"hp_ratio": 0.83,
		"atk_text": "18 -> 29",
		"atk_ratio": 0.78,
		"spd_text": "90",
		"spd_ratio": 0.72,
		"dash_text": "14 DMG (1s)",
		"dash_ratio": 0.82,
		"stats_line": "HP 100  •  ATK 18-29  •  DASH 14",
		"attack_info": "3-Hit Combo: Jab (18) -> Cross (21) -> Uppercut (29 DMG + Launch).",
		"passive_info": "Shockwave Finisher: Every 3rd punch blasts foes back with a gold ring.",
		"dash_info": "Shoulder Dash (Shift, 1s CD): Phases through enemies for 14 damage.",
		"desc": "3-hit punch combo ending in a shockwave uppercut + heavy Shoulder Dash.",
		"death_line": "Behemoth will crush them next time.",
	},
	{
		"id": "knight",
		"name": "Knight",
		"role": "KNIGHT",
		"subtitle": "Frost Greatsword",
		"scene_path": "res://scenes/player/Bahman.tscn",
		"sheet_path": "res://assets/textures/player_bahman.png",
		"accent": Color(0.42, 0.84, 1.0),
		"hp": 120,
		"hp_ratio": 1.00,
		"atk_text": "24 Wide",
		"atk_ratio": 0.92,
		"spd_text": "76",
		"spd_ratio": 0.58,
		"dash_text": "16 DMG (1s)",
		"dash_ratio": 0.94,
		"stats_line": "HP 120  •  ATK 24  •  DASH 16",
		"attack_info": "Greatsword Cleave: Wide 24-DMG frost slash hitting whole packs.",
		"passive_info": "Winter Aura: Slows nearby foes (30%->55%). Stand still to pulse ice DMG!",
		"dash_info": "Armored Charge (Shift, 1s CD): Heavy shield rush dealing 16 damage.",
		"desc": "Wide frost-sword cleave + Winter Aura that chills foes (stronger standing still).",
		"death_line": "Even the Knight's steel bends beneath the horde.",
	},
	{
		"id": "sylvara",
		"name": "Sylvara",
		"role": "ELF",
		"subtitle": "Elven Ranger",
		"scene_path": "res://scenes/player/Pari.tscn",
		"sheet_path": "res://assets/textures/player_pari.png",
		"accent": Color(0.40, 0.94, 0.58),
		"hp": 75,
		"hp_ratio": 0.63,
		"atk_text": "14 / 28",
		"atk_ratio": 0.84,
		"spd_text": "118 Fast",
		"spd_ratio": 1.00,
		"dash_text": "11 DMG (1s)",
		"dash_ratio": 0.70,
		"stats_line": "HP 75  •  ATK 14/28  •  SPD 118",
		"attack_info": "Elven Bow: Rapid 14-DMG shots; every 4th quick shot fires a 3-arrow fan.",
		"passive_info": "Hunter's Charge: Hold Attack (0.35s) for a 28-DMG piercing Great-Arrow!",
		"dash_info": "Wind-Step Dash (Shift, 1s CD): Fastest 390-speed dash dealing 11 damage.",
		"desc": "Fastest mover! Quick bow volleys, or HOLD Attack for a piercing Great-Arrow.",
		"death_line": "Sylvara dances away on the wind.",
	},
	{
		"id": "velmira",
		"name": "Velmira",
		"role": "VAMPIRE",
		"subtitle": "Crimson Vampire",
		"scene_path": "res://scenes/player/Shabnam.tscn",
		"sheet_path": "res://assets/textures/player_shabnam.png",
		"accent": Color(0.98, 0.30, 0.45),
		"hp": 85,
		"hp_ratio": 0.71,
		"atk_text": "13 x 2",
		"atk_ratio": 0.88,
		"spd_text": "104",
		"spd_ratio": 0.88,
		"dash_text": "15 DMG +HP",
		"dash_ratio": 0.90,
		"stats_line": "HP 85  •  ATK 13x2  •  LEECH",
		"attack_info": "Blood Boomerang: Spinning blade slices foes going OUT (13) & BACK (13)!",
		"passive_info": "Vampire Leech: Every hit heals +2 HP; 5 Blood Orbs blast a 16-DMG Nova!",
		"dash_info": "Bat-Mist Dash (Shift, 1s CD): Deals 15 damage and leeches +3 HP per foe.",
		"desc": "Boomerang Blood Blade hits out & back. Every hit leeches HP + charges Blood Nova!",
		"death_line": "Velmira hungers for another drop.",
	},
]

const LEGACY_ALIASES: Dictionary = {
	"borzo": "behemoth",
	"bahman": "knight",
	"pari": "sylvara",
	"shabnam": "velmira",
}

## Last chosen hero id across scene reloads in the current game session.
static var selected_id: String = "behemoth"

## When true, reloading Main (`R` on Game Over) skips the menu and retries
## immediately with `selected_id`. When false (initial launch or `C`/`Esc`),
## Main opens the Character Select screen first.
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
