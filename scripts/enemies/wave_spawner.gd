extends Node2D
## WaveSpawner - the heartbeat of the roguelike loop.
##
## Spawns waves of enemies until the player dies. Each wave is a bit
## bigger, faster and tougher than the last. When every enemy of a wave
## is dead there is a short breather, then the next wave rolls in.
##
## Design notes (why it works the way it does):
##  - SIGNAL-based: the spawner never touches the HUD or Main directly.
##    It broadcasts wave_started / enemy_spawned / wave_cleared and lets
##    listeners connect. Deleting the HUD cannot break spawning.
##  - Spawnpoints are chosen inside the arena (inset from the walls) and
##    always at LEAST min_spawn_distance away from the player, so nothing
##    ever appears on top of Borzo out of nowhere.
##  - Enemy stat scaling is additive, like the slime death slide:
##    every wave nudges speed / health / damage up a little.
##
##   wave: 1    2    3    4    5   ...
##   count: 3   4    5    6    7   ...   (base_count + wave - monsters_per_wave_step...)
##   hp:   30   40   50   60   70   ...
##   speed: 45  50   55   60   65   ...  (capped at max_move_speed)

# =====================================================================
# SIGNALS
# =====================================================================

## A new wave started. `wave_number` is 1-based (1, 2, 3, ...).
signal wave_started(wave_number: int, enemy_count: int)

## All enemies of the current wave are dead.
signal wave_cleared(wave_number: int)

## A fresh enemy just appeared in the world (Main listens to wire its
## `died` signal into the kill counter).
signal enemy_spawned(enemy: Node)


# =====================================================================
# EXPORTED SETTINGS
# =====================================================================

## The scene to instantiate for each enemy.
@export var enemy_scene: PackedScene = preload("res://scenes/enemies/Slime.tscn")

## Enemies in wave 1. wave N has base_count + (N - 1) * count_per_wave.
@export var base_count: int = 3

## Extra enemies added per wave.
@export var count_per_wave: int = 1

## Slime health in wave 1; +hp_per_wave each wave.
@export var base_health: int = 30
@export var hp_per_wave: int = 10

## Slime speed in wave 1; +speed_per_wave each wave, capped.
@export var base_speed: float = 45.0
@export var speed_per_wave: float = 5.0
@export var max_speed: float = 90.0

## Slime damage in wave 1; +1 every damage_step waves.
@export var base_damage: int = 8
@export var damage_step: int = 3

## Seconds between enemies of the same wave trickling in.
@export var spawn_interval: float = 0.6

## Breather after a wave is cleared, before the next one starts.
@export var rest_between_waves: float = 2.5

## Delay after the scene boots before wave 1 starts (orientation time).
@export var first_wave_delay: float = 1.5

# --- Arena bounds (inset from the walls of the 1280x720 test arena) ---
## Spawn candidates are inside this rectangle.
@export var arena_rect: Rect2 = Rect2(70, 70, 1140, 580)

## Never spawn closer than this to the player.
@export var min_spawn_distance: float = 220.0

## Max tries to find a spawnpoint far enough from the player; after that
## we accept the last candidate (soft limit beats freezing).
@export var max_spawn_tries: int = 20


# =====================================================================
# STATE
# =====================================================================

## Current wave number, 0 = nothing started yet.
var wave_number: int = 0

## Enemies of the current wave still alive.
var enemies_alive: int = 0

## Total enemies ever spawned, used to build unique names.
var total_spawned: int = 0

## Set by stop_spawning() - the spawner finishes silently after that.
var _stopped: bool = false

## Guards the async _run_waves() loop so it can never start twice.
var _running: bool = false


# =====================================================================
# SETUP + MAIN LOOP
# =====================================================================

func _ready() -> void:
	start_spawning()


## Kicks off the async wave loop exactly once.
func start_spawning() -> void:
	if _running:
		return
	_running = true
	_run_waves()


## Player died: the war is over, no more waves. Safe to call any time.
func stop_spawning() -> void:
	_stopped = true


## The one long-running coroutine: delay -> wave -> rest -> wave ...
## Every `await` re-checks _stopped, so death cleanly unwinds it.
func _run_waves() -> void:
	await _sleep(first_wave_delay)

	while not _stopped:
		wave_number += 1
		var count := base_count + (wave_number - 1) * count_per_wave
		wave_started.emit(wave_number, count)
		print("[Wave] Wave ", wave_number, " starting - ", count, " enemies")

		enemies_alive = 0
		for i in count:
			await _sleep(spawn_interval)
			if _stopped:
				return
			_spawn_enemy()
			enemies_alive += 1

		# Wait until the player has squashed every enemy of this wave.
		while enemies_alive > 0 and not _stopped:
			await _sleep(0.25)
		if _stopped:
			return

		wave_cleared.emit(wave_number)
		print("[Wave] Wave ", wave_number, " cleared!")
		await _sleep(rest_between_waves)


## Create one scaled enemy, place it far from the player, and announce it.
func _spawn_enemy() -> void:
	var enemy := enemy_scene.instantiate()
	if enemy == null:
		return

	# --- Wave scaling: push the exported stats before add_child(), so
	# the enemy's _ready() clamps see the final values.
	enemy.max_health = base_health + (wave_number - 1) * hp_per_wave
	enemy.current_health = enemy.max_health
	enemy.move_speed = minf(base_speed + (wave_number - 1) * speed_per_wave, max_speed)
	# The floor() here is intentional: damage grows in whole steps of
	# `damage_step` waves, so 1 / 3 must discard the decimal part.
	enemy.attack_damage = base_damage + floori((wave_number - 1) / float(damage_step))

	# The Enemy parent must exist so damage numbers and kill counting
	# keep working exactly like the hand-placed slimes did.
	var parent := get_parent().get_node_or_null("Enemies")
	if parent == null:
		parent = get_parent()
	parent.add_child(enemy)

	enemy.global_position = _pick_spawn_position()
	# Give the enemy a readable name BEFORE the log line - otherwise Godot
	# shows auto-generated names like "@CharacterBody2D@2".
	total_spawned += 1
	enemy.name = "Slime_W%d_%d" % [wave_number, total_spawned]
	print("[Wave] Spawned ", enemy.name,
		" hp=", enemy.max_health,
		" speed=", enemy.move_speed,
		" dmg=", enemy.attack_damage)

	# Pop-in feel: scale from 0 up over a blink of an eye.
	enemy.visuals.scale = Vector2.ZERO
	var tween := enemy.create_tween()
	tween.tween_property(enemy.visuals, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	enemy_spawned.emit(enemy)


## A random point inside the arena, at least min_spawn_distance away
## from the player. Player may be null right after death - then any
## point works.
func _pick_spawn_position() -> Vector2:
	var player_node: Node2D = get_tree().get_first_node_in_group("player")
	var pos := arena_rect.position
	var tries := 0
	while tries < max_spawn_tries:
		tries += 1
		pos = Vector2(
			randf_range(arena_rect.position.x, arena_rect.end.x),
			randf_range(arena_rect.position.y, arena_rect.end.y),
		)
		if player_node == null or not is_instance_valid(player_node):
			break
		if pos.distance_to(player_node.global_position) >= min_spawn_distance:
			break
	return pos


## Sleep that survives the node leaving the tree.
func _sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# =====================================================================
# BOOK-KEEPING
# =====================================================================

## Call this the moment a wave enemy dies (Main forwards the enemy's
## `died` signal). When it reaches zero, the wave loop unblocks itself
## - see _run_waves().
func notify_enemy_died() -> void:
	enemies_alive = maxi(enemies_alive - 1, 0)
