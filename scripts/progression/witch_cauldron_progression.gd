extends RefCounted
class_name WitchCauldronProgression
## Persistent profile, 3-Region Stage Unlocks, Witch Alchemy Reagents, Developer Cheats,
## and Distinct Per-Hero Scrollable OP Skill Trees!
##
## Skill Tree Topology (`1 -> 3 Exclusive 4-Tier Pillars -> 1 Converged [R] Ultimate`):
##   - `solo_top`    : Unique Hero Skill 1 (`max_level = 1`):
##                       * Behemoth -> 1.0s Full Invincibility after Shift
##                       * Knight   -> Radiant Aegis Shield Dome on Knight
##                       * Sylvara  -> 1.0s 100% Projectile Dodge after Shift
##                       * Noa      -> 1% Enemy HP Lifesteal on Attacks
##   - `p0..p2`      : 3 Distinct Hero Playstyle Pillars (`max_level = 5`, mutually exclusive
##                     until `Reset Points` is pressed!)
##   - `solo_bottom` : Unlocks Hero's Signature `[R]` Ultimate Ability (`max_level = 1`):
##                       * Behemoth `[R]` -> Infernal Rage (Fire VFX + 2x Damage!)
##                       * Knight   `[R]` -> Royal War Banner (+1 Allied Knight, 7s dur, 60s CD!)
##                       * Sylvara  `[R]` -> Hunter's Rapid Lock-On (Select 1 enemy -> auto arrow spam!)
##                       * Noa      `[R]` -> Sanguine Rain Toggle (Medium Blood Circle: 1% self drain,
##                                           1% enemy HP DPS, 1% Lifesteal on hit!)

const DEFAULT_SAVE_PATH := "user://witch_cottage_save.cfg"
const STARTING_BREW_POINTS: int = 0
const REAGENTS_PER_POTION: int = 3
const MAX_NODE_LEVEL: int = 5
const INFINITE_CHEAT_POINTS: int = 999999

const ALL_NODE_IDS: Array[String] = [
	"solo_top",
	"p0_t1", "p1_t1", "p2_t1",
	"p0_t2", "p1_t2", "p2_t2",
	"p0_t3", "p1_t3", "p2_t3",
	"p0_t4", "p1_t4", "p2_t4",
	"solo_bottom",
]

const REGIONS: Array[Dictionary] = [
	{
		"id": 1,
		"name": "Whispering Jungle",
		"boss_name": "Forest Colossus",
		"subtitle": "Slimes, Skeleton Archers, Stone Golems & Forest Colossus",
		"accent": Color(0.28, 0.92, 0.52),
	},
	{
		"id": 2,
		"name": "Cursed Bone Crypt",
		"boss_name": "Malakor, Arch-Lich",
		"subtitle": "Blink-Stalkers, Hex-Weavers, Bone Phalanx & Arch-Lich",
		"accent": Color(0.62, 0.48, 1.0),
	},
	{
		"id": 3,
		"name": "Infernal Citadel",
		"boss_name": "Igniszar, Dreadlord",
		"subtitle": "Hellfire Imps, Void Snipers, Magma Brutes & Dreadlord",
		"accent": Color(1.0, 0.42, 0.22),
	},
]

static var save_path: String = DEFAULT_SAVE_PATH
static var _loaded: bool = false
static var _reagents: int = 0
static var _max_unlocked_region: int = 1
static var _hero_points: Dictionary = {}
static var _hero_nodes: Dictionary = {}

## Developer Console Cheat State (`wizard` enables, `canoheil` disables ALL cheats!)
static var wizard_cheat_active: bool = false
static var _pre_wizard_snapshot_taken: bool = false
static var _pre_wizard_points: Dictionary = {}
static var _pre_wizard_nodes: Dictionary = {}

static var master_volume: float = 1.0
static var sfx_volume: float = 1.0
static var screen_shake_enabled: bool = true
static var fullscreen_enabled: bool = false


