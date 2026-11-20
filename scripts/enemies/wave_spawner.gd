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
##  - Wave 1-2 are pure slimes (learn the basics). From wave 3 archers
##    mix in, from wave 5 golems. Each type keeps its own base stats;
##    waves add a BONUS on top, so the golem always stays the tank.
##
##   wave:   1    2    3    4    5   ...
##   count:  3    4    5    6    7   ...  (base_count + wave - 1)
##   hp:   bonus +10 per wave on top of the type's own base

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

## The classic wave filler.
@export var slime_scene: PackedScene = preload("res://scenes/enemies/Slime.tscn")

## --- Phase 7: the enemy ROSTER ---------------------------------------
## Waves start pure (only slimes) and mix in new types as they get
## harder - the classic roguelike "unlock by escalation".
@export var archer_scene: PackedScene = preload("res://scenes/enemies/Archer.tscn")
@export var golem_scene: PackedScene = preload("res://scenes/enemies/Golem.tscn")

## --- Phase 8: the BOSS ------------------------------------------------
## Every boss_interval-th wave is a BOSS WAVE: nothing else spawns -
## the ringmaster alone. The player fights the colossus one on one,
## then the normal waves resume (harder than ever).
@export var boss_scene: PackedScene = preload("res://scenes/enemies/Colossus.tscn")
@export var boss_interval: int = 5

## First wave that can contain archers / golems.
@export var archer_start_wave: int = 3
@export var golem_start_wave: int = 5

## Chance (0..1) that any single enemy slot rolls that type, once
## unlocked. Slimes take whatever is left, so waves stay readable:
## wave 3 ≈ 70% slime / 30% archer, wave 5+ ≈ 55/30/15.
@export var archer_chance: float = 0.3
@export var golem_chance: float = 0.15

## --- Elites (hero versions of enemies, Phase 7) -----------------------
## First wave an elite can appear on, the base chance, how much the
## chance grows per wave, and the ceiling. Rough landing curve:
## wave 6 ≈ 8%, wave 10 ≈ 16%, wave 16+ ≈ 25% - by then the player is
## comparing elite kill TIMES, not whether they survive them.
@export var elite_start_wave: int = 6
@export var elite_chance: float = 0.08
@export var elite_chance_per_wave: float = 0.02
@export var elite_chance_cap: float = 0.25

## Enemies in wave 1. wave N has base_count + (N - 1) * count_per_wave.
@export var base_count: int = 3

## Extra enemies added per wave.
@export var count_per_wave: int = 1

## Bonus health every wave adds ON TOP of each type's own base stat.
@export var hp_per_wave: int = 10

## Bonus speed every wave adds, capped by each type's `max_move_speed`.
@export var speed_per_wave: float = 5.0

## Bonus damage of every type grows by +1 every `damage_step` waves.
@export var damage_step: int = 3

## Seconds between enemies of the same wave trickling in.
@export var spawn_interval: float = 0.6

## Breather after a wave is cleared, before the next one starts.
@export var rest_between_waves: float = 2.5

## True = after the breather, wait for continue_next_wave() (that is
## when Main shows the upgrade menu). False = old self-paced loop.
@export var wait_for_upgrades_between_waves: bool = true

## Delay after the scene boots before wave 1 starts (orientation time).
@export var first_wave_delay: float = 1.5

## When false (e.g. while Character Select is open), Main starts waves explicitly.
@export var autostart: bool = true

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

## Set by continue_next_wave(); read by _wait_for_continue().
var _continue_ok: bool = false


# =====================================================================
# SETUP + MAIN LOOP
# =====================================================================

func _ready() -> void:
	if autostart:
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
		var is_boss_wave: bool = wave_number % boss_interval == 0
		var count := 1 if is_boss_wave \
			else base_count + (wave_number - 1) * count_per_wave
		wave_started.emit(wave_number, count)
		print("[Wave] ", "BOSS WAVE " if is_boss_wave else "Wave ",
			wave_number, " starting - ", count, " enemies")

		enemies_alive = 0
		for i in count:
			await _sleep(spawn_interval)
			if _stopped:
				return
			if is_boss_wave:
				_spawn_boss()
			else:
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
		if _stopped:
			return

		# Roguelike gate: between waves the player picks an upgrade.
		# Main calls continue_next_wave() when the pick is done.
		if wait_for_upgrades_between_waves:
			await _wait_for_continue()
			if _stopped:
				return


