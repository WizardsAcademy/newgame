extends Node
## Headless verification suite for Phase 2 (melee combat + Slime enemy).
##
## Run it from the repo root with:
##
##   godot --headless --path . tests/combat_test.tscn
##
## (tests/combat_test.tscn is just a Node with this script attached. The
## --script flag only works for SceneTree/MainLoop scripts, so a scene is
## the simplest way to boot a normal Node and still get our prints.)
## It boots the real Main scene (scenes/main.tscn), so it exercises the
## same nodes, scripts and collision layers the game uses. Every check
## prints PASS / FAIL and the process exit code is 0 only if all of them
## passed.
##
## The tests cover the Phase 2 checklist:
##   1. scene wiring  - Hitbox exists, starts disabled, 20x16 shape
##   2. attack flow   - input -> hitbox ON -> hitbox OFF, movement locked
##   3. damage math   - 30 HP / 10 damage = exactly 3 hits to kill
##   4. no multi-hit  - one swing never damages the same slime twice
##   5. enemy AI      - slime walks toward the player, stops at 24 px
##   6. death         - slime frees itself after its death animation

const MAIN_SCENE := "res://scenes/main.tscn"

var _failures: int = 0
var _checks: int = 0
var main: Node = null


func _ready() -> void:
	print("=== Phase 2 headless combat verification ===")
	_run()


# =====================================================================
# TINY ASSERT HELPERS
# =====================================================================