static func get_region_info(region_id: int) -> Dictionary:
	var idx := clampi(region_id - 1, 0, REGIONS.size() - 1)
	return REGIONS[idx]


static func get_max_unlocked_region() -> int:
	ensure_loaded()
	if wizard_cheat_active:
		return REGIONS.size()
	return clampi(_max_unlocked_region, 1, REGIONS.size())


static func is_region_unlocked(region_id: int) -> bool:
	ensure_loaded()
	if wizard_cheat_active:
		return true
	return region_id >= 1 and region_id <= _max_unlocked_region


static func unlock_region(region_id: int) -> bool:
	ensure_loaded()
	var clamped := clampi(region_id, 1, REGIONS.size())
	if clamped > _max_unlocked_region:
		_max_unlocked_region = clamped
		save_to_disk()
		return true
	return false


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
			return ["I. Tempest Volley", "II. Trap & Venom", "III. Storm Sniper"]
		"knight":
			return ["I. Greatsword Cleave", "II. Lion Bastion", "III. Sky Crusader"]
		"noa":
			return ["I. Hemomancer", "II. Bat Empress", "III. Blood Reaper"]
		_:
			return ["I. Earthshaker", "II. Blood Berserker", "III. Volcanic Lord"]


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


static func _nodes_behemoth() -> Array[Dictionary]:
	return [
		_make_node("solo_top", 0, 1, -1, 0, 1, "Unstoppable Invincibility",
			"After Shift ends, Behemoth becomes 100% INVINCIBLE to all damage for 1.0s!", [], false),
		# Pillar 0: Earthshaker Titan (Ground Fissures, Pull & Concussion)
		_make_node("p0_t1", 1, 0, 0, 1, 5, "Seismic Knuckles",
			"Every punch unleashes a 76px Earth Shockwave & +14 Attack DMG/lv!", ["solo_top"], true),
		_make_node("p0_t2", 2, 0, 0, 9, 5, "Skullcrusher Stun",
			"Stuns last +0.4s/lv longer & deal +40% (+12%/lv) bonus DMG to stunned foes!", ["p0_t1"], true),
		_make_node("p0_t3", 3, 0, 0, 8, 5, "Tectonic Crater Pull",
			"Shift & Uppercut pull nearby foes inward and erupt a 96px Rock Crater (+25 DMG/lv)!", ["p0_t2"], true),
		_make_node("p0_t4", 4, 0, 0, 13, 5, "Worldbreaker Colossus",
			"+55 Max HP/lv, +26 Attack DMG/lv, & 2x Shockwave radius!", ["p0_t3"], true),
		# Pillar 1: Blood Berserker (360 Whirlwind, Missing-HP Frenzy & Rampage)
		_make_node("p1_t1", 1, 1, 1, 5, 5, "Primal Savagery",
			"+16% Attack Speed/lv & +16 Move Speed/lv!", ["solo_top"], false),
		_make_node("p1_t2", 2, 1, 1, 6, 5, "Whirlwind Cleave",
			"Every 2nd swing spins a 360° Barbarian Cleave & heals +6 (+4/lv) HP!", ["p1_t1"], false),
		_make_node("p1_t3", 3, 1, 1, 10, 5, "Undying Blood-Frenzy",
			"Gain up to +90% (+22%/lv) bonus DMG as HP drops & halve Shift cooldown!", ["p1_t2"], true),
		_make_node("p1_t4", 4, 1, 1, 15, 5, "Chieftain's Rampage",
			"+60 Max HP/lv, +24 Attack DMG/lv, & kills reset Shift + heal 20% Max HP!", ["p1_t3"], true),
		# Pillar 2: Volcanic Lord (Ignite Burn DoT, Thorns & Lava Eruptions — NO arrows!)
		_make_node("p2_t1", 1, 2, 2, 3, 5, "Molten Knuckles",
			"Punches IGNITE foes with stacking Burn DoT (18 + 14/lv DPS) & +12 DMG/lv!", ["solo_top"], true),
		_make_node("p2_t2", 2, 2, 2, 7, 5, "Magma Carapace",
			"+50 Max HP/lv & attackers suffer 30 (+18/lv) Volcanic Thorns + Ignite!", ["p2_t1"], false),
		_make_node("p2_t3", 3, 2, 2, 14, 5, "Volcanic Eruption",
			"Every 3rd combo hit calls down a Magma Pillar for 65 (+28/lv) AoE DMG!", ["p2_t2"], true),
		_make_node("p2_t4", 4, 2, 2, 4, 5, "Avatar of Ragnarok",
			"+30 Attack DMG/lv & slain enemies explode in an 88px Lava Fireball!", ["p2_t3"], true),
		# Converged [R] Ultimate
		_make_node("solo_bottom", 5, 1, -1, 14, 1, "[R] Infernal Rage",
			"UNLOCKS [R]: Engulfs Behemoth in roaring flames & DOUBLES (2x) ALL DAMAGE for 8s!",
			["p0_t4", "p1_t4", "p2_t4"], true),
	]


