extends Node2D
## Root World Orchestrator (`Main`) — Medieval Guild Hub Lobby, Stage Progression, & Sandbox Arena.
##
## World Modes:
##   1. `LOBBY`:
##      - Game starts in the playable Medieval Castle Guild Hall (`LobbyHub`)!
##      - Walk up to the Oak Wardrobe (`Komod`) on the left to swap heroes.
##      - Walk into the East Training Room to test combos, stuns, bow charges,
##        and Noa's 2-Fang 30% Curse on the `TrainingDummy`.
##      - Walk through the `"STAGES"` Gate to start Dungeon Stage progression.
##      - Walk through the corner `"SANDBOX"` Door in the Training Room to enter
##        the `1280x720` Arena Sandbox Map!
##   2. `STAGES`:
##      - Progressive medieval dungeon stages (`Stage 1`, `Stage 2`, ...).
##      - Clearing a stage awards an Upgrade AND spawns a physical `"NEXT STAGE"`
##        Gate + `"LOBBY"` Return Door so you advance stage-by-stage at your pace.
##   3. `SANDBOX`:
##      - Uses the classic `1280x720` Stone Arena Map (`Level`) with faded Mini-Map
##        (`alpha = 0.42`), free wave combat, and a `"LOBBY"` Return Door (`Esc` also
##        returns to the Guild Lobby anytime!).

enum WorldMode { LOBBY, STAGES, SANDBOX }

const DOOR_TEX_PATH := "res://assets/textures/lobby_door.png"
const RevivalRitualFXScript := preload("res://scripts/fx/revival_ritual_fx.gd")
const ReagentDropScript := preload("res://scripts/world/reagent_drop.gd")

@onready var level_root: Node2D = $Level
@onready var lobby_hub: Node2D = $LobbyHub
@onready var player: Node2D = $Player
@onready var enemies_root: Node2D = $Enemies
@onready var wave_spawner: Node2D = $WaveSpawner
@onready var wave_label: Label = $UI/WaveLabel
@onready var hero_hud: Control = $UI/HeroHUD
@onready var hurt_flash: ColorRect = $UI/HurtFlash
@onready var game_over_screen: Control = $UI/GameOver
@onready var upgrade_menu: Control = $UI/UpgradeMenu
@onready var character_select_menu: Control = $UI/CharacterSelectMenu
@onready var witch_skill_tree_menu: WitchSkillTreeMenu = $UI/WitchSkillTreeMenu
@onready var minimap: MiniMap = $UI/MiniMap
@onready var pause_menu: PauseMenu = $UI/PauseMenu
@onready var dev_console: DevConsole = $UI/DevConsole

var world_mode: int = WorldMode.LOBBY
var total_damage_dealt: int = 0
var last_hit_damage: int = 0
var kills: int = 0
var wave_number: int = 0
var _last_health: int = -1
var _hurt_tween: Tween
var game_is_over: bool = false

var _arena_gates_root: Node2D = null
var _next_stage_gate_pos: Vector2 = Vector2(640.0, 56.0)
var _lobby_return_gate_pos: Vector2 = Vector2(64.0, 360.0)
var _next_stage_gate_active: bool = false
var _lobby_return_gate_active: bool = false
var _portal_grace_left: float = 0.0
var _retry_mode: int = WorldMode.LOBBY
var _is_reviving: bool = false


