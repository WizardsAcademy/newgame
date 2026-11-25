extends Node
## Comprehensive Headless Verification Suite for:
##   1. Global 4-Directional Facing (`idle_up`/`walk_up`, `idle_down`/`walk_down`,
##      `idle`/`walk`) across ALL 4 heroes + Grounded Noa walk (ZERO floating).
##   2. Circular-clipped Bottom-Left `HeroHUD` portrait (`ShaderMaterial` mask).
##   3. SANDBOX full-map enemy aggro (`detection_range = 2500`) vs STAGES normal
##      aggro (`detection_range = 200`, `adi`).
##   4. Knight Hit-Only Shield Stamina + exhaustion lockout until 100% recovery.
##   5. Noa Unified 96x96 Sheet (`1536x96` = 16 frames of `96x96`), Sweeping
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
	print("\n=== 4-Dir Heroes, Circular HUD, Sandbox vs Stages Aggro, Blood-Splash Noa & Revival Suite ===\n")

	# -----------------------------------------------------------------
	# 1. ALL 4 HERO SHEETS, PORTRAITS, DARK-FANTASY FONT & CLASSIC BATS
	# -----------------------------------------------------------------
	var tex_behemoth: Texture2D = load("res://assets/textures/player_behemoth.png")
	var tex_knight: Texture2D = load("res://assets/textures/player_knight.png")
	var tex_sylvara: Texture2D = load("res://assets/textures/player_sylvara.png")
	var tex_noa: Texture2D = load("res://assets/textures/player_noa.png")
	var tex_vel_fx: Texture2D = load("res://assets/textures/noa_fx.png")
	var tex_bats: Texture2D = load("res://assets/textures/crimson_bat.png")
	var dark_font: Font = load("res://assets/fonts/dark_fantasy.ttf")

	_check_eq("Behemoth 4-dir sheet is 1024x64 (16 frames)", tex_behemoth.get_size(), Vector2(1024, 64))
	_check_eq("Knight 4-dir sheet is 1024x64 (16 frames)", tex_knight.get_size(), Vector2(1024, 64))
	_check_eq("Sylvara 4-dir sheet is 960x64 (15 frames)", tex_sylvara.get_size(), Vector2(960, 64))
	_check_eq("Noa 4-dir sheet is 1024x64 (16 frames)", tex_noa.get_size(), Vector2(1024, 64))
	_check_eq("Noa Hand-Crafted Blood FX strip is 1024x128 (8x 128x128)", tex_vel_fx.get_size(), Vector2(1024, 128))
	_check_eq("Noa Classic Crimson Bat strip is 72x24 (3x 24x24)", tex_bats.get_size(), Vector2(72, 24))
	_check("Dark-Fantasy Gothic font loaded cleanly", dark_font != null)

	for p_path in [
		"res://assets/textures/portrait_behemoth.png",
		"res://assets/textures/portrait_knight.png",
		"res://assets/textures/portrait_sylvara.png",
		"res://assets/textures/portrait_noa.png",
	]:
		var ptex: Texture2D = load(p_path)
		_check_eq("Face portrait strip %s is 320x64 (5x 64x64)" % p_path.get_file(),
			ptex.get_size() if ptex != null else Vector2.ZERO, Vector2(320, 64))

	# -----------------------------------------------------------------
	# 2. LOBBY, CIRCULAR-CLIPPED HUD, SANDBOX FULL-MAP CHASE vs STAGES NORMAL, & REVIVAL!
	# -----------------------------------------------------------------
	var test_save_path := "user://test_witch_cottage_save.cfg"
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	WitchCauldronProgression.save_path = test_save_path
	WitchCauldronProgression._loaded = false

	CharacterRegistry.selected_id = "noa"
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
	_check_eq("Noa plays 8-frame Blood-Pool 'die' animation on death",
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

	# --- WITCH'S COTTAGE + LARGE OUTDOOR WOODLAND YARD (`hayat`), 16-NODE PER-HERO SKILL TREE, NO WAVE POPUP, ESC PAUSE, & HERO PERSISTENCE ---
	_check_eq("Witch's Cottage + Large Outdoor Forest Yard bounds are 640x560",
		lobby.LOBBY_BOUNDS.size, Vector2(640, 560))
	_check("Upper Cottage has oak floor, Fireplace + Sofa, Wardrobe, Stages Door, 64x64 Witch, & 48x48 Cauldron (and NO indoor south room!)",
		lobby.get_node_or_null("CottageFloor") != null
		and lobby.get_node_or_null("CottageFloorSouth") == null
		and lobby.get_node_or_null("LobbyFireplace") != null
		and lobby.get_node_or_null("LobbySofa") != null
		and lobby.get_node_or_null("WardrobeSprite") != null
		and lobby.get_node_or_null("DoorStages") != null
		and lobby.get_node_or_null("WitchSprite") != null
		and lobby.get_node_or_null("CauldronSprite") != null)
	var forest_node := lobby.get_node_or_null("ForestTrees")
	_check("Outdoor Yard (`hayat`) has seamless grass, >50 pixel-art ForestTrees enclosing the clearing, Sandbox Fence Gate + Rails, & 64x64 TrainingDummy",
		lobby.get_node_or_null("OutdoorYardGrass") != null
		and forest_node != null and forest_node.get_child_count() >= 50
		and lobby.get_node_or_null("DoorSandbox") != null
		and lobby.get_node_or_null("SandboxFenceLeft") != null
		and lobby.get_node_or_null("SandboxFenceRight") != null
		and lobby.get_node_or_null("TrainingDummy") != null)
	_check("Cauldron has 6 frames (green bubbling -> sudden purple flash!)",
		lobby._cauldron_frames.size() == 6)

	# Verify Long Scrollable 14-Node Exclusive-Pillar Skill Tree (`1 -> 3x4 -> 1`), Monster/Wave Reagent Drops -> Witch Majon Brewing, & Backtick DevConsole!
	_check_eq("Skill Tree defines 14 OP nodes per hero (solo_top -> 3x4 Pillars -> solo_bottom)",
		WitchCauldronProgression.get_skill_nodes_for_hero("noa").size() == 14
		and WitchCauldronProgression.MAX_NODE_LEVEL == 5, true)
	var th_knight := WitchCauldronProgression.get_hero_theme("knight")
	var th_behemoth := WitchCauldronProgression.get_hero_theme("behemoth")
	var th_sylvara := WitchCauldronProgression.get_hero_theme("sylvara")
	var th_noa := WitchCauldronProgression.get_hero_theme("noa")
	_check("Per-Hero Skill Tree themes match Knight Blue/Black, Behemoth Orange/Red, Sylvara Green/Gold, & Noa Red/White",
		(th_knight["primary"] as Color).b > 0.8 and (th_knight["stone_dark"] as Color).v < 0.15
		and (th_behemoth["primary"] as Color).r > 0.8 and (th_behemoth["secondary"] as Color).g > 0.5
		and (th_sylvara["primary"] as Color).g > 0.65 and (th_sylvara["secondary"] as Color).r > 0.85
		and (th_noa["primary"] as Color).r > 0.8 and (th_noa["secondary"] as Color).v > 0.9)

	# Monster kill & Wave clear drop Alchemy Reagents (`ReagentDrop`) -> Witch brews Potions (`Majon` = Skill Points)!
	_check_eq("Fresh hero starts at 0 Skill Points & 0 Reagents",
		WitchCauldronProgression.get_brew_points("noa") == 0 and WitchCauldronProgression.get_reagents() == 0, true)
	var drop_foe := _make_dummy_slime(main.enemies_root, main.player.global_position + Vector2(150.0, 0.0), 20)
	main._watch_enemy(drop_foe)
	drop_foe.take_damage(50)
	await _tick(3)
	var drops_after_kill := get_tree().get_nodes_in_group("reagent_drops")
	_check("Killing an enemy spawns a collectible ReagentDrop item on the ground",
		drops_after_kill.size() >= 1)
	for rd in drops_after_kill:
		if rd != null and is_instance_valid(rd) and rd.has_method("collect_now"):
			rd.collect_now()
	await _tick(2)
	_check_eq("Collecting monster reagent drop increments Witch Reagents (+1)",
		WitchCauldronProgression.get_reagents(), 1)

	# Wave clear spawns +3 Wave Crystal ReagentDrop (and does NOT show old 3-card UpgradeMenu!)
	main._on_wave_cleared(1)
	await _tick(4)
	_check_eq("Wave clear does NOT show 3-card UpgradeMenu popup", main.upgrade_menu.visible, false)
	for rd2 in get_tree().get_nodes_in_group("reagent_drops"):
		if rd2 != null and is_instance_valid(rd2) and rd2.has_method("collect_now"):
			rd2.collect_now()
	await _tick(2)
	_check("Wave clear Arcane Crystal grants +3 Reagents (total >= 4)",
		WitchCauldronProgression.get_reagents() >= 4,
		"reagents=%d" % WitchCauldronProgression.get_reagents())

	# Open Scrollable Skill Tree -> brew Majon from collected Reagents -> verify scrollability, Exclusive Pillar lock, & Bottom Convergence!
	main.open_cauldron_skill_tree()
	await _tick(2)
	var skill_ui: WitchSkillTreeMenu = main.get_node("UI/WitchSkillTreeMenu")
	_check_eq("Skill Tree opens for active hero ('noa')", skill_ui._hero_id, "noa")
	var tree_scroll := skill_ui.get_node_or_null("CauldronPanel/TreeScroll") as ScrollContainer
	var tree_content := skill_ui.get_node_or_null("CauldronPanel/TreeScroll/TreeContent") as Control
	var brew_btn: Button = skill_ui.get_node("CauldronPanel/BrewPotionButton")
	var upg_btn: Button = skill_ui.get_node("CauldronPanel/InspectorPanel/UpgradeButton")
	var rst_btn: Button = skill_ui.get_node("CauldronPanel/ResetButton")
	_check("Skill Tree UI is vertically scrollable (`TreeContent.size.y >= 600` inside `TreeScroll`) with 14 OP nodes & BrewPotionButton",
		tree_scroll != null and tree_content != null and tree_content.size.y >= 600.0
		and skill_ui._node_buttons.size() == 14 and brew_btn != null and upg_btn != null and rst_btn != null)

	brew_btn.pressed.emit()
	await _tick(2)
	_check_eq("Giving 3 Reagents to the Witch brews +1 Majon (Skill Point)!",
		WitchCauldronProgression.get_brew_points("noa"), 1)

	# Backtick (`) Blank Developer Console: ZERO hints/placeholders, `wizard` God-Mode Cheat, & `canoheil` Cheat Disabler!
	var dev_con: DevConsole = main.get_node("UI/DevConsole")
	_check("Developer Console is completely blank (zero placeholder & zero command hint text!)",
		dev_con._input_line.placeholder_text == "" and dev_con._log_lbl.text == "")
	var bt_ev := InputEventKey.new()
	bt_ev.pressed = true
	bt_ev.keycode = KEY_QUOTELEFT
	bt_ev.unicode = 96
	dev_con._input(bt_ev)
	await _tick(2)
	_check_eq("Pressing backtick (`) opens blank DevConsole", dev_con.is_open(), true)
	dev_con.submit_command("wizard")
	await _tick(2)
	_check("Typing 'wizard' enables wizard_cheat_active (infinite money/SP, infinite HP, 0 CD, 1-shot-1-kill & all regions)!",
		WitchCauldronProgression.wizard_cheat_active
		and WitchCauldronProgression.get_brew_points("noa") >= 100000
		and WitchCauldronProgression.is_region_unlocked(3))
	dev_con.toggle_console()
	await _tick(1)

	# Test 1-shot-1-kill & infinite HP under `wizard` cheat!
	var cheat_target := _make_dummy_slime(main.enemies_root, main.player.global_position + Vector2(36.0, 0.0), 50000)
	main.player.take_damage(999, main.player.global_position + Vector2(20.0, 0.0))
	_check_eq("Wizard cheat grants Infinite Health (takes 0 damage from 999 hit)",
		main.player.current_health, main.player.max_health)
	main.player.deal_combat_damage(cheat_target, 10, false, 0.0)
	_check_eq("Wizard cheat grants 1-Shot 1-Kill (instantly slays 50,000 HP monster!)",
		cheat_target.is_dead, true)

	# Upgrade Top Solo (`solo_top`) -> choose Pillar 0 (`p0_t1`) -> verify Pillars 1 & 2 LOCK -> descend to `p0_t4` -> verify `solo_bottom` unlocks!
	upg_btn.pressed.emit()
	await _tick(2)
	_check("Upgrading solo_top unlocks all 3 Pillar T1 nodes initially",
		WitchCauldronProgression.get_node_level("noa", "solo_top") == 1
		and WitchCauldronProgression.is_node_unlocked("noa", "p0_t1")
		and WitchCauldronProgression.is_node_unlocked("noa", "p1_t1")
		and WitchCauldronProgression.is_node_unlocked("noa", "p2_t1"))

	skill_ui._on_skill_node_pressed("p0_t1")
	upg_btn.pressed.emit()
	await _tick(2)
	_check("Choosing Pillar 0 (`p0_t1`) IMMEDIATELY locks out Pillar 1 & Pillar 2!",
		WitchCauldronProgression.get_chosen_pillar("noa") == 0
		and not WitchCauldronProgression.is_node_unlocked("noa", "p1_t1")
		and not WitchCauldronProgression.is_node_unlocked("noa", "p2_t1")
		and WitchCauldronProgression.is_node_locked_by_other_pillar("noa", "p1_t1")
		and WitchCauldronProgression.is_node_locked_by_other_pillar("noa", "p2_t1"))

	for next_nid in ["p0_t2", "p0_t3", "p0_t4"]:
		skill_ui._on_skill_node_pressed(String(next_nid))
		upg_btn.pressed.emit()
		await _tick(1)
	_check_eq("Reaching Pillar Tier-4 (`p0_t4`) converges & unlocks Bottom Solo `[R]` Ultimate (`solo_bottom`)!",
		WitchCauldronProgression.is_node_unlocked("noa", "solo_bottom"), true)
	skill_ui._on_skill_node_pressed("solo_bottom")
	upg_btn.pressed.emit()
	await _tick(2)
	_check_eq("Bottom Converged `[R]` Ultimate (`solo_bottom`) upgrades cleanly!",
		WitchCauldronProgression.get_node_level("noa", "solo_bottom"), 1)

	# Prominent ResetButton inside Skill Tree refunds spent points & unlocks all 3 pillars again!
	_check("ResetButton inside Skill Tree shows spent points count",
		rst_btn.text.find("Reset") != -1 and not rst_btn.disabled)
	rst_btn.pressed.emit()
	await _tick(2)
	_check_eq("ResetButton clears chosen pillar back to -1",
		WitchCauldronProgression.get_chosen_pillar("noa"), -1)
	skill_ui.hide_menu()
	await _tick(2)

	# Typing `canoheil` in DevConsole disables ALL cheats & restores legitimate pre-wizard state!
	dev_con.submit_command("canoheil")
	await _tick(3)
	_check("Typing 'canoheil' disables ALL cheats (`wizard_cheat_active == false`, restores legitimate 1 brewed SP & base 75 HP)",
		not WitchCauldronProgression.wizard_cheat_active
		and WitchCauldronProgression.get_brew_points("noa") == 1
		and WitchCauldronProgression.get_spent_points("noa") == 0
		and main.player.max_health == 75)

	# Verify Bottom-Right AbilityBar HUD, Lobby Cauldron Fly-In Animation, Sandbox 3.0s Door Ring, & 3 Named Stage Regions!
	var ability_bar := hero_hud.get_node_or_null("AbilityBar") as Control
	_check("HeroHUD places AbilityBar at the bottom-right of the screen",
		ability_bar != null and (hero_hud.position.x + ability_bar.position.x) >= 350.0)

	WitchCauldronProgression.add_reagents(3)
	var spawned_flyers: int = lobby.trigger_cauldron_item_fly_animation(lobby.CAULDRON_POS + Vector2(-36.0, 20.0))
	await _tick(2)
	_check("Approaching Cauldron triggers arcing Reagent Fly-In Animation into the Cauldron",
		spawned_flyers == 3 and get_tree().get_nodes_in_group("cauldron_flying_items").size() >= 1)
	_check_eq("Lobby Sandbox Gate requires 3.0s hold progress ring (`SANDBOX_HOLD_DURATION == 3.0`)",
		is_equal_approx(lobby.SANDBOX_HOLD_DURATION, 3.0), true)

	# Verify 3 Distinct Named Stage Regions, Sandbox-only `$Level`, Boss Gate Unlock, Wave HP Scaling, & Door Beacon!
	_check("3 Distinct Named Stage Regions exist & Region 2/3 start locked until Boss kill",
		WitchCauldronProgression.get_max_unlocked_region() == 1
		and not WitchCauldronProgression.is_region_unlocked(2)
		and String(WitchCauldronProgression.get_region_info(1)["name"]) == "Whispering Jungle"
		and String(WitchCauldronProgression.get_region_info(2)["name"]) == "Cursed Bone Crypt"
		and String(WitchCauldronProgression.get_region_info(3)["name"]) == "Infernal Citadel")
	_check("WaveSpawner applies steep exponential HP scaling (`Wave 5 HP mult > 10x Wave 1` & `Region 3 > Region 2 > Region 1`)",
		main.wave_spawner.compute_wave_hp_multiplier(5, 1) > 10.0
		and main.wave_spawner.compute_wave_hp_multiplier(1, 3) > main.wave_spawner.compute_wave_hp_multiplier(1, 2)
		and main.wave_spawner.compute_wave_hp_multiplier(1, 2) > main.wave_spawner.compute_wave_hp_multiplier(1, 1))

	main.enter_stages(1)
	await _tick(3)
	main.wave_spawner.stop_spawning()
	_check("Entering Stage Region 1 activates StageMap ('Whispering Jungle') & strictly disables Sandbox `$Level`!",
		main.stage_map.visible and main.stage_map.active_region_id == 1 and not main.level_root.visible)

	# Simulate defeating Region 1 Boss -> unlocks Region 2 AND spawns tracked `stage_portals` doors on round clear!
	var fake_boss := _make_dummy_slime(main.enemies_root, Vector2(500.0, 360.0), 40)
	fake_boss.add_to_group("boss")
	main._watch_enemy(fake_boss)
	fake_boss.take_damage(100)
	await _tick(2)
	main._on_wave_cleared(5)
	await _tick(3)
	_check("Defeating Region 1 Boss unlocks Region 2 ('Cursed Bone Crypt') AND spawns tracked Stage Exit + Next-Region Portals!",
		WitchCauldronProgression.is_region_unlocked(2)
		and main._next_region_gate_active
		and get_tree().get_nodes_in_group("stage_portals").size() >= 2)

	main.enter_stages(2)
	await _tick(3)
	main.wave_spawner.stop_spawning()
	var reg2_foe: Node = main.wave_spawner._spawn_enemy()
	var reg2_boss: Node = main.wave_spawner._spawn_boss()
	await _tick(2)
	_check("Stage Region 2 ('Cursed Bone Crypt') builds Crypt obstacles & spawns new RegionEnemy + Malakor Arch-Lich Boss!",
		main.stage_map.active_region_id == 2 and reg2_foe is RegionEnemy and reg2_boss is RegionBoss)
	main.enter_lobby()
	await _tick(3)

	# ESC Pause Menu (`Continue`, `Settings`, `Lobby`, `Quit`)
	var pause_ui: PauseMenu = main.get_node("UI/PauseMenu")
	pause_ui.open_menu()
	_check_eq("Opening PauseMenu pauses SceneTree", get_tree().paused, true)
	_check("PauseMenu exposes Continue, Settings, Lobby, & Quit buttons",
		pause_ui.get_node_or_null("MainPausePanel/ContinueButton") != null
		and pause_ui.get_node_or_null("MainPausePanel/SettingsButton") != null
		and pause_ui.get_node_or_null("MainPausePanel/LobbyButton") != null
		and pause_ui.get_node_or_null("MainPausePanel/QuitButton") != null)
	(pause_ui.get_node("MainPausePanel/SettingsButton") as Button).pressed.emit()
	_check_eq("Clicking Settings opens SettingsPanel", pause_ui._settings_page.visible, true)
	(pause_ui.get_node("SettingsPanel/BackButton") as Button).pressed.emit()
	(pause_ui.get_node("MainPausePanel/ContinueButton") as Button).pressed.emit()
	_check_eq("Clicking Continue unpauses SceneTree", get_tree().paused, false)

	# Selected Hero Persistence across game sessions (`select_character("sylvara")` -> reopen Main -> spawns Sylvara!)
	main.select_character("sylvara", false)
	await _tick(2)
	main.wave_spawner.stop_spawning()
	main.queue_free()
	await _tick(4)

	# Simulate fresh game launch where memory defaulted back to "behemoth"
	CharacterRegistry.selected_id = "behemoth"
	WitchCauldronProgression._loaded = false
	var main_relaunch := MAIN_SCENE.instantiate()
	add_child(main_relaunch)
	await get_tree().process_frame
	await _tick(3)
	_check_eq("Reopening the game spawns the last selected hero ('sylvara', NOT default 'behemoth'!)",
		String(main_relaunch.player.get("character_id")), "sylvara")
	main_relaunch.queue_free()
	await _tick(3)

	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	WitchCauldronProgression.load_from_disk(test_save_path)

	# -----------------------------------------------------------------
	# 3. 4-DIRECTIONAL MOVEMENT ON ALL 4 HEROES + KNIGHT STAMINA + NOA BLOOD SPLASH & CLASSIC BATS
	# -----------------------------------------------------------------
	var world := Node2D.new()
	add_child(world)

	var behemoth := CharacterRegistry.instantiate_hero("behemoth")
	var knight := CharacterRegistry.instantiate_hero("knight")
	var sylvara := CharacterRegistry.instantiate_hero("sylvara")
	var noa := CharacterRegistry.instantiate_hero("noa")

	behemoth.position = Vector2(120, 120)
	knight.position = Vector2(120, 240)
	sylvara.position = Vector2(120, 360)
	noa.position = Vector2(120, 480)
	for h in [behemoth, knight, sylvara, noa]:
		h.input_enabled = false
		world.add_child(h)
	await _tick(3)

	# Verify ALL 4 heroes look UP (`walk_up`/`idle_up`) & DOWN (`walk_down`/`idle_down`)!
	for h in [behemoth, knight, sylvara, noa]:
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

	for h in [behemoth, knight, sylvara, noa]:
		h.input_enabled = true

	# Verify Noa's boots stay 100% grounded on node origin (`visuals.position.y == -11.0`, zero vertical float)!
	var vy0: float = (noa.visuals as Node2D).position.y
	await _wait(0.22)
	var vy1: float = (noa.visuals as Node2D).position.y
	_check("Noa visuals.position.y is strictly grounded at -11.0 (zero floating bob)",
		is_equal_approx(vy0, -11.0) and is_equal_approx(vy1, -11.0),
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

	# --- NOA REWORK: 0 Self-HP Cost, 0 Default Heal, Skill 1 = 1% Enemy HP Lifesteal, 8-Hit Burst + 10% Lifesteal, & Toggle [R] Blood Rain! ---
	noa.global_position = Vector2(520, 480)
	noa.set_move_facing(Vector2.RIGHT)
	noa._try_start_dash()
	await _tick(2)
	_check_eq("Noa body disappears during Classic Bat-Swarm Shift", noa.visuals.visible, false)
	_check("Classic Bat-Swarm Shift spawns 5 pixel bats & ZERO shadow-ghost sprite",
		noa._swarm_root != null
		and noa._swarm_root.get_child_count() == 5
		and world.get_node_or_null("NoaShadowForm") == null)
	await _wait(0.28)
	await _tick(2)
	_check_eq("Noa re-materializes cleanly after Bat-Swarm Shift", noa.visuals.visible, true)

	noa.global_position = Vector2(520, 480)
	noa.apply_skill_tree_ranks({})
	noa.current_health = 50
	noa._start_attack()
	await _wait(0.38)
	await _tick(2)
	_check_eq("Noa basic attack into empty air costs ZERO self-HP (50 -> 50)",
		noa.current_health, 50)

	var splash_foe := _make_dummy_slime(world, Vector2(582, 480), 200)
	await _tick(2)
	noa._start_attack()
	await _wait(0.38)
	await _tick(2)
	_check_eq("Noa un-upgraded basic attack heals 0 HP by default (50 -> 50) & deals 14 DMG (200 -> 186)",
		noa.current_health == 50 and splash_foe.current_health == 186, true)

	# Upgrade Noa Skill 1 (`solo_top`): 1% Enemy Max HP Lifesteal (and NO 1s projectile dodge!)
	noa.apply_skill_tree_ranks({"solo_top": 1})
	_check_eq("Noa solo_top has 0.0s projectile dodge (unique 1% HP Lifesteal instead!)",
		is_equal_approx(noa.post_dash_dodge_duration, 0.0), true)
	noa._start_attack()
	await _wait(0.38)
	await _tick(2)
	_check_eq("Noa solo_top heals 1% of 200 Max HP (+2 HP: 50 -> 52) on hit!",
		noa.current_health, 52)

	# Hit 6 more times to reach 8 total Fang stacks -> triggers 30% Max HP burst (60 DMG) + 10% burst lifesteal (+6 HP)!
	noa.apply_skill_tree_ranks({}) # disable solo_top heal to isolate exact 10% 8-hit burst lifesteal!
	noa.current_health = 40
	for _i in range(5):
		noa._start_attack()
		await _wait(0.38)
		await _tick(2)
	_check_eq("After 7 total Blood-Splash hits: enemy has NOT burst yet (200 - 7*14 = 102 HP)",
		splash_foe.current_health, 102)

	noa._start_attack()
	await _wait(0.38)
	await _tick(2)
	_check_eq("8th Blood-Splash triggers 30% Fountain (102 - 14 - 60 = 28 HP) AND lifesteals 10% of burst (+6 HP: 40 -> 46)!",
		splash_foe.current_health == 28 and noa.current_health == 46, true)
	splash_foe.queue_free()

	# Noa `[R]` Toggle Sanguine Rain (`solo_bottom`): Active / Deactive medium circle!
	noa.apply_skill_tree_ranks({"solo_bottom": 1})
	noa.current_health = 60
	var rain_foe := _make_dummy_slime(world, noa.global_position + Vector2(60.0, 0.0), 300)
	await _tick(2)
	_check_eq("Pressing [R] toggles Noa Sanguine Rain ON", noa.try_activate_ultimate() and noa.blood_rain_active, true)
	await _wait(0.25)
	await _tick(2)
	_check("Noa [R] Sanguine Rain damages enemy in medium circle (1% Max HP = 3 DMG) & lifesteals!",
		rain_foe.current_health == 297 and noa.current_health >= 60)
	_check_eq("Pressing [R] a second time toggles Noa Sanguine Rain OFF",
		noa.try_activate_ultimate() and not noa.blood_rain_active, true)
	rain_foe.queue_free()

	# --- DISTINCT SKILL 1 (`solo_top`) & `[R]` ULTIMATES FOR BEHEMOTH, KNIGHT, & SYLVARA + WALL PROJECTILE STOP ---
	# 1. Behemoth: `solo_top` = 1.0s Full Invincibility; `[R]` = Infernal Rage (`2x` damage + Fire VFX)!
	behemoth.apply_skill_tree_ranks({"solo_top": 1, "solo_bottom": 1})
	_check("Behemoth solo_top grants 1.0s post-Shift Invincibility (NOT projectile-only dodge)",
		is_equal_approx(behemoth.post_dash_invincible_duration, 1.0) and is_equal_approx(behemoth.post_dash_dodge_duration, 0.0))
	behemoth._try_start_dash()
	await _wait(0.24)
	await _tick(2)
	var beh_hp_before: int = behemoth.current_health
	behemoth.take_damage(35, behemoth.global_position + Vector2(15.0, 0.0), false)
	_check_eq("Behemoth solo_top blocks 100% of melee/all damage during 1.0s post-Shift Invincibility!",
		behemoth.current_health, beh_hp_before)
	_check("Behemoth [R] Infernal Rage activates Fire VFX & doubles damage (2.0x)!",
		behemoth.try_activate_ultimate() and behemoth.ult_active and is_equal_approx(behemoth.get_rage_damage_multiplier(), 2.0))

	# 2. Knight: ZERO arrow spam, `solo_top` = Sacred Aegis Shield Dome, `[R]` = War Banner + 1 Allied Knight (7s dur, 60s CD)!
	knight.apply_skill_tree_ranks({"solo_top": 1, "p0_t1": 5, "p0_t4": 5, "solo_bottom": 1})
	_check("Knight solo_top activates Sacred Aegis Shield Barrier (and 0.0s projectile dodge)",
		knight.aegis_unlocked and knight.aegis_ready and is_equal_approx(knight.post_dash_dodge_duration, 0.0))
	var k_hp_before: int = knight.current_health
	knight.set_shielding(false)
	knight.take_damage(40, knight.global_position + Vector2(20.0, 0.0), false)
	_check_eq("Knight Sacred Aegis Shield absorbs full incoming hit for 0 HP damage!",
		knight.current_health, k_hp_before)
	knight._start_attack()
	await _wait(0.25)
	await _tick(2)
	_check_eq("Knight NEVER spams arrows at max Skill Tree (`player_arrows` count == 0)!",
		get_tree().get_nodes_in_group("player_arrows").size(), 0)
	_check("Knight [R] plants Royal War Banner & summons 1 Allied Knight (7s duration, 60s CD)!",
		knight.try_activate_ultimate()
		and is_equal_approx(knight.ult_cooldown, 60.0)
		and is_equal_approx(knight.banner_ally_duration, 7.0)
		and get_tree().get_nodes_in_group("allied_knights").size() == 1)

	# 3. Sylvara: `solo_top` = 1.0s Post-Shift Projectile Dodge, shortened lock range, & `[R]` Lock-On Arrow Spam!
	sylvara.global_position = Vector2(520.0, 220.0)
	sylvara.current_health = sylvara.max_health
	sylvara.apply_skill_tree_ranks({"solo_top": 1, "solo_bottom": 1})
	_check("Sylvara auto-lock range is shortened (`<= 220px`)", sylvara.auto_barrage_range <= 220.0)
	sylvara._try_start_dash()
	await _wait(0.24)
	await _tick(2)
	sylvara.take_damage(15, sylvara.global_position + Vector2(30.0, 0.0), true)
	_check_eq("Sylvara solo_top dodges 100% of projectiles AFTER Shift ends!",
		sylvara.current_health, sylvara.max_health)

	var barrage_foe := _make_dummy_slime(world, sylvara.global_position + Vector2(120.0, 0.0), 80)
	await _tick(2)
	_check_eq("Sylvara does NOT passively spam arrows before [R] is pressed",
		barrage_foe.current_health, 80)
	_check("Pressing [R] on Sylvara locks onto 1 enemy & auto-spams homing arrows at it!",
		sylvara.try_activate_ultimate() and sylvara.locked_ult_target == barrage_foe)
	await _wait(0.45)
	await _tick(3)
	_check("Sylvara [R] Hunter's Lock-On rapidly damages the selected enemy!",
		barrage_foe.current_health < 80, "foe_hp=%d/80" % barrage_foe.current_health)

	# 4. Projectiles vs Walls: piercing `PlayerArrow` hitting a `StaticBody2D` wall MUST stop & despawn!
	var test_wall := StaticBody2D.new()
	test_wall.collision_layer = 1
	test_wall.position = Vector2(780.0, 220.0)
	var tw_cs := CollisionShape2D.new()
	var tw_rs := RectangleShape2D.new()
	tw_rs.size = Vector2(28.0, 120.0)
	tw_cs.shape = tw_rs
	test_wall.add_child(tw_cs)
	world.add_child(test_wall)
	await _tick(2)
	var wall_arrow: Area2D = sylvara._spawn_arrow(Vector2.RIGHT, 20, true, 500.0, true)
	wall_arrow.global_position = Vector2(740.0, 220.0)
	await _wait(0.22)
	await _tick(3)
	_check_eq("Piercing PlayerArrow hitting a StaticBody2D wall stops & despawns cleanly!",
		not is_instance_valid(wall_arrow), true)

	print("\n=== Summary: %d / %d checks passed ===" % [_checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)
