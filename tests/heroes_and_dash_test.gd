extends Node
## Comprehensive Headless Verification Suite for the Medieval Lobby, 96x96 Heroes,
## Circular Face-Only HeroHUD + Green Energy, Knight 100%-Block Energy Shield,
## Behemoth Stuns, Sylvara Bow & Gale Vault, and Velmira's Returning Blood Whip +
## 1-HP Safety Lock + 2-Fang 30% Curse + Bat-Swarm Vanish!
##
## Run with:
##   godot --headless --path . tests/heroes_and_dash_test.tscn

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SLIME_SCENE := preload("res://scenes/enemies/Slime.tscn")
const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")

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


func _make_dummy_slime(parent: Node, at: Vector2, hp: int = 100) -> CharacterBody2D:
	var slime: CharacterBody2D = SLIME_SCENE.instantiate()
	slime.max_health = hp
	slime.current_health = hp
	slime.detection_range = 0.0
	slime.attack_trigger_range = 0.0
	slime.position = at
	parent.add_child(slime)
	return slime


func _run() -> void:
	print("\n=== Medieval Hub Lobby, 96x96 Heroes, Face HeroHUD, Energy Shield & Blood Whip Suite ===\n")

	# -----------------------------------------------------------------
	# 1. ALL 4 HERO SPRITE SHEETS AT 96x96 + 64x64 FACE PORTRAIT STRIPS
	# -----------------------------------------------------------------
	var tex_behemoth: Texture2D = load("res://assets/textures/player_borzo.png")
	var tex_knight: Texture2D = load("res://assets/textures/player_bahman.png")
	var tex_sylvara: Texture2D = load("res://assets/textures/player_pari.png")
	var tex_velmira: Texture2D = load("res://assets/textures/player_shabnam.png")
	_check_eq("Behemoth sheet is 960x96 (10 frames of 96x96)", tex_behemoth.get_size(), Vector2(960, 96))
	_check_eq("Knight sheet is 960x96 (10 frames of 96x96)", tex_knight.get_size(), Vector2(960, 96))
	_check_eq("Sylvara sheet is 864x96 (9 frames of 96x96)", tex_sylvara.get_size(), Vector2(864, 96))
	_check_eq("Velmira sheet is 768x96 (8 frames of 96x96, white hair)", tex_velmira.get_size(), Vector2(768, 96))

	for p_path in [
		"res://assets/textures/portrait_borzo.png",
		"res://assets/textures/portrait_bahman.png",
		"res://assets/textures/portrait_pari.png",
		"res://assets/textures/portrait_shabnam.png",
	]:
		var ptex: Texture2D = load(p_path)
		_check_eq("Face portrait strip %s is 320x64 (5x 64x64 states)" % p_path.get_file(),
			ptex.get_size(), Vector2(320, 64))

	# -----------------------------------------------------------------
	# 2. GUILD HUB LOBBY, WARDROBE, TRAINING DUMMY, SANDBOX DOOR & HUD
	# -----------------------------------------------------------------
	CharacterRegistry.selected_id = "behemoth"
	CharacterRegistry.quick_retry_same_hero = false
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await _tick(3)

	_check_eq("Game boots directly into playable Guild Hub LOBBY", main.world_mode, main.WorldMode.LOBBY)
	_check("Top-left control text clutter (UI/Hint & UI/Stats) removed",
		main.get_node_or_null("UI/Hint") == null and main.get_node_or_null("UI/Stats") == null)

	var lobby: Node2D = main.get_node("LobbyHub")
	var hero_hud: Control = main.get_node("UI/HeroHUD")
	var minimap: MiniMap = main.get_node("UI/MiniMap")
	_check_eq("LobbyHub is visible in LOBBY mode", lobby.visible, true)
	_check_eq("MiniMap is hidden while inside Lobby", minimap.visible, false)
	_check("TrainingDummy exists in Lobby's East Training Room", lobby.dummy_instance != null)
	_check("SANDBOX sign exists above corner Training Room door",
		lobby.get_node_or_null("SandboxSign") != null and (lobby.get_node("SandboxSign") as Label).text == "SANDBOX")

	# Hit the TrainingDummy in the Lobby -> takes damage, never dies, stays immovable!
	var dummy: CharacterBody2D = lobby.dummy_instance
	var dummy_origin := dummy.global_position
	main.player.deal_combat_damage(dummy, 25, false, 18.0)
	await _tick(2)
	_check_eq("TrainingDummy took 25 damage (100 -> 75)", dummy.current_health, 75)
	_check_eq("TrainingDummy is immovable on knockback", dummy.global_position, dummy_origin)
	main.player.deal_combat_damage(dummy, 500, false, 18.0)
	_check_eq("TrainingDummy clamps at 1 HP (never permanently dies)", dummy.current_health, 1)

	# Open Wardrobe (`Komod`) inside Lobby and equip Fallen Knight!
	main.open_wardrobe()
	await get_tree().process_frame
	var select_menu: Control = main.get_node("UI/CharacterSelectMenu")
	_check_eq("Hero Wardrobe opens CharacterSelectMenu", select_menu.is_open(), true)
	select_menu._confirm_index(1) # Equip Knight!
	await get_tree().process_frame
	await _tick(2)
	_check_eq("Equipping Knight from Lobby Wardrobe keeps player in LOBBY", main.world_mode, main.WorldMode.LOBBY)
	_check_eq("Equipped hero in Lobby is now Knight (150 HP)", main.player.max_health, 150)
	_check_eq("HeroHUD updated to KNIGHT with 150 HP", hero_hud.max_hp, 150)

	# HeroHUD face reactions: Hurt ("AKH!" frame 4) & Low-HP (frame 3)!
	main.player.take_damage(20, main.player.global_position + Vector2(20, 0))
	await get_tree().process_frame
	_check_eq("Enemy hit triggers Hero body 'hurt' animation", main.player.anim_player.current_animation, "hurt")
	_check_eq("Enemy hit triggers HeroHUD hurt wince face (frame 4)", hero_hud.is_showing_hurt_face(), true)
	_check_eq("HeroHUD 'AKH!' reaction badge appears on hit", (hero_hud.get_node("OuchBadge") as Label).visible, true)

	await _wait(0.55) # Let hurt reaction & i-frames progress
	main.player.current_health = 35 # <= 35% of 150 -> Low-HP face!
	hero_hud.set_health_values(35, 150)
	await get_tree().process_frame
	_check_eq("Dropping <= 35% HP switches HeroHUD to Low-HP face (frame 3)", hero_hud.is_showing_low_hp_face(), true)

	# Step into Corner SANDBOX Door -> transitions to SANDBOX Arena + Faded Mini-Map!
	await _wait(0.5)
	main.player.global_position = lobby.SANDBOX_DOOR_POS + Vector2(0, 12)
	await get_tree().process_frame
	await _tick(3)
	_check_eq("Walking into SANDBOX corner door enters SANDBOX Arena", main.world_mode, main.WorldMode.SANDBOX)
	_check_eq("Classic 1280x720 Arena Level is active in SANDBOX", main.level_root.visible, true)
	_check("MiniMap is visible AND faded (alpha ~ 0.42) in Arena",
		minimap.visible and is_equal_approx(minimap.modulate.a, 0.42),
		"alpha=%.2f" % minimap.modulate.a)

	# Return to Lobby and step into North STAGES Gate -> enters STAGES mode!
	main.enter_lobby()
	await get_tree().process_frame
	await _wait(0.5)
	main.player.global_position = lobby.STAGES_DOOR_POS + Vector2(0, 12)
	await get_tree().process_frame
	await _tick(3)
	_check_eq("Walking into North STAGES Gate enters STAGES progression", main.world_mode, main.WorldMode.STAGES)

	main.wave_spawner.stop_spawning()
	main.queue_free()
	await _tick(4)

	# -----------------------------------------------------------------
	# 3. HERO STATS, SPEED RANKING, COMBAT REWORKS & UNIQUE SHIFT SKILLS
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
	await _tick(3)

	_check_eq("Knight HP is 150 (highest)", knight.max_health, 150)
	_check_eq("Behemoth HP is 120", behemoth.max_health, 120)
	_check_eq("Sylvara HP is 100", sylvara.max_health, 100)
	_check_eq("Velmira HP is 75 (lowest)", velmira.max_health, 75)
	_check("Move speed ranking: Sylvara (124) fastest > Velmira (104) > Behemoth (92) > Knight (68) slowest",
		sylvara.move_speed > velmira.move_speed
		and velmira.move_speed > behemoth.move_speed
		and behemoth.move_speed > knight.move_speed,
		"syl=%.0f vel=%.0f beh=%.0f kni=%.0f" % [sylvara.move_speed, velmira.move_speed, behemoth.move_speed, knight.move_speed])

	# --- A. BEHEMOTH: Stunning Punches + Stunning Shoulder Charge ---
	var s_punch := _make_dummy_slime(world, Vector2(142, 120), 120)
	await _tick(2)
	behemoth._start_attack()
	await _wait(0.14)
	await _tick(2)
	_check("Behemoth punch damages AND stuns enemy",
		s_punch.current_health < 120 and EnemyStatusScript.is_stunned(s_punch),
		"hp=%d stunned=%s" % [s_punch.current_health, str(EnemyStatusScript.is_stunned(s_punch))])
	await _wait(0.55)

	var s_ram := _make_dummy_slime(world, Vector2(150, 120), 120)
	await _tick(2)
	behemoth._try_start_dash()
	await _wait(0.24)
	await _tick(2)
	_check("Behemoth Shoulder Charge [Shift] damages AND stuns enemy",
		s_ram.current_health < 120 and EnemyStatusScript.is_stunned(s_ram),
		"hp=%d stunned=%s" % [s_ram.current_health, str(EnemyStatusScript.is_stunned(s_ram))])

	# --- B. KNIGHT: Passive Armor + 100%-HP-Block Energy Shield + Exhaustion Lockout + Shield Charge ---
	knight.take_damage(10, knight.global_position + Vector2(20, 0))
	_check_eq("Knight passive Fallen Plate Armor (-3) reduces unshielded 10 DMG -> 7 (150 -> 143)",
		knight.current_health, 143)
	await _wait(0.95) # Clear i-frames

	knight.current_energy = 100.0
	knight.set_shielding(true)
	await _tick(2)
	_check_eq("Knight raises Tower Shield in 'guard' pose", knight.is_shielding and knight.anim_player.current_animation == "guard", true)
	knight.take_damage(20, knight.global_position + Vector2(20, 0))
	_check_eq("Knight Tower Shield blocks 100% of HP damage (143 -> 143, ZERO HP lost!)", knight.current_health, 143)
	_check("Blocking with Tower Shield drained Green Energy instead of HP",
		knight.current_energy < 100.0, "energy=%.1f" % knight.current_energy)

	# Drain energy to 0 -> Shield breaks & locks out until 100% Energy recovered!
	knight.take_damage(80, knight.global_position + Vector2(20, 0))
	_check_eq("Massive hit still deals 0 HP damage on breaking shield block", knight.current_health, 143)
	_check_eq("Depleting Energy triggers shield_exhausted lockout", knight.shield_exhausted, true)
	knight.current_energy = 50.0
	knight.set_shielding(true)
	_check_eq("Cannot raise Shield at 50% Energy while recovering from exhaustion", knight.is_shielding, false)
	knight.restore_energy(60.0) # Reaches 100/100!
	await _tick(2)
	_check_eq("Reaching 100% Energy clears shield_exhausted lockout", knight.shield_exhausted, false)
	knight.set_shielding(false)

	var s_kni := _make_dummy_slime(world, knight.global_position + Vector2(28, 0), 100)
	await _tick(2)
	knight._try_start_dash()
	await _wait(0.24)
	await _tick(2)
	_check("Knight Shield-Wall Charge [Shift] rams enemy for damage", s_kni.current_health < 100, "hp=%d" % s_kni.current_health)

	# --- C. SYLVARA: Visible Held Bow Charge + Sylvan Gale Vault (0 DMG, Phases, Slows) ---
	var s_syl := _make_dummy_slime(world, sylvara.global_position + Vector2(26, 0), 100)
	var base_slime_spd: float = s_syl.move_speed
	await _tick(2)
	sylvara._try_start_dash()
	await _wait(0.24)
	await _tick(2)
	_check_eq("Sylvara Sylvan Gale Vault deals 0 Shift damage", s_syl.current_health, 100)
	_check("Sylvara Sylvan Gale Vault phased past enemy & slowed it",
		sylvara.global_position.x > s_syl.global_position.x + 10.0 and s_syl.move_speed < base_slime_spd,
		"syl_x=%.1f slime_spd=%.1f" % [sylvara.global_position.x, s_syl.move_speed])

	sylvara.global_position = Vector2(520, 360)
	sylvara.facing = 1.0
	var p1 := _make_dummy_slime(world, Vector2(600, 360), 100)
	var p2 := _make_dummy_slime(world, Vector2(650, 360), 100)
	await _tick(2)
	sylvara._on_attack_pressed(InputEventAction.new())
	sylvara._draw_time = 0.45
	sylvara._release_bow_shot()
	await _wait(0.40)
	await _tick(2)
	_check("Sylvara charged Recurve Bow shot pierces multiple enemies",
		p1.current_health < 100 and p2.current_health < 100,
		"p1=%d p2=%d" % [p1.current_health, p2.current_health])

	# --- D. VELMIRA: Returning Blood Whip Orb + 1 HP Floor + 30% 2-Fang Burst + Bat-Swarm Vanish ---
	velmira.global_position = Vector2(520, 480)
	velmira.facing = 1.0

	# D1: Bat-Swarm Vanish [Shift] — body hides, 5 crimson bats spawn, reappears at destination!
	var s_bat := _make_dummy_slime(world, Vector2(548, 480), 100)
	await _tick(2)
	velmira._try_start_dash()
	await _tick(2)
	_check_eq("Velmira body disappears during Bat-Swarm Shift", velmira.visuals.visible, false)
	_check("Velmira spawns 5 flying crimson bats during Bat-Swarm Shift",
		velmira._swarm_root != null and velmira._swarm_root.get_child_count() == 5)
	await _wait(0.28)
	await _tick(2)
	_check_eq("Velmira re-materializes when Bat-Swarm Shift ends", velmira.visuals.visible, true)
	_check_eq("Bat-Swarm Shift dealt 0 Shift damage while phasing past enemy", s_bat.current_health, 100)
	s_bat.free()

	# D2: Self-HP Cost into empty air + STRICT 1-HP Floor (never self-kills!)
	velmira.global_position = Vector2(520, 480)
	velmira.current_health = 60
	velmira._start_attack() # Costs 5 HP (6% of 75 = 5), misses -> 0 return heal!
	await _wait(0.36)
	await _tick(2)
	_check_eq("Blood Whip into empty air costs 5 HP and heals 0 on miss (60 -> 55)", velmira.current_health, 55)

	velmira.current_health = 1
	velmira._start_attack()
	await _wait(0.36)
	await _tick(2)
	_check_eq("Velmira at 1 HP NEVER kills herself with Blood Whip (1 -> 1, alive!)",
		velmira.current_health == 1 and not velmira.is_dead, true)

	# D3: Returning Blood Whip hitting 1 enemy -> heals `paid_hp + 1` (+1 HP net!)
	#     + 4 hits trigger 2-Fang Circle 30% Max-HP Explosion!
	velmira.current_health = 50
	var whip_foe := _make_dummy_slime(world, Vector2(590, 480), 100)
	await _tick(2)

	velmira._start_attack() # Hit 1/4: pays 5 (50->45), orb returns healing 5+1=6 -> 51 HP (+1 net!), deals 13 DMG (100->87)
	await _wait(0.36)
	await _tick(2)
	_check_eq("Returning Blood Whip hitting 1 enemy yields +1 net HP (50 - 5 + 6 = 51)", velmira.current_health, 51)
	_check_eq("First Blood Whip hit deals 13 DMG (100 -> 87)", whip_foe.current_health, 87)

	# Hits 2 & 3 build the 2-Fang crimson circle to 3/4...
	for _i in range(2):
		velmira._start_attack()
		await _wait(0.36)
		await _tick(2)
	_check_eq("After 3 Blood Whip hits: enemy at 61 HP (100 - 3*13) with 3/4 Fang circle", whip_foe.current_health, 61)

	# Hit 4 fills the 2-Fang circle (4/4) -> 13 whip DMG + 30 burst DMG (30% of 100 Max HP) = 43 DMG (61 -> 18)!
	velmira._start_attack()
	await _wait(0.36)
	await _tick(2)
	_check_eq("4th hit detonates 2-Fang Circle for 30% Max HP (61 - 13 - 30 = 18 HP)!", whip_foe.current_health, 18)

	print("\n=== Summary: %d / %d checks passed ===" % [_checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)