func _ready() -> void:
	# Load persistent profile (last chosen Hero, per-hero Cauldron Skill Tree, & Settings)!
	WitchCauldronProgression.load_from_disk()

	_arena_gates_root = Node2D.new()
	_arena_gates_root.name = "ArenaGates"
	add_child(_arena_gates_root)
	move_child(_arena_gates_root, player.get_index())

	if game_over_screen != null and game_over_screen.has_signal("not_yet_pressed"):
		game_over_screen.not_yet_pressed.connect(_on_not_yet_pressed)

	for enemy in enemies_root.get_children():
		_watch_enemy(enemy)

	wave_spawner.wave_started.connect(_on_wave_started)
	wave_spawner.wave_cleared.connect(_on_wave_cleared)
	wave_spawner.enemy_spawned.connect(_on_enemy_spawned)

	upgrade_menu.upgrade_chosen.connect(_on_upgrade_chosen)
	upgrade_menu.hide_menu()

	character_select_menu.character_highlighted.connect(_on_character_highlighted)
	character_select_menu.character_selected.connect(_on_character_selected)

	if witch_skill_tree_menu != null:
		witch_skill_tree_menu.skill_leveled_up.connect(_on_cauldron_skill_leveled_up)
		if witch_skill_tree_menu.has_signal("potion_brewed"):
			witch_skill_tree_menu.potion_brewed.connect(_on_cauldron_potion_brewed)
		if witch_skill_tree_menu.has_signal("tree_reset"):
			witch_skill_tree_menu.tree_reset.connect(_on_cauldron_tree_reset)
		witch_skill_tree_menu.menu_closed.connect(_on_cauldron_menu_closed)

	if dev_console != null:
		dev_console.command_wizard_triggered.connect(_on_console_wizard)
		dev_console.command_canoheil_triggered.connect(_on_console_canoheil)
		dev_console.console_toggled.connect(_on_console_toggled)

	if pause_menu != null:
		pause_menu.lobby_requested.connect(_on_pause_lobby_requested)

	if lobby_hub != null:
		lobby_hub.wardrobe_opened.connect(open_wardrobe)
		if lobby_hub.has_signal("cauldron_opened"):
			lobby_hub.cauldron_opened.connect(open_cauldron_skill_tree)
		if lobby_hub.has_signal("potion_brewed_in_world"):
			lobby_hub.potion_brewed_in_world.connect(_on_world_potion_brewed)
		lobby_hub.enter_stages_requested.connect(enter_stages)
		lobby_hub.enter_sandbox_requested.connect(enter_sandbox)

	if minimap != null:
		minimap.faded_alpha = 0.42
		minimap.modulate.a = 0.42
		minimap.set_arena_refs(level_root, player)

	if CharacterRegistry.quick_retry_same_hero:
		CharacterRegistry.quick_retry_same_hero = false
		if _retry_mode == WorldMode.SANDBOX:
			enter_sandbox()
		else:
			enter_stages()
	else:
		enter_lobby(CharacterRegistry.selected_id)


# =====================================================================
# WORLD TRANSITIONS: LOBBY / STAGES / SANDBOX
# =====================================================================

func _get_lobby_bounds() -> Rect2:
	if lobby_hub != null and "LOBBY_BOUNDS" in lobby_hub:
		return lobby_hub.LOBBY_BOUNDS
	return Rect2(0.0, 0.0, 480.0, 280.0)


func enter_lobby(char_id: String = "") -> void:
	var target_id := char_id if char_id != "" else CharacterRegistry.selected_id
	world_mode = WorldMode.LOBBY
	game_is_over = false
	game_over_screen.visible = false
	upgrade_menu.hide_menu()
	if character_select_menu.is_open():
		character_select_menu.hide_menu()
	if witch_skill_tree_menu != null and witch_skill_tree_menu.is_open():
		witch_skill_tree_menu.hide_menu()
	if pause_menu != null and pause_menu.is_open():
		pause_menu.close_menu()

	wave_spawner.stop_spawning()
	_clear_combat_enemies()
	_clear_arena_gates()
	_set_arena_level_active(false)

	var spawn_at := Vector2(214.0, 204.0)
	if lobby_hub != null and "SPAWN_POINT" in lobby_hub:
		spawn_at = lobby_hub.SPAWN_POINT
	var entry := _replace_player_instance(target_id, true, spawn_at)
	CharacterRegistry.selected_id = String(entry["id"])
	_apply_camera_bounds(_get_lobby_bounds())

	if lobby_hub != null:
		lobby_hub.activate_lobby(player)

	if minimap != null:
		minimap.visible = false
		minimap.set_player_accent(entry["accent"])

	wave_label.text = ""
	wave_label.visible = false
	_sync_hero_hud(entry)


