extends Node
## Headless verification suite for melee combat + Slime enemy + Main signal wiring.
##
## Run it from the repo root with:
##
##   godot --headless --path . tests/combat_test.tscn
##
## Boots the real Main scene (`scenes/main.tscn`) with Behemoth (`1536x96` hero
## sheet, `Visuals.scale = Vector2(0.5, 0.5)`), enters the Arena with wave
## spawning paused, and spawns 3 controlled Slimes (`Slime1`, `Slime2`, `Slime3`)
## to verify:
##   1. scene wiring  - Hitbox exists, starts disabled, 26x20 shape at (18, 0)
##   2. attack flow   - input -> windup -> hitbox ON -> hitbox OFF, movement locked
##   3. damage math   - 30 HP slime: Jab (18 DMG -> 12 HP) + Cross (21 DMG -> 0 HP)
##   4. no multi-hit  - one swing never damages the same slime twice
##   5. enemy AI      - slime idles >200 px, chases <200 px, stops at ~24 px
##   6. death & HUD   - slime frees itself after death; Main tracks damage & kills

const MAIN_SCENE := "res://scenes/main.tscn"
const SLIME_SCENE := preload("res://scenes/enemies/Slime.tscn")

var _failures: int = 0
var _checks: int = 0
var main: Node = null