func _check(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("PASS  ", label, ("  (" + detail + ")") if detail != "" else "")
	else:
		_failures += 1
		print("FAIL  ", label, ("  (" + detail + ")") if detail != "" else "")


func _check_eq(label: String, actual: Variant, expected: Variant) -> void:
	_check(label, actual == expected, "got %s, expected %s" % [str(actual), str(expected)])


## Advance the game by `frames` physics ticks. `await` here keeps the
## engine's main loop running, which is what makes physics/timers work.
func _tick(frames: int = 1) -> void:
	for i in frames:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# =====================================================================
# THE TESTS
# =====================================================================

func _run() -> void:
	# -----------------------------------------------------------------
	# SETUP: load the real main scene as a child of this test node.
	# -----------------------------------------------------------------
	var packed: PackedScene = load(MAIN_SCENE)
	main = packed.instantiate()

	# Sample the spawn positions BEFORE the scene runs a single physics
	# frame: slimes start walking immediately when the player is close,
	# so one tick later "Slime1" is already a pixel off its spawn point.
	var spawn_positions: Array[Vector2] = []
	for child in main.get_node("Enemies").get_children():
		spawn_positions.append(child.position)

	add_child(main)
	await _tick(3)

	var player: CharacterBody2D = main.get_node("Player")
	var hitbox: Area2D = player.get_node("Hitbox")

	# ---------------------------------------------------------------
	# 1. SCENE WIRING
	# ---------------------------------------------------------------
	print("\n--- 1. Scene wiring ---")
	_check("Player has an AttackPoint marker", player.has_node("AttackPoint"))
	_check("Player has a Hitbox Area2D", hitbox != null)
	var hb_shape: CollisionShape2D = hitbox.get_node("CollisionShape2D")
	var rect: RectangleShape2D = hb_shape.shape as RectangleShape2D
	_check_eq("Hitbox shape size is 20x16", rect.size, Vector2(20, 16))
	_check("Hitbox starts with monitoring = false", hitbox.monitoring == false)
	_check("Hitbox starts with monitorable = false", hitbox.monitorable == false)
	_check_eq("Hitbox sits at the AttackPoint offset (12, 0)", hitbox.position, Vector2(12, 0))
	_check_eq("Player attack_damage is 10", player.attack_damage, 10)
	_check("Player is in the \"player\" group", player.is_in_group("player"))

	var slimes := _slimes(main)
	_check_eq("Main scene spawns 3 slimes", slimes.size(), 3)
	_check("Slimes spawn at (200,200) (600,400) (1000,300)",
		spawn_positions == [Vector2(200, 200), Vector2(600, 400), Vector2(1000, 300)],
		str(spawn_positions))
	for s in slimes:
		_check(s.name + " starts at 30/30 HP", s.current_health == 30 and s.max_health == 30)
		_check(s.name + " has a Hurtbox Area2D", s.has_node("Hurtbox"))
		_check(s.name + " has a HealthBar", s.has_node("HealthBar"))

	# ---------------------------------------------------------------
	# 2. ATTACK FLOW: input -> hitbox on -> hitbox off, movement locked
	# ---------------------------------------------------------------
	print("\n--- 2. Attack flow (simulated input) ---")
	# Park the player far from every slime so this part is only about
	# the swing itself.
	player.global_position = Vector2(640, 620)
	await _tick(2)

	_check_eq("Not attacking before input", player.is_attacking, false)

	# Send a real InputEvent through the input pipeline, exactly like
	# pressing Space would.
	var press := InputEventAction.new()
	press.action = "attack"
	press.pressed = true
	Input.parse_input_event(press)
	await _tick(1)
	Input.flush_buffered_events()
	await _tick(1)

	_check_eq("Attack started by \"attack\" input", player.is_attacking, true)
	_check_eq("Attack animation is playing", player.get_node("AnimPlayer").current_animation, "attack")
	_check("Hitbox still OFF during the wind-up", hitbox.monitoring == false)

	# Wait past the 0.05 s wind-up: the hitbox must be ON now.
	await _wait(0.07)
	_check("Hitbox ON ~0.05 s into the swing", hitbox.monitoring == true)

	# ... and the punch pose (animation frame 1) must be on screen.
	var punch_fx: Sprite2D = player.get_node("Visuals/PunchFx")
	var frame_one: AtlasTexture = punch_fx.texture as AtlasTexture
	_check("Punch pose is visible during the hit window", punch_fx.visible == true)
	_check("Sprite switched to animation frame 1",
		(player.get_node("Visuals").texture as AtlasTexture).region == Rect2(16, 0, 16, 16),
		str((player.get_node("Visuals").texture as AtlasTexture).region))

	# Movement lock: hold "move_right" during the swing, the player
	# must not move.
	var start_pos: Vector2 = player.global_position
	Input.action_press("move_right")
	await _tick(3)
	var moved := absf(player.global_position.x - start_pos.x)
	Input.action_release("move_right")
	_check("Movement locked while attacking", moved < 0.5, "moved %.2f px" % moved)

	# After 0.15 s the hitbox must be off again, and the punch pose gone.
	await _wait(0.14)
	_check("Hitbox OFF after ~0.1 s active window", hitbox.monitoring == false)
	_check("Punch pose is hidden again after 0.1 s", punch_fx.visible == false,
		"played on %s" % str(frame_one.atlas.resource_path))
	_check("Sprite is back to animation frame 0",
		(player.get_node("Visuals").texture as AtlasTexture).region == Rect2(0, 0, 16, 16),
		str((player.get_node("Visuals").texture as AtlasTexture).region))

	# And after the full 0.2 s swing the lock is released.
	await _wait(0.1)
	_check_eq("Attack lock released after 0.2 s", player.is_attacking, false)

	# ---------------------------------------------------------------
	# 3. DAMAGE MATH: 3 hits of 10 damage kill a 30 HP slime
	# ---------------------------------------------------------------
	print("\n--- 3. Damage: 30 HP / 10 damage = 3 hits ---")
	var target: CharacterBody2D = _slime_named(main, "Slime1")
	# Turn the AI off for this test by parking the player outside the
	# detection range: the slime must not chase while we measure.
	_check_eq("Slime1 full health", target.current_health, 30)

	# Stand right next to the slime, facing right, and punch it.
	_place_for_hit(player, target)
	await _tick(2)

	var hit_signal_payload: Array = []
	player.attack_hit.connect(func(enemy): hit_signal_payload.append(enemy))

	# Start the swing and sample the feedback while it is still on screen:
	# the flash lasts 0.1 s and the spark 0.15 s, both starting ~0.08 s in.
	player._start_attack()
	await _wait(player.attack_windup + 0.05)
	_check_eq("After hit 1: 30 - 10 = 20 HP", target.current_health, 20)
	_check_eq("Health bar value follows the health", target.get_node("HealthBar").value, 20.0)
	_check("attack_hit signal fired once", hit_signal_payload.size() == 1)
	if hit_signal_payload.size() == 1:
		_check("attack_hit carries the enemy that was hit", hit_signal_payload[0] == target)
	_check("Slime flashed white after the hit",
		target.get_node("Visuals").self_modulate == Color(1, 1, 1, 1),
		str(target.get_node("Visuals").self_modulate))
	_check("A hit spark was spawned", _count_hit_sparks(main) >= 1)

	# The flash must wear off again (back to the slime's own green).
	await _wait(player.attack_duration)
	_check("White flash ends after 0.1 s",
		target.get_node("Visuals").self_modulate == target.body_color,
		str(target.get_node("Visuals").self_modulate))
	_check("Hit sparks clean themselves up", _count_hit_sparks(main) == 0)
	_place_for_hit(player, target)
	await _punch(player)
	_check_eq("After hit 2: 20 - 10 = 10 HP", target.current_health, 10)
	_check_eq("Health bar value follows the health", target.get_node("HealthBar").value, 10.0)

	await _wait(player.attack_duration + 0.1)
	_place_for_hit(player, target)
	# Slime1 cannot fight back, but it DOES chase: while we line up the
	# next punch it may wander back into range on its own. Read the result
	# before the corpse frees itself (0.3 s after the killing blow).
	player._start_attack()
	await _wait(player.attack_windup + 0.08)
	_check_eq("After hit 3: 10 - 10 = 0 HP", target.current_health, 0)
	_check("Slime is dead after 3 hits", target.is_dead == true)
	await _wait(player.attack_duration)

	# ---------------------------------------------------------------
	# 6. DEATH: the node frees itself after death_duration
	# ---------------------------------------------------------------
	print("\n--- 6. Death and queue_free() ---")
	_check("Slime still exists during the death animation", is_instance_valid(target))
	await _wait(0.5)
	_check("Slime was freed 0.3 s after dying", not is_instance_valid(target))
	var slime_count_now := _slimes(main).size()
	_check_eq("2 slimes left in the arena", slime_count_now, 2)

	# ---------------------------------------------------------------
	# 4. NO MULTI-HIT: one swing = one damage instance per enemy
	# ---------------------------------------------------------------
	print("\n--- 4. One swing cannot hit the same slime twice ---")
	var second: CharacterBody2D = _slime_named(main, "Slime2")
	_place_for_hit(player, second)
	await _tick(2)
	await _punch(player)
	_check_eq("One full swing removed exactly 10 HP", second.current_health, 20)

	# ---------------------------------------------------------------
	# 5. ENEMY AI: chases when in range, stops at 24 px
	# ---------------------------------------------------------------
	print("\n--- 5. Slime AI ---")
	var third: CharacterBody2D = _slime_named(main, "Slime3")

	# (a) Player far away (> 200 px): slime must stay put.
	player.global_position = third.global_position + Vector2(400, 0)
	await _tick(2)
	var far_start: Vector2 = third.global_position
	await _wait(0.25)
	_check("Slime idles when the player is out of range (>200 px)",
		third.global_position.distance_to(far_start) < 1.0,
		"drifted %.2f px" % third.global_position.distance_to(far_start))

	# (b) Player 150 px away: slime must crawl toward them at ~40 px/s.
	third.current_health = 30  # keep it alive for this test
	player.global_position = third.global_position + Vector2(150, 0)
	await _tick(2)
	var chase_start: Vector2 = third.global_position
	var dist_before := third.global_position.distance_to(player.global_position)
	await _wait(0.5)
	var dist_after := third.global_position.distance_to(player.global_position)
	var travelled := third.global_position.distance_to(chase_start)
	_check("Slime moves toward the player when within 200 px",
		third.global_position.x > chase_start.x + 5.0, "moved %.2f px" % travelled)
	_check("Slime is closing the distance", dist_after < dist_before - 5.0,
		"%.1f -> %.1f px" % [dist_before, dist_after])
	_check("Slime speed is about 40 px/s (30-50 px in 0.5 s)",
		travelled > 12.0 and travelled < 28.0, "%.2f px" % travelled)

	# (c) Slime must stop once adjacent (within 24 px).
	# From 150 px at 40 px/s that takes (150-24)/40 = 3.15 s, so wait a
	# little longer than that.
	await _wait(3.6)
	var final_dist := third.global_position.distance_to(player.global_position)
	_check("Slime stops at ~24 px from the player",
		final_dist <= 26.0, "final distance %.2f px" % final_dist)
	var stopped_at: Vector2 = third.global_position
	await _wait(0.4)
	_check("Slime does not keep pushing once adjacent",
		third.global_position.distance_to(stopped_at) < 2.0,
		"drifted %.2f px" % third.global_position.distance_to(stopped_at))

	# ---------------------------------------------------------------
	# 6b. SIGNAL WIRING: the HUD listens to attack_hit / died
	# ---------------------------------------------------------------
	print("\n--- 6b. Signal-based HUD ---")
	var stats_label: Label = main.get_node("UI/Stats")
	# Slime2 (20 HP) and Slime3 are alive; total damage so far is 30
	# (three hits on Slime1) + 10 (one hit on Slime2) = 40.
	_check("HUD counted the damage dealt so far", main.total_damage_dealt == 40,
		"label says: " + stats_label.text)
	_check("HUD recorded the last hit damage", main.last_hit_damage == 10)
	# Slime1 really died earlier and its `died` signal was heard by the
	# level without the player or the slime knowing the HUD exists.
	_check("HUD counted the real kill from the died signal", main.kills == 1,
		stats_label.text)
	main._on_enemy_died()
	_check("HUD kill counter increments on the died signal", main.kills == 2,
		stats_label.text)

	# ---------------------------------------------------------------
	# 7. Regression: Phase 1 still works
	# ---------------------------------------------------------------
	print("\n--- 7. Phase 1 regression ---")
	player.is_attacking = false
	var walk_start: Vector2 = player.global_position
	Input.action_press("move_right")
	await _tick(10)
	Input.action_release("move_right")
	_check("Player still walks (Phase 1 movement intact)",
		player.global_position.x > walk_start.x + 5.0,
		"moved %.2f px" % (player.global_position.x - walk_start.x))
	_check("Walk animation still switches",
		player.get_node("AnimPlayer").current_animation != "attack")

	# ---------------------------------------------------------------
	# SUMMARY
	# ---------------------------------------------------------------
	print("\n=== %d checks, %d failed ===" % [_checks, _failures])
	if _failures == 0:
		print("RESULT: ALL TESTS PASSED")
	else:
		print("RESULT: FAILURES PRESENT")
	get_tree().quit(0 if _failures == 0 else 1)


# =====================================================================
# TEST UTILITIES
# =====================================================================

func _slimes(root: Node) -> Array:
	var result: Array = []
	for node in root.get_tree().get_nodes_in_group("enemies"):
		result.append(node)
	return result


func _slime_named(root: Node, node_name: String) -> CharacterBody2D:
	var path := "Enemies/" + node_name
	if root.has_node(path):
		return root.get_node(path)
	return null


func _count_hit_sparks(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if child.name.begins_with("HitSpark") or child.get_script() == preload("res://scripts/fx/hit_spark.gd"):
			count += 1
	return count


## Put the player 18 px to the LEFT of the slime, facing right, so the
## hitbox (which sticks out 12 px on the facing side) overlaps the
## slime's Hurtbox (9 px half-width).
func _place_for_hit(player: CharacterBody2D, enemy: CharacterBody2D) -> void:
	player.global_position = enemy.global_position + Vector2(-18, 0)
	player.facing = 1.0
	player.get_node("Visuals").scale.x = 1.0
	player.get_node("Hitbox").position.x = 12.0


## Simulate one full attack and wait for it to finish.
## (One extra physics frame is added for the overlap fallback check.)
func _punch(player: CharacterBody2D) -> void:
	player._start_attack()
	await player.get_tree().create_timer(player.attack_duration + 0.15).timeout
	# Make sure the hitbox really is back off between punches.
	await _tick(2)
