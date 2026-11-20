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
	print("=== Phase 2 & 3 headless combat verification ===")
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
	await get_tree().process_frame
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
	_check("PunchFx full-body overlay sprite removed", not player.has_node("Visuals/PunchFx"))

	var sheet_tex: Texture2D = (player.get_node("Visuals").texture as AtlasTexture).atlas
	_check_eq("Player placeholder sprite sheet is 64x16 (4 frames)",
		sheet_tex.get_size(), Vector2(64, 16))

	var anim_player: AnimationPlayer = player.get_node("AnimPlayer")
	var idle_anim: Animation = anim_player.get_animation("idle")
	var walk_anim: Animation = anim_player.get_animation("walk")
	var attack_anim: Animation = anim_player.get_animation("attack")
	_check_eq("Idle animation uses frame 0 (0,0,16,16)",
		(idle_anim.track_get_key_value(0, 0) as AtlasTexture).region, Rect2(0, 0, 16, 16))
	_check("Walk animation uses frames 1 and 2",
		walk_anim.track_get_key_count(0) == 2
		and (walk_anim.track_get_key_value(0, 0) as AtlasTexture).region == Rect2(16, 0, 16, 16)
		and (walk_anim.track_get_key_value(0, 1) as AtlasTexture).region == Rect2(32, 0, 16, 16))
	_check_eq("Attack animation has loop disabled", attack_anim.loop_mode, Animation.LOOP_NONE)
	_check("Attack animation keys: frame 0 @ 0.0s, frame 3 @ 0.05s, frame 0 @ 0.15s",
		attack_anim.track_get_key_count(0) == 3
		and is_equal_approx(attack_anim.track_get_key_time(0, 0), 0.0)
		and is_equal_approx(attack_anim.track_get_key_time(0, 1), 0.05)
		and is_equal_approx(attack_anim.track_get_key_time(0, 2), 0.15)
		and (attack_anim.track_get_key_value(0, 0) as AtlasTexture).region == Rect2(0, 0, 16, 16)
		and (attack_anim.track_get_key_value(0, 1) as AtlasTexture).region == Rect2(48, 0, 16, 16)
		and (attack_anim.track_get_key_value(0, 2) as AtlasTexture).region == Rect2(0, 0, 16, 16))

	var slimes := _slimes(main)
	_check_eq("Main scene spawns 3 slimes", slimes.size(), 3)
	_check("Slimes spawn at (200,200) (600,400) (1000,300)",
		spawn_positions == [Vector2(200, 200), Vector2(600, 400), Vector2(1000, 300)],
		str(spawn_positions))
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

	# ---- Slime art wiring (the rounded 12-pose sheet, not a green box) ----
	var art_slime: CharacterBody2D = slimes[0]
	var slime_visuals: Node2D = art_slime.get_node("Visuals")
	var slime_body: Sprite2D = slime_visuals.get_node("Body")
	_check("Slime body is the 12-pose x 4-variant family sheet (384x256)",
		slime_body.hframes == 12 and slime_body.vframes == 8
		and slime_body.texture.get_size() == Vector2(384, 256),
		"%dx%d frames from %s" % [slime_body.hframes, slime_body.vframes,
			str(slime_body.texture.get_size())])
	_check("Slime has a soft ground shadow and a goo puddle",
		slime_visuals.has_node("Shadow") and slime_visuals.has_node("Puddle"))
	# Every variant occupies a 24-frame block: 12 coloured poses, then the
	# 12 white flash silhouettes. A spawned slime must show a coloured pose
	# of its own block, never a flash row.
	_check("Slime shows a coloured pose, never the white flash row at spawn",
		(slime_body.frame % 24) < 12 and not slime_visuals.is_flashing(),
		"frame=%d" % slime_body.frame)
	_check("Slime visuals own facing / locomotion / attack poses",
		slime_visuals.has_method("set_facing") and slime_visuals.has_method("set_moving")
		and slime_visuals.has_method("play_telegraph") and slime_visuals.has_method("play_lunge")
		and slime_visuals.has_method("play_hurt") and slime_visuals.has_method("play_death"))

	# ---------------------------------------------------------------
	# 1b. PHASE 3 WIRING: Autoloads, SFX bus, Player AudioStreamPlayers
	# ---------------------------------------------------------------
	print("\n--- 1b. Phase 3 wiring (ScreenShake, HitStop, SFX) ---")
	var root_vp := get_tree().root
	_check("ScreenShake autoload singleton exists and is registered",
		root_vp.has_node("ScreenShake") and ScreenShake != null)
	_check("ScreenShake exposes max_intensity and decay_rate",
		is_equal_approx(ScreenShake.max_intensity, 8.0) and is_equal_approx(ScreenShake.decay_rate, 4.0))
	_check("HitStop autoload singleton exists and is registered",
		root_vp.has_node("HitStop") and HitStop != null)
	var sfx_bus_idx := AudioServer.get_bus_index("SFX")
	_check("Audio bus \"SFX\" exists in AudioServer", sfx_bus_idx >= 1, "bus index %d" % sfx_bus_idx)
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
	var punch_sfx: AudioStreamPlayer = player.get_node("PunchSFX")
	var slime1_check: CharacterBody2D = _slime_named(main, "Slime1")
	_check("Punch SFX plays immediately on attack start", punch_sfx.playing == true)
	_check("Hit SFX does NOT play on empty-air swing",
		(slime1_check.get_node("HitSFX") as AudioStreamPlayer).playing == false)
	_check("Death SFX does NOT play on empty-air swing",
		(slime1_check.get_node("DeathSFX") as AudioStreamPlayer).playing == false)

	# Wait past the 0.05 s wind-up: the hitbox must be ON now, and the
	# single Visuals sprite must show frame 3 (the punch pose) with NO
	# second full-body sprite node visible anywhere on the player.
	await _wait(0.07)
	_check("Hitbox ON ~0.05 s into the swing", hitbox.monitoring == true)
	var cam: Camera2D = player.get_node("Camera2D")
	_check("Camera2D offset is non-zero during attack shake window",
		cam.offset.length() > 0.01, str(cam.offset))

	var active_region: Rect2 = (player.get_node("Visuals").texture as AtlasTexture).region
	_check_eq("Visuals texture region equals punch frame region (frame 3) during attack",
		active_region, Rect2(48, 0, 16, 16))

	var visible_player_sprites := _visible_sprites(player)
	_check("No second full-body sprite node is visible during attack",
		visible_player_sprites.size() == 1 and visible_player_sprites[0] == player.get_node("Visuals"),
		"visible sprites on player: %d" % visible_player_sprites.size())
	_check_eq("No impact spark spawned during empty-air swing", _count_hit_sparks(main), 0)

	# Movement lock: hold "move_right" during the swing, the player
	# must not move.
	var start_pos: Vector2 = player.global_position
	Input.action_press("move_right")
	await _tick(3)
	var moved := absf(player.global_position.x - start_pos.x)
	Input.action_release("move_right")
	_check("Movement locked while attacking", moved < 0.5, "moved %.2f px" % moved)

	# After 0.15 s the hitbox must be off again, and Visuals back to frame 0.
	await _wait(0.14)
	_check("Hitbox OFF after ~0.1 s active window", hitbox.monitoring == false)
	_check_eq("Sprite is back to animation frame 0",
		(player.get_node("Visuals").texture as AtlasTexture).region, Rect2(0, 0, 16, 16))

	# And after the full 0.2 s swing the lock is released and camera settles.
	await _wait(0.1)
	_check_eq("Attack lock released after 0.2 s", player.is_attacking, false)
	_check_eq("Camera2D offset settles back to zero after shake", cam.offset, Vector2.ZERO)

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
	await _wait(0.1)
	_check_eq("Camera2D offset resets to zero after stacked shake", cam.offset, Vector2.ZERO)

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
	var hit_moment_samples := {
		"time_scale": 1.0,
		"cam_offset": Vector2.ZERO,
		"hit_sfx_playing": false,
		"death_sfx_playing": false,
	}
	player.attack_hit.connect(func(enemy):
		hit_signal_payload.append(enemy)
		if hit_signal_payload.size() == 1:
			hit_moment_samples["time_scale"] = Engine.time_scale
			hit_moment_samples["cam_offset"] = cam.offset
			hit_moment_samples["hit_sfx_playing"] = (enemy.get_node("HitSFX") as AudioStreamPlayer).playing
			hit_moment_samples["death_sfx_playing"] = (enemy.get_node("DeathSFX") as AudioStreamPlayer).playing
	)

	# Start the swing and sample the feedback while it is still on screen:
	# the flash lasts 0.1 s and the spark 0.15 s, both starting ~0.08 s in.
	player._start_attack()
	await _wait(player.attack_windup + 0.05)
	_check_eq("After hit 1: 30 - 10 = 20 HP", target.current_health, 20)
	_check_eq("Health bar value follows the health", target.get_node("HealthBar").value, 20.0)
	_check("attack_hit signal fired once", hit_signal_payload.size() == 1)
	if hit_signal_payload.size() == 1:
		_check("attack_hit carries the enemy that was hit", hit_signal_payload[0] == target)
	_check("Engine.time_scale drops during HitStop freeze on hit",
		float(hit_moment_samples["time_scale"]) < 0.2,
		"time_scale=%.3f" % float(hit_moment_samples["time_scale"]))
	_check("Camera2D offset is non-zero during hit screen shake",
		(hit_moment_samples["cam_offset"] as Vector2).length() > 0.01,
		str(hit_moment_samples["cam_offset"]))
	_check("Hit SFX plays on successful enemy hit",
		bool(hit_moment_samples["hit_sfx_playing"]) == true)
	_check("Death SFX does NOT play on non-lethal hit",
		bool(hit_moment_samples["death_sfx_playing"]) == false)
	_check("Engine.time_scale restores to 1.0 after 50 ms HitStop",
		is_equal_approx(Engine.time_scale, 1.0),
		"time_scale=%.3f" % Engine.time_scale)
	# The flash is the white silhouette row of the sheet: inside the
	# variant's block, but past its 12 coloured poses.
	var target_body: Sprite2D = target.get_node("Visuals/Body")
	_check("Slime flashed white after the hit (white sheet row)",
		target.is_flashing() and (target_body.frame % 24) >= 12,
		"flashing=%s frame=%d" % [str(target.is_flashing()), target_body.frame])
	_check("A hit spark was spawned", _count_hit_sparks(main) >= 1)
	var spark_node: Node2D = _first_hit_spark(main)
	if spark_node != null:
		var spark_vis: Sprite2D = spark_node.get_node("Visual")
		_check("Hit spark uses a 6x6 region (not a body copy)",
			spark_vis.region_enabled and spark_vis.region_rect == Rect2(0, 0, 6, 6),
			str(spark_vis.region_rect))

	# The flash must wear off again (back to the slime's own green).
	await _wait(player.attack_duration)
	_check("White flash ends after 0.1 s (back to the coloured row)",
		not target.is_flashing() and target_body.frame < 12,
		"flashing=%s frame=%d" % [str(target.is_flashing()), target_body.frame])
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
	var death_sfx_played_on_kill := [false]
	target.died.connect(func():
		death_sfx_played_on_kill[0] = (target.get_node("DeathSFX") as AudioStreamPlayer).playing
	)
	player._start_attack()
	await _wait(player.attack_windup + 0.08)
	_check_eq("After hit 3: 10 - 10 = 0 HP", target.current_health, 0)
	_check("Slime is dead after 3 hits", target.is_dead == true)
	_check("Death SFX plays when slime health reaches 0", death_sfx_played_on_kill[0] == true)
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
	# 7. Regression: Phase 1 movement + Phase 3 footsteps
	# ---------------------------------------------------------------
	print("\n--- 7. Phase 1 regression & footsteps ---")
	player.is_attacking = false
	await _tick(2)
	var footstep_sfx: AudioStreamPlayer = player.get_node("FootstepSFX")
	_check("Footstep SFX is silent while idle", footstep_sfx.playing == false)
	var walk_start: Vector2 = player.global_position
	Input.action_press("move_right")
	await _tick(1)
	var footstep_played_moving: bool = footstep_sfx.playing
	await _tick(9)
	var walk_region: Rect2 = (player.get_node("Visuals").texture as AtlasTexture).region
	var walk_anim_name: String = player.get_node("AnimPlayer").current_animation
	Input.action_release("move_right")
	await _tick(2)
	_check("Player still walks (Phase 1 movement intact)",
		player.global_position.x > walk_start.x + 5.0,
		"moved %.2f px" % (player.global_position.x - walk_start.x))
	_check("Walk animation still switches",
		walk_anim_name == "walk",
		walk_anim_name)
	_check("Walk animation displays frame 1 or frame 2",
		walk_region == Rect2(16, 0, 16, 16) or walk_region == Rect2(32, 0, 16, 16),
		str(walk_region))
	_check("Footstep SFX plays during movement", footstep_played_moving == true)
	_check("Footstep SFX stops immediately when idle", footstep_sfx.playing == false)

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


func _first_hit_spark(root: Node) -> Node2D:
	for child in root.get_children():
		if child.name.begins_with("HitSpark") or child.get_script() == preload("res://scripts/fx/hit_spark.gd"):
			return child as Node2D
	return null


## Collect every visible Sprite2D inside `subtree` so tests can guarantee
## no duplicate full-body overlay sprite appears during an attack.
func _visible_sprites(subtree: Node) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	if subtree is Sprite2D and (subtree as Sprite2D).is_visible_in_tree():
		result.append(subtree as Sprite2D)
	for child in subtree.get_children():
		result.append_array(_visible_sprites(child))
	return result


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