static func _nodes_knight() -> Array[Dictionary]:
	return [
		_make_node("solo_top", 0, 1, -1, 7, 1, "Sacred Aegis Shield",
			"Surrounds Knight with a glowing Sacred Shield Barrier that absorbs hits & surges on Shift!", [], false),
		# Pillar 0: Greatsword Cleave (Pure Melee Mastery, Sunder & 360 Spin — ZERO arrows!)
		_make_node("p0_t1", 1, 0, 0, 1, 5, "Sweeping Greatsword",
			"+45% wider Greatsword Cleave arc & +15 Attack DMG/lv!", ["solo_top"], true),
		_make_node("p0_t2", 2, 0, 0, 4, 5, "Armor-Sundering Steel",
			"Consecutive hits crack enemy armor (+14%/lv bonus DMG taken) & +12 DMG/lv!", ["p0_t1"], true),
		_make_node("p0_t3", 3, 0, 0, 8, 5, "Templar Verdict Crit",
			"40% (+10%/lv) Crit Chance for 2.5x Holy Greatsword Damage!", ["p0_t2"], true),
		_make_node("p0_t4", 4, 0, 0, 10, 5, "Excalibur Whirlwind",
			"+35% Attack Speed, +28 DMG/lv, & every 3rd slash spins a 360° Golden Cleave!", ["p0_t3"], true),
		# Pillar 1: Lion Bastion (Fortress Shield, Counter-Shockwave & Consecrated Ground)
		_make_node("p1_t1", 1, 1, 1, 6, 5, "Golden Lion Plate",
			"+60 Max HP/lv, +4 Flat Armor/lv, & -50% Shield Energy drain!", ["solo_top"], false),
		_make_node("p1_t2", 2, 1, 1, 13, 5, "Lion's Roar Counter",
			"Blocking any hit blasts nearby foes (115px) for 50 (+24/lv) Holy Shockwave DMG!", ["p1_t1"], false),
		_make_node("p1_t3", 3, 1, 1, 12, 5, "Consecrated Sanctuary",
			"Holy ground aura heals +10 (+6/lv) HP/sec & burns nearby monsters!", ["p1_t2"], false),
		_make_node("p1_t4", 4, 1, 1, 7, 5, "Unbreakable Phalanx",
			"Shield NEVER exhausts, +70 Max HP/lv, & +20 Attack DMG/lv!", ["p1_t3"], false),
		# Pillar 2: Sky Crusader (Shield-Ram, Sky Lightning Pillar & Execute)
		_make_node("p2_t1", 1, 2, 2, 11, 5, "Thunder Shield-Ram",
			"+16 Move Speed/lv, -12% Shift CD/lv, & +24 Shift Ram DMG/lv!", ["solo_top"], false),
		_make_node("p2_t2", 2, 2, 2, 3, 5, "Heavensfall Lightning",
			"Shift landing calls down a Sky Lightning Pillar for 65 (+28/lv) AoE DMG!", ["p2_t1"], true),
		_make_node("p2_t3", 3, 2, 2, 9, 5, "Chains of Judgment",
			"Shift stuns foes for 1.6s & executes non-boss enemies under 28% HP!", ["p2_t2"], true),
		_make_node("p2_t4", 4, 2, 2, 14, 5, "Solaris Grand Paladin",
			"+26 Attack DMG/lv, +100% Energy Regen, & kills reset Shift!", ["p2_t3"], true),
		# Converged [R] Ultimate (`banner + 1 allied knight, 7s dur, 1min CD`!)
		_make_node("solo_bottom", 5, 1, -1, 15, 1, "[R] Royal War Banner",
			"UNLOCKS [R]: Plants a Lion Banner & summons 1 Allied Knight to fight for 7s (60s CD)!",
			["p0_t4", "p1_t4", "p2_t4"], true),
	]


