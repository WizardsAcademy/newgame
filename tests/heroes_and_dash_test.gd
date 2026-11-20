extends Node
## Headless verification suite for:
##   1. High-detail 32x32 hero spritesheets & renamed roster (Behemoth, Knight, Sylvara, Velmira)
##   2. Tactical Mini-Map (`UI/MiniMap`): NO camera box, directional arrows for far enemies,
##      exact map position revealed ONLY when close (`<= enemy_reveal_distance`)!
##   3. Shift-Dash rules:
##      - ONLY Behemoth & Knight deal damage with Shift (`dash_deals_damage == true`)
##      - Sylvara (Elf) deals 0 Shift damage and phases THROUGH enemies (`dash_phases_enemies == true`)
##      - Velmira (Vampire) deals 0 Shift damage (`dash_deals_damage == false`)
##   4. Knight: NO Frost Aura + Active Kite Shield (`Right-Click / E`) with 60% damage reduction (10 -> 4!)
##   5. Velmira: Crimson Blood Splash costs -6 self HP on cast (hurts on miss!) and heals +8 HP on enemy hit (+2 net!)
##
## Run with:
##   godot --headless --path . tests/heroes_and_dash_test.tscn

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SLIME_SCENE := preload("res://scenes/enemies/Slime.tscn")
const ARCHER_SCENE := preload("res://scenes/enemies/Archer.tscn")

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
	print("\n=== Detailed 32x32 Heroes, Knight Shield, Blood Splash, Shift Rules & Proximity Mini-Map Suite ===\n")

	# -----------------------------------------------------------------
	# 1. 32x32 HIGH-DETAIL SPRITESHEETS & ROSTER
	# -----------------------------------------------------------------
	var tex_behemoth: Texture2D = load("res://assets/textures/player_borzo.png")
	var tex_knight: Texture2D = load("res://assets/textures/player_bahman.png")
	var tex_sylvara: Texture2D = load("res://assets/textures/player_pari.png")
	var tex_velmira: Texture2D = load("res://assets/textures/player_shabnam.png")
	_check_eq("Behemoth spritesheet upgraded to 192x32 (6x 32x32)", tex_behemoth.get_size(), Vector2(192, 32))
	_check_eq("Knight spritesheet upgraded to 224x32 (7x 32x32 incl. Shield Guard)", tex_knight.get_size(), Vector2(224, 32))
	_check_eq("Sylvara spritesheet upgraded to 192x32 (6x 32x32)", tex_sylvara.get_size(), Vector2(192, 32))
	_check_eq("Velmira spritesheet upgraded to 192x32 (6x 32x32)", tex_velmira.get_size(), Vector2(192, 32))

	# -----------------------------------------------------------------
	# 2. MINI-MAP: NO CAMERA BOX + DIRECTIONAL ARROW WHEN FAR / EXACT SPOT WHEN CLOSE
	# -----------------------------------------------------------------
	CharacterRegistry.quick_retry_same_hero = false
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await _tick(2)

	var select_menu: Control = main.get_node("UI/CharacterSelectMenu")
	var minimap: MiniMap = main.get_node("UI/MiniMap")
	select_menu._confirm_index(0) # Pick Behemoth
	await get_tree().process_frame
	await _tick(2)
	main.wave_spawner.stop_spawning()
	for child in main.enemies_root.get_children():
		child.free()

	main.player.global_position = Vector2(300, 300)
	var far_enemy := _make_dummy_slime(main.enemies_root, Vector2(900, 300), 80)
	await _tick(2)

	var far_blips := minimap.get_enemy_blips()
	_check_eq("MiniMap detects 1 living enemy", far_blips.size(), 1)
	_check("Far enemy (>210px) is NOT revealed on exact MiniMap spot",
		far_blips[0]["revealed"] == false and far_blips[0]["exact_map_pos"] == Vector2(-1, -1),
		str(far_blips[0]))
	_check("Far enemy shows a rightward directional arrow (+X) from player",
		(far_blips[0]["direction"] as Vector2).x > 0.98,
		str(far_blips[0]["direction"]))

	# Now move player close (`<= 210px`) -> exact enemy position is discovered!
	main.player.global_position = Vector2(760, 300)
	await _tick(2)
	var near_blips := minimap.get_enemy_blips()
	_check("Approaching within reveal distance reveals exact enemy spot on MiniMap",
		near_blips[0]["revealed"] == true and (near_blips[0]["exact_map_pos"] as Vector2).distance_to(Vector2(90, 30)) < 0.5,
		str(near_blips[0]["exact_map_pos"]))

	main.queue_free()
	await _tick(3)

	# -----------------------------------------------------------------
	# 3. SHIFT-DASH RULES: ONLY BEHEMOTH & KNIGHT DEAL SHIFT DAMAGE;
	#    SYLVARA PHASES THROUGH ENEMIES WITH 0 SHIFT DAMAGE!
	# -----------------------------------------------------------------
	var world := Node2D.new()
	add_child(world)

	var behemoth := CharacterRegistry.instantiate_hero("behemoth")
	var knight := CharacterRegistry.instantiate_hero("knight")
	var sylvara := CharacterRegistry.instantiate_hero("sylvara")
	var velmira := CharacterRegistry.instantiate_hero("velmira")

	behemoth.position = Vector2(120, 120)
	knight.position = Vector2(120, 240)
	sylvara.position = Vector2(120, 360)
	velmira.position = Vector2(120, 480)
	world.add_child(behemoth)
	world.add_child(knight)
	world.add_child(sylvara)
	world.add_child(velmira)

	var s_beh := _make_dummy_slime(world, Vector2(146, 120), 100)
	var s_kni := _make_dummy_slime(world, Vector2(146, 240), 100)
	var s_syl := _make_dummy_slime(world, Vector2(146, 360), 100)
	var s_vel := _make_dummy_slime(world, Vector2(154, 480), 100)
	await _tick(3)

	_check_eq("Behemoth dash_deals_damage is true", behemoth.dash_deals_damage, true)
	_check_eq("Knight dash_deals_damage is true", knight.dash_deals_damage, true)
	_check_eq("Sylvara dash_deals_damage is false", sylvara.dash_deals_damage, false)
	_check_eq("Sylvara dash_phases_enemies is true", sylvara.dash_phases_enemies, true)
	_check_eq("Velmira dash_deals_damage is false", velmira.dash_deals_damage, false)

	# Trigger dashes on all 4 heroes!
	behemoth._try_start_dash()
	knight._try_start_dash()
	sylvara._try_start_dash()
	velmira._try_start_dash()
	await _wait(0.22)
	await _tick(2)

	_check("Behemoth Shift-Dash dealt damage to enemy", s_beh.current_health < 100,
		"hp=%d" % s_beh.current_health)
	_check("Knight Shift-Dash dealt damage to enemy", s_kni.current_health < 100,
		"hp=%d" % s_kni.current_health)
	_check_eq("Sylvara Shift-Dash dealt ZERO damage", s_syl.current_health, 100)
	_check("Sylvara Shift-Dash phased cleanly past the enemy",
		sylvara.global_position.x > s_syl.global_position.x + 12.0,
		"sylvara_x=%.1f slime_x=%.1f" % [sylvara.global_position.x, s_syl.global_position.x])
	_check_eq("Velmira Shift-Dash dealt ZERO damage", s_vel.current_health, 100)

	# UpgradePool check: Razor Dash never offered to Sylvara/Velmira
	var razor_entry := UpgradePool._find("razor_dash")
	_check_eq("UpgradePool allows razor_dash for Behemoth", UpgradePool._has_room(razor_entry, behemoth), true)
	_check_eq("UpgradePool blocks razor_dash for Sylvara", UpgradePool._has_room(razor_entry, sylvara), false)
	_check_eq("UpgradePool blocks razor_dash for Velmira", UpgradePool._has_room(razor_entry, velmira), false)

	# -----------------------------------------------------------------
	# 4. KNIGHT: FROST AURA REMOVED + ACTIVE SHIELD (60% REDUCTION: 10 -> 4!)
	# -----------------------------------------------------------------
	_check("Knight has NO WinterAura node (Frost Aura removed)",
		knight.get_node_or_null("WinterAura") == null)
	var nearby_slime := _make_dummy_slime(world, knight.global_position + Vector2(26, 0), 100)
	var base_spd: float = nearby_slime.move_speed
	await _wait(0.25)
	await _tick(2)
	_check("Nearby enemy move_speed is NOT chilled around Knight",
		is_equal_approx(nearby_slime.move_speed, base_spd),
		"spd=%.1f" % nearby_slime.move_speed)

	_check_eq("Shield input action exists in InputMap", InputMap.has_action("shield"), true)
	knight.current_health = 120
	knight.set_shielding(true)
	await _tick(2)
	_check_eq("Knight enters is_shielding state & guard animation",
		knight.is_shielding and knight.anim_player.current_animation == "guard", true)

	knight.take_damage(10, knight.global_position + Vector2(20, 0))
	_check_eq("Knight Shield reduces 10 damage by 60% -> blocks 6, takes 4 (120 -> 116)",
		knight.current_health, 116)
	knight.set_shielding(false)

	# -----------------------------------------------------------------
	# 5. VELMIRA: CRIMSON BLOOD SPLASH (-6 SELF HP ON CAST, +8 HEAL ON HIT = +2 NET)
	# -----------------------------------------------------------------
	velmira.global_position = Vector2(520, 480)
	velmira.facing = 1.0
	velmira.current_health = 70
	await _tick(2)

	# Cast 1: Miss into empty air -> loses 6 HP (70 -> 64)!
	velmira._start_attack()
	await _wait(velmira.attack_duration + 0.08)
	await _tick(2)
	_check_eq("Velmira Blood Splash into empty air costs 6 self-HP (70 -> 64)",
		velmira.current_health, 64)

	# Cast 2: Hit enemy in front -> pays 6 HP (64->58) + heals 8 HP on hit = 66 (+2 net)!
	var splash_target := _make_dummy_slime(world, Vector2(575, 480), 100)
	await _tick(2)
	velmira._start_attack()
	await _wait(velmira.attack_duration + 0.08)
	await _tick(2)
	_check("Velmira Blood Splash damages enemy in front",
		splash_target.current_health < 100,
		"slime_hp=%d" % splash_target.current_health)
	_check_eq("Velmira Blood Splash hitting 1 enemy yields +2 net HP (64 - 6 + 8 = 66)",
		velmira.current_health, 66)

	# -----------------------------------------------------------------
	# 6. BEHEMOTH COMBO & SYLVARA CHARGED PIERCING BOW REGRESSION CHECK
	# -----------------------------------------------------------------
	sylvara.global_position = Vector2(520, 360)
	sylvara.facing = 1.0
	var p1 := _make_dummy_slime(world, Vector2(610, 360), 100)
	var p2 := _make_dummy_slime(world, Vector2(665, 360), 100)
	await _tick(2)
	sylvara._on_attack_pressed(InputEventAction.new())
	sylvara._draw_time = 0.45
	sylvara._release_bow_shot()
	await _wait(0.45)
	await _tick(2)
	_check("Sylvara charged Great-Arrow still pierces multiple enemies",
		p1.current_health < 100 and p2.current_health < 100,
		"p1=%d p2=%d" % [p1.current_health, p2.current_health])

	print("\n=== %d/%d checks passed ===" % [_checks - _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