func enter_stages() -> void:
	world_mode = WorldMode.STAGES
	_retry_mode = WorldMode.STAGES
	game_is_over = false
	game_over_screen.visible = false
	upgrade_menu.hide_menu()
	if character_select_menu.is_open():
		character_select_menu.hide_menu()
	if witch_skill_tree_menu != null and witch_skill_tree_menu.is_open():
		witch_skill_tree_menu.hide_menu()
	if pause_menu != null and pause_menu.is_open():
		pause_menu.close_menu()

	if lobby_hub != null:
		lobby_hub.deactivate_lobby()
	_clear_combat_enemies()
	_clear_arena_gates()
	_set_arena_level_active(true)

	var entry := _replace_player_instance(CharacterRegistry.selected_id, true, Vector2(220.0, 360.0))
	_apply_camera_bounds(Rect2(0.0, 0.0, 1280.0, 720.0))

	if minimap != null:
		minimap.visible = true
		minimap.is_in_menu = false
		minimap.modulate.a = minimap.faded_alpha
		minimap.set_arena_refs(level_root, player)
		minimap.set_player_accent(entry["accent"])

	wave_label.visible = true
	_sync_hero_hud(entry)
	wave_spawner.full_map_aggro = false
	wave_spawner.wait_for_upgrades_between_waves = true
	wave_spawner.start_spawning(true)


func enter_sandbox() -> void:
	world_mode = WorldMode.SANDBOX
	_retry_mode = WorldMode.SANDBOX
	game_is_over = false
	game_over_screen.visible = false
	upgrade_menu.hide_menu()
	if character_select_menu.is_open():
		character_select_menu.hide_menu()
	if witch_skill_tree_menu != null and witch_skill_tree_menu.is_open():
		witch_skill_tree_menu.hide_menu()
	if pause_menu != null and pause_menu.is_open():
		pause_menu.close_menu()

	if lobby_hub != null:
		lobby_hub.deactivate_lobby()
	_clear_combat_enemies()
	_clear_arena_gates()
	_set_arena_level_active(true)

	var entry := _replace_player_instance(CharacterRegistry.selected_id, true, Vector2(320.0, 360.0))
	_apply_camera_bounds(Rect2(0.0, 0.0, 1280.0, 720.0))

	if minimap != null:
		minimap.visible = true
		minimap.is_in_menu = false
		minimap.modulate.a = minimap.faded_alpha
		minimap.set_arena_refs(level_root, player)
		minimap.set_player_accent(entry["accent"])

	# Spawn a permanent LOBBY Return Door on the west side of the Sandbox Arena!
	_spawn_arena_gate(_lobby_return_gate_pos, "LOBBY", 1, Color(0.52, 1.0, 0.88))
	_lobby_return_gate_active = true
	_portal_grace_left = 0.65

	wave_label.visible = true
	_sync_hero_hud(entry)
	_pop_wave_label("SANDBOX ARENA", Color(0.55, 1.0, 0.88, 0.95))
	wave_spawner.full_map_aggro = true
	wave_spawner.wait_for_upgrades_between_waves = false
	wave_spawner.start_spawning(true)


func open_wardrobe() -> void:
	if game_is_over or character_select_menu.is_open():
		return
	if witch_skill_tree_menu != null and witch_skill_tree_menu.is_open():
		witch_skill_tree_menu.hide_menu()
	if player != null and "input_enabled" in player:
		player.input_enabled = false
	if lobby_hub != null:
		lobby_hub.interactions_enabled = false
	character_select_menu.show_menu(CharacterRegistry.selected_id)


func open_cauldron_skill_tree() -> void:
	if game_is_over or witch_skill_tree_menu == null or witch_skill_tree_menu.is_open():
		return
	if character_select_menu.is_open():
		character_select_menu.hide_menu()
	if player != null and "input_enabled" in player:
		player.input_enabled = false
	if lobby_hub != null:
		lobby_hub.interactions_enabled = false
	witch_skill_tree_menu.show_for_hero(CharacterRegistry.selected_id)


func _on_cauldron_menu_closed() -> void:
	if player != null and is_instance_valid(player) and "input_enabled" in player and not game_is_over:
		player.input_enabled = true
	if lobby_hub != null and world_mode == WorldMode.LOBBY:
		lobby_hub.interactions_enabled = true
		if lobby_hub.has_method("set_cauldron_cooldown"):
			lobby_hub.set_cauldron_cooldown(0.45)


