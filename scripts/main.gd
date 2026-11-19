extends Node2D
## Level root for the arena.
##
## Its ONLY job is wiring: it listens to signals broadcast by the player
## and the enemies and shows them on screen. It never touches health,
## hitboxes or AI - that is the whole point of the signal-based design.
##
##   Player.attack_hit(enemy)     -> floating "-10" + "damage dealt" label
##   Slime.died                   -> kill counter
##   Slime.health_changed(hp,max) -> (nothing yet - a good place for a
##                                   target health bar in a later phase)
##   WaveSpawner.wave_started(n)  -> "Wave N" banner in the HUD
##   WaveSpawner.wave_cleared(n)  -> "cleared" message in the HUD
##   WaveSpawner.enemy_spawned(e) -> watch the new enemy like the others
##
## Because the level connects these signals, deleting the HUD cannot
## break combat, and adding a combo counter does not touch player.gd.


# =====================================================================
# NODE REFERENCES
# =====================================================================

@onready var player: Node2D = $Player
@onready var enemies_root: Node2D = $Enemies
@onready var stats_label: Label = $UI/Stats
@onready var player_health_bar: Node2D = $UI/PlayerHealthBar
@onready var game_over_screen: Control = $UI/GameOver
@onready var wave_spawner: Node2D = $WaveSpawner
@onready var wave_label: Label = $UI/WaveLabel
@onready var hurt_flash: ColorRect = $UI/HurtFlash
@onready var upgrade_menu: Control = $UI/UpgradeMenu


# =====================================================================
# STATE (shown in the debug label)
# =====================================================================

var total_damage_dealt: int = 0
var last_hit_damage: int = 0
var kills: int = 0
## Current wave number, shown in the debug label.
var wave_number: int = 0
## Health from the previous health_changed signal - used to detect
## whether the latest change was damage (a decrease) or healing.
var _last_health: int = -1
## Tween of the hurt flash, kept so a new hit can cancel the old fade
## instead of fighting it.
var _hurt_tween: Tween
## True once the player died and the Game Over overlay is showing.
var game_is_over: bool = false


# =====================================================================
# SETUP
# =====================================================================

func _ready() -> void:
	# `connect` only stores a reference to the callable; nothing happens
	# until the signal is emitted. If the signal already exists (it is
	# declared with `signal attack_hit(enemy)` in player.gd), passing a
	# Callable with the wrong number of arguments is an error, so the
	# signatures must match.
	player.attack_hit.connect(_on_player_attack_hit)
	player.health_changed.connect(_on_player_health_changed)
	player.player_died.connect(_on_player_died)

	for enemy in enemies_root.get_children():
		_watch_enemy(enemy)

	# --- Wave system wiring -------------------------------------------
	# The spawner owns the wave state machine; the level only listens.
	wave_spawner.wave_started.connect(_on_wave_started)
	wave_spawner.wave_cleared.connect(_on_wave_cleared)
	wave_spawner.enemy_spawned.connect(_on_enemy_spawned)

	# --- Upgrade system wiring (phase 7)-------------------------------
	# Loop: wave cleared -> roll 3 -> player picks -> apply -> release
	# the spawner. The pool applies the stats itself; Main only glues.
	upgrade_menu.upgrade_chosen.connect(_on_upgrade_chosen)
	upgrade_menu.hide_menu()  # start closed

	# Seed the health bar with the starting health BEFORE anything can
	# hit us (the bar redraws on every health_changed anyway).
	player_health_bar.set_health(player.current_health, player.max_health)

	_update_stats_label()


## Called for enemies that appear later (spawners, waves, ...).
func _watch_enemy(enemy: Node) -> void:
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)


# =====================================================================
# SIGNAL HANDLERS
# =====================================================================

func _on_player_attack_hit(enemy: Node) -> void:
	# The player already applied the damage; we just present it.
	last_hit_damage = player.attack_damage
	total_damage_dealt += last_hit_damage

	_spawn_damage_number(enemy.global_position, last_hit_damage)
	_update_stats_label()


func _on_enemy_died() -> void:
	kills += 1
	# Tell the spawner an enemy is gone - the wave is "cleared" only
	# when its live counter reaches zero, so every death must be
	# reported back. This is the one place where the level feeds a
	# signal *into* the spawner instead of only listening.
	wave_spawner.notify_enemy_died()
	_update_stats_label()


