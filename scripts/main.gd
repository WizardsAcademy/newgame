extends Node2D
## Level root for the arena.
##
## Signal-based HUD & run orchestrator (docs/ARCHITECTURE.md):
##   CharacterSelectMenu.character_selected -> spawn chosen hero + start waves
##   Player.attack_hit(enemy)               -> floating damage number + stats
##   Player.health_changed(hp, max_hp)      -> health bar + red flash / heal popup
##   Player.dash_cooldown_changed(rem, dur) -> Shift-Dash cooldown bar
##   Player.player_died                     -> Game Over overlay
##   WaveSpawner.wave_started / cleared     -> wave banner + UpgradeMenu


# =====================================================================
# NODE REFERENCES
# =====================================================================

@onready var player: Node2D = $Player
@onready var enemies_root: Node2D = $Enemies
@onready var stats_label: Label = $UI/Stats
@onready var hp_text_label: Label = $UI/HPText
@onready var player_health_bar: Node2D = $UI/PlayerHealthBar
@onready var dash_text_label: Label = $UI/DashText
@onready var dash_bar: Node2D = $UI/DashBar
@onready var game_over_screen: Control = $UI/GameOver
@onready var game_over_subtitle: Label = $UI/GameOver/Subtitle
@onready var wave_spawner: Node2D = $WaveSpawner
@onready var wave_label: Label = $UI/WaveLabel
@onready var hurt_flash: ColorRect = $UI/HurtFlash
@onready var upgrade_menu: Control = $UI/UpgradeMenu
@onready var character_select_menu: Control = $UI/CharacterSelectMenu


# =====================================================================
# STATE
# =====================================================================

var total_damage_dealt: int = 0
var last_hit_damage: int = 0
var kills: int = 0
var wave_number: int = 0
var _last_health: int = -1
var _hurt_tween: Tween
var game_is_over: bool = false
var _spawn_origin: Vector2 = Vector2(320, 180)


# =====================================================================
# SETUP
# =====================================================================

func _ready() -> void:
	if player != null:
		_spawn_origin = player.position

	for enemy in enemies_root.get_children():
		_watch_enemy(enemy)

	# --- Wave system wiring -------------------------------------------
	wave_spawner.wave_started.connect(_on_wave_started)
	wave_spawner.wave_cleared.connect(_on_wave_cleared)
	wave_spawner.enemy_spawned.connect(_on_enemy_spawned)

	# --- Upgrade menu wiring ------------------------------------------
	upgrade_menu.upgrade_chosen.connect(_on_upgrade_chosen)
	upgrade_menu.hide_menu()

	# --- Character Select wiring --------------------------------------
	character_select_menu.character_selected.connect(_on_character_selected)

	if CharacterRegistry.quick_retry_same_hero:
		CharacterRegistry.quick_retry_same_hero = false
		select_character(CharacterRegistry.selected_id)
	else:
		# Hold the default player still until the user picks their hero.
		if player != null and "input_enabled" in player:
			player.input_enabled = false
		player_health_bar.set_health(100, 100)
		dash_bar.set_health(1.0, 1.0)
		_update_stats_label()
		character_select_menu.show_menu(CharacterRegistry.selected_id)


## Spawn the chosen hero (`"borzo"`, `"bahman"`, `"pari"`, `"shabnam"`),
## wire all player signals into the HUD, and begin Wave 1.
func select_character(char_id: String) -> void:
	if character_select_menu != null and character_select_menu.is_open():
		character_select_menu.hide_menu()

	var entry := CharacterRegistry.get_entry(char_id)
	CharacterRegistry.selected_id = String(entry["id"])

	# Replace the placeholder Player node cleanly.
	if player != null and is_instance_valid(player):
		remove_child(player)
		player.queue_free()

	var new_player := CharacterRegistry.instantiate_hero(String(entry["id"]))
	new_player.name = "Player"
	new_player.position = _spawn_origin
	add_child(new_player)
	# Keep Player right above Enemies in draw order, matching main.tscn.
	move_child(new_player, enemies_root.get_index())
	player = new_player

	player.attack_hit.connect(_on_player_attack_hit)
	player.health_changed.connect(_on_player_health_changed)
	player.player_died.connect(_on_player_died)
	if player.has_signal("dash_cooldown_changed"):
		player.dash_cooldown_changed.connect(_on_dash_cooldown_changed)

	if "input_enabled" in player:
		player.input_enabled = true

	_last_health = player.current_health
	hp_text_label.text = String(entry["name"]).to_upper()
	player_health_bar.set_health(player.current_health, player.max_health)
	dash_bar.set_health(1.0, 1.0)
	dash_text_label.text = "DASH"
	game_over_subtitle.text = "%s  Press R to retry  |  C / Esc: choose hero" % String(entry["death_line"])

	_update_stats_label()
	wave_spawner.start_spawning()


func _on_character_selected(char_id: String) -> void:
	select_character(char_id)


func _watch_enemy(enemy: Node) -> void:
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)


