extends Node
## Comprehensive Headless Verification Suite for:
##   1. Knight Hit-Only Shield Stamina (0 passive hold drain, stamina drops ONLY
##      when attacks hit the raised shield, locks out at 0 until 100% recovery).
##   2. Spawning & Actively Chasing Enemies in BOTH SANDBOX and STAGES modes
##      (including Lobby <-> Sandbox <-> Stages transitions).
##   3. Velmira Reference Sheet (`3800x200` 19-frame sprite sheet, `960x192`
##      5-state portrait strip, `640x160` Blood Magic FX, `192x64` Crimson Bats,
##      `idle`/`walk`/`attack`/`attack_lance`/`charge`/`hurt`/`die`, 1-HP floor,
##      returning Blood Whip, 2-Fang 30% Max-HP burst, & Shadow-Bat Shift).
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


func _first_living_enemy(enemies_root: Node) -> Node2D:
	for ch in enemies_root.get_children():
		if ch != null and is_instance_valid(ch) and ch is Node2D and ch.get("is_dead") != true:
			return ch as Node2D
	return null


func _run() -> void:
	print("\n=== Knight Shield Stamina, Sandbox+Stages Chasing Enemies & Velmira Reference Suite ===\n")

	# -----------------------------------------------------------------
	# 1. ALL 4 HERO SPRITE SHEETS + FACE PORTRAITS + VELMIRA REFERENCE FX
	# -----------------------------------------------------------------
	var tex_behemoth: Texture2D = load("res://assets/textures/player_borzo.png")
	var tex_knight: Texture2D = load("res://assets/textures/player_bahman.png")
	var tex_sylvara: Texture2D = load("res://assets/textures/player_pari.png")
	var tex_velmira: Texture2D = load("res://assets/textures/player_shabnam.png")
	var tex_vel_fx: Texture2D = load("res://assets/textures/velmira_fx.png")
	var tex_bats: Texture2D = load("res://assets/textures/crimson_bat.png")

	_check_eq("Behemoth sheet is 960x96 (10 frames of 96x96)", tex_behemoth.get_size(), Vector2(960, 96))
	_check_eq("Knight sheet is 960x96 (10 frames of 96x96)", tex_knight.get_size(), Vector2(960, 96))
	_check_eq("Sylvara sheet is 864x96 (9 frames of 96x96)", tex_sylvara.get_size(), Vector2(864, 96))
	_check_eq("Velmira reference sheet is 3800x200 (19 frames of 200x200)", tex_velmira.get_size(), Vector2(3800, 200))
	_check_eq("Velmira Blood Magic FX sheet is 640x160 (4 frames of 160x160)", tex_vel_fx.get_size(), Vector2(640, 160))
	_check_eq("Velmira Crimson Bat sheet is 192x64 (3 frames of 64x64)", tex_bats.get_size(), Vector2(192, 64))

	for p_path in [
		"res://assets/textures/portrait_borzo.png",
		"res://assets/textures/portrait_bahman.png",
		"res://assets/textures/portrait_pari.png",
		"res://assets/textures/portrait_shabnam.png",
	]:
		var ptex: Texture2D = load(p_path)
		_check("Face portrait strip %s has 5 square states (w == 5*h)" % p_path.get_file(),
			ptex != null and ptex.get_width() == ptex.get_height() * 5,
			"size=%s" % str(ptex.get_size() if ptex != null else Vector2.ZERO))

	var vel_ptex: Texture2D = load("res://assets/textures/portrait_shabnam.png")
	_check_eq("Velmira reference portrait strip is 960x192 (5x 192x192)", vel_ptex.get_size(), Vector2(960, 192))

	# -----------------------------------------------------------------
	# 2. GUILD HUB LOBBY, WARDROBE, SANDBOX CHASING ENEMIES & STAGES CHASING ENEMIES!
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
	var enemies_root: Node2D = main.get_node("Enemies")
	_check_eq("LobbyHub is visible in LOBBY mode", lobby.visible, true)
	_check_eq("MiniMap is hidden while inside Lobby", minimap.visible, false)
	_check("TrainingDummy exists in Lobby's East Training Room", lobby.dummy_instance != null)

	# Hit the TrainingDummy in the Lobby -> takes damage, never dies, stays immovable!
	var dummy: CharacterBody2D = lobby.dummy_instance
	var dummy_origin := dummy.global_position
	main.player.deal_combat_damage(dummy, 25, false, 18.0)
	await _tick(2)
	_check_eq("TrainingDummy took 25 damage (100 -> 75)", dummy.current_health, 75)
	_check_eq("TrainingDummy is immovable on knockback", dummy.global_position, dummy_origin)
	main.player.deal_combat_damage(dummy, 500, false, 18.0)
	_check_eq("TrainingDummy clamps at 1 HP (never permanently dies)", dummy.current_health, 1)

	# Open Wardrobe inside Lobby and equip Velmira first to verify her 192x192 HUD portrait, then Knight!
	main.open_wardrobe()
	await get_tree().process_frame
	var select_menu: Control = main.get_node("UI/CharacterSelectMenu")
	_check_eq("Hero Wardrobe opens CharacterSelectMenu", select_menu.is_open(), true)
	select_menu._confirm_index(3) # Equip Velmira!
	await get_tree().process_frame
	await _tick(2)
	_check_eq("Velmira equipped in Lobby with 5-frame circular HUD portrait", hero_hud._portrait_frames.size(), 5)

	main.open_wardrobe()
	await get_tree().process_frame
	select_menu._confirm_index(1) # Equip Knight!
	await get_tree().process_frame
	await _tick(2)
	_check_eq("Equipping Knight from Lobby Wardrobe keeps player in LOBBY", main.world_mode, main.WorldMode.LOBBY)
	_check_eq("Equipped hero in Lobby is now Knight (150 HP)", main.player.max_health, 150)

	# HeroHUD face reactions: Hurt ("AKH!" frame 4) & Low-HP (frame 3)!
	main.player.take_damage(20, main.player.global_position + Vector2(20, 0))
	await get_tree().process_frame
	_check_eq("Enemy hit triggers Hero body 'hurt' animation", main.player.anim_player.current_animation, "hurt")
	_check_eq("Enemy hit triggers HeroHUD hurt wince face (frame 4)", hero_hud.is_showing_hurt_face(), true)

	await _wait(0.55)
	main.player.current_health = 35
	hero_hud.set_health_values(35, 150)
	await get_tree().process_frame
	_check_eq("Dropping <= 35% HP switches HeroHUD to Low-HP face (frame 3)", hero_hud.is_showing_low_hp_face(), true)

	# --- SANDBOX: Enter SANDBOX Door -> Enemies SPAWN and ACTIVELY CHASE Player! ---
	main.player.current_health = 150
	await _wait(0.5)
	main.player.global_position = lobby.SANDBOX_DOOR_POS + Vector2(0, 12)
	await get_tree().process_frame
	await _tick(3)
	_check_eq("Walking into SANDBOX corner door enters SANDBOX Arena", main.world_mode, main.WorldMode.SANDBOX)
	_check("MiniMap is visible AND faded (alpha ~ 0.42) in SANDBOX",
		minimap.visible and is_equal_approx(minimap.modulate.a, 0.42),
		"alpha=%.2f" % minimap.modulate.a)

	# Wait ~0.6s for Wave 1 enemies to spawn in SANDBOX and verify active chasing!
	await _wait(0.65)
	await _tick(3)
	var sb_enemy := _first_living_enemy(enemies_root)
	_check("SANDBOX spawns live enemies after Lobby transition",
		sb_enemy != null, "count=%d" % enemies_root.get_child_count())
	if sb_enemy != null:
		var d0 := sb_enemy.global_position.distance_to(main.player.global_position)
		await _wait(0.55)
		await _tick(4)
		var d1 := sb_enemy.global_position.distance_to(main.player.global_position)
		_check("SANDBOX enemies actively CHASE the player (distance shrinks)",
			d1 < d0 - 4.0, "d0=%.1f -> d1=%.1f" % [d0, d1])

	# --- STAGES: Return to Lobby -> Enter North STAGES Gate -> Enemies SPAWN and ACTIVELY CHASE Player! ---
	main.enter_lobby()
	await get_tree().process_frame
	await _wait(0.5)
	main.player.global_position = lobby.STAGES_DOOR_POS + Vector2(0, 12)
	await get_tree().process_frame
	await _tick(3)
	_check_eq("Walking into North STAGES Gate enters STAGES progression", main.world_mode, main.WorldMode.STAGES)

	await _wait(0.65)
	await _tick(3)
	var st_enemy := _first_living_enemy(enemies_root)
	_check("STAGES spawns live enemies after Lobby->Sandbox->Lobby transition",
		st_enemy != null, "count=%d" % enemies_root.get_child_count())
	if st_enemy != null:
		var sd0 := st_enemy.global_position.distance_to(main.player.global_position)
		await _wait(0.55)
		await _tick(4)
		var sd1 := st_enemy.global_position.distance_to(main.player.global_position)
		_check("STAGES enemies actively CHASE the player (distance shrinks)",
			sd1 < sd0 - 4.0, "d0=%.1f -> d1=%.1f" % [sd0, sd1])

	main.wave_spawner.stop_spawning()
	main.queue_free()
	await _tick(4)

	# -----------------------------------------------------------------
	# 3. HERO STATS, KNIGHT SHIELD STAMINA FIX & VELMIRA REFERENCE ANIMATIONS/KIT
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

	for anim_name in ["idle", "walk", "attack", "attack_lance", "charge", "hurt", "die"]:
		_check("Velmira AnimPlayer has '%s' animation from reference sheet" % anim_name,
			velmira.anim_player.has_animation(anim_name))

	# --- A. BEHEMOTH: Stunning Punches + Stunning Shoulder Charge ---
	var s_punch := _make_dummy_slime(world, Vector2(142, 120), 120)
	await _tick(2)
	behemoth._start_attack()
	await _wait(0.14)
	await _tick(2)
	_check("Behemoth punch damages AND stuns enemy",
		s_punch.current_health < 120 and EnemyStatusScript.is_stunned(s_punch))
	await _wait(0.55)

	var s_ram := _make_dummy_slime(world, Vector2(150, 120), 120)
	await _tick(2)
	behemoth._try_start_dash()
	await _wait(0.24)
	await _tick(2)
	_check("Behemoth Shoulder Charge [Shift] damages AND stuns enemy",
		s_ram.current_health < 120 and EnemyStatusScript.is_stunned(s_ram))

	# --- B. KNIGHT: HOLDING SHIELD DRAINS 0 STAMINA; ONLY HITS DRAIN STAMINA; LOCKS AT 0 UNTIL FULL ---
	knight.take_damage(10, knight.global_position + Vector2(20, 0))
	_check_eq("Knight passive Fallen Plate Armor (-3) reduces unshielded 10 DMG -> 7 (150 -> 143)",
		knight.current_health, 143)
	await _wait(0.95) # Clear i-frames

	knight.current_energy = 100.0
	knight.set_shielding(true)
	await _tick(2)
	_check_eq("Knight raises Tower Shield in 'guard' pose",
		knight.is_shielding and knight.anim_player.current_animation == "guard", true)

	# Hold shield for 0.6s with NO enemy attacks -> stamina MUST stay at 100.0 (ZERO passive drain!)
	await _wait(0.60)
	await _tick(5)
	_check("Holding Knight shield with NO hits drains ZERO stamina (100 -> 100)",
		is_equal_approx(knight.current_energy, 100.0), "energy=%.2f" % knight.current_energy)

	# Hit 1 onto raised shield -> 0 HP lost, stamina DOES decrease!
	knight.take_damage(20, knight.global_position + Vector2(20, 0))
	_check_eq("Knight Tower Shield blocks 100% of HP damage (143 -> 143, ZERO HP lost!)", knight.current_health, 143)
	_check("Attack hitting Knight's raised shield DOES decrease stamina",
		knight.current_energy < 100.0 and knight.current_energy > 0.0,
		"energy=%.1f" % knight.current_energy)
	var energy_after_hit1: float = knight.current_energy

	# Hold shield another 0.4s with NO attacks -> stamina stays right at `energy_after_hit1`!
	await _wait(0.40)
	await _tick(3)
	_check("Holding shield after hit neither drains nor regenerates stamina while raised",
		is_equal_approx(knight.current_energy, energy_after_hit1),
		"energy=%.2f expected=%.2f" % [knight.current_energy, energy_after_hit1])

	# Heavy hit drains remaining stamina to 0 -> Shield breaks & locks out until 100% recovery!
	knight.take_damage(80, knight.global_position + Vector2(20, 0))
	_check_eq("Shield-breaking hit still blocks 100% HP damage", knight.current_health, 143)
	_check_eq("Depleting stamina to 0 sets shield_exhausted = true & drops shield",
		knight.shield_exhausted and not knight.is_shielding, true)

	knight.current_energy = 50.0
	knight.set_shielding(true)
	_check_eq("Cannot raise Shield at 50% stamina while recovering from exhaustion", knight.is_shielding, false)
	knight.restore_energy(60.0) # Reaches 100/100!
	await _tick(2)
	_check_eq("Recovering stamina to 100% clears shield_exhausted lockout", knight.shield_exhausted, false)
	_check_eq("Knight can raise Shield again once stamina fully recovers", knight.is_shielding, true)
	knight.set_shielding(false)

	var s_kni := _make_dummy_slime(world, knight.global_position + Vector2(28, 0), 100)
	await _tick(2)
	knight._try_start_dash()
	await _wait(0.24)
	await _tick(2)
	_check("Knight Shield-Wall Charge [Shift] rams enemy for damage", s_kni.current_health < 100)

	# --- C. SYLVARA: Held Bow Charge + Sylvan Gale Vault ---
	var s_syl := _make_dummy_slime(world, sylvara.global_position + Vector2(26, 0), 100)
	var base_slime_spd: float = s_syl.move_speed
	await _tick(2)
	sylvara._try_start_dash()
	await _wait(0.24)
	await _tick(2)
	_check_eq("Sylvara Sylvan Gale Vault deals 0 Shift damage", s_syl.current_health, 100)
	_check("Sylvara Sylvan Gale Vault phased past enemy & slowed it",
		sylvara.global_position.x > s_syl.global_position.x + 10.0 and s_syl.move_speed < base_slime_spd)

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
		p1.current_health < 100 and p2.current_health < 100)

	# --- D. VELMIRA: Reference Animations, Bat+Shadow Shift, 1-HP Floor, Blood Whip & 30% Fang Burst ---
	velmira.global_position = Vector2(520, 480)
	velmira.facing = 1.0

	# D1: Bat-Swarm + Shadow-Mist Vanish [Shift]!
	var s_bat := _make_dummy_slime(world, Vector2(548, 480), 100)
	await _tick(2)
	velmira._try_start_dash()
	await _tick(2)
	_check_eq("Velmira body disappears during Bat-Swarm Shift", velmira.visuals.visible, false)
	_check("Velmira spawns 5 flying crimson bats + Shadow-Bat form during Shift",
		velmira._swarm_root != null and velmira._swarm_root.get_child_count() == 5 and velmira._shadow_trail_sprite != null)
	await _wait(0.28)
	await _tick(2)
	_check_eq("Velmira re-materializes when Bat-Swarm Shift ends", velmira.visuals.visible, true)
	_check_eq("Bat-Swarm Shift dealt 0 Shift damage while phasing past enemy", s_bat.current_health, 100)
	s_bat.free()

	# D2: Self-HP Cost into empty air + STRICT 1-HP Floor (never self-kills!)
	velmira.global_position = Vector2(520, 480)
	velmira.current_health = 60
	velmira._start_attack() # Plays 'attack', costs 5 HP, misses -> 0 return heal!
	await _wait(0.36)
	await _tick(2)
	_check_eq("Blood Whip into empty air costs 5 HP and heals 0 on miss (60 -> 55)", velmira.current_health, 55)

	velmira.current_health = 1
	velmira._start_attack() # Alternates to 'attack_lance'!
	await _wait(0.36)
	await _tick(2)
	_check_eq("Velmira at 1 HP NEVER kills herself with Blood Whip (1 -> 1, alive!)",
		velmira.current_health == 1 and not velmira.is_dead, true)

	# D3: Returning Blood Whip + 4-hit 30% Max-HP 2-Fang Crimson Spire Eruption!
	velmira.current_health = 50
	var whip_foe := _make_dummy_slime(world, Vector2(590, 480), 100)
	await _tick(2)

	velmira._start_attack()
	await _wait(0.36)
	await _tick(2)
	_check_eq("Returning Blood Whip hitting 1 enemy yields +1 net HP (50 - 5 + 6 = 51)", velmira.current_health, 51)
	_check_eq("First Blood Whip hit deals 13 DMG (100 -> 87)", whip_foe.current_health, 87)

	for _i in range(2):
		velmira._start_attack()
		await _wait(0.36)
		await _tick(2)
	_check_eq("After 3 Blood Whip hits: enemy at 61 HP (100 - 3*13) with 3/4 Fang circle", whip_foe.current_health, 61)

	velmira._start_attack()
	await _wait(0.36)
	await _tick(2)
	_check_eq("4th hit detonates 2-Fang Circle for 30% Max HP (61 - 13 - 30 = 18 HP)!", whip_foe.current_health, 18)

	# D4: Enemy lethal hit triggers Velmira's reference 'die' kneel-collapse animation!
	velmira.take_damage(200, velmira.global_position + Vector2(20, 0))
	await get_tree().process_frame
	_check_eq("Lethal enemy damage plays Velmira's 'die' animation upright",
		velmira.is_dead and velmira.anim_player.current_animation == "die" and is_equal_approx(velmira.visuals.rotation_degrees, 0.0),
		true)

	print("\n=== Summary: %d / %d checks passed ===" % [_checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)