func _on_cauldron_skill_leveled_up(hero_id: String, node_id: String, _new_level: int) -> void:
	if player != null and is_instance_valid(player):
		var cur_pos := player.position
		var keep_open := (witch_skill_tree_menu != null and witch_skill_tree_menu.is_open())
		var entry := _replace_player_instance(hero_id, not keep_open, cur_pos)
		if world_mode == WorldMode.LOBBY:
			_apply_camera_bounds(_get_lobby_bounds())
			if lobby_hub != null:
				lobby_hub.player_ref = player
				if lobby_hub.has_method("play_world_potion_handoff"):
					lobby_hub.play_world_potion_handoff(player, node_id == "solo_bottom" or node_id.begins_with("p0") or node_id.begins_with("p2"))
		else:
			_apply_camera_bounds(Rect2(0.0, 0.0, 1280.0, 720.0))
		_sync_hero_hud(entry)
		_spawn_status_popup(player.global_position + Vector2(-10.0, -14.0), "SKILL UP!", Color(0.76, 1.0, 0.84))


func _on_cauldron_potion_brewed(_hero_id: String, _new_points: int) -> void:
	if player != null and is_instance_valid(player):
		if world_mode == WorldMode.LOBBY and lobby_hub != null and lobby_hub.has_method("play_world_potion_handoff"):
			lobby_hub.play_world_potion_handoff(player, true)
		_spawn_status_popup(player.global_position + Vector2(-14.0, -14.0), "+1 MAJON!", Color(0.86, 0.62, 1.0))
	if hero_hud != null:
		hero_hud.queue_redraw()


func _on_world_potion_brewed(brewed_count: int) -> void:
	if player != null and is_instance_valid(player):
		_spawn_status_popup(player.global_position + Vector2(-18.0, -16.0),
			"+%d MAJON BREWED!" % brewed_count, Color(0.90, 0.64, 1.0))
	if witch_skill_tree_menu != null:
		witch_skill_tree_menu.refresh_if_open()
	if hero_hud != null:
		hero_hud.queue_redraw()


func _on_console_toggled(is_open_now: bool) -> void:
	if player == null or not is_instance_valid(player) or not ("input_enabled" in player):
		return
	if is_open_now:
		player.input_enabled = false
	else:
		var menu_blocking := (
			game_is_over
			or (character_select_menu != null and character_select_menu.is_open())
			or (witch_skill_tree_menu != null and witch_skill_tree_menu.is_open())
			or (pause_menu != null and pause_menu.is_open())
		)
		player.input_enabled = not menu_blocking


func _on_console_wizard() -> void:
	WitchCauldronProgression.grant_wizard_points(10000)
	if witch_skill_tree_menu != null:
		witch_skill_tree_menu.refresh_if_open()
	if hero_hud != null:
		hero_hud.queue_redraw()
	if player != null and is_instance_valid(player):
		_spawn_status_popup(player.global_position + Vector2(-24.0, -18.0), "+10000 SKILL PTS!", Color(1.0, 0.88, 0.34))


func _on_console_canoheil() -> void:
	WitchCauldronProgression.reset_all_heroes()
	if player != null and is_instance_valid(player):
		var cur_pos := player.position
		var blocking := (
			game_is_over
			or (dev_console != null and dev_console.is_open())
			or (character_select_menu != null and character_select_menu.is_open())
			or (witch_skill_tree_menu != null and witch_skill_tree_menu.is_open())
		)
		var entry := _replace_player_instance(CharacterRegistry.selected_id, not blocking, cur_pos)
		if world_mode == WorldMode.LOBBY:
			_apply_camera_bounds(_get_lobby_bounds())
			if lobby_hub != null:
				lobby_hub.player_ref = player
		else:
			_apply_camera_bounds(Rect2(0.0, 0.0, 1280.0, 720.0))
		_sync_hero_hud(entry)
		_spawn_status_popup(player.global_position + Vector2(-20.0, -18.0), "HEROES RESET!", Color(0.58, 0.96, 1.0))
	if witch_skill_tree_menu != null:
		witch_skill_tree_menu.refresh_if_open()


func _on_cauldron_tree_reset(hero_id: String) -> void:
	if player != null and is_instance_valid(player):
		var cur_pos := player.position
		var keep_open := (witch_skill_tree_menu != null and witch_skill_tree_menu.is_open())
		var entry := _replace_player_instance(hero_id, not keep_open, cur_pos)
		if world_mode == WorldMode.LOBBY:
			_apply_camera_bounds(_get_lobby_bounds())
			if lobby_hub != null:
				lobby_hub.player_ref = player
		else:
			_apply_camera_bounds(Rect2(0.0, 0.0, 1280.0, 720.0))
		_sync_hero_hud(entry)


func _on_pause_lobby_requested() -> void:
	enter_lobby()


