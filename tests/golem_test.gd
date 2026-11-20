extends Node
## Headless verification suite for the Stone Golem.
##
## Run it from the repo root with:
##
##   godot --headless --path . tests/golem_test.tscn
##
## Two things are covered:
##   1. THE FIGHT still behaves exactly as it did before the art pass —
##      long telegraph, one live slam frame, the stuck recovery window, the
##      elite package, crumble on death. Every number is pinned at the end.
##   2. THE LOOK: the 12-pose brute sheet, the white flash row, the crumble
##      into rubble, and the facing flip.
##
## The world is built by hand (one real Golem + tests/fake_player.gd with a
## throwaway hurtbox Area2D on the enemy-detectable layer), so the suite never
## depends on the wave spawner or the Main scene.
##
## The exit code is 0 only when every check passed.

const FAKE_PLAYER := preload("res://tests/fake_player.gd")

## Layers: the golem's slam sensor (AttackArea) scans layer 64, which is what
## a player's hurtbox lives on. Same numbers as Player.tscn.
const LAYER_PLAYER_HURTBOX: int = 64

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


func _frames(count: int = 1) -> void:
	for i in count:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## A fake player plus a throwaway hurtbox so the golem's slam can actually
## connect. The fake player itself carries take_damage() and counts the hits.
func _make_player(world: Node, at: Vector2) -> Node2D:
	var fake: Node2D = FAKE_PLAYER.new()
	fake.add_to_group("player")
	fake.position = at
	world.add_child(fake)

	var hurt := Area2D.new()
	hurt.name = "Hurtbox"
	hurt.collision_layer = LAYER_PLAYER_HURTBOX
	hurt.collision_mask = 0
	fake.add_child(hurt)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	hurt.add_child(shape)
	return fake


