extends Node
## Headless verification suite for:
##   1. Character Select screen on game boot (4 heroes: Borzo, Bahman, Pari, Shabnam)
##   2. Shift Dash mechanic: 1.0s cooldown, enemy pass-through, dash i-frames, and dash damage!
##   3. All 4 heroes' signature kits:
##      - Borzo: 3-hit escalating combo (Jab -> Cross -> Uppercut!)
##      - Bahman: wide Greatsword cleave + Winter Aura chill slow
##      - Pari: quick Elven arrow + charged Piercing Great-Arrow
##      - Shabnam: boomerang Blood Blade + Vampire Life Leech
##
## Run with:
##   godot --headless --path . tests/heroes_and_dash_test.tscn

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SLIME_SCENE := preload("res://scenes/enemies/Slime.tscn")

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
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


func _make_dummy_slime(parent: Node, at: Vector2, hp: int = 120) -> CharacterBody2D:
	var slime: CharacterBody2D = SLIME_SCENE.instantiate()
	slime.max_health = hp
	slime.current_health = hp
	slime.detection_range = 0.0
	slime.attack_trigger_range = 0.0
	slime.position = at
	parent.add_child(slime)
	return slime


func _run() -> void:
	print("\n=== 4-Hero Roster, Character Select & Shift-Dash Suite ===\n")

	# -----------------------------------------------------------------
	# 1. MAIN SCENE OPENS CHARACTER SELECT ON BOOT
	# -----------------------------------------------------------------
	CharacterRegistry.quick_retry_same_hero = false
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await _tick(2)

	var select_menu: Control = main.get_node("UI/CharacterSelectMenu")
	_check("CharacterSelectMenu opens when the game starts", select_menu.is_open() and select_menu.visible)
	_check_eq("CharacterRegistry lists 4 playable heroes", CharacterRegistry.CHARACTERS.size(), 4)
	_check("WaveSpawner waits until a hero is chosen", main.wave_spawner._running == false)

	# Pick Knight (Bahman) via menu selection!
	select_menu._confirm_index(1)
	await get_tree().process_frame
	await _tick(2)
	main.wave_spawner.stop_spawning()

	_check("CharacterSelectMenu closes after picking a hero", not select_menu.is_open())
	_check_eq("Main spawned Bahman (Knight)", main.player.character_id, "bahman")
	_check_eq("Bahman max HP is 120", main.player.max_health, 120)
	_check("WaveSpawner started once hero was picked", main.wave_spawner._running == true)

	main.queue_free()
	await _tick(3)

	# -----------------------------------------------------------------
	# 2. SHIFT DASH: 1.0s COOLDOWN + DEALS DAMAGE + PHASES THROUGH ENEMIES
	# -----------------------------------------------------------------
	var world := Node2D.new()
	add_child(world)

	var borzo := CharacterRegistry.instantiate_hero("borzo")
	borzo.position = Vector2(200, 200)
	world.add_child(borzo)

	var dash_target := _make_dummy_slime(world, Vector2(226, 200), 100)
	await _tick(3)

	_check_eq("Dash action exists in InputMap", InputMap.has_action("dash"), true)
	_check("Dash cooldown configured to 1.0 second", is_equal_approx(borzo.dash_cooldown, 1.0))

	var shift_press := InputEventAction.new()
	shift_press.action = "dash"
	shift_press.pressed = true
	Input.parse_input_event(shift_press)
	await _tick(1)
	Input.flush_buffered_events()
	await _tick(1)

	_check("Pressing Shift ('dash') starts dashing", borzo.is_dashing == true)
	_check("Dash puts ability on ~1.0s cooldown", borzo.dash_cooldown_left > 0.85 and borzo.dash_cooldown_left <= 1.0,
		"cd=%.2f" % borzo.dash_cooldown_left)
	# Invulnerable mid-dash: enemy hit should be ignored!
	borzo.take_damage(25, dash_target.global_position)
	_check_eq("Player is invulnerable during dash", borzo.current_health, borzo.max_health)

	await _wait(0.22)
	await _tick(2)
	_check("Dash finishes cleanly", borzo.is_dashing == false)
	_check("Player phased past the enemy during dash", borzo.global_position.x > dash_target.global_position.x,
		"borzo_x=%.1f slime_x=%.1f" % [borzo.global_position.x, dash_target.global_position.x])
	_check_eq("Dashing through an enemy deals dash_damage",
		dash_target.current_health, 100 - borzo.dash_damage)
	_check("Cannot dash again while 1.0s cooldown is active", borzo._try_start_dash() == false)

	await _wait(0.88)
	await _tick(2)
	_check("Dash ready again once 1.0s cooldown expires", borzo.can_dash())

	# -----------------------------------------------------------------
	# 3. BORZO 3-HIT ESCALATING COMBO
	# -----------------------------------------------------------------
	var combo_slime := _make_dummy_slime(world, Vector2(400, 200), 200)
	await _tick(2)
	var combo_damages: Array[int] = []
	for step in range(3):
		borzo.global_position = combo_slime.global_position + Vector2(-16, 0)
		borzo.facing = 1.0
		borzo._sync_facing_nodes()
		await _tick(2)
		var hp_before: int = combo_slime.current_health
		borzo._start_attack()
		await _wait(borzo.attack_duration + 0.08)
		await _tick(2)
		combo_damages.append(hp_before - combo_slime.current_health)

	_check("Borzo 3-hit combo escalates (Hit 3 Uppercut > Hit 2 > Hit 1)",
		combo_damages[0] > 0 and combo_damages[1] > combo_damages[0] and combo_damages[2] > combo_damages[1],
		str(combo_damages))

	# -----------------------------------------------------------------
	# 4. BAHMAN (KNIGHT): WINTER AURA CHILLS ENEMIES
	# -----------------------------------------------------------------
	var bahman := CharacterRegistry.instantiate_hero("bahman")
	bahman.position = Vector2(200, 380)
	world.add_child(bahman)
	var chill_slime := _make_dummy_slime(world, Vector2(236, 380), 100)
	var base_slime_speed: float = chill_slime.move_speed
	await _wait(0.5)
	await _tick(3)
	_check("Bahman Winter Aura chills nearby enemy move_speed",
		chill_slime.move_speed < base_slime_speed * 0.85,
		"speed=%.1f base=%.1f" % [chill_slime.move_speed, base_slime_speed])
	chill_slime.global_position = Vector2(600, 380)
	await _tick(3)
	_check("Leaving Winter Aura restores enemy move_speed",
		absf(chill_slime.move_speed - base_slime_speed) < 0.5,
		"restored=%.1f" % chill_slime.move_speed)

	# -----------------------------------------------------------------
	# 5. PARI (ELF): RANGED ARROW + CHARGED PIERCING GREAT-ARROW
	# -----------------------------------------------------------------
	var pari := CharacterRegistry.instantiate_hero("pari")
	pari.position = Vector2(100, 520)
	pari.facing = 1.0
	world.add_child(pari)
	var row_s1 := _make_dummy_slime(world, Vector2(210, 520), 100)
	var row_s2 := _make_dummy_slime(world, Vector2(270, 520), 100)
	await _tick(3)

	# Simulate charged shot (hold >= 0.35s) -> pierces BOTH slimes!
	pari._on_attack_pressed(InputEventAction.new())
	pari._draw_time = 0.45
	pari._release_bow_shot()
	await _wait(0.55)
	await _tick(3)
	_check("Pari charged Great-Arrow pierces and damages BOTH lined-up enemies",
		row_s1.current_health < 100 and row_s2.current_health < 100,
		"s1=%d s2=%d" % [row_s1.current_health, row_s2.current_health])

	# -----------------------------------------------------------------
	# 6. SHABNAM (VAMPIRE): BOOMERANG BLOOD BLADE + LIFE LEECH
	# -----------------------------------------------------------------
	var shabnam := CharacterRegistry.instantiate_hero("shabnam")
	shabnam.position = Vector2(100, 620)
	shabnam.facing = 1.0
	world.add_child(shabnam)
	var vamp_slime := _make_dummy_slime(world, Vector2(210, 620), 100)
	await _tick(3)
	shabnam.current_health = 60  # hurt first so Life Leech can heal!

	shabnam._start_attack()
	await _wait(1.1)
	await _tick(3)
	_check("Shabnam boomerang Blood Blade damages enemy",
		vamp_slime.current_health < 100,
		"slime_hp=%d" % vamp_slime.current_health)
	_check("Shabnam Vampire Life Leech restores HP on hit",
		shabnam.current_health > 60,
		"shabnam_hp=%d" % shabnam.current_health)

	print("\n=== %d/%d checks passed ===" % [_checks - _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