## Backwards-compatible helper (used by tests & direct character swap):
## equips `char_id` AND persists `selected_hero` so reopening the game launches
## straight into the Witch's Cottage as this exact hero!
func select_character(char_id: String, start_arena_immediately: bool = false) -> void:
	if character_select_menu != null and character_select_menu.is_open():
		character_select_menu.hide_menu()

	var norm := WitchCauldronProgression.save_selected_hero(char_id)

	if start_arena_immediately:
		enter_sandbox()
		return

	if world_mode == WorldMode.LOBBY:
		var wardrobe_exit := Vector2(114.0, 156.0)
		if lobby_hub != null and "WARDROBE_EXIT_POS" in lobby_hub:
			wardrobe_exit = lobby_hub.WARDROBE_EXIT_POS
		var entry := _replace_player_instance(norm, true, wardrobe_exit)
		_apply_camera_bounds(_get_lobby_bounds())
		if lobby_hub != null:
			lobby_hub.player_ref = player
			lobby_hub.interactions_enabled = true
			lobby_hub.set_wardrobe_cooldown(0.75)
		if minimap != null:
			minimap.visible = false
			minimap.set_player_accent(entry["accent"])
		_sync_hero_hud(entry)
	elif world_mode == WorldMode.SANDBOX:
		enter_sandbox()
	else:
		enter_stages()


func _on_character_highlighted(char_id: String) -> void:
	if not character_select_menu.is_open():
		return
	var entry := CharacterRegistry.get_entry(char_id)
	var preview_pos := player.position if player != null and is_instance_valid(player) else Vector2(114.0, 156.0)
	_replace_player_instance(String(entry["id"]), false, preview_pos)
	if world_mode == WorldMode.LOBBY:
		_apply_camera_bounds(_get_lobby_bounds())
		if lobby_hub != null:
			lobby_hub.player_ref = player
	else:
		_apply_camera_bounds(Rect2(0.0, 0.0, 1280.0, 720.0))
	_sync_hero_hud(entry)


func _on_character_selected(char_id: String) -> void:
	select_character(char_id, false)


# =====================================================================
# PLAYER & WORLD HELPERS
# =====================================================================

func _set_arena_level_active(active: bool) -> void:
	if level_root == null:
		return
	level_root.visible = active
	for child in level_root.get_children():
		if child is StaticBody2D:
			var col := child.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if col != null:
				col.set_deferred("disabled", not active)


func _clear_combat_enemies() -> void:
	for child in enemies_root.get_children():
		child.queue_free()
	for node in get_tree().get_nodes_in_group("player_arrows"):
		node.queue_free()
	for rdrop in get_tree().get_nodes_in_group("reagent_drops"):
		rdrop.queue_free()


func _clear_arena_gates() -> void:
	_next_stage_gate_active = false
	_lobby_return_gate_active = false
	if _arena_gates_root != null:
		for child in _arena_gates_root.get_children():
			child.queue_free()


func _spawn_arena_gate(at: Vector2, label_txt: String, frame_idx: int, sign_col: Color) -> void:
	if _arena_gates_root == null:
		return
	var holder := Node2D.new()
	holder.position = at

	if ResourceLoader.exists(DOOR_TEX_PATH):
		var dtex: Texture2D = load(DOOR_TEX_PATH)
		if dtex != null:
			var sp := Sprite2D.new()
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var at_tex := AtlasTexture.new()
			at_tex.atlas = dtex
			at_tex.region = Rect2(float(frame_idx * 64), 0.0, 64.0, 64.0)
			sp.texture = at_tex
			sp.scale = Vector2(0.75, 0.75)
			holder.add_child(sp)

	var lbl := Label.new()
	lbl.text = label_txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", sign_col)
	lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.05, 0.95))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.position = Vector2(-52.0, -44.0)
	lbl.size = Vector2(104.0, 16.0)
	holder.add_child(lbl)

	_arena_gates_root.add_child(holder)


func _apply_camera_bounds(bounds: Rect2) -> void:
	if player == null or not is_instance_valid(player):
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.limit_left = int(bounds.position.x)
		cam.limit_top = int(bounds.position.y)
		cam.limit_right = int(bounds.end.x)
		cam.limit_bottom = int(bounds.end.y)