func _ready() -> void:
	print("=== Headless combat verification ===")
	_run()


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
	CharacterRegistry.selected_id = "behemoth"
	CharacterRegistry.quick_retry_same_hero = false

	var packed: PackedScene = load(MAIN_SCENE)
	main = packed.instantiate()
	add_child(main)
	await get_tree().process_frame
	await _tick(3)

	# Switch into the classic 1280x720 Arena (`SANDBOX`), pause WaveSpawner,
	# clear random spawns, and place 3 deterministic Slimes with normal 200px sight.
	main.enter_sandbox()
	await get_tree().process_frame
	main.wave_spawner.stop_spawning()
	main._clear_combat_enemies()
	await _tick(3)

	var enemies_root: Node2D = main.get_node("Enemies")
	var desired_spawns: Array[Vector2] = [Vector2(200, 200), Vector2(600, 400), Vector2(1000, 300)]
	for i in range(desired_spawns.size()):
		var s: CharacterBody2D = SLIME_SCENE.instantiate()
		s.name = "Slime%d" % (i + 1)
		s.variant_id = "grass"
		s.position = desired_spawns[i]
		enemies_root.add_child(s)
		s.detection_range = 200.0
		main._watch_enemy(s)

	var player: CharacterBody2D = main.get_node("Player")
	player.global_position = Vector2(640, 650)
	await _tick(2)

	var hitbox: Area2D = player.get_node("Hitbox")

	# ---------------------------------------------------------------
	# 1. SCENE WIRING
	# ---------------------------------------------------------------
	print("\n--- 1. Scene wiring ---")
	_check("Player has an AttackPoint marker", player.has_node("AttackPoint"))
	_check("Player has a Hitbox Area2D", hitbox != null)
	var hb_shape: CollisionShape2D = hitbox.get_node("CollisionShape2D")
	var rect: RectangleShape2D = hb_shape.shape as RectangleShape2D
	_check_eq("Hitbox shape size is 26x20", rect.size, Vector2(26, 20))
	_check("Hitbox starts with monitoring = false", hitbox.monitoring == false)
	_check("Hitbox starts with monitorable = false", hitbox.monitorable == false)
	_check_eq("Hitbox sits at the AttackPoint offset (18, 0)", hitbox.position, Vector2(18, 0))
	_check_eq("Behemoth attack_damage is 18", player.attack_damage, 18)
	_check("Player is in the \"player\" group", player.is_in_group("player"))
	_check("PunchFx full-body overlay sprite removed", not player.has_node("Visuals/PunchFx"))

	var visuals_node: Sprite2D = player.get_node("Visuals")
	_check_eq("Hero Visuals.scale is Vector2(0.5, 0.5)",
		Vector2(absf(visuals_node.scale.x), visuals_node.scale.y), Vector2(0.5, 0.5))
	var sheet_tex: Texture2D = (visuals_node.texture as AtlasTexture).atlas
	_check_eq("Behemoth sprite sheet is 1024x64 (16 frames)",
		sheet_tex.get_size(), Vector2(1024, 64))

	var anim_player: AnimationPlayer = player.get_node("AnimPlayer")
	var idle_anim: Animation = anim_player.get_animation("idle")
	var walk_anim: Animation = anim_player.get_animation("walk")
	var attack_anim: Animation = anim_player.get_animation("attack")
	_check_eq("Idle animation uses frame 0 (0,0,64,64)",
		(idle_anim.track_get_key_value(0, 0) as AtlasTexture).region, Rect2(0, 0, 64, 64))
	_check("Walk animation uses frames 1 and 2 (64x64 cells)",
		walk_anim.track_get_key_count(0) == 2
		and (walk_anim.track_get_key_value(0, 0) as AtlasTexture).region == Rect2(64, 0, 64, 64)
		and (walk_anim.track_get_key_value(0, 1) as AtlasTexture).region == Rect2(128, 0, 64, 64))
	_check_eq("Attack animation has loop disabled", attack_anim.loop_mode, Animation.LOOP_NONE)
	_check("Attack animation keys: windup f3 @ 0.0s, jab f4 @ 0.14s, idle f0 @ 0.33s",
		attack_anim.track_get_key_count(0) == 3
		and (attack_anim.track_get_key_value(0, 0) as AtlasTexture).region == Rect2(192, 0, 64, 64)
		and (attack_anim.track_get_key_value(0, 1) as AtlasTexture).region == Rect2(256, 0, 64, 64)
		and (attack_anim.track_get_key_value(0, 2) as AtlasTexture).region == Rect2(0, 0, 64, 64))

	var slimes := _slimes(main)
	_check_eq("Arena holds 3 test slimes", slimes.size(), 3)
	for s in slimes:
		_check(s.name + " starts at 30/30 HP", s.current_health == 30 and s.max_health == 30)
		_check(s.name + " has a Hurtbox Area2D", s.has_node("Hurtbox"))
		_check(s.name + " has a HealthBar", s.has_node("HealthBar"))
		_check(s.name + " has HitSFX and DeathSFX AudioStreamPlayers on SFX bus",
			s.has_node("HitSFX") and s.has_node("DeathSFX")
			and (s.get_node("HitSFX") as AudioStreamPlayer).bus == &"SFX"
			and (s.get_node("DeathSFX") as AudioStreamPlayer).bus == &"SFX"
			and (s.get_node("HitSFX") as AudioStreamPlayer).stream is AudioStreamWAV
			and (s.get_node("DeathSFX") as AudioStreamPlayer).stream is AudioStreamWAV)

	var art_slime: CharacterBody2D = slimes[0]
	var slime_visuals: Node2D = art_slime.get_node("Visuals")
	var slime_body: Sprite2D = slime_visuals.get_node("Body")
	_check("Slime body is the 12-pose x 4-variant family sheet (384x256)",
		slime_body.hframes == 12 and slime_body.vframes == 8
		and slime_body.texture.get_size() == Vector2(384, 256))
	_check("Slime has a soft ground shadow and a goo puddle",
		slime_visuals.has_node("Shadow") and slime_visuals.has_node("Puddle"))
	_check("Slime shows a coloured pose, never the white flash row at spawn",
		(slime_body.frame % 24) < 12 and not slime_visuals.is_flashing())

	# ---------------------------------------------------------------
	# 1b. AUTOLOADS & SFX BUS
	# ---------------------------------------------------------------
	print("\n--- 1b. Autoloads & SFX bus ---")
	var root_vp := get_tree().root
	_check("ScreenShake autoload singleton exists and is registered",
		root_vp.has_node("ScreenShake") and ScreenShake != null)
	_check("HitStop autoload singleton exists and is registered",
		root_vp.has_node("HitStop") and HitStop != null)
	var sfx_bus_idx := AudioServer.get_bus_index("SFX")
	_check("Audio bus \"SFX\" exists in AudioServer", sfx_bus_idx >= 1)
	_check("Player has PunchSFX AudioStreamPlayer on SFX bus",
		player.has_node("PunchSFX")
		and (player.get_node("PunchSFX") as AudioStreamPlayer).bus == &"SFX"
		and (player.get_node("PunchSFX") as AudioStreamPlayer).stream is AudioStreamWAV)
	_check("Player has FootstepSFX AudioStreamPlayer on SFX bus",
		player.has_node("FootstepSFX")
		and (player.get_node("FootstepSFX") as AudioStreamPlayer).bus == &"SFX"
		and (player.get_node("FootstepSFX") as AudioStreamPlayer).stream is AudioStreamWAV)

	# ---------------------------------------------------------------
	# 2. ATTACK FLOW: input -> hitbox on -> hitbox off, movement locked
	# ---------------------------------------------------------------
	print("\n--- 2. Attack flow (simulated input) ---")
	player.global_position = Vector2(640, 650)
	player._combo_step = 0
	await _tick(2)

	_check_eq("Not attacking before input", player.is_attacking, false)

	var press := InputEventAction.new()
	press.action = "attack"
	press.pressed = true
	Input.parse_input_event(press)
	await _tick(1)
	Input.flush_buffered_events()
	await _tick(1)
	var rel := InputEventAction.new()
	rel.action = "attack"
	rel.pressed = false
	Input.parse_input_event(rel)
	Input.flush_buffered_events()

	_check_eq("Attack started by \"attack\" input", player.is_attacking, true)
	_check_eq("Attack animation is playing", player.get_node("AnimPlayer").current_animation, "attack")
	_check("Hitbox still OFF during the wind-up", hitbox.monitoring == false)
	var punch_sfx: AudioStreamPlayer = player.get_node("PunchSFX")
	var slime1_check: CharacterBody2D = _slime_named(main, "Slime1")
	_check("Punch SFX plays immediately on attack start", punch_sfx.playing == true)
	_check("Hit SFX does NOT play on empty-air swing",
		(slime1_check.get_node("HitSFX") as AudioStreamPlayer).playing == false)

	# Past the 0.14 s wind-up, hitbox turns ON and frame 4 (jab) is shown.
	await _wait(0.18)
	_check("Hitbox ON during active strike window", hitbox.monitoring == true)
	var cam: Camera2D = player.get_node("Camera2D")
	var active_region: Rect2 = (visuals_node.texture as AtlasTexture).region
	_check_eq("Visuals texture region equals jab frame (frame 4) during attack",
		active_region, Rect2(256, 0, 64, 64))
	_check_eq("No impact spark spawned during empty-air swing", _count_hit_sparks(main), 0)

	var start_pos: Vector2 = player.global_position
	Input.action_press("move_right")
	await _tick(3)
	var moved := absf(player.global_position.x - start_pos.x)
	Input.action_release("move_right")
	_check("Movement locked while attacking", moved < 0.5, "moved %.2f px" % moved)

	await _wait(0.16)
	_check("Hitbox OFF after active window", hitbox.monitoring == false)

	await _wait(0.16)
	_check_eq("Attack lock released after swing completes", player.is_attacking, false)
	_check_eq("Sprite returns to frame 0",
		(visuals_node.texture as AtlasTexture).region, Rect2(0, 0, 64, 64))

	# Verify ScreenShake additive stacking + max_intensity clamp directly.
	ScreenShake.shake(2.0, 0.06)
	var single_amp := ScreenShake.get_current_intensity()
	ScreenShake.shake(3.0, 0.06)
	var stacked_amp := ScreenShake.get_current_intensity()
	_check("ScreenShake stacks overlapping shakes additively",
		stacked_amp > single_amp + 2.0,
		"single=%.2f stacked=%.2f" % [single_amp, stacked_amp])
	ScreenShake.shake(20.0, 0.06)
	_check("ScreenShake clamps stacked intensity to max_intensity",
		ScreenShake.get_current_intensity() <= ScreenShake.max_intensity + 0.001)
	await _wait(0.15)
	_check_eq("Camera2D offset resets to zero after stacked shake", cam.offset, Vector2.ZERO)

	# ---------------------------------------------------------------
	# 3. DAMAGE MATH: Jab (18 DMG) + Cross (21 DMG) kill a 30 HP slime
	# ---------------------------------------------------------------
	print("\n--- 3. Damage: 30 HP slime (Jab 18 + Cross 21) ---")
	var target: CharacterBody2D = _slime_named(main, "Slime1")
	_check_eq("Slime1 full health", target.current_health, 30)

	player._combo_step = 0
	_place_for_hit(player, target)
	await _tick(2)

	var hit_signal_payload: Array = []
	var hit_moment_samples := {
		"time_scale": 1.0,
		"hit_sfx_playing": false,
		"death_sfx_playing": false,
	}
	player.attack_hit.connect(func(enemy):
		hit_signal_payload.append(enemy)
		if hit_signal_payload.size() == 1:
			hit_moment_samples["time_scale"] = Engine.time_scale
			hit_moment_samples["hit_sfx_playing"] = (enemy.get_node("HitSFX") as AudioStreamPlayer).playing
			hit_moment_samples["death_sfx_playing"] = (enemy.get_node("DeathSFX") as AudioStreamPlayer).playing
	)

	player._start_attack()
	await _wait(player.attack_windup + 0.06)
	_check_eq("After hit 1 (Jab 18 DMG): 30 - 18 = 12 HP", target.current_health, 12)
	_check_eq("Health bar value follows the health", target.get_node("HealthBar").value, 12.0)
	_check("attack_hit signal fired once", hit_signal_payload.size() == 1)
	_check("Engine.time_scale drops during HitStop freeze on hit",
		float(hit_moment_samples["time_scale"]) < 0.2,
		"time_scale=%.3f" % float(hit_moment_samples["time_scale"]))
	_check("Hit SFX plays on successful enemy hit",
		bool(hit_moment_samples["hit_sfx_playing"]) == true)
	_check("Death SFX does NOT play on non-lethal hit",
		bool(hit_moment_samples["death_sfx_playing"]) == false)
	_check("A hit spark was spawned", _count_hit_sparks(main) >= 1)

	await _wait(player.attack_duration)
	_check("Engine.time_scale restores to 1.0 after HitStop",
		is_equal_approx(Engine.time_scale, 1.0))

	_place_for_hit(player, target)
	await _tick(2)
	var death_sfx_played_on_kill := [false]
	target.died.connect(func():
		death_sfx_played_on_kill[0] = (target.get_node("DeathSFX") as AudioStreamPlayer).playing
	)
	player._start_attack()
	await _wait(player.attack_windup + 0.08)
	_check_eq("After hit 2 (Cross 21 DMG): 12 -> 0 HP", target.current_health, 0)
	_check("Slime is dead after 2 combo hits", target.is_dead == true)
	_check("Death SFX plays when slime health reaches 0", death_sfx_played_on_kill[0] == true)
	await _wait(player.attack_duration)

	# ---------------------------------------------------------------
	# 6. DEATH: the node frees itself after death_duration
	# ---------------------------------------------------------------
	print("\n--- 6. Death and queue_free() ---")
	await _wait(0.55)
	_check("Slime was freed after dying", not is_instance_valid(target))
	_check_eq("2 slimes left in the arena", _slimes(main).size(), 2)

	# ---------------------------------------------------------------
	# 4. NO MULTI-HIT: one swing = one damage instance per enemy
	# ---------------------------------------------------------------
	print("\n--- 4. One swing cannot hit the same slime twice ---")
	var second: CharacterBody2D = _slime_named(main, "Slime2")
	player._combo_step = 0
	_place_for_hit(player, second)
	await _tick(2)
	await _punch(player)
	_check_eq("One full Jab swing removed exactly 18 HP (30 -> 12)", second.current_health, 12)

	# ---------------------------------------------------------------
	# 5. ENEMY AI: chases when in range, stops at ~24 px
	# ---------------------------------------------------------------
	print("\n--- 5. Slime AI ---")
	var third: CharacterBody2D = _slime_named(main, "Slime3")

	player.global_position = third.global_position + Vector2(-400, 0)
	await _tick(2)
	var far_start: Vector2 = third.global_position
	await _wait(0.25)
	_check("Slime idles when the player is out of range (>200 px)",
		third.global_position.distance_to(far_start) < 1.0,
		"drifted %.2f px" % third.global_position.distance_to(far_start))

	third.current_health = 30
	player.global_position = third.global_position + Vector2(-150, 0)
	await _tick(2)
	var chase_start: Vector2 = third.global_position
	var dist_before := third.global_position.distance_to(player.global_position)
	await _wait(0.5)
	var dist_after := third.global_position.distance_to(player.global_position)
	var travelled := third.global_position.distance_to(chase_start)
	_check("Slime moves toward the player when within 200 px",
		travelled > 8.0, "moved %.2f px" % travelled)
	_check("Slime is closing the distance", dist_after < dist_before - 5.0,
		"%.1f -> %.1f px" % [dist_before, dist_after])

	await _wait(3.6)
	var final_dist := third.global_position.distance_to(player.global_position)
	_check("Slime stops near the player (~24 px)",
		final_dist <= 32.0, "final distance %.2f px" % final_dist)

	# ---------------------------------------------------------------
	# 6b. SIGNAL WIRING: Main tracks damage dealt and kills
	# ---------------------------------------------------------------
	print("\n--- 6b. Signal-based stats on Main ---")
	# Total dealt: 18 (Jab) + 21 (Cross) on Slime1 + 18 (Jab) on Slime2 = 57
	_check_eq("Main counted total damage dealt (18 + 21 + 18 = 57)", main.total_damage_dealt, 57)
	_check_eq("Main recorded last hit damage (18)", main.last_hit_damage, 18)
	_check_eq("Main counted the real kill from the died signal", main.kills, 1)

	# ---------------------------------------------------------------
	# 7. Movement + footsteps
	# ---------------------------------------------------------------
	print("\n--- 7. Movement & footsteps ---")
	player.is_attacking = false
	player.global_position = Vector2(300, 620)
	await _tick(2)
	var footstep_sfx: AudioStreamPlayer = player.get_node("FootstepSFX")
	_check("Footstep SFX is silent while idle", footstep_sfx.playing == false)
	var footstep_finished_during_walk := [false]
	footstep_sfx.finished.connect(func(): footstep_finished_during_walk[0] = true)
	var walk_start: Vector2 = player.global_position
	Input.action_press("move_right")
	await _tick(1)
	var footstep_played_moving: bool = footstep_sfx.playing or footstep_finished_during_walk[0]
	await _tick(9)
	if footstep_sfx.playing or footstep_finished_during_walk[0]:
		footstep_played_moving = true
	var walk_region: Rect2 = (visuals_node.texture as AtlasTexture).region
	var walk_anim_name: String = player.get_node("AnimPlayer").current_animation
	Input.action_release("move_right")
	await _tick(2)
	_check("Player walks cleanly",
		player.global_position.x > walk_start.x + 5.0,
		"moved %.2f px" % (player.global_position.x - walk_start.x))
	_check_eq("Walk animation switches to walk", walk_anim_name, "walk")
	_check("Walk animation displays frame 1 or frame 2 (64x64)",
		walk_region == Rect2(64, 0, 64, 64) or walk_region == Rect2(128, 0, 64, 64),
		str(walk_region))
	_check("Footstep SFX plays during movement", footstep_played_moving == true)
	_check("Footstep SFX stops immediately when idle", footstep_sfx.playing == false)

	print("\n=== %d checks, %d failed ===" % [_checks, _failures])
	if _failures == 0:
		print("RESULT: ALL TESTS PASSED")
	else:
		print("RESULT: FAILURES PRESENT")
	get_tree().quit(0 if _failures == 0 else 1)


func _slimes(root: Node) -> Array:
	var result: Array = []
	for node in root.get_tree().get_nodes_in_group("enemies"):
		if node != null and is_instance_valid(node) and node.get("is_dead") != true:
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


func _place_for_hit(player: CharacterBody2D, enemy: CharacterBody2D) -> void:
	player.global_position = enemy.global_position + Vector2(-22, 0)
	player.set_move_facing(Vector2.RIGHT)


func _punch(player: CharacterBody2D) -> void:
	player._start_attack()
	await player.get_tree().create_timer(player.attack_duration + 0.15).timeout
	await _tick(2)