static func _nodes_sylvara() -> Array[Dictionary]:
	return [
		_make_node("solo_top", 0, 1, -1, 5, 1, "Windveil Mirage",
			"After Shift ends, Sylvara dodges 100% of ALL enemy projectiles for 1.0s!", [], false),
		# Pillar 0: Tempest Volley (Multishot Fan, Piercing & Starburst AoE)
		_make_node("p0_t1", 1, 0, 0, 1, 5, "Split-Tempest Volley",
			"EVERY shot fires a multi-arrow fan (+2 arrows, +10 DMG/lv)!", ["solo_top"], true),
		_make_node("p0_t2", 2, 0, 0, 10, 5, "Thorn-Pierce Flight",
			"All arrows PIERCE through enemies & gain +9 Attack DMG/lv!", ["p0_t1"], false),
		_make_node("p0_t3", 3, 0, 0, 8, 5, "Emerald Starburst",
			"Arrows detonate on hit in a 58px AoE blast for +65% (+15%/lv) DMG!", ["p0_t2"], true),
		_make_node("p0_t4", 4, 0, 0, 14, 5, "Zero-Draw Stormbow",
			"Cut bow charge & fire cooldown by 55% and gain +22 Attack DMG/lv!", ["p0_t3"], true),
		# Pillar 1: Trap & Venom Warden (Bramble Traps, Venom Snare & Ricochet)
		_make_node("p1_t1", 1, 1, 1, 11, 5, "Bramble Snare Vault",
			"+18 Move Speed/lv, -12% Shift CD/lv, & Shift drops a Thorny Bramble Trap!", ["solo_top"], false),
		_make_node("p1_t2", 2, 1, 1, 2, 5, "Venomvine Arrows",
			"Arrows slow foes by 55% & inject 16 (+12/lv) Venom burst damage!", ["p1_t1"], false),
		_make_node("p1_t3", 3, 1, 1, 3, 5, "Ricochet Wind-Shot",
			"Arrows BOUNCE to a 2nd nearby enemy for 80% (+10%/lv) DMG!", ["p1_t2"], true),
		_make_node("p1_t4", 4, 1, 1, 12, 5, "Warden of the Wilds",
			"+42 Max HP/lv, +25% Energy Regen/lv, & kills reset Shift + heal 10 HP!", ["p1_t3"], false),
		# Pillar 2: Storm Sniper (2.5x Crits, Chain Lightning & Longshot Execute)
		_make_node("p2_t1", 1, 2, 2, 4, 5, "Eagle-Eye Critical",
			"Arrows gain 35% (+10%/lv) Crit Chance to strike for 2.5x DAMAGE!", ["solo_top"], true),
		_make_node("p2_t2", 2, 2, 2, 0, 5, "Chain-Lightning Arrows",
			"Arrows arc Lightning to 2 nearby foes (60% +12%/lv DMG) & stun on charge!", ["p2_t1"], true),
		_make_node("p2_t3", 3, 2, 2, 9, 5, "Heartseeker Execute",
			"+Up to 45% Longshot DMG & instantly EXECUTE creeps below 30% (+4%/lv) HP!", ["p2_t2"], true),
		_make_node("p2_t4", 4, 2, 2, 15, 5, "Avatar of the Hunt",
			"+24 Attack DMG/lv & +30% total bow damage multiplier!", ["p2_t3"], true),
		# Converged [R] Ultimate (`Press R -> lock onto 1 enemy & rapid-spam arrows!`)
		_make_node("solo_bottom", 5, 1, -1, 14, 1, "[R] Hunter's Rapid Lock-On",
			"UNLOCKS [R]: Selects 1 enemy & auto-spams rapid homing arrows onto them!",
			["p0_t4", "p1_t4", "p2_t4"], true),
	]


