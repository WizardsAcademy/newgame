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
		if child is Sprite2D and child.name == "EliteAura" and child.texture != null:
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
	# 7. ART RIG - the 12-pose skeleton sheet (visual-only redesign)
	# ----------------------------------------------------------------
	# A second archer whose AI is switched OFF, so nothing fights the rig
	# while we poke poses. Nothing here touches gameplay: the checks below
	# also pin the numbers the redesign promised NOT to change.
	var rig_world := Node2D.new()
	add_child(rig_world)

	var rig: CharacterBody2D = archer_scene.instantiate()
	rig_world.add_child(rig)
	rig.set_physics_process(false)
	await _tick(2)

	# UNTYPED on purpose: test scripts are not compiled against the game
	# scripts, so a `Node2D`-typed variable would refuse `play_draw()` at
	# parse time. A plain `var` keeps the calls dynamic (same trick as
	# combat_test uses on the slime's visuals).
	var vis = rig.get_node("Visuals")
	var art: Sprite2D = vis.get_node("Body")

	_check("Archer visuals expose the pose API",
		vis.has_method("set_facing") and vis.has_method("set_moving")
		and vis.has_method("play_draw") and vis.has_method("play_release")
		and vis.has_method("play_mock") and vis.has_method("play_hurt")
		and vis.has_method("play_death") and vis.has_method("flash"))
	_check("Archer keeps a ground shadow", vis.has_node("Shadow"))

	var tex_detail: String = "no texture"
	if art.texture != null:
		tex_detail = "%dx%d" % [art.texture.get_width(), art.texture.get_height()]
	_check("Sheet is 12 poses x 2 rows (384x64 at 32x32)",
		art.hframes == 12 and art.vframes == 2
		and art.texture != null
		and art.texture.get_width() == 384 and art.texture.get_height() == 64,
		"%dx%d grid, texture %s" % [art.hframes, art.vframes, tex_detail])

	# Facing flips the sprite without moving the collision box.
	vis.set_facing(-1.0)
	await _frames(2)
	var flipped_left: bool = art.flip_h
	vis.set_facing(1.0)
	await _frames(2)
	_check("Facing flips the art, not the body",
		flipped_left and not art.flip_h and rig.position == Vector2.ZERO)

	# Locomotion: the walk cycle alternates the two step poses.
	vis.set_moving(true)
	await _frames(3)
	var walk_frame: int = art.frame
	vis.set_moving(false)
	await _frames(3)
	_check("Walking shows a walk frame (3 or 4)", walk_frame == 3 or walk_frame == 4,
		"frame=%d" % walk_frame)
	_check("Standing still shows an idle frame (0 or 1)",
		art.frame == 0 or art.frame == 1, "frame=%d" % art.frame)

	# The bow draw advances with the AI's own aim progress.
	vis.play_draw(0.15)
	await _frames(1)
	var early_draw: int = art.frame
	vis.play_draw(0.95)
	await _frames(1)
	var full_draw: int = art.frame
	_check("Draw progress picks the half-drawn pose then the full draw",
		early_draw == 5 and full_draw == 6,
		"early=%d full=%d" % [early_draw, full_draw])

	vis.play_release()
	await _frames(1)
	_check_eq("Release pose after the shot", art.frame, 7)

	vis.play_mock()
	await _frames(1)
	_check_eq("Mocking head tilt", art.frame, 8)

	vis.play_hurt()
	await _frames(1)
	_check_eq("Hurt flinch", art.frame, 9)

	# The white silhouettes live one row down: flash = frame + 12.
	vis.flash(0.12)
	await _frames(2)
	var flash_frame: int = art.frame
	await _wait(0.2)
	await _frames(2)
	_check("Hit flash uses the white silhouette row",
		flash_frame >= 12 and art.frame < 12,
		"flash=%d after=%d" % [flash_frame, art.frame])

	# Death: knees fold, then the heap that is left behind.
	vis.play_death()
	await _frames(2)
	var collapse_frame: int = art.frame
	await _wait(0.25)
	await _frames(2)
	_check("Death collapses into a bone heap",
		collapse_frame == 10 and art.frame == 11,
		"collapse=%d heap=%d" % [collapse_frame, art.frame])

	# The redesign is visual only - pin the numbers it promised to leave alone.
	_check("Gameplay numbers untouched by the art pass",
		rig.max_health == 24 and is_equal_approx(rig.move_speed, 55.0)
		and is_equal_approx(rig.aim_duration, 0.55)
		and is_equal_approx(rig.attack_cooldown, 2.0)
		and is_equal_approx(rig.shooting_distance, 260.0)
		and is_equal_approx(rig.retreat_distance, 90.0),
		"hp=%d speed=%.1f aim=%.2f cd=%.2f" % [rig.max_health, rig.move_speed,
			rig.aim_duration, rig.attack_cooldown])
	_check("Hitbox and hurtbox sizes are unchanged",
		(rig.get_node("CollisionShape2D").shape as RectangleShape2D).size == Vector2(12, 14)
		and (rig.get_node("Hurtbox/CollisionShape2D").shape as RectangleShape2D).size == Vector2(15, 16))

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


## Wait for idle frames - the visuals node animates in _process, not in
## physics, so the pose checks have to sample rendered frames.
func _frames(count: int = 1) -> void:
	for i in count:
		await get_tree().process_frame

func _ready() -> void:
	_run()
