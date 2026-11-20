extends Node
## Headless verification suite for:
##   1. Renamed 4-hero roster: Behemoth, Knight, Sylvara, Velmira (+ legacy ID aliases)
##   2. Redesigned Character Select screen (live arena preview, showcase panel, non-overlapping layout)
##   3. Top-Right Tactical Mini-Map (`UI/MiniMap`): 1:10 arena coordinates, obstacles, & live enemy blips
##   4. Shift Dash mechanic: 1.0s cooldown, enemy pass-through, dash i-frames, and dash damage!
##   5. All 4 heroes' signature kits (Behemoth combo, Knight Winter Aura, Sylvara piercing bow, Velmira Blood Blade + leech)
##
## Run with:
##   godot --headless --path . tests/heroes_and_dash_test.tscn

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SLIME_SCENE := preload("res://scenes/enemies/Slime.tscn")
const ARCHER_SCENE := preload("res://scenes/enemies/Archer.tscn")
const GOLEM_SCENE := preload("res://scenes/enemies/Golem.tscn")

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
	print("\n=== 4-Hero Roster (Behemoth, Knight, Sylvara, Velmira), Mini-Map & Shift-Dash Suite ===\n")

	# -----------------------------------------------------------------
	# 1. HERO NAMES & REGISTRY CHECK
	# -----------------------------------------------------------------
	_check_eq("CharacterRegistry lists 4 playable heroes", CharacterRegistry.CHARACTERS.size(), 4)
	_check_eq("Hero 1 is Behemoth", CharacterRegistry.CHARACTERS[0]["name"], "Behemoth")
	_check_eq("Hero 2 is Knight", CharacterRegistry.CHARACTERS[1]["name"], "Knight")
	_check_eq("Hero 3 is Sylvara", CharacterRegistry.CHARACTERS[2]["name"], "Sylvara")
	_check_eq("Hero 4 is Velmira", CharacterRegistry.CHARACTERS[3]["name"], "Velmira")
	_check_eq("Legacy IDs still resolve cleanly", CharacterRegistry.get_entry("pari")["id"], "sylvara")

	# -----------------------------------------------------------------
	# 2. MAIN SCENE: SHOWCASE CHARACTER SELECT + TOP-RIGHT MINI-MAP
	# -----------------------------------------------------------------
	CharacterRegistry.quick_retry_same_hero = false
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await _tick(2)

	var select_menu: Control = main.get_node("UI/CharacterSelectMenu")
	var minimap: MiniMap = main.get_node("UI/MiniMap")
	var backdrop: ColorRect = select_menu.get_node("Backdrop")
	var header_panel: Panel = select_menu.get_node("HeaderPanel")

	_check("CharacterSelectMenu opens on startup", select_menu.is_open() and select_menu.visible)
	_check("Backdrop is translucent (< 0.5 alpha) so live Arena map shows through",
		backdrop.color.a < 0.5, "alpha=%.2f" % backdrop.color.a)
	_check("Top-Right MiniMap is visible during Character Select", minimap.visible)
	_check("MiniMap sits in top-right corner of 640x360 viewport",
		minimap.position.x >= 495.0 and minimap.position.y <= 16.0,
		"pos=%s" % str(minimap.position))
	_check("CharacterSelect Header does not overlap Top-Right MiniMap",
		header_panel.position.x + header_panel.size.x < minimap.position.x,
		"header_right=%.1f minimap_left=%.1f" % [header_panel.position.x + header_panel.size.x, minimap.position.x])
	_check_eq("MiniMap detected all 3 arena stone obstacles", minimap._obstacle_rects.size(), 3)

	# Hover/highlight Sylvara -> live-previews Sylvara in the Arena & MiniMap!
	select_menu._on_card_hovered(2)
	await get_tree().process_frame
	_check_eq("Highlighting card 3 previews Sylvara live in the Arena", main.player.character_id, "sylvara")
	_check("WaveSpawner still waits until hero is confirmed", main.wave_spawner._running == false)

	# Confirm Knight!
	select_menu._confirm_index(1)
	await get_tree().process_frame
	await _tick(2)
	main.wave_spawner.stop_spawning()

	_check("CharacterSelectMenu closes after confirming hero", not select_menu.is_open())
	_check_eq("Main spawned Knight", main.player.character_id, "knight")
	_check_eq("HUD HP label displays KNIGHT", main.hp_text_label.text, "KNIGHT")
	_check_eq("Knight max HP is 120", main.player.max_health, 120)

	# Verify MiniMap tracks live enemies (Slime, Archer, Elite Golem) and drops dead ones!
	for child in main.enemies_root.get_children():
		child.free()
	var map_slime := _make_dummy_slime(main.enemies_root, Vector2(640, 360), 50)
	var map_archer: CharacterBody2D = ARCHER_SCENE.instantiate()
	map_archer.position = Vector2(1000, 200)
	main.enemies_root.add_child(map_archer)
	var map_golem: CharacterBody2D = GOLEM_SCENE.instantiate()
	map_golem.is_elite = true
	map_golem.position = Vector2(200, 600)
	main.enemies_root.add_child(map_golem)
	await _tick(2)

	var blips := minimap.get_enemy_blips()
	_check_eq("MiniMap tracks all 3 living enemies", blips.size(), 3)
	var center_map := minimap.world_to_map(Vector2(640, 360))
	_check("MiniMap maps arena center (640,360) to radar center (64,36)",
		center_map.distance_to(Vector2(64, 36)) < 0.5, str(center_map))
	map_slime.take_damage(999)
	await _tick(2)
	_check_eq("MiniMap immediately excludes dead enemies", minimap.get_enemy_blips().size(), 2)

	main.queue_free()
	await _tick(3)

	# -----------------------------------------------------------------
	# 3. SHIFT DASH: 1.0s COOLDOWN + DEALS DAMAGE + PHASES THROUGH ENEMIES
	# -----------------------------------------------------------------
	var world := Node2D.new()
	add_child(world)

	var behemoth := CharacterRegistry.instantiate_hero("behemoth")
	behemoth.position = Vector2(200, 200)
	world.add_child(behemoth)

	var dash_target := _make_dummy_slime(world, Vector2(226, 200), 100)
	await _tick(3)

	_check_eq("Dash action exists in InputMap", InputMap.has_action("dash"), true)
	_check("Dash cooldown configured to 1.0 second", is_equal_approx(behemoth.dash_cooldown, 1.0))

	var shift_press := InputEventAction.new()
	shift_press.action = "dash"
	shift_press.pressed = true
	Input.parse_input_event(shift_press)
	await _tick(1)
	Input.flush_buffered_events()
	await _tick(1)

	_check("Pressing Shift ('dash') starts dashing", behemoth.is_dashing == true)
	_check("Dash puts ability on ~1.0s cooldown", behemoth.dash_cooldown_left > 0.85 and behemoth.dash_cooldown_left <= 1.0,
		"cd=%.2f" % behemoth.dash_cooldown_left)
	behemoth.take_damage(25, dash_target.global_position)
	_check_eq("Player is invulnerable during dash", behemoth.current_health, behemoth.max_health)

	await _wait(0.22)
	await _tick(2)
	_check("Dash finishes cleanly", behemoth.is_dashing == false)
	_check("Player phased past the enemy during dash", behemoth.global_position.x > dash_target.global_position.x,
		"behemoth_x=%.1f slime_x=%.1f" % [behemoth.global_position.x, dash_target.global_position.x])
	_check_eq("Dashing through an enemy deals dash_damage",
		dash_target.current_health, 100 - behemoth.dash_damage)
	_check("Cannot dash again while 1.0s cooldown is active", behemoth._try_start_dash() == false)

	await _wait(0.88)
	await _tick(2)
	_check("Dash ready again once 1.0s cooldown expires", behemoth.can_dash())

	# -----------------------------------------------------------------
	# 4. BEHEMOTH 3-HIT ESCALATING COMBO
	# -----------------------------------------------------------------
	var combo_slime := _make_dummy_slime(world, Vector2(400, 200), 200)
	await _tick(2)
	var combo_damages: Array[int] = []
	for step in range(3):
		behemoth.global_position = combo_slime.global_position + Vector2(-16, 0)
		behemoth.facing = 1.0
		behemoth._sync_facing_nodes()
		await _tick(2)
		var hp_before: int = combo_slime.current_health
		behemoth._start_attack()
		await _wait(behemoth.attack_duration + 0.08)
		await _tick(2)
		combo_damages.append(hp_before - combo_slime.current_health)

	_check("Behemoth 3-hit combo escalates (Hit 3 Uppercut > Hit 2 > Hit 1)",
		combo_damages[0] > 0 and combo_damages[1] > combo_damages[0] and combo_damages[2] > combo_damages[1],
		str(combo_damages))

	# -----------------------------------------------------------------
	# 5. KNIGHT: WINTER AURA CHILLS ENEMIES
	# -----------------------------------------------------------------
	var knight := CharacterRegistry.instantiate_hero("knight")
	knight.position = Vector2(200, 380)
	world.add_child(knight)
	var chill_slime := _make_dummy_slime(world, Vector2(236, 380), 100)
	var base_slime_speed: float = chill_slime.move_speed
	await _wait(0.5)
	await _tick(3)
	_check("Knight Winter Aura chills nearby enemy move_speed",
		chill_slime.move_speed < base_slime_speed * 0.85,
		"speed=%.1f base=%.1f" % [chill_slime.move_speed, base_slime_speed])
	chill_slime.global_position = Vector2(600, 380)
	await _tick(3)
	_check("Leaving Winter Aura restores enemy move_speed",
		absf(chill_slime.move_speed - base_slime_speed) < 0.5,
		"restored=%.1f" % chill_slime.move_speed)

	# -----------------------------------------------------------------
	# 6. SYLVARA (ELF): RANGED ARROW + CHARGED PIERCING GREAT-ARROW
	# -----------------------------------------------------------------
	var sylvara := CharacterRegistry.instantiate_hero("sylvara")
	sylvara.position = Vector2(100, 520)
	sylvara.facing = 1.0
	world.add_child(sylvara)
	var row_s1 := _make_dummy_slime(world, Vector2(210, 520), 100)
	var row_s2 := _make_dummy_slime(world, Vector2(270, 520), 100)
	await _tick(3)

	sylvara._on_attack_pressed(InputEventAction.new())
	sylvara._draw_time = 0.45
	sylvara._release_bow_shot()
	await _wait(0.55)
	await _tick(3)
	_check("Sylvara charged Great-Arrow pierces and damages BOTH lined-up enemies",
		row_s1.current_health < 100 and row_s2.current_health < 100,
		"s1=%d s2=%d" % [row_s1.current_health, row_s2.current_health])

	# -----------------------------------------------------------------
	# 7. VELMIRA (VAMPIRE): BOOMERANG BLOOD BLADE + LIFE LEECH
	# -----------------------------------------------------------------
	var velmira := CharacterRegistry.instantiate_hero("velmira")
	velmira.position = Vector2(100, 620)
	velmira.facing = 1.0
	world.add_child(velmira)
	var vamp_slime := _make_dummy_slime(world, Vector2(210, 620), 100)
	await _tick(3)
	velmira.current_health = 60

	velmira._start_attack()
	await _wait(1.1)
	await _tick(3)
	_check("Velmira boomerang Blood Blade damages enemy",
		vamp_slime.current_health < 100,
		"slime_hp=%d" % vamp_slime.current_health)
	_check("Velmira Vampire Life Leech restores HP on hit",
		velmira.current_health > 60,
		"velmira_hp=%d" % velmira.current_health)

	print("\n=== %d/%d checks passed ===" % [_checks - _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
