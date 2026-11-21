extends RefCounted
class_name UpgradePool
## UpgradePool - the in-run roguelike rewards ("pick 1 of 3").
##
## Every wave cleared, the player rolls 3 of these and picks ONE.
## The effects are LIVE RUN STATS: they stack during a run and reset
## with the scene on death - exactly the "you get stronger within a
## run" half of the roguelike loop. (Permanent, cross-run growth is the
## SKILL TREE - that is phase 9 and uses death currency, not this.)
##
## WHY data + one apply() switch instead of Callable per upgrade?
## Godot's const arrays cannot hold method references, and one big
## readable table is friendlier for a beginner to extend: add a row
## here, add one branch in apply(), done.
##
## Balance rule (docs/CHARACTERS.md): every tweak of these numbers gets
## logged in the Balance Log.

# =====================================================================
# THE POOL - one row per upgrade
# =====================================================================
#   id      : stable string (save files / log lines use it)
#   title   : card caption
#   desc    : one-line "what it does NOW"
#   min/max : clamp bounds so the same upgrade can't be picked forever
#             (a stat that hits its clamp stops appearing)

const POOL: Array[Dictionary] = [
	{
		"id": "iron_fist",
		"title": "Sharpened Strike",
		"desc": "+5 attack damage",
		"min": 1, "max": 100, "step": 5,
	},
	{
		"id": "extra_hp",
		"title": "Second Wind",
		"desc": "+15 max HP (and heal 15)",
		"min": 25, "max": 250, "step": 15,
	},
	{
		"id": "swift_hooves",
		"title": "Swift Hooves",
		"desc": "+8 move speed",
		"min": 70, "max": 220, "step": 8,
	},
	{
		"id": "quick_hands",
		"title": "Quick Hands",
		"desc": "Faster attacks (-0.05s)",
		"min": 0.14, "max": 0.55, "step": 0.05,
	},
	{
		"id": "ghost_feet",
		"title": "Ghost Feet",
		"desc": "+0.15s invulnerability after taking a hit",
		"min": 0.8, "max": 2.0, "step": 0.15,
	},
	{
		"id": "heavy_push",
		"title": "Bulldozer Shoulder",
		"desc": "+45 knockback power",
		"min": 180, "max": 500, "step": 45,
	},
	{
		"id": "razor_dash",
		"title": "Razor Dash",
		"desc": "+8 Shift-Charge damage",
		"min": 8, "max": 64, "step": 8,
	},
	{
		"id": "emerald_vigor",
		"title": "Emerald Vigor",
		"desc": "+25 Max Energy & +6/s regen",
		"min": 100, "max": 200, "step": 25,
	},
]


# =====================================================================
# ROLLING
# =====================================================================

## Pick `count` DISTINCT upgrades that are still useful for this player:
## an upgrade only appears in the roll while its target stat still has
## room to grow (current value < its max bound). This stops the pile of
## "+damage" cards in wave 12 being just padding.
static func roll(player: Node, count: int = 3) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for entry in POOL:
		if _has_room(entry, player):
			options.append(entry)

	# Fisher-Yates style shuffle, then take the first `count`.
	for i in range(options.size() - 1, 0, -1):
		var j := randi_range(0, i)
		var tmp := options[i]
		options[i] = options[j]
		options[j] = tmp

	if options.size() <= count:
		return options  # late game: pool shrinks, show what is left
	return options.slice(0, count)


## True while the player's matching stat is still below the entry's max.
static func _has_room(entry: Dictionary, player: Node) -> bool:
	match entry["id"]:
		"iron_fist":
			return player.attack_damage < entry["max"]
		"extra_hp":
			return player.max_health < entry["max"]
		"swift_hooves":
			return player.move_speed < entry["max"]
		"quick_hands":
			return player.attack_duration > entry["min"]
		"ghost_feet":
			return player.invulnerability_time < entry["max"]
		"heavy_push":
			return player.knockback_speed < entry["max"]
		"razor_dash":
			return player.get("dash_deals_damage") == true and ("dash_damage" in player) and player.dash_damage < entry["max"]
		"emerald_vigor":
			return ("max_energy" in player) and player.max_energy < entry["max"]
	return false


# =====================================================================
# APPLYING
# =====================================================================

## Apply one upgrade to the player. Returns the amount actually gained
## (for the floating "+5" style feedback), so the UI can show reality
## instead of hope.
##
## Clamps on the way in: values can never leave the sane bounds, and a
## clamp hit here equals "no real gain" - Main may then drop a hint.
static func apply(id: String, player: Node) -> String:
	var entry := _find(id)
	if entry.is_empty() or player == null:
		return ""
	var step: float = float(entry["step"])

	match id:
		"iron_fist":
			player.attack_damage = mini(int(player.attack_damage + step), int(entry["max"]))
			if "combo_damage_1" in player:
				player.combo_damage_1 += int(step)
				player.combo_damage_2 += int(step)
				player.combo_damage_3 += int(step)
			if "arrow_damage" in player:
				player.arrow_damage += int(step) - 1
				player.charged_arrow_damage += int(step) + 2
			return "+%d damage" % step
		"extra_hp":
			player.max_health = mini(int(player.max_health + step), int(entry["max"]))
			# Heal by the same amount: +max HP that does not heal feels
			# like a scam, and Scam = pillar "fair but hard" violation.
			player.current_health = mini(int(player.current_health + step), int(player.max_health))
			if player.has_signal("health_changed"):
				player.health_changed.emit(player.current_health, player.max_health)
			return "+%d max HP" % step
		"swift_hooves":
			player.move_speed = minf(player.move_speed + step, float(entry["max"]))
			return "+%d speed" % step
		"quick_hands":
			player.attack_duration = maxf(player.attack_duration - step, float(entry["min"]))
			return "faster punches"
		"ghost_feet":
			player.invulnerability_time = minf(player.invulnerability_time + step, float(entry["max"]))
			return "longer i-frames"
		"heavy_push":
			player.knockback_speed = minf(player.knockback_speed + step, float(entry["max"]))
			return "stronger knockback"
		"razor_dash":
			if "dash_damage" in player:
				player.dash_damage = mini(int(player.dash_damage + step), int(entry["max"]))
			return "+%d dash damage" % step
		"emerald_vigor":
			if "max_energy" in player:
				player.max_energy = minf(player.max_energy + step, float(entry["max"]))
				player.current_energy = player.max_energy
				player.energy_regen_per_sec += 6.0
				if player.has_signal("energy_changed"):
					player.energy_changed.emit(player.current_energy, player.max_energy)
			return "+%d Max Energy" % step
	return ""


static func _find(id: String) -> Dictionary:
	for entry in POOL:
		if entry["id"] == id:
			return entry
	return {}
