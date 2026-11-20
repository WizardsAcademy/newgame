extends RefCounted
class_name CharacterRegistry
## Central data-driven roster of the 4 playable heroes.
##
## Order matches the Character Select cards [1]..[4]:
##   1. Borzo   - Iron-Fist Brawler  (melee 3-hit combo + heavy Shoulder Dash)
##   2. Bahman  - Frost Knight       (wide greatsword + Winter Aura chill field)
##   3. Pari    - Elf Ranger         (swift bow + hold for piercing Great-Arrow)
##   4. Shabnam - Crimson Vampire    (boomerang Blood Blade + Life Leech & Nova)

const CHARACTERS: Array[Dictionary] = [
	{
		"id": "borzo",
		"name": "Borzo",
		"role": "BRAWLER",
		"subtitle": "Iron-Fist Brawler",
		"scene_path": "res://scenes/player/Player.tscn",
		"sheet_path": "res://assets/textures/player_borzo.png",
		"accent": Color(0.96, 0.68, 0.28),
		"stats_line": "HP 100  |  DMG 18  |  DASH 14",
		"desc": "3-hit punch combo ending in a shockwave uppercut + heavy Shoulder Dash.",
		"death_line": "Borzo needs to punch harder.",
	},
	{
		"id": "bahman",
		"name": "Bahman",
		"role": "KNIGHT",
		"subtitle": "Frost Greatsword",
		"scene_path": "res://scenes/player/Bahman.tscn",
		"sheet_path": "res://assets/textures/player_bahman.png",
		"accent": Color(0.45, 0.84, 1.0),
		"stats_line": "HP 120  |  DMG 24  |  DASH 16",
		"desc": "Wide frost-sword cleave + Winter Aura that chills foes (stronger standing still).",
		"death_line": "Even steel bends beneath the horde.",
	},
	{
		"id": "pari",
		"name": "Pari",
		"role": "ELF",
		"subtitle": "Elven Ranger",
		"scene_path": "res://scenes/player/Pari.tscn",
		"sheet_path": "res://assets/textures/player_pari.png",
		"accent": Color(0.42, 0.92, 0.58),
		"stats_line": "HP 75   |  DMG 14  |  DASH 11",
		"desc": "Fastest mover! Quick bow volleys, or HOLD Attack for a piercing Great-Arrow.",
		"death_line": "Keep moving - an elf never stands still.",
	},
	{
		"id": "shabnam",
		"name": "Shabnam",
		"role": "VAMPIRE",
		"subtitle": "Blood Blade",
		"scene_path": "res://scenes/player/Shabnam.tscn",
		"sheet_path": "res://assets/textures/player_shabnam.png",
		"accent": Color(0.95, 0.28, 0.42),
		"stats_line": "HP 85   |  DMG 13x2 | DASH 15",
		"desc": "Boomerang Blood Blade hits out & back. Every hit leeches HP + charges Blood Nova!",
		"death_line": "The night hungers for another drop.",
	},
]

## Last chosen hero id across scene reloads in the current game session.
static var selected_id: String = "borzo"

## When true, reloading Main (`R` on Game Over) skips the menu and retries
## immediately with `selected_id`. When false (initial launch or `C`/`Esc`),
## Main opens the Character Select screen first.
static var quick_retry_same_hero: bool = false


static func get_entry(id: String) -> Dictionary:
	for entry in CHARACTERS:
		if entry["id"] == id:
			return entry
	return CHARACTERS[0]


static func get_index(id: String) -> int:
	for i in CHARACTERS.size():
		if CHARACTERS[i]["id"] == id:
			return i
	return 0


static func instantiate_hero(id: String) -> CharacterBody2D:
	var entry := get_entry(id)
	var packed: PackedScene = load(entry["scene_path"])
	return packed.instantiate() as CharacterBody2D
