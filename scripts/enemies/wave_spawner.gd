extends Node2D
## WaveSpawner - spawns scaled enemy waves in `STAGES` and `SANDBOX` modes.
##
## Guarantees:
##   1. Safe stop/restart across Lobby <-> Sandbox <-> Stages transitions via
##      monotonic `_run_token` (calling `stop_spawning()` in Lobby never blocks
##      subsequent `start_spawning()` calls!).
##   2. Spawned enemies appear in an active ring (`165..340 px`) around the
##      player with full-arena `detection_range = 2400.0` so every enemy in
##      BOTH Sandbox and Stages immediately locks onto and chases the player!

signal wave_started(wave_number: int, enemy_count: int)
signal wave_cleared(wave_number: int)
signal enemy_spawned(enemy: Node)

@export var slime_scene: PackedScene = preload("res://scenes/enemies/Slime.tscn")
@export var archer_scene: PackedScene = preload("res://scenes/enemies/Archer.tscn")
@export var golem_scene: PackedScene = preload("res://scenes/enemies/Golem.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/enemies/Colossus.tscn")
@export var boss_interval: int = 5

@export var archer_start_wave: int = 3
@export var golem_start_wave: int = 5
@export var archer_chance: float = 0.3
@export var golem_chance: float = 0.15

@export var elite_start_wave: int = 6
@export var elite_chance: float = 0.08
@export var elite_chance_per_wave: float = 0.02
@export var elite_chance_cap: float = 0.25

@export var base_count: int = 4
@export var count_per_wave: int = 1
@export var hp_per_wave: int = 10
@export var speed_per_wave: float = 5.0
@export var damage_step: int = 3

@export var spawn_interval: float = 0.32
@export var rest_between_waves: float = 1.4
@export var wait_for_upgrades_between_waves: bool = true
@export var first_wave_delay: float = 0.30
@export var autostart: bool = true

@export var arena_rect: Rect2 = Rect2(70, 70, 1140, 580)
@export var min_spawn_distance: float = 195.0
@export var max_spawn_distance: float = 360.0
@export var max_spawn_tries: int = 24
@export var full_map_aggro: bool = false

var wave_number: int = 0
var enemies_alive: int = 0
var total_spawned: int = 0

var _stopped: bool = false
var _running: bool = false
var _continue_ok: bool = false
var _run_token: int = 0


func _ready() -> void:
	if autostart:
		start_spawning(true)


## Starts (or restarts) the wave loop cleanly.
func start_spawning(reset_waves: bool = true) -> void:
	_run_token += 1
	var my_token := _run_token
	_stopped = false
	_continue_ok = false
	if reset_waves:
		wave_number = 0
	enemies_alive = 0
	_running = true
	_run_waves(my_token)


## Halts any in-flight wave coroutine immediately.
func stop_spawning() -> void:
	_run_token += 1
	_stopped = true
	_running = false
	_continue_ok = false
	enemies_alive = 0


func _is_cancelled(my_token: int) -> bool:
	return _stopped or my_token != _run_token or not is_inside_tree()


func _run_waves(my_token: int) -> void:
	await _sleep(first_wave_delay)
	if _is_cancelled(my_token):
		return

	while not _is_cancelled(my_token):
		wave_number += 1
		var is_boss_wave: bool = wave_number % boss_interval == 0
		var count := 1 if is_boss_wave else base_count + (wave_number - 1) * count_per_wave
		wave_started.emit(wave_number, count)
		print("[Wave] ", "BOSS WAVE " if is_boss_wave else "Wave ",
			wave_number, " starting - ", count, " enemies")

		enemies_alive = 0
		for i in count:
			if i > 0:
				await _sleep(spawn_interval)
			if _is_cancelled(my_token):
				return
			if is_boss_wave:
				_spawn_boss()
			else:
				_spawn_enemy()
			enemies_alive += 1

		while enemies_alive > 0 and not _is_cancelled(my_token):
			# Self-heal `enemies_alive` if all combat enemies were cleared externally
			var parent := get_parent().get_node_or_null("Enemies") if get_parent() != null else null
			if parent != null:
				var living := 0
				for ch in parent.get_children():
					if ch != null and is_instance_valid(ch) and ch.get("is_dead") != true:
						living += 1
				if living == 0 and enemies_alive > 0:
					enemies_alive = 0
					break
			await _sleep(0.20)
		if _is_cancelled(my_token):
			return

		wave_cleared.emit(wave_number)
		print("[Wave] Wave ", wave_number, " cleared!")
		await _sleep(rest_between_waves)
		if _is_cancelled(my_token):
			return

		if wait_for_upgrades_between_waves:
			await _wait_for_continue(my_token)
			if _is_cancelled(my_token):
				return