# ---------------------------------------------------------------------
# WAVE SIGNAL HANDLERS
# ---------------------------------------------------------------------

func _on_wave_started(number: int, _enemy_count: int) -> void:
	wave_number = number
	_pop_wave_label("Wave %d" % number)
	_update_stats_label()


func _on_wave_cleared(number: int) -> void:
	# Green banner instead of the usual warm colour, so the eye can
	# tell "you won this one" apart from "a new one begins".
	_pop_wave_label("Wave %d cleared!" % number, Color(0.7, 1.0, 0.75))

	# --- The roguelike reward: roll 1-of-3 upgrades ------------------
	# (Only while the player is alive - a corpse gets no rewards and,
	# when the run restarts, everything resets with the scene.)
	if not game_is_over:
		_show_upgrade_menu()


func _show_upgrade_menu() -> void:
	var options := UpgradePool.roll(player, 3)
	if options.is_empty():
		# Nothing left in the pool (all stats maxed): skip gracefully.
		wave_spawner.continue_next_wave()
		return
	upgrade_menu.show_menu(options)


func _on_upgrade_chosen(id: String) -> void:
	var feedback := UpgradePool.apply(id, player)
	print("[Upgrade] picked ", id, " -> ", feedback)
	# Release the wave machine - the next wave rolls in.
	wave_spawner.continue_next_wave()


## Set the banner text and play a quick "pop": it starts bigger and
## transparent, then claps down to normal size.
##
## GOTCHA: scaling a Control pivots at its top-LEFT corner by default,
## which looks like a slide instead of a pop - so we centre `pivot_offset`
## first. The one-frame wait lets the label lay out its new text, because
## `size` updates on the next layout pass, not the moment we set `text`.
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
	# Enemies spawned by the spawner get the same treatment as the
	# static ones used to: kill counting + damage numbers.
	_watch_enemy(enemy)


func _on_player_health_changed(current: int, max_health: int) -> void:
	player_health_bar.set_health(current, max_health)
	# A DECREASE in health means Borzo took a hit: flash the whole
	# screen red for a moment. (Healing would be an increase - ignored.)
	if _last_health >= 0 and current < _last_health:
		_flash_hurt()
	_last_health = current


## Brief full-screen red flash when the player takes damage.
func _flash_hurt() -> void:
	# Kill any flash still fading from the previous hit so two hits in
	# a row don't make two tweens fight over the same alpha property.
	if _hurt_tween and _hurt_tween.is_valid():
		_hurt_tween.kill()
	hurt_flash.color.a = 0.22
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(hurt_flash, "color:a", 0.0, 0.35)


func _on_player_died() -> void:
	game_is_over = true
	game_over_screen.visible = true
	# A dead player picks no upgrades - close the menu if it was open.
	if upgrade_menu != null:
		upgrade_menu.hide_menu()
		# And let the wave loop drain quietly (it checks _stopped).
		wave_spawner.continue_next_wave()
	# Stop the wave machine immediately - no point spawning enemies
	# into an empty arena while the Game Over screen is up.
	wave_spawner.stop_spawning()
	# Optional juice: a last big shudder when Borzo hits the floor.
	ScreenShake.shake(6.0, 0.35)


func _unhandled_input(event: InputEvent) -> void:
	# Only meaningful on the Game Over screen: reload the whole scene.
	# Everything (health, slimes, labels) resets with it, because all
	# state lives in nodes of this scene or its children.
	if game_is_over and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _update_stats_label() -> void:
	if stats_label == null:
		return
	# Enemies are no longer static scene children (the spawner owns
	# them), so we show the wave number instead of a live count.
	stats_label.text = "damage dealt: %d   last hit: %d   kills: %d   wave: %d" % [
		total_damage_dealt,
		last_hit_damage,
		kills,
		wave_number,
	]


# =====================================================================
# FLOATING DAMAGE NUMBERS
# =====================================================================

## A Label that pops out of the enemy, drifts up and fades, then frees
## itself - the classic "-10" you see in every action game.
## Created in code (no extra scene file) to keep this example compact.
func _spawn_damage_number(at: Vector2, amount: int) -> void:
	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
	label.add_theme_font_size_override("font_size", 10)
	# Centre the text so it appears to grow out of the enemy's head.
	label.position = at + Vector2(-8, -22)
	# Labels inside a Node2D world need to be behind the UI canvas;
	# adding it to the level root puts it in world space.
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 14.0, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)