static func _nodes_noa() -> Array[Dictionary]:
	return [
		_make_node("solo_top", 0, 1, -1, 6, 1, "Sanguine 1% HP Bite",
			"Attacks gain Vampiric Lifesteal equal to 1% of the hit enemy's Max HP!", [], true),
		# Pillar 0: Crimson Hemomancer (8-Hit Blood Fountain Mastery & Contagion)
		_make_node("p0_t1", 1, 0, 0, 2, 5, "Accelerated Fangs",
			"Every 2nd hit inflicts +1 bonus Fang Stack toward the 8-hit burst & +12 DMG/lv!", ["solo_top"], true),
		_make_node("p0_t2", 2, 0, 0, 3, 5, "Gushing Artery",
			"8-Hit Blood Fountain deals +6%/lv extra Enemy Max HP & +4%/lv Lifesteal!", ["p0_t1"], true),
		_make_node("p0_t3", 3, 0, 0, 1, 5, "Scarlet Contagion",
			"+22px Blood-Splash reach/lv, +15 DMG/lv, & kills spread 4 Fang Stacks!", ["p0_t2"], true),
		_make_node("p0_t4", 4, 0, 0, 12, 5, "Empress of Vitae",
			"+48 Max HP/lv & +26 Attack DMG/lv!", ["p0_t3"], true),
		# Pillar 1: Bat Empress (Damaging Mist-Shift & Orbiting Bat Familiars)
		_make_node("p1_t1", 1, 1, 1, 5, 5, "Ravenous Bat-Shift",
			"Bat-Swarm Shift bites foes for 32 (+18/lv) DMG & applies 2 Fang Stacks!", ["solo_top"], true),
		_make_node("p1_t2", 2, 1, 1, 11, 5, "Midnight Haste",
			"+18 Move Speed/lv & -12% Bat-Swarm Shift cooldown/lv!", ["p1_t1"], false),
		_make_node("p1_t3", 3, 1, 1, 10, 5, "Orbiting Bat Familiars",
			"Summons 3 Crimson Bats around Noa that bite nearby foes (+16 DMG/lv + Stacks)!", ["p1_t2"], true),
		_make_node("p1_t4", 4, 1, 1, 15, 5, "Queen of Midnight",
			"+42 Max HP/lv, +22 DMG/lv, & kills instantly reset Bat-Swarm Shift!", ["p1_t3"], true),
		# Pillar 2: Phantom Blood-Reaper (Attack Speed, 2.5x Crits & Corpse Blood-Novas)
		_make_node("p2_t1", 1, 2, 2, 13, 5, "Frenzied Claws",
			"+16% faster Blood-Splash speed/lv & +12 Attack DMG/lv!", ["solo_top"], true),
		_make_node("p2_t2", 2, 2, 2, 8, 5, "Crimson Rose Crit",
			"38% (+10%/lv) Crit Chance for 2.5x Crimson Slash Damage!", ["p2_t1"], true),
		_make_node("p2_t3", 3, 2, 2, 9, 5, "Corpse Exsanguination",
			"Slain foes explode in an 88px Blood Mist Nova for 52 (+24/lv) AoE DMG!", ["p2_t2"], true),
		_make_node("p2_t4", 4, 2, 2, 14, 5, "Immortal Reaper",
			"+50 Max HP/lv, +26 DMG/lv, & +50% DMG to enemies below 40% HP!", ["p2_t3"], true),
		# Converged [R] Ultimate (`Toggle ON/OFF Blood Circle: 1% self drain, 1% enemy DPS, 1% lifesteal!`)
		_make_node("solo_bottom", 5, 1, -1, 14, 1, "[R] Sanguine Rain (Toggle)",
			"UNLOCKS [R] TOGGLE: Pours blood in a circle (1% self HP/s, 1% foe HP DPS, +1% Lifesteal/hit)!",
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
	_max_unlocked_region = 1
	wizard_cheat_active = false
	_pre_wizard_snapshot_taken = false
	_pre_wizard_points.clear()
	_pre_wizard_nodes.clear()
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
	_max_unlocked_region = clampi(int(cfg.get_value("profile", "max_unlocked_region", 1)), 1, REGIONS.size())

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
	if wizard_cheat_active:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "selected_hero", CharacterRegistry.selected_id)
	cfg.set_value("profile", "reagents", _reagents)
	cfg.set_value("profile", "max_unlocked_region", _max_unlocked_region)

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
	if wizard_cheat_active:
		return INFINITE_CHEAT_POINTS
	var hid := String(CharacterRegistry.get_entry(hero_id)["id"])
	return int(_hero_points.get(hid, STARTING_BREW_POINTS))


static func add_brew_points(hero_id: String, amount: int = 1) -> int:
	ensure_loaded()
	if amount <= 0:
		return get_brew_points(hero_id)
	var hid := String(CharacterRegistry.get_entry(hero_id)["id"])
	_hero_points[hid] = int(_hero_points.get(hid, STARTING_BREW_POINTS)) + amount
	save_to_disk()
	return get_brew_points(hid)


static func enable_wizard_cheat() -> void:
	ensure_loaded()
	if not _pre_wizard_snapshot_taken:
		_pre_wizard_points = _hero_points.duplicate(true)
		_pre_wizard_nodes = _hero_nodes.duplicate(true)
		_pre_wizard_snapshot_taken = true
	wizard_cheat_active = true
	for entry in CharacterRegistry.CHARACTERS:
		var hid := String(entry["id"])
		_hero_points[hid] = INFINITE_CHEAT_POINTS


static func grant_wizard_points(_amount: int = 10000) -> void:
	enable_wizard_cheat()


static func disable_all_cheats() -> void:
	ensure_loaded()
	wizard_cheat_active = false
	if _pre_wizard_snapshot_taken:
		_hero_points = _pre_wizard_points.duplicate(true)
		_hero_nodes = _pre_wizard_nodes.duplicate(true)
		_pre_wizard_snapshot_taken = false
		_pre_wizard_points.clear()
		_pre_wizard_nodes.clear()
	save_to_disk()


static func reset_all_heroes() -> void:
	ensure_loaded()
	wizard_cheat_active = false
	_pre_wizard_snapshot_taken = false
	_pre_wizard_points.clear()
	_pre_wizard_nodes.clear()
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
	if not wizard_cheat_active:
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
	if not wizard_cheat_active:
		_hero_points[hid] = maxi(int(_hero_points.get(hid, 0)) - 1, 0)
	var map: Dictionary = _hero_nodes.get(hid, _make_empty_node_map())
	var max_lv := get_node_max_level(hid, node_id)
	map[node_id] = clampi(int(map.get(node_id, 0)) + 1, 0, max_lv)
	_hero_nodes[hid] = map
	save_to_disk()
	return true


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
