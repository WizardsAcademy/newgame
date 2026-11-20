extends Node
## Headless verification suite for the Skeleton Archer (Phases 7a/7b):
## the aim (telegraph) phase and its GROUND RISK LINE.
##
## Run it from the repo root with:
##
##   godot --headless --path . tests/archer_test.tscn
##
## Unlike combat_test.gd (which boots the whole Main scene), this suite
## builds a tiny world by hand: one real Archer + one FAKE player Node2D
## in the "player" group. The archer only needs `global_position` and
## `get("is_dead")` from the player, so a plain Node2D stands in fine.
## That keeps the test fast and immune to wave-spawner naming changes
## (see the Slime1/Slime_W1_1 drift combat_test suffered).
##
## The exit code is 0 only when every check passed.

var _failures: int = 0
var _checks: int = 0


func _check(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("PASS  ", label, ("  (" + detail + ")") if detail != "" else "")
	else:
		_failures += 1
		print("FAIL  ", label, ("  (" + detail + ")") if detail != "" else "")


func _check_eq(label: String, actual: Variant, expected: Variant) -> void:
	_check(label, actual == expected, "got %s, expected %s" % [str(actual), str(expected)])


func _tick(frames: int = 1) -> void:
	for i in frames:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _run() -> void:
	print("\n=== Archer (aim telegraph + risk line) ===\n")

	var archer_scene: PackedScene = load("res://scenes/enemies/Archer.tscn")

	# ----------------------------------------------------------------
	# 1. AIM STATE ENTERS AUTOMATICALLY WITH A RISK LINE
	# ----------------------------------------------------------------
	var world := Node2D.new()
	add_child(world)

	var fake_player := Node2D.new()
	fake_player.add_to_group("player")
	fake_player.position = Vector2(150, 0)   # inside shooting_distance (260)
	world.add_child(fake_player)

	var archer: CharacterBody2D = archer_scene.instantiate()
	world.add_child(archer)
	await _tick(3)

	_check("Archer entered AIM within shooting range",
		archer._attack_state == archer.AttackState.AIM,
		"state=%d" % archer._attack_state)
	_check("Risk line exists during aim", archer._aim_line != null)

	if archer._aim_line != null and archer._aim_line.points.size() == 2:
		var end_point: Vector2 = archer._aim_line.points[1]
		_check("Risk line aims toward the player (x > 0)", end_point.x > 0,
			"end=%s" % str(end_point))
		_check("Risk line is clamped to shooting_distance",
			end_point.length() <= archer.shooting_distance + 1.0,
			"len=%.1f" % end_point.length())
	else:
		_check_eq("Risk line has exactly 2 points", archer._aim_line.points.size(), 2)

	# ----------------------------------------------------------------
	# 2. THE LINE RE-AIMS EVERY FRAME (it never lies)
	# ----------------------------------------------------------------
	fake_player.position = Vector2(-100, 60)   # jump to the other side
	await _tick(3)

	if archer._aim_line != null and archer._aim_line.points.size() == 2:
		var reaimed: Vector2 = archer._aim_line.points[1]
		_check("Risk line re-aims toward the moved player (x < 0)", reaimed.x < 0,
			"end=%s" % str(reaimed))
	else:
		_check("Risk line still alive after player moved", false)

	# ----------------------------------------------------------------
	# 3. FIRING CONSUMES THE LINE AND SPAWNS THE ARROW
	# ----------------------------------------------------------------
	await _wait(0.9)   # aim_duration is 0.55; wait well past it so the
	                   # SHOOT frame has definitely happened (headless
	                   # timers drift a little against physics ticks)
	await _tick(5)

	_check("Risk line is gone after firing", archer._aim_line == null)
	_check("Archer is in COOLDOWN after firing",
		archer._attack_state == archer.AttackState.COOLDOWN,
		"state=%d" % archer._attack_state)

	var arrow: Area2D = null
	for child in world.get_children():
		if child != archer and child is Area2D and child.has_method("launch"):
			arrow = child
	_check("An arrow was spawned by firing", arrow != null)

	if arrow != null:
		_check("Arrow looks toward the last aim direction (x < 0)",
			arrow.global_position.x < archer.global_position.x + 20.0,
			"arrow at %s" % str(arrow.global_position))

	# ----------------------------------------------------------------
	# 4. PANIC EXHAUSTION - the guaranteed kill window
	# ----------------------------------------------------------------
	# Force a COOLDOWN state so the archer is free to flee (in REPOSITION
	# inside shooting range it would instantly re-aim instead).
	archer._attack_state = archer.AttackState.COOLDOWN
	archer._attack_timer = 3.0
	fake_player.position = Vector2(60, 0)   # closer than retreat_distance
	await _tick(2)

	var flee_speed: float = archer.velocity.length()
	_check("Fleeing is slowed to retreat_speed_factor",
		absf(flee_speed - archer.move_speed * archer.retreat_speed_factor) < 1.0,
		"flee=%.1f expected=%.1f" % [flee_speed, archer.move_speed * archer.retreat_speed_factor])

	archer._panic_time = archer.panic_exhaust_after   # panic fully built up
	await _tick(2)
	_check("Exhaustion window starts after fleeing too long",
		archer._exhausted > 0.0)
	_check("Exhausted archer stands still (no retreat)",
		archer.velocity.length() < 1.0, "v=%s" % str(archer.velocity))
	_check("Exhausted archer shows the grey tell",
		archer.visuals.modulate.r < 1.0,
		"modulate=%s" % str(archer.visuals.modulate))

	await _wait(1.4)   # longer than panic_exhausted_duration (1.2)
	await _tick(2)
	_check("Breath recovers: can flee/act again",
		archer._exhausted <= 0.0)
	_check("Grey tell clears after recovery",
		archer.is_dead or archer.visuals.modulate == Color.WHITE)

	# ----------------------------------------------------------------
	# 5. DYING MID-AIM KILLS THE LINE TOO
	# ----------------------------------------------------------------
	var fake_player2 := Node2D.new()
	fake_player2.add_to_group("player")
	fake_player2.position = Vector2(120, 0)
	world.add_child(fake_player2)

	var archer2: CharacterBody2D = archer_scene.instantiate()
	world.add_child(archer2)
	await _tick(3)
	_check("Second archer aimed", archer2._attack_state == archer2.AttackState.AIM)

	archer2.take_damage(999)   # one-shot: die while aiming
	await _tick(2)
	_check("Risk line is gone after death", archer2._aim_line == null)
	_check("Archer reported is_dead", archer2.is_dead)

	# ----------------------------------------------------------------
	# 6. ELITE ARCHER - 3x HP + golden ring + 3-arrow volley
	# ----------------------------------------------------------------
	var elite_world := Node2D.new()
	add_child(elite_world)

	var elite_player := Node2D.new()
	elite_player.add_to_group("player")
	elite_player.position = Vector2(150, 0)
	elite_world.add_child(elite_player)

	var elite_archer: CharacterBody2D = archer_scene.instantiate()
	elite_archer.become_elite()          # spawner calls this BEFORE add_child
	elite_world.add_child(elite_archer)
	await _tick(3)

	_check("Elite HP is 3x base (24 -> 72)", elite_archer.max_health == 72,
		"hp=%d" % elite_archer.max_health)
	var has_aura := false
	for child in elite_archer.get_children():
		if child is Line2D and child.points.size() >= 24:
			has_aura = true
	_check("Elite golden ring exists under the feet", has_aura)

	# Count arrows strictly around this one shot: snapshot before the
	# aim ends, compare after - earlier test arrows live in `world`,
	# this elite archer lives in `elite_world`, so nothing overlaps.
	var arrows_before := _count_children_arrows(elite_world)
	await _wait(0.9)   # aim_duration 0.55 + margin
	await _tick(5)
	var arrows_after := _count_children_arrows(elite_world)
	_check_eq("Elite volley spawns 3 arrows", arrows_after - arrows_before, 3)

	# ----------------------------------------------------------------
	print("\n%d/%d checks passed." % [_checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)


## How many "arrow" projectiles (Area2D with launch()) sit directly in a node.
func _count_children_arrows(container: Node) -> int:
	var count := 0
	for child in container.get_children():
		if child is Area2D and child.has_method("launch"):
			count += 1
	return count


func _ready() -> void:
	_run()