func _run() -> void:
	print("\n=== Stone Golem (heavy brute: slam + 12-pose rig) ===\n")

	var golem_scene: PackedScene = load("res://scenes/enemies/Golem.tscn")

	# ----------------------------------------------------------------
	# 1. THE TELEGRAPH IS LONG AND LOUD
	# ----------------------------------------------------------------
	var world := Node2D.new()
	add_child(world)

	# 30 px away: inside slam_trigger_range (44), so the fight starts at once.
	var fake_player: Node2D = _make_player(world, Vector2(30, 0))

	var golem: CharacterBody2D = golem_scene.instantiate()
	world.add_child(golem)
	await _tick(3)

	_check("Close player puts the golem into TELEGRAPH",
		golem._attack_state == golem.AttackState.TELEGRAPH,
		"state=%d" % golem._attack_state)

	var vis = golem.get_node("Visuals")
	var art: Sprite2D = vis.get_node("Body")
	await _frames(2)
	_check_eq("Telegraph shows the fists-overhead pose", art.frame, 5)
	_check("Telegraph also glows red (second read, not colour-only)",
		golem.visuals.modulate.r > golem.visuals.modulate.b,
		"modulate=%s" % str(golem.visuals.modulate))

	# ----------------------------------------------------------------
	# 2. THE SLAM: one live frame, full damage, then the punish window
	# ----------------------------------------------------------------
	# Poll until the (0.08 s long!) slam window actually connects, instead of
	# guessing a sleep: the pose check has to happen INSIDE that window.
	var guard: int = 0
	while fake_player.hit_count == 0 and guard < 240:
		await _tick(1)
		guard += 1
	_check("The slam connects at all", fake_player.hit_count == 1,
		"after %d physics frames" % guard)
	_check_eq("Slam lands for attack_damage", fake_player.last_damage, 15)
	_check_eq("The player is hit exactly once per slam", fake_player.hit_count, 1)
	await _frames(1)
	_check("Slam frame shows the fists-in-the-floor pose", art.frame == 6,
		"frame=%d" % art.frame)

	await _wait(0.15)
	_check("After the slam the golem is stuck in RECOVER",
		golem._attack_state == golem.AttackState.RECOVER,
		"state=%d" % golem._attack_state)
	await _frames(2)
	_check_eq("Recovery shows the slumped, seams-dying pose", art.frame, 7)
	_check("The slam hitbox is OFF during the punish window",
		not golem.attack_area.monitoring)

	# The punish window really does reopen the fight afterwards.
	await _wait(1.0)   # recover 0.9 -> COOLDOWN
	await _tick(2)
	_check("Recovery hands back to COOLDOWN (fight resumes)",
		golem._attack_state == golem.AttackState.COOLDOWN,
		"state=%d" % golem._attack_state)

	# ----------------------------------------------------------------
	# 3. THE ART RIG
	# ----------------------------------------------------------------
	_check("Golem visuals expose the pose API",
		vis.has_method("set_facing") and vis.has_method("set_moving")
		and vis.has_method("play_telegraph") and vis.has_method("play_slam")
		and vis.has_method("play_recover") and vis.has_method("play_hurt")
		and vis.has_method("play_roar") and vis.has_method("play_rise")
		and vis.has_method("play_death") and vis.has_method("flash"))
	_check("Golem keeps a ground shadow", vis.has_node("Shadow"))

	var tex_detail: String = "no texture"
	if art.texture != null:
		tex_detail = "%dx%d" % [art.texture.get_width(), art.texture.get_height()]
	_check("Sheet is 12 poses x 2 rows (480x80 at 40x40)",
		art.hframes == 12 and art.vframes == 2
		and art.texture != null
		and art.texture.get_width() == 480 and art.texture.get_height() == 80,
		"%dx%d grid, texture %s" % [art.hframes, art.vframes, tex_detail])

	# Facing: the golem only flips its art, never its body.
	fake_player.position = Vector2(-200, 0)
	await _tick(4)
	await _frames(2)
	var flipped: bool = art.flip_h
	_check("Golem faces the player by flipping the art", flipped)
	_check("Facing does not move the collision body",
		golem.get_node("CollisionShape2D").position == Vector2.ZERO)

	# Poses are driven by the AI's own method calls, one per beat.
	vis.play_slam()
	await _frames(1)
	var slam_pose: int = art.frame
	vis.play_roar()
	await _frames(1)
	var roar_pose: int = art.frame
	vis.play_hurt()
	await _frames(1)
	var hurt_pose: int = art.frame
	vis.play_rise()
	await _frames(1)
	var rise_pose: int = art.frame
	_check("Every beat has its own pose (slam/roar/hurt/rise)",
		slam_pose == 6 and roar_pose == 2 and hurt_pose == 8 and rise_pose == 9,
		"slam=%d roar=%d hurt=%d rise=%d" % [slam_pose, roar_pose, hurt_pose, rise_pose])

	# The white silhouettes live one row down: flash = frame + 12.
	vis.flash(0.12)
	await _frames(2)
	var flash_frame: int = art.frame
	await _wait(0.2)
	await _frames(2)
	_check("Hit flash uses the white silhouette row",
		flash_frame >= 12 and art.frame < 12,
		"flash=%d after=%d" % [flash_frame, art.frame])

	# ----------------------------------------------------------------
	# 4. ELITE: 3x HP, +5 damage, 1.5x slam radius, and the flare pose
	# ----------------------------------------------------------------
	var elite_world := Node2D.new()
	add_child(elite_world)
	_make_player(elite_world, Vector2(400, 0))   # far: it just walks

	var elite: CharacterBody2D = golem_scene.instantiate()
	elite.become_elite()                          # spawner order: before add_child
	elite_world.add_child(elite)
	await _tick(3)
	await _frames(2)

	_check_eq("Elite HP is 3x base (90 -> 270)", elite.max_health, 270)
	_check_eq("Elite slam hits harder (15 + 5)", elite.attack_damage, 20)
	var elite_circle: CircleShape2D = (
		elite.get_node("AttackArea/CollisionShape2D").shape as CircleShape2D)
	_check("Elite slam radius is 1.5x (46 -> 69)",
		is_equal_approx(elite_circle.radius, 69.0),
		"radius=%.1f" % elite_circle.radius)
	var elite_art: Sprite2D = elite.get_node("Visuals/Body")
	_check("Elite flares the seams on spawn (UPRISING pose)",
		elite_art.frame == 9, "frame=%d" % elite_art.frame)
	_check("Base golem's slam radius was NOT changed by the elite",
		is_equal_approx((golem.get_node("AttackArea/CollisionShape2D").shape
			as CircleShape2D).radius, 46.0))

	# ----------------------------------------------------------------
	# 5. DEATH: crumble, then the rubble pile
	# ----------------------------------------------------------------
	golem.take_damage(999)
	await _tick(2)
	await _frames(2)
	var crumble_pose: int = art.frame
	_check("Dead golem flags is_dead", golem.is_dead)
	_check_eq("Death starts on the crumble pose", crumble_pose, 10)

	await _wait(0.3)   # crumble_time 0.22
	await _frames(2)
	_check_eq("The crumble leaves a rubble pile", art.frame, 11)
	_check("Dead golem stops scanning for slam targets",
		not golem.attack_area.monitoring)

	# ----------------------------------------------------------------
	# 6. THE NUMBERS THE ART PASS PROMISED NOT TO TOUCH
	# ----------------------------------------------------------------
	var fresh: CharacterBody2D = golem_scene.instantiate()
	world.add_child(fresh)
	await _tick(2)
	_check("Golem gameplay numbers untouched by the art pass",
		fresh.max_health == 90 and is_equal_approx(fresh.move_speed, 30.0)
		and fresh.attack_damage == 15
		and is_equal_approx(fresh.telegraph_duration, 0.8)
		and is_equal_approx(fresh.slam_active_duration, 0.08)
		and is_equal_approx(fresh.recover_duration, 0.9)
		and is_equal_approx(fresh.attack_cooldown, 0.6)
		and is_equal_approx(fresh.slam_trigger_range, 44.0)
		and is_equal_approx(fresh.slam_radius, 46.0),
		"hp=%d speed=%.1f dmg=%d telegraph=%.2f recover=%.2f" % [
			fresh.max_health, fresh.move_speed, fresh.attack_damage,
			fresh.telegraph_duration, fresh.recover_duration])
	_check("Hitbox and hurtbox sizes are unchanged",
		(fresh.get_node("CollisionShape2D").shape as RectangleShape2D).size == Vector2(20, 20)
		and (fresh.get_node("Hurtbox/CollisionShape2D").shape as RectangleShape2D).size == Vector2(24, 24))

	# ----------------------------------------------------------------
	print("\n%d/%d checks passed." % [_checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)


func _ready() -> void:
	_run()