# =====================================================================
# SIGNAL HANDLERS
# =====================================================================

func _on_player_attack_hit(enemy: Node) -> void:
	var dealt: int = player.attack_damage
	if "last_dealt_damage" in player and int(player.last_dealt_damage) > 0:
		dealt = int(player.last_dealt_damage)
	var from_dash: bool = bool(player.get("last_hit_was_dash"))

	last_hit_damage = dealt
	total_damage_dealt += dealt

	if enemy != null and is_instance_valid(enemy):
		var num_color := Color(0.45, 0.95, 1.0) if from_dash else Color(1.0, 0.95, 0.4)
		_spawn_damage_number((enemy as Node2D).global_position, dealt, num_color)
	_update_stats_label()


func _on_dash_cooldown_changed(remaining: float, duration: float) -> void:
	var total := maxf(duration, 0.01)
	var ready_ratio := clampf(1.0 - remaining / total, 0.0, 1.0)
	dash_bar.set_health(ready_ratio, 1.0)
	dash_text_label.text = "DASH" if remaining <= 0.01 else "%.1fs" % remaining


func _on_enemy_died() -> void:
	kills += 1
	wave_spawner.notify_enemy_died()
	_update_stats_label()


# ---------------------------------------------------------------------
# WAVE & UPGRADE HANDLERS
# ---------------------------------------------------------------------

func _on_wave_started(number: int, _enemy_count: int) -> void:
	wave_number = number
	_pop_wave_label("Wave %d" % number)
	_update_stats_label()


func _on_wave_cleared(number: int) -> void:
	_pop_wave_label("Wave %d cleared!" % number, Color(0.7, 1.0, 0.75))
	if not game_is_over:
		_show_upgrade_menu()


func _show_upgrade_menu() -> void:
	var options := UpgradePool.roll(player, 3)
	if options.is_empty():
		wave_spawner.continue_next_wave()
		return
	if player != null and "input_enabled" in player:
		player.input_enabled = false
	upgrade_menu.show_menu(options)


func _on_upgrade_chosen(id: String) -> void:
	var feedback := UpgradePool.apply(id, player)
	print("[Upgrade] picked ", id, " -> ", feedback)
	if player != null and "input_enabled" in player and not game_is_over:
		player.input_enabled = true
	wave_spawner.continue_next_wave()


func _pop_wave_label(new_text: String, color := Color(1, 0.95, 0.75, 0.95)) -> void:
	wave_label.text = new_text
	wave_label.add_theme_color_override("font_color", color)
	await get_tree().process_frame
	wave_label.pivot_offset = wave_label.size / 2.0
	wave_label.modulate.a = 0.0
	wave_label.scale = Vector2(1.6, 1.6)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave_label, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave_label, "modulate:a", 1.0, 0.15)


func _on_enemy_spawned(enemy: Node) -> void:
	_watch_enemy(enemy)


func _on_player_health_changed(current: int, max_health: int) -> void:
	player_health_bar.set_health(current, max_health)
	if _last_health >= 0 and current < _last_health:
		_flash_hurt()
	elif _last_health >= 0 and current > _last_health and player != null:
		_spawn_heal_number(player.global_position, current - _last_health)
	_last_health = current


func _flash_hurt() -> void:
	if _hurt_tween and _hurt_tween.is_valid():
		_hurt_tween.kill()
	hurt_flash.color.a = 0.22
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(hurt_flash, "color:a", 0.0, 0.35)


func _on_player_died() -> void:
	game_is_over = true
	game_over_screen.visible = true
	if upgrade_menu != null:
		upgrade_menu.hide_menu()
		wave_spawner.continue_next_wave()
	wave_spawner.stop_spawning()
	ScreenShake.shake(6.0, 0.35)


func _unhandled_input(event: InputEvent) -> void:
	if character_select_menu != null and character_select_menu.is_open():
		return

	if game_is_over:
		if event.is_action_pressed("restart"):
			CharacterRegistry.quick_retry_same_hero = true
			get_tree().reload_current_scene()
			return
		if event is InputEventKey and event.pressed and not event.echo:
			var k := (event as InputEventKey).keycode
			if k == KEY_C or k == KEY_ESCAPE:
				CharacterRegistry.quick_retry_same_hero = false
				get_tree().reload_current_scene()
				return
		return

	# Press Esc anytime during a run to return to the Hero Select screen.
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			CharacterRegistry.quick_retry_same_hero = false
			get_tree().reload_current_scene()


func _update_stats_label() -> void:
	if stats_label == null:
		return
	var hero_label := String(CharacterRegistry.get_entry(CharacterRegistry.selected_id)["name"])
	stats_label.text = "hero: %s   dmg: %d   last: %d   kills: %d   wave: %d" % [
		hero_label,
		total_damage_dealt,
		last_hit_damage,
		kills,
		wave_number,
	]


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
	tween.tween_property(label, "position:y", label.position.y - 12.0, 0.45)
	tween.tween_property(label, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(label.queue_free)
