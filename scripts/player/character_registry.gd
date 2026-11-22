extends RefCounted
class_name CharacterRegistry
## Central data-driven roster of the 4 playable 96x96 medieval heroes.
##
## Order matches the Hero Wardrobe cards [1]..[4]:
##   1. Behemoth - Medieval Pit-Champion (120 HP, Stunning Punches + Shoulder Charge Stun)
##   2. Knight   - Fallen Knight         (150 HP, Armor + Energy 100% Shield + Giant Greatsword)
##   3. Sylvara  - Blonde Elven Ranger   (100 HP, Fastest Speed, Held Recurve Bow + Sylvan Vault)
##   4. Noa  - White-Haired Vampire  (75 HP, Returning Blood Whip + 30% Fang Mark + Bat Swarm)

const CHARACTERS: Array[Dictionary] = [
	{
		"id": "behemoth",
		"name": "Behemoth",
		"role": "BRAWLER",
		"subtitle": "Medieval Pit-Champion",
		"scene_path": "res://scenes/player/Behemoth.tscn",
		"sheet_path": "res://assets/textures/player_behemoth.png",
		"portrait_path": "res://assets/textures/portrait_behemoth.png",
		"frame_count": 16,
		"accent": Color(0.98, 0.68, 0.26),
		"hp": 120,
		"hp_ratio": 0.80,
		"atk_text": "18-29 + Stun",
		"atk_ratio": 0.84,
		"spd_text": "92",
		"spd_ratio": 0.74,
		"dash_text": "Shoulder Stun",
		"dash_ratio": 0.95,
		"stats_line": "HP 120  •  SPD 92  •  STUN COMBO",
		"attack_info": "Iron-Cestus Combo: Jab -> Cross -> Uppercut (18-29 DMG); every punch STUNS foes!",
		"passive_info": "Concussive Gauntlets: 3rd-hit Uppercut unleashes a heavy stun shockwave.",
		"dash_info": "Shoulder Charge [Shift]: Rams with his iron pauldron (18 DMG + 1.1s Stun)!",
		"desc": "120 HP medieval brawler whose iron fists and shoulder charge stun enemies.",
		"death_line": "The pit champion falls, fists still clenched.",
	},
	{
		"id": "knight",
		"name": "Knight",
		"role": "FALLEN KNIGHT",
		"subtitle": "Betrayed Greatsword Tank",
		"scene_path": "res://scenes/player/Knight.tscn",
		"sheet_path": "res://assets/textures/player_knight.png",
		"portrait_path": "res://assets/textures/portrait_knight.png",
		"frame_count": 16,
		"accent": Color(0.42, 0.82, 1.0),
		"hp": 150,
		"hp_ratio": 1.00,
		"atk_text": "26 Spin",
		"atk_ratio": 0.94,
		"spd_text": "68 Heavy",
		"spd_ratio": 0.52,
		"dash_text": "Shield Ram",
		"dash_ratio": 0.90,
		"stats_line": "HP 150  •  ARMOR + ENERGY SHIELD",
		"attack_info": "Zweihander Spin: Swings & spins his colossal Greatsword for 26 wide DMG.",
		"passive_info": "Plate Armor (-3 DMG) + Shield [RMB/E]: Blocks 100% HP DMG; only hits drain Stamina (locks at 0 until full)!",
		"dash_info": "Shield-Wall Charge [Shift]: Braces Tower Shield in front and rams foes (16 DMG).",
		"desc": "150 HP Fallen Knight. Shield blocks 100% HP via Energy; slowest, heaviest titan.",
		"death_line": "Betrayed once more, the Fallen Knight kneels.",
	},
	{
		"id": "sylvara",
		"name": "Sylvara",
		"role": "ELF RANGER",
		"subtitle": "Blonde Woodland Archer",
		"scene_path": "res://scenes/player/Sylvara.tscn",
		"sheet_path": "res://assets/textures/player_sylvara.png",
		"portrait_path": "res://assets/textures/portrait_sylvara.png",
		"frame_count": 15,
		"accent": Color(0.40, 0.94, 0.58),
		"hp": 100,
		"hp_ratio": 0.67,
		"atk_text": "15 / 30 Bow",
		"atk_ratio": 0.86,
		"spd_text": "124 Fastest",
		"spd_ratio": 1.00,
		"dash_text": "Sylvan Vault",
		"dash_ratio": 0.88,
		"stats_line": "HP 100  •  SPD 124 (FASTEST)  •  BOW",
		"attack_info": "Elven Recurve Bow: Swift 15-DMG arrows; Hold Attack to charge a 30-DMG Piercing Shot!",
		"passive_info": "Fleetfoot Ranger: Highest base speed (124) and glides while charging her bow.",
		"dash_info": "Sylvan Gale Vault [Shift]: Phases enemies, slows pursuers & grants +28% Tailwind!",
		"desc": "100 HP fastest ranger!Visibly draws & charges her golden-yew Recurve Bow.",
		"death_line": "Sylvara's golden arrow falls silent in the glade.",
	},
	{
		"id": "noa",
		"name": "Noa",
		"role": "VAMPIRE",
		"subtitle": "Crimson Hemomancer",
		"scene_path": "res://scenes/player/Noa.tscn",
		"sheet_path": "res://assets/textures/player_noa.png",
		"portrait_path": "res://assets/textures/portrait_noa.png",
		"frame_count": 16,
		"accent": Color(0.98, 0.30, 0.45),
		"hp": 75,
		"hp_ratio": 0.50,
		"atk_text": "14 Splash + 30%",
		"atk_ratio": 0.88,
		"spd_text": "104",
		"spd_ratio": 0.84,
		"dash_text": "Bat Swarm",
		"dash_ratio": 0.92,
		"stats_line": "HP 75  •  BLOOD SPLASH  •  30% FANG",
		"attack_info": "Crimson Blood-Splash Slash: Wide sweeping crimson splash arc; heals back cost + 1 HP per hit (locks at 1 HP)!",
		"passive_info": "2-Fang Blood Curse: 4th hit erupts a massive Crimson Blood Fountain for 30% of enemy Max HP!",
		"dash_info": "Bat-Swarm Vanish [Shift]: Dissolves into 5 flapping Vampire Bats & materializes ahead!",
		"desc": "75 HP vampire princess: sweeping Blood-Splash arcs, 30% Blood Fountain & Bat-Swarm Shift.",
		"death_line": "Noa melts into a dark crimson pool.",
	},
]

static var selected_id: String = "behemoth"
static var quick_retry_same_hero: bool = false


static func normalize_id(id: String) -> String:
	return id.to_lower()


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