func _replace_player_instance(char_id: String, enable_combat: bool, spawn_pos: Vector2) -> Dictionary:
	var entry := CharacterRegistry.get_entry(char_id)
	if player != null and is_instance_valid(player):
		remove_child(player)
		player.queue_free()

	var new_player := CharacterRegistry.instantiate_hero(String(entry["id"]))
	new_player.name = "Player"
	new_player.position = spawn_pos
	add_child(new_player)
	move_child(new_player, enemies_root.get_index())
	WitchCauldronProgression.apply_to_hero_instance(new_player)
	player = new_player

	if "input_enabled" in player:
		player.input_enabled = enable_combat

	player.attack_hit.connect(_on_player_attack_hit)
	player.health_changed.connect(_on_player_health_changed)
	player.player_died.connect(_on_player_died)
	if player.has_signal("energy_changed"):
		player.energy_changed.connect(_on_player_energy_changed)
	if player.has_signal("hurt_triggered"):
		player.hurt_triggered.connect(_on_player_hurt_triggered)
	if player.has_signal("damage_mitigated"):
		player.damage_mitigated.connect(_on_player_damage_mitigated)

	_last_health = player.current_health
	return entry


func _sync_hero_hud(entry: Dictionary) -> void:
	if hero_hud == null or player == null or not is_instance_valid(player):
		return
	hero_hud.visible = true
	hero_hud.bind_hero_entry(entry)
	hero_hud.set_health_values(int(player.current_health), int(player.max_health))
	var cur_en := float(player.current_energy) if "current_energy" in player else 100.0
	var max_en := float(player.max_energy) if "max_energy" in player else 100.0
	var exhausted: bool = (player.get("shield_exhausted") == true)
	hero_hud.set_energy_values(cur_en, max_en, exhausted)


func _process(delta: float) -> void:
	if _portal_grace_left > 0.0:
		_portal_grace_left = maxf(_portal_grace_left - delta, 0.0)
		return

	if game_is_over or player == null or not is_instance_valid(player):
		return
	if world_mode == WorldMode.LOBBY:
		return

	var ppos := player.global_position
	if _lobby_return_gate_active and ppos.distance_to(_lobby_return_gate_pos + Vector2(0.0, 8.0)) <= 28.0:
		_portal_grace_left = 0.8
		enter_lobby()
		return

	if _next_stage_gate_active and ppos.distance_to(_next_stage_gate_pos + Vector2(0.0, 10.0)) <= 30.0:
		_portal_grace_left = 0.8
		_clear_arena_gates()
		if player.has_method("heal"):
			player.heal(maxi(int(round(float(player.max_health) * 0.15)), 8))
		wave_spawner.continue_next_wave()


# =====================================================================
# SIGNAL HANDLERS
# =====================================================================

func _watch_enemy(enemy: Node) -> void:
	if enemy != null and enemy.has_signal("died"):
		var cb := _on_enemy_died.bind(enemy)
		if not enemy.died.is_connected(cb):
			enemy.died.connect(cb)


func _spawn_reagent_drop(at_pos: Vector2, amount: int, frame_idx: int, label_str: String) -> Node2D:
	var drop := ReagentDropScript.new()
	drop.name = "ReagentDrop"
	add_child(drop)
	drop.setup(at_pos, amount, frame_idx, label_str, player)
	drop.collected.connect(_on_reagent_collected)
	return drop


func _on_reagent_collected(amount: int, item_name: String, world_pos: Vector2) -> void:
	WitchCauldronProgression.add_reagents(amount)
	_spawn_status_popup(world_pos + Vector2(-12.0, -10.0), "+%d %s" % [amount, item_name], Color(0.56, 1.0, 0.74))
	if witch_skill_tree_menu != null:
		witch_skill_tree_menu.refresh_if_open()
	if hero_hud != null:
		hero_hud.queue_redraw()


func _on_player_attack_hit(enemy: Node) -> void:
	var dealt: int = int(player.attack_damage)
	if "last_dealt_damage" in player and int(player.last_dealt_damage) > 0:
		dealt = int(player.last_dealt_damage)
	var from_dash: bool = player.get("last_hit_was_dash") == true

	last_hit_damage = dealt
	total_damage_dealt += dealt

	if enemy != null and is_instance_valid(enemy):
		var num_color := Color(0.45, 0.95, 1.0) if from_dash else Color(1.0, 0.95, 0.4)
		_spawn_damage_number((enemy as Node2D).global_position, dealt, num_color)


