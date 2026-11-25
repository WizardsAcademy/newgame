extends Node2D
## WaveSpawner - spawns scaled enemy waves in `STAGES` (Regions 1, 2, 3) and `SANDBOX`!
##
## Core Roguelite Loop:
##   - Standalone `.tscn` enemies keep their unit-test base stats when instantiated directly,
##     while `WaveSpawner` applies **steep exponential Wave HP & Damage scaling** (`1.85^(wave-1)`
##     plus Region 2 & Region 3 multipliers!) so creeps quickly become monstrously tanky,
##     forcing players to gather Herbs/Crystals, return to the Witch's Cottage to brew Majon,
##     unlock OP Skill Tree pillars + `[R]` Ultimates, and push deeper!
##   - Region 1 (`Whispering Jungle`): Slimes, Skeleton Archers, Stone Golems & `Forest Colossus`.
##   - Region 2 (`Cursed Bone Crypt`): Blink-Stalkers, Hex-Weavers, Bone Phalanx & `Malakor, Arch-Lich`.
##   - Region 3 (`Infernal Citadel`): Hellfire Imps, Void Snipers, Magma Juggernauts & `Igniszar, Dreadlord`.

signal wave_started(wave_number: int, enemy_count: int)
signal wave_cleared(wave_number: int)
signal enemy_spawned(enemy: Node)

const RegionEnemyScript := preload("res://scripts/enemies/region_enemy.gd")
const RegionBossScript := preload("res://scripts/enemies/region_boss.gd")

@export var slime_scene: PackedScene = preload("res://scenes/enemies/Slime.tscn")
@export var archer_scene: PackedScene = preload("res://scenes/enemies/Archer.tscn")
@export var golem_scene: PackedScene = preload("res://scenes/enemies/Golem.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/enemies/Colossus.tscn")
@export var boss_interval: int = 5

@export var archer_start_wave: int = 2
@export var golem_start_wave: int = 3
@export var archer_chance: float = 0.34
@export var golem_chance: float = 0.22

@export var elite_start_wave: int = 4
@export var elite_chance: float = 0.14
@export var elite_chance_per_wave: float = 0.04
@export var elite_chance_cap: float = 0.42

@export var base_count: int = 4
@export var count_per_wave: int = 2
@export var hp_per_wave: int = 22
@export var speed_per_wave: float = 5.5
@export var damage_step: int = 2

@export var spawn_interval: float = 0.30
@export var rest_between_waves: float = 1.2
@export var wait_for_upgrades_between_waves: bool = true
@export var first_wave_delay: float = 0.30
@export var autostart: bool = true

@export var arena_rect: Rect2 = Rect2(70, 70, 1140, 580)
@export var min_spawn_distance: float = 195.0
@export var max_spawn_distance: float = 360.0
@export var max_spawn_tries: int = 24
@export var full_map_aggro: bool = false

## Active Stage Region (`1` = Whispering Jungle, `2` = Cursed Bone Crypt, `3` = Infernal Citadel)
var stage_region_id: int = 1
var wave_number: int = 0
var enemies_alive: int = 0
var total_spawned: int = 0

var _stopped: bool = false
var _running: bool = false
var _continue_ok: bool = false
var _run_token: int = 0


static func compute_wave_hp_multiplier(wave_num: int, region_id: int = 1) -> float:
	var w := maxi(wave_num, 1)
	var reg := clampi(region_id, 1, 3)
	var region_mult := 1.0 if reg == 1 else (2.75 if reg == 2 else 6.20)
	# Brutal exponential HP scaling (`1.85^(w-1)`) so deeper waves demand OP Skill Tree upgrades!
	return region_mult * pow(1.85, float(w - 1))


static func compute_wave_dmg_multiplier(wave_num: int, region_id: int = 1) -> float:
	var w := maxi(wave_num, 1)
	var reg := clampi(region_id, 1, 3)
	var region_mult := 1.0 if reg == 1 else (1.55 if reg == 2 else 2.35)
	return region_mult * pow(1.26, float(w - 1))


func _ready() -> void:
	if autostart:
		start_spawning(true)


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
		await _sleep(rest_between_waves)
		if _is_cancelled(my_token):
			return

		if wait_for_upgrades_between_waves:
			await _wait_for_continue(my_token)
			if _is_cancelled(my_token):
				return


func _instantiate_enemy_for_active_region(current_wave: int) -> Node2D:
	# Sandbox or Region 1 (`Whispering Jungle`): classic Slime, Skeleton Archer, & Stone Golem!
	var reg := 1 if full_map_aggro else clampi(stage_region_id, 1, 3)
	if reg == 1:
		var scene := _pick_scene_for_wave(current_wave)
		var inst := scene.instantiate() as Node2D
		if inst != null and "variant_id" in inst:
			inst.variant_id = SlimeVariant.pick_for_wave(current_wave)
		return inst

	var renemy := RegionEnemyScript.new()
	if reg == 2:
		# Region 2 (`Cursed Bone Crypt`): Blink-Stalkers, Hex-Weavers, & Bone Phalanx!
		var roll2 := randf()
		if current_wave >= 2 and roll2 < 0.34:
			renemy.configure_kind(RegionEnemyScript.Kind.CRYPT_HEXER)
		elif current_wave >= 2 and roll2 < 0.58:
			renemy.configure_kind(RegionEnemyScript.Kind.CRYPT_PHALANX)
		else:
			renemy.configure_kind(RegionEnemyScript.Kind.CRYPT_STALKER)
	else:
		# Region 3 (`Infernal Citadel`): Hellfire Kamikaze Imps, Void Snipers, & Magma Juggernauts!
		var roll3 := randf()
		if roll3 < 0.36:
			renemy.configure_kind(RegionEnemyScript.Kind.CITADEL_SNIPER)
		elif roll3 < 0.62:
			renemy.configure_kind(RegionEnemyScript.Kind.CITADEL_BRUTE)
		else:
			renemy.configure_kind(RegionEnemyScript.Kind.CITADEL_IMP)
	return renemy


