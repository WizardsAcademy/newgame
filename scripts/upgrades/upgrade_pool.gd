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
		"title": "مشت آهنی",
		"desc": "+5 دمیج مشت",
		"min": 1, "max": 100, "step": 5,
	},
	{
		"id": "extra_hp",
		"title": "جن‌گیر",
		"desc": "+15 جان بیشینه (و ۱۵ جان الان)",
		"min": 25, "max": 250, "step": 15,
	},
	{
		"id": "swift_hooves",
		"title": "سُمِ تند",
		"desc": "+8 سرعت حرکت",
		"min": 90, "max": 220, "step": 8,
	},
	{
		"id": "quick_hands",
		"title": "دستِ تند",
		"desc": "پانچ سریع‌تر (-0.06 ثانیه)",
		"min": 0.18, "max": 0.45, "step": 0.06,
	},
	{
		"id": "ghost_feet",
		"title": "پای شبح",
		"desc": "+0.15 ثانیه بی‌مرگی بعد از ضربه خوردن",
		"min": 0.8, "max": 2.0, "step": 0.15,
	},
	{
		"id": "heavy_push",
		"title": "شانه‌ی سنگین",
		"desc": "nock‌بک مشت +45 (دشمن‌ها دورتر پرت می‌شوند)",
		"min": 180, "max": 500, "step": 45,
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
	return ""


static func _find(id: String) -> Dictionary:
	for entry in POOL:
		if entry["id"] == id:
			return entry
	return {}
