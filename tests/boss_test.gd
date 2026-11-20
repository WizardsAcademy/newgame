extends Node
## Headless verification suite for the FIRST BOSS: Forest Colossus.
##
## Run it from the repo root with:
##
##   godot --headless --path . tests/boss_test.tscn
##
## Builds a tiny world: one real Colossus + a scripted fake player
## (tests/fake_player.gd) that records hits. Covers the Phase 8 DoD
## mechanics: the three attack phases (SLAM / SWEEP / ROOTS), their
## telegraphs, the enrage flip, and death. Exit code 0 = all passed.

const FAKE_PLAYER := preload("res://tests/fake_player.gd")

var _failures: int = 0
var _checks: int = 0
var _boss_died: bool = false


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
	print("\n=== Forest Colossus (Phase 8 boss) ===\n")

	var world := Node2D.new()
	add_child(world)

	# The fake player starts FAR (150 px): any closer and the very first
	# physics frame already flips the boss into a SLAM telegraph before
	# section 2 ever gets a say - that ordering bug cost us a test run.
	var fake_player: Node2D = FAKE_PLAYER.new()
	fake_player.add_to_group("player")
	fake_player.position = Vector2(150, 0)
	world.add_child(fake_player)

	var boss: CharacterBody2D = load("res://scenes/enemies/Colossus.tscn").instantiate()
	boss.died.connect(func() -> void: _boss_died = true)
	world.add_child(boss)
	await _tick(3)

	# ----------------------------------------------------------------
	# 1. BASE STATS / WIRING
	# ----------------------------------------------------------------
	_check_eq("Boss base HP is 400", boss.max_health, 400)
	_check_eq("Health bar is boss-wide (56x6)", boss.health_bar.bar_size, Vector2(56, 6))
	_check("Boss starts NOT enraged", boss.is_enraged == false)

	# ----------------------------------------------------------------
	# 2. FAR PLAYER -> ROOTS (the ranged threat)
	# ----------------------------------------------------------------
	_check("Boss casts ROOTS at a far player",
		boss._state == boss.ColossusState.TELEGRAPH
		and boss._current_attack == boss.BossAttack.ROOTS,
		"state=%d attack=%d" % [boss._state, boss._current_attack])
	_check_eq("Roots target = the player's spot",
		boss._roots_target, Vector2(150, 0))

	var ring_found := false
	for child in world.get_children():
		if child is Line2D and child.get_parent() == world:
			ring_found = true
	_check("Red roots ring painted in the arena", ring_found)

	await _wait(1.2)   # roots_telegraph 0.9 + margin
	await _tick(2)
	_check_eq("Roots caught the standing player", fake_player.hit_count, 1)
	_check_eq("Roots damage is 12", fake_player.last_damage, 12)
	_check("Roots ring is consumed after the burst", boss._roots_ring == null)

	# ----------------------------------------------------------------
	# 3. CLOSE PLAYER -> melee strikes alternate SLAM / SWEEP
	# ----------------------------------------------------------------
	fake_player.position = Vector2(50, 0)
	# Let the leftover roots RECOVER (0.4) + COOLDOWN (0.4) run out.
	await _wait(1.1)
	var melee_check_done := await _wait_for_state(boss,
		boss.ColossusState.TELEGRAPH, 2.0)
	_check("Close player -> melee telegraph",
		melee_check_done and (boss._current_attack == boss.BossAttack.SLAM
			or boss._current_attack == boss.BossAttack.SWEEP),
		"attack=%d" % boss._current_attack)

	var first_attack: int = boss._current_attack
	var strike_area: Area2D = boss.slam_area if first_attack == boss.BossAttack.SLAM \
		else boss.sweep_area
	var other_area: Area2D = boss.sweep_area if first_attack == boss.BossAttack.SLAM \
		else boss.slam_area

	# Poll for the strike window: it is live for only ~0.08 s, so a
	# fixed wait would miss it. 0.02 s steps catch it (up to 2 s).
	var saw_live := false
	for i in 100:
		if strike_area.monitoring:
			saw_live = true
			break
		await get_tree().create_timer(0.02).timeout
	await _tick(1)
	_check("The strike area went LIVE in its window", saw_live)
	_check("The OTHER area stays asleep", other_area.monitoring == false)

	# After the strike: the punish window. Poll for RECOVER, then check
	# the timer is in the right ballpark for THIS attack.
	await _wait_for_state(boss, boss.ColossusState.RECOVER, 1.0)
	var expected_recover: float = boss.slam_recover if first_attack == boss.BossAttack.SLAM \
		else boss.sweep_recover
	_check("After the strike comes the punish window (RECOVER)",
		boss._state == boss.ColossusState.RECOVER
		and boss._timer > expected_recover * 0.5,
		"timer=%.2f expected>%.2f" % [boss._timer, expected_recover * 0.5])

	# ----------------------------------------------------------------
	# 4. ENRAGE at 25% HP (below the 30% line)
	# ----------------------------------------------------------------
	boss.take_damage(310)   # 400 -> 90 = 22.5%
	await _tick(2)
	_check("Boss flips ENRAGED below 30% HP", boss.is_enraged)
	_check("Enrage speeds up movement",
		absf(boss.move_speed - 26.0 * boss.enrage_speed_factor) < 0.1,
		"speed=%.1f" % boss.move_speed)
	_check("Enrage telegraphs get shorter",
		absf(boss._attack_telegraph_time(boss.BossAttack.SLAM)
			- boss.slam_telegraph * boss.enrage_telegraph_factor) < 0.01)

	# ----------------------------------------------------------------
	# 5. DEATH
	# ----------------------------------------------------------------
	boss.take_damage(999)
	await _tick(2)
	_check("Boss reports death", boss.is_dead and _boss_died)

	print("\n%d/%d checks passed." % [_checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)


func _ready() -> void:
	_run()


## Poll until the boss reaches `wanted_state` (helper for timing that
## must not be frame-exact). Returns true if seen within `timeout` s.
func _wait_for_state(boss: CharacterBody2D, wanted_state: int, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if boss._state == wanted_state:
			return true
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05
	return false