## Create one scaled enemy of a random unlocked type, place it far from
## the player, and announce it.
func _spawn_enemy() -> void:
	var scene := _pick_scene_for_wave(wave_number)
	var enemy := scene.instantiate()
	if enemy == null:
		return

	# --- SLIME FAMILY ROLL -------------------------------------------
	# Separate from the archer/golem roll above: once a SLIME slot is
	# chosen, this decides WHICH slime fills it (grass/acid/ember/basalt).
	# Set before add_child() so _ready() -> _apply_variant() scales the
	# stats we are about to write, and so the elite roll below stacks on
	# top of the variant instead of overwriting it.
	if "variant_id" in enemy:
		enemy.variant_id = SlimeVariant.pick_for_wave(wave_number)

	# --- Wave scaling (additive ON TOP of each type's own base stats,
	# so the golem stays the tank and the slime stays the fodder) ------
	enemy.max_health += (wave_number - 1) * hp_per_wave
	enemy.current_health = enemy.max_health
	# Slow guys must not become fast - each enemy script carries its own
	# `max_move_speed` cap that matches its personality.
	enemy.move_speed = minf(
		enemy.move_speed + (wave_number - 1) * speed_per_wave,
		enemy.max_move_speed)
	# The floor() here is intentional: damage grows in whole steps of
	# `damage_step` waves, so 1 / 3 must discard the decimal part.
	enemy.attack_damage += floori((wave_number - 1) / float(damage_step))

	# The Enemies parent must exist so damage numbers and kill counting
	# keep working exactly like the hand-placed slimes did.
	var parent := get_parent().get_node_or_null("Enemies")
	if parent == null:
		parent = get_parent()
	parent.add_child(enemy)

	enemy.global_position = _pick_spawn_position()

	# --- ELITE ROLL ------------------------------------------------
	# From elite_start_wave on, every enemy has a growing chance to be
	# a hero version: golden ring at the feet, 3x HP, one extra ability.
	# The roll happens AFTER the wave stat bonus, so become_elite()
	# triples the FINAL health - the elite really is boss-lite.
	var is_elite_spawned: bool = false
	if wave_number >= elite_start_wave:
		var chance := minf(
			elite_chance + (wave_number - elite_start_wave) * elite_chance_per_wave,
			elite_chance_cap)
		if randf() < chance and enemy.has_method("become_elite"):
			enemy.become_elite()
			is_elite_spawned = true

	# Readable name: "<type>_W<wave>_<n>", e.g. Archer_W3_12. The scene's
	# root node name ("Slime"/"Archer"/"Golem") is the type tag - read it
	# BEFORE we overwrite enemy.name below.
	total_spawned += 1
	var type_name: String = String(enemy.name)
	# Slimes advertise their variant in the node name ("AcidSlime_W3_7"),
	# which makes the spawn log and remote-debugger tree self-explaining.
	if "variant_id" in enemy:
		type_name = SlimeVariant.display_tag(enemy.variant_id)
	if is_elite_spawned:
		type_name = "Elite" + type_name
	enemy.name = "%s_W%d_%d" % [type_name, wave_number, total_spawned]
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


## Weighted pick of which enemy type fills one slot of this wave.
## wave 1-2: pure slime (learn the basics) -> then new faces mix in.
func _pick_scene_for_wave(current_wave: int) -> PackedScene:
	if current_wave >= golem_start_wave and randf() < golem_chance:
		return golem_scene
	if current_wave >= archer_start_wave and randf() < archer_chance:
		return archer_scene
	return slime_scene


## The boss enters the arena: no wave scaling, no elite roll - its stats
## are exported and tuned as ONE design (docs/ROADMAP.md Phase 8). Boss
## waves are a pure 1v1 statement: the fight YOU learned waves for.
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

	# Same dramatic pop-in as regular enemies, just slower + bigger.
	boss.visuals.scale = Vector2.ZERO
	var tween := boss.create_tween()
	tween.tween_property(boss.visuals, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	enemy_spawned.emit(boss)


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


## Block until continue_next_wave() (or stop_spawning()). Polling keeps
## this dead simple and death-safe; a signal await born BEFORE the pick
## is also fine, but then Player death needs its own release - polling
## checks _stopped every tick, so nothing can hang.
func _wait_for_continue() -> void:
	while not _continue_ok and not _stopped:
		await _sleep(0.1)
	_continue_ok = false


## Upgrade pick done (or skipped) - the next wave may start. Safe to
## call any time, any number of times.
func continue_next_wave() -> void:
	_continue_ok = true


# =====================================================================
# BOOK-KEEPING
# =====================================================================

## Call this the moment a wave enemy dies (Main forwards the enemy's
## `died` signal). When it reaches zero, the wave loop unblocks itself
## - see _run_waves().
func notify_enemy_died() -> void:
	enemies_alive = maxi(enemies_alive - 1, 0)