func _spawn_enemy() -> void:
	var scene := _pick_scene_for_wave(wave_number)
	var enemy := scene.instantiate()
	if enemy == null:
		return

	if "variant_id" in enemy:
		enemy.variant_id = SlimeVariant.pick_for_wave(wave_number)

	enemy.max_health += (wave_number - 1) * hp_per_wave
	enemy.current_health = enemy.max_health
	enemy.move_speed = minf(
		enemy.move_speed + (wave_number - 1) * speed_per_wave,
		enemy.max_move_speed)
	enemy.attack_damage += floori((wave_number - 1) / float(damage_step))

	# In SANDBOX (`full_map_aggro == true`), enemies see the player from anywhere on the map & chase!
	# In STAGES (`full_map_aggro == false`), enemies keep their normal default detection radius (`adi`).
	if full_map_aggro and "detection_range" in enemy:
		enemy.detection_range = 2500.0

	var parent := get_parent().get_node_or_null("Enemies")
	if parent == null:
		parent = get_parent()
	parent.add_child(enemy)

	if full_map_aggro and "detection_range" in enemy:
		enemy.detection_range = 2500.0

	enemy.global_position = _pick_spawn_position()

	var is_elite_spawned: bool = false
	if wave_number >= elite_start_wave:
		var chance := minf(
			elite_chance + (wave_number - elite_start_wave) * elite_chance_per_wave,
			elite_chance_cap)
		if randf() < chance and enemy.has_method("become_elite"):
			enemy.become_elite()
			is_elite_spawned = true

	total_spawned += 1
	var type_name: String = String(enemy.name)
	if "variant_id" in enemy:
		type_name = SlimeVariant.display_tag(enemy.variant_id)
	if is_elite_spawned:
		type_name = "Elite" + type_name
	enemy.name = "%s_W%d_%d" % [type_name, wave_number, total_spawned]
	print("[Wave] Spawned ", enemy.name,
		" hp=", enemy.max_health,
		" speed=", enemy.move_speed,
		" dmg=", enemy.attack_damage)

	enemy.visuals.scale = Vector2.ZERO
	var tween := enemy.create_tween()
	tween.tween_property(enemy.visuals, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	enemy_spawned.emit(enemy)


func _pick_scene_for_wave(current_wave: int) -> PackedScene:
	if current_wave >= golem_start_wave and randf() < golem_chance:
		return golem_scene
	if current_wave >= archer_start_wave and randf() < archer_chance:
		return archer_scene
	return slime_scene


func _spawn_boss() -> void:
	var boss := boss_scene.instantiate()
	if boss == null:
		return
	var parent := get_parent().get_node_or_null("Enemies")
	if parent == null:
		parent = get_parent()
	parent.add_child(boss)
	boss.global_position = _pick_spawn_position()

	total_spawned += 1
	boss.name = "Colossus_W%d_%d" % [wave_number, total_spawned]
	print("[Wave] Spawned ", boss.name, " hp=", boss.max_health)

	boss.visuals.scale = Vector2.ZERO
	var tween := boss.create_tween()
	tween.tween_property(boss.visuals, "scale", Vector2.ONE, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	enemy_spawned.emit(boss)


func _is_clear_of_obstacles(pt: Vector2) -> bool:
	var level := get_parent().get_node_or_null("Level") if get_parent() != null else null
	if level == null:
		return true
	for ch in level.get_children():
		if ch is StaticBody2D and ch.name.begins_with("Obstacle"):
			if pt.distance_to((ch as Node2D).global_position) < 58.0:
				return false
	return true


func _pick_spawn_position() -> Vector2:
	var player_node: Node2D = get_tree().get_first_node_in_group("player")
	var ppos := player_node.global_position if (player_node != null and is_instance_valid(player_node)) else Vector2(-9999.0, -9999.0)

	# In STAGES (`full_map_aggro == false`), spawn normally across the whole arena (`>= 220 px` away).
	# In SANDBOX (`full_map_aggro == true`), spawn across the arena too — every enemy has `detection_range = 2500`
	# so they spot the player from EVERYWHERE on the map and chase immediately!
	for _i in range(max_spawn_tries):
		var candidate := Vector2(
			randf_range(arena_rect.position.x, arena_rect.end.x),
			randf_range(arena_rect.position.y, arena_rect.end.y),
		)
		if candidate.distance_to(ppos) >= min_spawn_distance and _is_clear_of_obstacles(candidate):
			return candidate

	return Vector2(
		randf_range(arena_rect.position.x, arena_rect.end.x),
		randf_range(arena_rect.position.y, arena_rect.end.y),
	)


func _sleep(seconds: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout


func _wait_for_continue(my_token: int) -> void:
	while not _continue_ok and not _is_cancelled(my_token):
		await _sleep(0.1)
	_continue_ok = false


func continue_next_wave() -> void:
	_continue_ok = true


func notify_enemy_died() -> void:
	enemies_alive = maxi(enemies_alive - 1, 0)