func _spawn_enemy() -> Node:
	var enemy := _instantiate_enemy_for_active_region(wave_number)
	if enemy == null:
		return null

	var reg := 1 if full_map_aggro else clampi(stage_region_id, 1, 3)
	var hp_mult := compute_wave_hp_multiplier(wave_number, reg)
	var dmg_mult := compute_wave_dmg_multiplier(wave_number, reg)

	var base_hp: int = int(enemy.get("max_health"))
	var scaled_hp: int = maxi(int(roundf(float(base_hp) * hp_mult)) + (wave_number - 1) * hp_per_wave, base_hp)
	enemy.set("max_health", scaled_hp)
	enemy.set("current_health", scaled_hp)

	if "move_speed" in enemy and "max_move_speed" in enemy:
		enemy.set("move_speed", minf(
			float(enemy.get("move_speed")) + float(wave_number - 1) * speed_per_wave,
			float(enemy.get("max_move_speed"))
		))
	if "attack_damage" in enemy:
		var base_dmg: int = int(enemy.get("attack_damage"))
		enemy.set("attack_damage", maxi(int(roundf(float(base_dmg) * dmg_mult)), base_dmg))

	if full_map_aggro and "detection_range" in enemy:
		enemy.set("detection_range", 2500.0)

	var parent := get_parent().get_node_or_null("Enemies")
	if parent == null:
		parent = get_parent()
	parent.add_child(enemy)

	if full_map_aggro and "detection_range" in enemy:
		enemy.set("detection_range", 2500.0)

	enemy.global_position = _pick_spawn_position()

	var is_elite_spawned: bool = false
	if wave_number >= elite_start_wave:
		var chance := minf(
			elite_chance + float(wave_number - elite_start_wave) * elite_chance_per_wave,
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

	var vis := enemy.get("visuals") as Node2D
	if vis != null:
		var target_scale := vis.scale
		vis.scale = Vector2.ZERO
		var tween := enemy.create_tween()
		tween.tween_property(vis, "scale", target_scale, 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	enemy_spawned.emit(enemy)
	return enemy


func _pick_scene_for_wave(current_wave: int) -> PackedScene:
	if current_wave >= golem_start_wave and randf() < golem_chance:
		return golem_scene
	if current_wave >= archer_start_wave and randf() < archer_chance:
		return archer_scene
	return slime_scene


func _spawn_boss() -> Node:
	var reg := 1 if full_map_aggro else clampi(stage_region_id, 1, 3)
	var boss: Node2D = null
	if reg == 1:
		boss = boss_scene.instantiate() as Node2D
	else:
		var rboss := RegionBossScript.new()
		rboss.configure_for_region(reg)
		boss = rboss

	if boss == null:
		return null

	var hp_mult := compute_wave_hp_multiplier(wave_number, reg)
	var dmg_mult := compute_wave_dmg_multiplier(wave_number, reg)

	var parent := get_parent().get_node_or_null("Enemies")
	if parent == null:
		parent = get_parent()
	parent.add_child(boss)

	# Scale Boss HP & Damage AFTER `_ready()` so `.tscn` defaults are multiplied cleanly!
	var base_bhp: int = int(boss.get("max_health"))
	var scaled_bhp: int = maxi(int(roundf(float(base_bhp) * hp_mult)), base_bhp)
	boss.set("max_health", scaled_bhp)
	boss.set("current_health", scaled_bhp)
	if "attack_damage" in boss:
		boss.set("attack_damage", maxi(int(roundf(float(int(boss.get("attack_damage"))) * dmg_mult)), int(boss.get("attack_damage"))))

	boss.global_position = _pick_spawn_position()

	total_spawned += 1
	boss.name = "Boss_R%d_W%d_%d" % [reg, wave_number, total_spawned]

	var vis := boss.get("visuals") as Node2D
	if vis != null:
		var target_sc := vis.scale
		vis.scale = Vector2.ZERO
		var tween := boss.create_tween()
		tween.tween_property(vis, "scale", target_sc, 0.5)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	enemy_spawned.emit(boss)
	return boss


func _is_clear_of_obstacles(pt: Vector2) -> bool:
	var root := get_parent()
	if root == null:
		return true
	var level := root.get_node_or_null("Level") as Node2D
	if level != null and level.visible:
		for ch in level.get_children():
			if ch is StaticBody2D and ch.name.begins_with("Obstacle"):
				if pt.distance_to((ch as Node2D).global_position) < 58.0:
					return false
	var stage_map := root.get_node_or_null("StageMap")
	if stage_map != null and stage_map.visible and stage_map.has_method("is_point_clear"):
		if not bool(stage_map.is_point_clear(pt, 52.0)):
			return false
	return true


func _pick_spawn_position() -> Vector2:
	var player_node: Node2D = get_tree().get_first_node_in_group("player")
	var ppos := player_node.global_position if (player_node != null and is_instance_valid(player_node)) else Vector2(-9999.0, -9999.0)

	for _i in range(max_spawn_tries):
		var candidate := Vector2(
			randf_range(arena_rect.position.x, arena_rect.end.x),
			randf_range(arena_rect.position.y, arena_rect.end.y),
		)
		if candidate.distance_to(ppos) >= min_spawn_distance and _is_clear_of_obstacles(candidate):
			return candidate

	return Vector2(640.0, 360.0)


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