func _on_enemy_died() -> void:
	kills += 1
	if world_mode != WorldMode.LOBBY:
		wave_spawner.notify_enemy_died()


func _on_wave_started(number: int, _enemy_count: int) -> void:
	wave_number = number
	var prefix := "Sandbox Wave %d" if world_mode == WorldMode.SANDBOX else "Stage %d" % number
	if world_mode == WorldMode.SANDBOX:
		prefix = "Sandbox Wave %d" % number
	_pop_wave_label(prefix)


func _on_wave_cleared(number: int) -> void:
	if game_is_over:
		return
	# Award +1 Witch Brew Point for the active hero's Cauldron Skill Tree (NO 3-card popup!)
	WitchCauldronProgression.add_brew_points(CharacterRegistry.selected_id, 1)
	if world_mode == WorldMode.SANDBOX:
		_pop_wave_label("Wave %d Cleared!  +1 Brew Point" % number, Color(0.65, 1.0, 0.82))
	else:
		_pop_wave_label("Stage %d Cleared!  +1 Brew Point" % number, Color(0.72, 1.0, 0.76))
		_after_stage_reward()


func _show_upgrade_menu() -> void:
	var options := UpgradePool.roll(player, 3)
	if options.is_empty():
		_after_stage_reward()
		return
	if player != null and "input_enabled" in player:
		player.input_enabled = false
	upgrade_menu.show_menu(options)


func _on_upgrade_chosen(id: String) -> void:
	UpgradePool.apply(id, player)
	if hero_hud != null and player != null:
		hero_hud.set_health_values(int(player.current_health), int(player.max_health))
		if "current_energy" in player:
			hero_hud.set_energy_values(float(player.current_energy), float(player.max_energy), player.get("shield_exhausted") == true)
	if player != null and "input_enabled" in player and not game_is_over:
		player.input_enabled = true
	_after_stage_reward()


func _after_stage_reward() -> void:
	if world_mode == WorldMode.SANDBOX:
		wave_spawner.continue_next_wave()
	else:
		# Spawn physical NEXT STAGE + LOBBY doors so Stages play room-by-room!
		_clear_arena_gates()
		_spawn_arena_gate(_next_stage_gate_pos, "NEXT STAGE", 0, Color(1.0, 0.88, 0.44))
		_spawn_arena_gate(_lobby_return_gate_pos, "LOBBY", 1, Color(0.52, 1.0, 0.88))
		_next_stage_gate_active = true
		_lobby_return_gate_active = true
		_portal_grace_left = 0.55
		_pop_wave_label("Enter NEXT STAGE Gate", Color(1.0, 0.90, 0.52))


func _pop_wave_label(new_text: String, color := Color(1, 0.95, 0.75, 0.95)) -> void:
	wave_label.visible = true
	wave_label.text = new_text
	wave_label.add_theme_color_override("font_color", color)
	await get_tree().process_frame
	if not is_inside_tree() or wave_label == null:
		return
	wave_label.pivot_offset = wave_label.size / 2.0
	wave_label.modulate.a = 0.0
	wave_label.scale = Vector2(1.45, 1.45)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave_label, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave_label, "modulate:a", 1.0, 0.15)


func _on_enemy_spawned(enemy: Node) -> void:
	_watch_enemy(enemy)


func _on_player_damage_mitigated(blocked_amount: int, final_amount: int) -> void:
	if player != null and is_instance_valid(player) and blocked_amount > 0:
		var label_str := "BLOCKED!" if final_amount == 0 else "ARMOR -%d" % blocked_amount
		var col := Color(0.45, 0.96, 0.68) if final_amount == 0 else Color(0.68, 0.84, 1.0)
		_spawn_status_popup(player.global_position + Vector2(0.0, -10.0), label_str, col)


func _on_player_energy_changed(cur_en: float, max_en: float) -> void:
	if hero_hud != null and player != null:
		hero_hud.set_energy_values(cur_en, max_en, player.get("shield_exhausted") == true)


func _on_player_hurt_triggered(_amount: int = 0) -> void:
	if hero_hud != null:
		hero_hud.trigger_hurt_reaction()
	_flash_hurt()


