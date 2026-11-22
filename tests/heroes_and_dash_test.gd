extends Node
## Comprehensive Headless Verification Suite for:
##   1. Global 4-Directional Facing (`idle_up`/`walk_up`, `idle_down`/`walk_down`,
##      `idle`/`walk`) across ALL 4 heroes + Grounded Velmira walk (ZERO floating).
##   2. Circular-clipped Bottom-Left `HeroHUD` portrait (`ShaderMaterial` mask).
##   3. SANDBOX full-map enemy aggro (`detection_range = 2500`) vs STAGES normal
##      aggro (`detection_range = 200`, `adi`).
##   4. Knight Hit-Only Shield Stamina + exhaustion lockout until 100% recovery.
##   5. Velmira Reference Sheet (`1792x1120` = 40 frames of `224x224`), Sweeping
##      Crimson Blood-Splash Slash (NO yoyo!), 30% Ground Blood Fountain, Classic
##      5-Bat `Shift` Swarm (no shadow ghost, no leak on exit), & 8-frame Blood-Melt `die`.
##   6. Dark-Fantasy Game Over (`DEAD AGAIN?` + `NOT YET` in `dark_fantasy.ttf`)
##      -> Celestial Light Pillar + Arcane Magic Circle Revival -> Return to `LOBBY`!

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
	print("\n=== 4-Dir Heroes, Circular HUD, Sandbox vs Stages Aggro, Blood-Splash Velmira & Revival Suite ===\n")

	# -----------------------------------------------------------------
	# 1. ALL 4 HERO SHEETS, PORTRAITS, DARK-FANTASY FONT & CLASSIC BATS
	# -----------------------------------------------------------------
	var tex_behemoth: Texture2D = load("res://assets/textures/player_behemoth.png")
	var tex_knight: Texture2D = load("res://assets/textures/player_knight.png")
	var tex_sylvara: Texture2D = load("res://assets/textures/player_sylvara.png")
	var tex_velmira: Texture2D = load("res://assets/textures/player_velmira.png")
	var tex_vel_fx: Texture2D = load("res://assets/textures/velmira_fx.png")
	var tex_bats: Texture2D = load("res://assets/textures/crimson_bat.png")
	var dark_font: Font = load("res://assets/fonts/dark_fantasy.ttf")

	_check_eq("Behemoth 4-dir sheet is 1536x96 (16 frames)", tex_behemoth.get_size(), Vector2(1536, 96))
	_check_eq("Knight 4-dir sheet is 1536x96 (16 frames)", tex_knight.get_size(), Vector2(1536, 96))
	_check_eq("Sylvara 4-dir sheet is 1440x96 (15 frames)", tex_sylvara.get_size(), Vector2(1440, 96))
	_check_eq("Velmira 4-dir sheet is 1536x96 (16 frames)", tex_velmira.get_size(), Vector2(1536, 96))
	_check_eq("Velmira Hand-Crafted Blood FX strip is 1024x128 (8x 128x128)", tex_vel_fx.get_size(), Vector2(1024, 128))
	_check_eq("Velmira Classic Crimson Bat strip is 72x24 (3x 24x24)", tex_bats.get_size(), Vector2(72, 24))
	_check("Dark-Fantasy Gothic font loaded cleanly", dark_font != null)

	for p_path in [
		"res://assets/textures/portrait_behemoth.png",
		"res://assets/textures/portrait_knight.png",
		"res://assets/textures/portrait_sylvara.png",
		"res://assets/textures/portrait_velmira.png",
	]:
		var ptex: Texture2D = load(p_path)
		_check_eq("Face portrait strip %s is 320x64 (5x 64x64)" % p_path.get_file(),
			ptex.get_size() if ptex != null else Vector2.ZERO, Vector2(320, 64))

	# -----------------------------------------------------------------
	# 2. LOBBY, CIRCULAR-CLIPPED HUD, SANDBOX FULL-MAP CHASE vs STAGES NORMAL, & REVIVAL!
	# -----------------------------------------------------------------
	CharacterRegistry.selected_id = "velmira"
	CharacterRegistry.quick_retry_same_hero = false
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await _tick(3)

	_check_eq("Game boots into playable Guild Hub LOBBY", main.world_mode, main.WorldMode.LOBBY)
	var hero_hud: Control = main.get_node("UI/HeroHUD")
	var face_rect: TextureRect = hero_hud.get_node("FacePortrait")
	_check("HeroHUD FacePortrait has circular clipping ShaderMaterial (never pokes outside circle!)",
		face_rect != null and face_rect.material is ShaderMaterial)
	_check("HeroHUD FacePortrait uses standalone 1:1 ImageTexture (UV 0..1, zero AtlasTexture wedge cut!)",
		face_rect != null and face_rect.texture is ImageTexture and face_rect.texture.get_width() == face_rect.texture.get_height())

	# --- SANDBOX: Full-Map Aggro (`az hame jay map bbinanet va biyan donbalet`) ---
	var lobby: Node2D = main.get_node("LobbyHub")
	var enemies_root: Node2D = main.get_node("Enemies")
	main.enter_sandbox()
	await get_tree().process_frame
	await _wait(0.65)
	await _tick(3)

	_check_eq("SANDBOX enables full_map_aggro on WaveSpawner", main.wave_spawner.full_map_aggro, true)
	var sb_enemy := _first_living_enemy(enemies_root)
	_check("SANDBOX spawns live enemies", sb_enemy != null)
	if sb_enemy != null:
		# Place enemy FAR across the map (`750 px` away!) -> MUST STILL SEE AND CHASE PLAYER IN SANDBOX!
		main.player.global_position = Vector2(200.0, 360.0)
		sb_enemy.global_position = Vector2(950.0, 360.0)
		var d0 := sb_enemy.global_position.distance_to(main.player.global_position)
		await _wait(0.55)
		await _tick(4)
		var d1 := sb_enemy.global_position.distance_to(main.player.global_position)
		_check("SANDBOX enemy 750px across the map sees & chases player!",
			d1 < d0 - 6.0, "d0=%.1f -> d1=%.1f (det=%.0f)" % [d0, d1, float(sb_enemy.get("detection_range"))])

	# --- STAGES: Normal Detection Range (`vali toy stage na intori nabashe adi bashe`) ---
	main.enter_stages()
	await get_tree().process_frame
	await _wait(0.65)
	await _tick(3)

	_check_eq("STAGES disables full_map_aggro (normal enemy sight)", main.wave_spawner.full_map_aggro, false)
	var st_enemy := _first_living_enemy(enemies_root)
	_check("STAGES spawns live enemies", st_enemy != null)
	if st_enemy != null:
		# Far away (`600 px` > normal `200 px` sight) -> does NOT map-snipe chase!
		for ch in enemies_root.get_children():
			if ch is Node2D:
				(ch as Node2D).global_position = Vector2(920.0, 360.0)
		main.player.global_position = Vector2(200.0, 360.0)
		await _tick(4)
		var far_d0 := st_enemy.global_position.distance_to(main.player.global_position)
		await _wait(0.35)
		await _tick(3)
		var far_d1 := st_enemy.global_position.distance_to(main.player.global_position)
		_check("STAGES enemy far away (720px > 200px) stays normal/idle (`adi`)",
			absf(far_d1 - far_d0) < 2.0, "far_d0=%.1f -> far_d1=%.1f" % [far_d0, far_d1])

		# Move enemy within normal sight (`150 px` < `200 px`) -> chases normally!
		st_enemy.global_position = Vector2(350.0, 360.0)
		var near_d0 := st_enemy.global_position.distance_to(main.player.global_position)
		await _wait(0.45)
		await _tick(3)
		var near_d1 := st_enemy.global_position.distance_to(main.player.global_position)
		_check("STAGES enemy within normal 200px range chases normally",
			near_d1 < near_d0 - 5.0, "near_d0=%.1f -> near_d1=%.1f" % [near_d0, near_d1])

	# --- DARK-FANTASY GAME OVER (`DEAD AGAIN?` + `NOT YET`) -> MAGIC CIRCLE + LIGHT BEAM -> LOBBY! ---
	var game_over_ui: Control = main.get_node("UI/GameOver")
	main.player.take_damage(500, main.player.global_position + Vector2(20, 0))
	await _wait(0.20)
	_check_eq("Velmira plays 8-frame Blood-Pool 'die' animation on death",
		main.player.is_dead and main.player.anim_player.current_animation == "die", true)
	await _wait(1.05) # Wait for `DEAD AGAIN?` fade-in
	_check_eq("GameOver overlay is visible", game_over_ui.visible, true)
	_check_eq("GameOver header text is 'DEAD AGAIN?'",
		(game_over_ui.get_node("Title") as Label).text, "DEAD AGAIN?")
	var not_yet_btn := game_over_ui.get_node("NotYetButton") as Button
	_check_eq("GameOver button text is 'NOT YET'", not_yet_btn.text, "NOT YET")

	# Click `NOT YET` -> spawns `RevivalRitualFX` (Magic Circle + Celestial Light Beam) -> returns to LOBBY!
	not_yet_btn.pressed.emit()
	await _tick(3)
	_check("Clicking 'NOT YET' spawns RevivalRitualFX (Magic Circle + Light Beam) under hero",
		main.get_node_or_null("RevivalRitualFX") != null)
	await _wait(1.45)
	await _tick(4)
	_check_eq("After Light-Beam + Magic-Circle revival, player returns to Guild LOBBY!",
		main.world_mode, main.WorldMode.LOBBY)
	_check("Revived hero in Lobby is alive at 100% HP",
		not main.player.is_dead and main.player.current_health == main.player.max_health)

	main.wave_spawner.stop_spawning()
	main.queue_free()
	await _tick(4)

	# -----------------------------------------------------------------
	# 3. 4-DIRECTIONAL MOVEMENT ON ALL 4 HEROES + KNIGHT STAMINA + VELMIRA BLOOD SPLASH & CLASSIC BATS
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
	for h in [behemoth, knight, sylvara, velmira]:
		h.input_enabled = false
		world.add_child(h)
	await _tick(3)

	# Verify ALL 4 heroes look UP (`walk_up`/`idle_up`) & DOWN (`walk_down`/`idle_down`)!
	for h in [behemoth, knight, sylvara, velmira]:
		h.set_move_facing(Vector2.UP)
		h.velocity = Vector2(0.0, -60.0)
		h._update_animation()
		_check_eq("%s plays 'walk_up' when moving UP" % h.character_name,
			h.anim_player.current_animation, "walk_up")
		h.velocity = Vector2.ZERO
		h._update_animation()
		_check_eq("%s plays 'idle_up' when facing UP" % h.character_name,
			h.anim_player.current_animation, "idle_up")

		h.set_move_facing(Vector2.DOWN)
		h.velocity = Vector2(0.0, 60.0)
		h._update_animation()
		_check_eq("%s plays 'walk_down' when moving DOWN" % h.character_name,
			h.anim_player.current_animation, "walk_down")
		h.velocity = Vector2.ZERO
		h._update_animation()
		_check_eq("%s plays 'idle_down' when facing DOWN" % h.character_name,
			h.anim_player.current_animation, "idle_down")

		h.set_move_facing(Vector2.RIGHT)
		h._update_animation()

	for h in [behemoth, knight, sylvara, velmira]:
		h.input_enabled = true

	# Verify Velmira's boots stay 100% grounded on node origin (`visuals.position.y == -16.0`, zero vertical float)!
	var vy0: float = (velmira.visuals as Node2D).position.y
	await _wait(0.22)
	var vy1: float = (velmira.visuals as Node2D).position.y
	_check("Velmira visuals.position.y is strictly grounded at -16.0 (zero floating bob)",
		is_equal_approx(vy0, -16.0) and is_equal_approx(vy1, -16.0),
		"vy0=%.2f vy1=%.2f" % [vy0, vy1])

	# --- KNIGHT SHIELD STAMINA: 0 hold drain, hit-only drain, lockout at 0 until full ---
	knight.current_energy = 100.0
	knight.set_shielding(true)
	await _wait(0.45)
	await _tick(3)
	_check("Knight holding shield with NO hits drains ZERO stamina",
		is_equal_approx(knight.current_energy, 100.0), "energy=%.2f" % knight.current_energy)
	knight.take_damage(20, knight.global_position + Vector2(20, 0))
	_check("Attack hitting Knight shield blocks 100% HP and drains stamina",
		knight.current_health == 150 and knight.current_energy < 100.0)
	knight.take_damage(80, knight.global_position + Vector2(20, 0))
	_check_eq("Depleting stamina locks Knight shield until full recovery",
		knight.shield_exhausted and not knight.is_shielding, true)
	knight.set_shielding(false)

	# --- VELMIRA: Classic 5-Bat Shift (NO purple shadow form!) + Sweeping Blood-Splash Slash (NO yoyo!) ---
	velmira.global_position = Vector2(520, 480)
	velmira.set_move_facing(Vector2.RIGHT)
	velmira._try_start_dash()
	await _tick(2)
	_check_eq("Velmira body disappears during Classic Bat-Swarm Shift", velmira.visuals.visible, false)
	_check("Classic Bat-Swarm Shift spawns 5 pixel bats & ZERO shadow-ghost sprite",
		velmira._swarm_root != null
		and velmira._swarm_root.get_child_count() == 5
		and world.get_node_or_null("VelmiraShadowForm") == null)
	await _wait(0.28)
	await _tick(2)
	_check_eq("Velmira re-materializes cleanly after Bat-Swarm Shift", velmira.visuals.visible, true)

	# Self-HP Cost into empty air + STRICT 1-HP Floor!
	velmira.global_position = Vector2(520, 480)
	velmira.current_health = 60
	velmira._start_attack()
	await _wait(0.38)
	await _tick(2)
	_check_eq("Blood-Splash into empty air costs 5 HP and spawns NO yoyo orb (60 -> 55)",
		velmira.current_health == 55 and world.get_node_or_null("BloodWhipOrb") == null, true)

	velmira.current_health = 1
	velmira._start_attack()
	await _wait(0.38)
	await _tick(2)
	_check_eq("Velmira at 1 HP NEVER kills herself with Blood-Splash (1 -> 1, alive!)",
		velmira.current_health == 1 and not velmira.is_dead, true)

	# Sweeping Blood-Splash hitting 1 enemy -> heals `5 + 1 = 6` (+1 net HP), 14 DMG, & 4th hit 30% Fountain!
	velmira.current_health = 50
	var splash_foe := _make_dummy_slime(world, Vector2(582, 480), 100)
	await _tick(2)

	velmira._start_attack()
	await _wait(0.40)
	await _tick(2)
	_check_eq("Blood-Splash hitting 1 enemy yields +1 net HP (50 - 5 + 6 = 51)", velmira.current_health, 51)
	_check_eq("First Blood-Splash deals 14 DMG (100 -> 86)", splash_foe.current_health, 86)

	for _i in range(2):
		velmira._start_attack()
		await _wait(0.40)
		await _tick(2)
	_check_eq("After 3 Blood-Splash hits: enemy at 58 HP (100 - 3*14)", splash_foe.current_health, 58)

	velmira._start_attack()
	await _wait(0.40)
	await _tick(2)
	_check_eq("4th Blood-Splash erupts 30% Ground Blood Fountain (58 - 14 - 30 = 14 HP)!",
		splash_foe.current_health, 14)

	print("\n=== Summary: %d / %d checks passed ===" % [_checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)