func _on_player_health_changed(current: int, max_health: int) -> void:
	if hero_hud != null:
		hero_hud.set_health_values(current, max_health)
	if _last_health >= 0 and current < _last_health:
		if player != null and player.get("last_health_change_was_self_cost") == true:
			_spawn_status_popup(player.global_position + Vector2(-4.0, -8.0),
				"-%d HP" % (_last_health - current), Color(0.96, 0.24, 0.38))
	elif _last_health >= 0 and current > _last_health and player != null:
		_spawn_heal_number(player.global_position, current - _last_health)
	_last_health = current


func _flash_hurt() -> void:
	if _hurt_tween and _hurt_tween.is_valid():
		_hurt_tween.kill()
	hurt_flash.color = Color(0.85, 0.08, 0.12, 0.22)
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(hurt_flash, "color:a", 0.0, 0.35)


func _on_player_died() -> void:
	game_is_over = true
	_is_reviving = false
	if upgrade_menu != null:
		upgrade_menu.hide_menu()
	wave_spawner.stop_spawning()
	ScreenShake.shake(6.0, 0.35)
	if game_over_screen != null:
		if game_over_screen.has_method("present_game_over"):
			game_over_screen.present_game_over(0.75)
		else:
			game_over_screen.visible = true


## Triggered when the player clicks `[ NOT YET ]` on the `DEAD AGAIN?` screen:
## opens an Arcane Magic Circle beneath the fallen hero, strikes down a Pillar
## of Celestial Light to lift them back up, and teleports them into the Lobby!
func _on_not_yet_pressed() -> void:
	if _is_reviving:
		return
	_is_reviving = true

	if game_over_screen != null:
		if game_over_screen.has_method("dismiss_for_revival"):
			game_over_screen.dismiss_for_revival()
		else:
			game_over_screen.visible = false

	_clear_combat_enemies()

	if player != null and is_instance_valid(player):
		var ritual := RevivalRitualFXScript.new()
		ritual.name = "RevivalRitualFX"
		ritual.setup(player, 1.25)
		add_child(ritual)
		await ritual.ritual_completed
	else:
		await get_tree().create_timer(0.4).timeout

	if not is_inside_tree():
		return

	# Radiant golden-white arrival flash into the Guild Hub Lobby!
	if hurt_flash != null:
		if _hurt_tween and _hurt_tween.is_valid():
			_hurt_tween.kill()
		hurt_flash.color = Color(1.0, 0.96, 0.80, 0.55)
		_hurt_tween = create_tween()
		_hurt_tween.tween_property(hurt_flash, "color:a", 0.0, 0.45)

	_is_reviving = false
	CharacterRegistry.quick_retry_same_hero = false
	enter_lobby()


func _unhandled_input(event: InputEvent) -> void:
	if dev_console != null and dev_console.is_open():
		return
	if character_select_menu != null and character_select_menu.is_open():
		return
	if witch_skill_tree_menu != null and witch_skill_tree_menu.is_open():
		return
	if pause_menu != null and pause_menu.is_open():
		return

	if game_is_over:
		if _is_reviving:
			return
		if event is InputEventKey and event.pressed and not event.echo:
			var k := (event as InputEventKey).keycode
			if k == KEY_ESCAPE:
				_on_not_yet_pressed()
				return
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var kc := (event as InputEventKey).keycode
		if kc == KEY_ESCAPE and pause_menu != null:
			pause_menu.open_menu()
			get_viewport().set_input_as_handled()


# =====================================================================
# FLOATING NUMBERS
# =====================================================================

func _spawn_damage_number(at: Vector2, amount: int, color := Color(1, 0.95, 0.4)) -> void:
	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 10)
	label.position = at + Vector2(-8, -22)
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 14.0, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)


func _spawn_heal_number(at: Vector2, amount: int) -> void:
	var label := Label.new()
	label.text = "+%d" % amount
	label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.58))
	label.add_theme_font_size_override("font_size", 9)
	label.position = at + Vector2(-6, -24)
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 14.0, 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.chain().tween_callback(label.queue_free)


func _spawn_status_popup(at: Vector2, txt: String, color: Color) -> void:
	var label := Label.new()
	label.text = txt
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_font_size_override("font_size", 8)
	label.position = at + Vector2(-14, -22)
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 12.0, 0.48)
	tween.tween_property(label, "modulate:a", 0.0, 0.48)
	tween.chain().tween_callback(label.queue_free)
