extends CharacterBody2D
## "Slime" - the first enemy of the game, and the tutorial for every
## attacking enemy that followed.
##
## What the AI does (this file):
##  - sleeps until the player is within `detection_range`,
##  - crawls toward them and stops just short (`stop_distance`),
##  - telegraphs, lunges, hits, recovers, waits out `attack_cooldown`,
##  - takes damage, flashes white, pops into goo when its health runs out.
##
## THE SLIME FAMILY (scripts/enemies/slime_variant.gd)
##  This one script drives FOUR creatures. `variant_id` picks which member of
##  the family we are, and everything variant-specific is data:
##    grass  - the baseline (unchanged behaviour)
##    acid   - slower, tankier, leaves a damaging pool when it dies
##    ember  - faster, frailer, detonates shortly after dying
##    basalt - slow and heavy, its spiked body damages on contact
##  The wave spawner sets `variant_id` BEFORE the node enters the tree, so
##  `_ready()` -> `_apply_variant()` can scale the stats the spawner already
##  wrote (wave bonus first, then the variant multiplier - same ordering the
##  elite helper uses).
##
## What it LOOKS like (scripts/enemies/slime_visuals.gd):
##  a rounded jelly that breathes, blinks, hops, squashes on landing,
##  winds up red before a lunge and splats into a puddle on death.
##  The split matters: every number in this file is gameplay, every pixel
##  is over there.
##
## =========================================================================
## THE TWO HALVES OF A HIT (beginner-friendly)
## =========================================================================
## A melee hit needs TWO boxes that are allowed to notice each other.
## Layers are numbers 1-32 in the Inspector, but in the .tscn text file
## they are stored as a bitmask: layer 2 = 2, layer 3 = 4, layer 4 = 8,
## layer 5 = 16 (= 1 << (layer_number - 1)).
##
##   layer 1  walls / world
##   layer 2  player BODY        collision_layer = 2
##   layer 3  enemy BODY         collision_layer = 4
##   layer 4  player HITBOX      collision_layer = 8   mask = 16
##   layer 5  enemy HURTBOX      collision_layer = 16  mask = 8
##
## Detection is NOT mutual. On every CollisionObject2D:
##   * `collision_layer` = which layers *I* exist on (who am I?)
##   * `collision_mask`  = which layers *I* look for (who do I care about?)
##
## The fist (layer 4) looks for layer 5, and the hurtbox (layer 5) looks
## for layer 4, so they meet in the middle. If you forget one half, no
## signal is ever emitted and the punch silently does nothing - the #1
## melee bug in Godot. Note that the fist does NOT look for layer 3: it
## never needs enemy bodies, because take_damage() is reached through the
## hurtbox. That is also why slimes cannot punch each other by accident.
##
## When they meet, the PLAYER decides the damage (`take_damage` below).
## The enemy never checks "was I punched?" on its own; that keeps the
## combat logic in exactly one place.


# =====================================================================
# SIGNALS
# =====================================================================
# Emitted after any hit; `current_health` is already updated.
signal health_changed(current_health: int, max_health: int)

## Emitted once, the moment the last hit lands (before the corpse fades).
signal died


# =====================================================================
# EXPORTED SETTINGS (editable per-instance in the Inspector)
# =====================================================================

@export var max_health: int = 30
@export var current_health: int = 30

## Pixels per second while chasing the player.
@export var move_speed: float = 40.0

## Hard cap the wave spawner may push us to (matches the old max_speed).
@export var max_move_speed: float = 90.0

## The slime only starts chasing when the player is this close (pixels).
@export var detection_range: float = 200.0

## Stop distance: once the slime is this close (centre to centre) it
## stops moving so it does not shove the player around. 24 px is roughly
## one sprite width plus a small gap.
@export var stop_distance: float = 24.0

## How long the white flash lasts after a hit, in seconds.
@export var flash_duration: float = 0.1

## How long the death "squash and fade" takes before queue_free().
@export var death_duration: float = 0.3

## The slime's signature green. Drives the goo droplets / death splat.
## `_apply_variant()` overwrites it with the variant's goo colour, so the
## droplets always match the body without any extra art.
@export var body_color: Color = Color("6ec866")

## Which member of the slime family this is: "grass" / "acid" / "ember" /
## "basalt" (see slime_variant.gd). The wave spawner overwrites this right
## after instantiate(), before the node is added to the tree.
@export var variant_id: String = "grass"

## Damage the BODY deals on touch, per `contact_interval`. Only the Basalt
## slime uses this (0 = off, so the other three behave exactly as before).
@export var contact_damage: int = 0

## How close the player has to be for contact damage (px, centre to centre).
@export var contact_range: float = 20.0

## Seconds between contact-damage ticks.
@export var contact_interval: float = 0.8

# --- Phase 4: the slime ATTACKS back ----------------------------------

## Damage dealt when the lunge connects with the player.
@export var attack_damage: int = 8

## The slime starts winding up an attack once the player is this close.
@export var attack_trigger_range: float = 34.0

## Pixels per second while lunging at the player.
@export var lunge_speed: float = 170.0

## Telegraph duration: the squash + red tint warning BEFORE the lunge.
## Longer = more forgiving to dodge.
@export var telegraph_duration: float = 0.35

## Seconds the lunge lasts (hitbox is live during this window).
@export var lunge_duration: float = 0.25

## Breather after a lunge before the next attack can start.
@export var attack_cooldown: float = 1.2


# =====================================================================
# STATE
# =====================================================================

## True as soon as the last hit landed. The slime stops moving,
## stops accepting damage, and starts its death animation.
var is_dead: bool = false

## True while the white flash is showing (used to not restart it).
var _is_flashing: bool = false

## Set by the wave spawner for hero versions (golden ring, 3x HP).
var is_elite: bool = false

# --- Phase 4 attack state machine --------------------------------------
# CHASE      -> too far: walk to the player
# TELEGRAPH  -> close: squash + tint red (the DODGE ME warning)
# LUNGE      -> spring at where the player was, hitbox live
# RECOVER    -> lunge over, brief slide to a stop
# COOLDOWN   -> back to chasing, but cannot re-attack yet
enum AttackState { CHASE, TELEGRAPH, LUNGE, RECOVER, COOLDOWN }

var _attack_state: AttackState = AttackState.CHASE
var _attack_timer: float = 0.0
var _lunge_dir: Vector2 = Vector2.RIGHT
## True when the CURRENT lunge already hit the player (one hit per lunge).
var _has_hit_this_lunge: bool = false


# =====================================================================
# NODE REFERENCES
# =====================================================================

## Variant death effects live in the ARENA, not on the slime: the corpse is
## queue_free()d 0.3 s after dying, which is far too early for an ember fuse.
const AcidPoolScene := preload("res://scenes/fx/AcidPool.tscn")
const EmberBlastScene := preload("res://scenes/fx/EmberBlast.tscn")

## The look lives in slime_visuals.gd (12-pose family sheet, hop cycle,
## squash & stretch, hit flash, death splat). The AI below never touches
## pixels, and the variant only chooses which row of that sheet is drawn.
@onready var visuals: SlimeVisuals = $Visuals
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_area: Area2D = $AttackArea
@onready var health_bar: Node2D = $HealthBar  # custom-drawn bar, see health_bar.gd
@onready var hit_sfx: AudioStreamPlayer = $HitSFX
@onready var death_sfx: AudioStreamPlayer = $DeathSFX

## The player is looked up once at spawn time. `group: "player"` is set
## by Player.tscn, so this keeps working no matter where the player is in
## the scene tree.
var player: Node2D = null

## Resolved variant data (filled in _apply_variant()).
var variant_data: Dictionary = {}

## Which death/contact mechanic this variant runs (SlimeVariant.Mechanic).
var mechanic: int = SlimeVariant.Mechanic.NONE

## Time left before the body may hurt the player again.
var _contact_cooldown: float = 0.0


# =====================================================================
# SETUP
# =====================================================================

func _ready() -> void:
	# Variant FIRST: it rewrites max_health / speeds / damage / telegraph
	# and the sheet row before anything else reads those numbers.
	_apply_variant()

	# Start asleep: a freshly spawned slime breathes in place until the
	# player walks into its detection range.
	visuals.set_moving(false)
	visuals.set_facing(1.0)
	visuals.set_goo_color(body_color)

	# Procedural placeholder audio (cached in SFXGenerator so all slimes
	# share the same generated waveform buffers in memory).
	hit_sfx.stream = SFXGenerator.create_hit_sfx()
	death_sfx.stream = SFXGenerator.create_death_sfx()

	# Clamp health so an accidental Inspector value cannot create a
	# slime that starts dead or over-healed.
	current_health = clampi(current_health, 0, max_health)

	# Find the player. `get_first_node_in_group` returns null if there is
	# no player yet; the check in _physics_process() then simply makes
	# the slime idle instead of crashing.
	player = get_tree().get_first_node_in_group("player")

	# The attack sensor is OFF until the lunge. Same "deliberate hit"
	# pattern as the player's fist.
	attack_area.monitoring = false
	attack_area.monitorable = false
	attack_area.area_entered.connect(_on_attack_area_area_entered)

	_update_health_bar()
	health_changed.emit(current_health, max_health)


# =====================================================================
# MAIN LOOP
# =====================================================================

func _physics_process(delta: float) -> void:
	if is_dead:
		# A dead slime must not keep sliding around. move_and_slide()
		# with a zero velocity also stops it from being pushed.
		velocity = Vector2.ZERO
		return

	# Advance the attack state machine (telegraph -> lunge -> ...).
	_update_attack_state(delta)

	# Basalt spikes hurt on touch, independent of the lunge state machine.
	_update_contact_damage(delta)

	# Movement per state: only CHASE and LUNGE make the slime move.
	match _attack_state:
		AttackState.CHASE, AttackState.COOLDOWN:
			_chase_player()
		AttackState.TELEGRAPH, AttackState.RECOVER:
			velocity = Vector2.ZERO
			move_and_slide()
			visuals.set_moving(false)
		AttackState.LUNGE:
			velocity = _lunge_dir * lunge_speed
			move_and_slide()
			visuals.set_facing(_lunge_dir.x)
			visuals.set_moving(true)


## Advance telegraph/lunge/recover/cooldown timers.
func _update_attack_state(delta: float) -> void:
	_attack_timer -= delta

	match _attack_state:
		AttackState.TELEGRAPH:
			if _attack_timer <= 0.0:
				_start_lunge()
		AttackState.LUNGE:
			if _attack_timer <= 0.0:
				_end_lunge()
		AttackState.RECOVER:
			if _attack_timer <= 0.0:
				_attack_state = AttackState.COOLDOWN
				_attack_timer = attack_cooldown
		AttackState.COOLDOWN:
			if _attack_timer <= 0.0:
				_attack_state = AttackState.CHASE
		_:
			pass  # CHASE: leaves through _maybe_start_attack()

	# In CHASE, a player in range starts the telegraph.
	if _attack_state == AttackState.CHASE:
		_maybe_start_attack()


## Player close enough (and alive)? Then wind up an attack: the classic
## "tell the player BEFORE you hit them" telegraph.
func _maybe_start_attack() -> void:
	if not _is_player_alive():
		return
	var distance := global_position.distance_to(player.global_position)
	if distance <= attack_trigger_range:
		_attack_state = AttackState.TELEGRAPH
		_attack_timer = telegraph_duration
		velocity = Vector2.ZERO
		visuals.set_moving(false)
		_show_telegraph()


## The warning: gather low, lean back, tremble and glow red. All of that
## is one call - the timing lives in slime_visuals.gd next to the art.
func _show_telegraph() -> void:
	visuals.play_telegraph()


## Spring at where the player STOOD at take-off; hitbox live.
func _start_lunge() -> void:
	if not _is_player_alive():
		# Player vanished mid-telegraph: revert visuals and go back to chase.
		_cancel_telegraph()
		return
	_lunge_dir = (player.global_position - global_position).normalized()
	_has_hit_this_lunge = false
	attack_area.set_deferred("monitoring", true)
	_attack_state = AttackState.LUNGE
	_attack_timer = lunge_duration

	# Un-squash into the long "spring" pose, facing the jump direction.
	visuals.set_facing(_lunge_dir.x)
	visuals.play_lunge()


## Lunge over: hitbox off, brief slide to a stop.
func _end_lunge() -> void:
	attack_area.set_deferred("monitoring", false)
	_attack_state = AttackState.RECOVER
	_attack_timer = 0.35
	velocity = Vector2.ZERO

	# Return to the resting dome, then back to breathing/hopping.
	visuals.play_recover()


## Abort an in-progress telegraph (safety valve for edge cases).
func _cancel_telegraph() -> void:
	_attack_state = AttackState.COOLDOWN
	_attack_timer = attack_cooldown * 0.5
	visuals.play_recover()


## Called by the wave spawner for hero versions of this enemy.
## Shared package (3x HP + golden ring) lives in Elite. The slime's
## own extra: RAGE - a much faster telegraph and a snappier lunge,
## so the elite jells before you think you have the time to dodge.
func become_elite() -> void:
	is_elite = true
	Elite.make_enemy_elite(self)
	telegraph_duration *= 0.6
	lunge_speed *= 1.15
	# Slightly bigger + warmer, on top of the shared golden ring.
	visuals.become_elite()


## The player is "usable" for attacking while it exists and is not dead.
func _is_player_alive() -> bool:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	return not player.get("is_dead")


## Very small "follow the player" AI.
##
## It is intentionally naive: walk in a straight line toward the player,
## slow down near them, and stop. No pathfinding yet - the arena is open
## enough that the straight line is good enough for Phase 2.
func _chase_player() -> void:
	# The player may have been freed (scene change, respawn, ...).
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		visuals.set_moving(false)
		return

	# The player is dead: stop pestering the corpse and just idle.
	if player.get("is_dead"):
		velocity = Vector2.ZERO
		move_and_slide()
		visuals.set_moving(false)
		return

	var to_player: Vector2 = player.global_position - global_position
	var distance := to_player.length()

	if distance > detection_range:
		# Too far away: go back to sleep.
		velocity = Vector2.ZERO
	elif distance > stop_distance:
		# In range but not adjacent: crawl toward the player.
		# .normalized() keeps the speed constant on diagonals.
		velocity = to_player.normalized() * move_speed
	else:
		# Close enough: stop, so the slime does not push the player
		# around or jitter back and forth on top of them.
		velocity = Vector2.ZERO

	move_and_slide()

	# Face the player (the sheet is drawn facing right). The 6 px dead zone
	# stops a slime standing on top of the player from flickering back and
	# forth between the two sides every frame.
	if absf(to_player.x) > 6.0:
		visuals.set_facing(to_player.x)
	# And let the visuals decide between breathing in place and hopping.
	visuals.set_moving(velocity.length() > 0.0)


# =====================================================================
# DAMAGE
# =====================================================================

## The lunge's AttackArea touched something. Walk up from the touched
## node until we find the Player (it has take_damage()), then make the
## CALL: the enemy decides the damage - that is the same contract the
## player's fist follows with our Hurtbox.
func _on_attack_area_area_entered(area: Area2D) -> void:
	if _has_hit_this_lunge or is_dead:
		return

	var current: Node = area
	var guard := 4  # never walk further than a few parents up
	while current != null and guard > 0:
		if current != self and current.has_method("take_damage"):
			_has_hit_this_lunge = true

			# Same combat juice the player's punches get, softer.
			HitStop.freeze(0.03)
			ScreenShake.shake(2.5, 0.12)
			hit_sfx.play()

			current.take_damage(attack_damage, global_position)
			print("[Slime] ", name, " hit the player for ",
				attack_damage, " damage")
			return
		current = current.get_parent()
		guard -= 1

## Called by the player's hitbox: enemy.take_damage(player.attack_damage).
##
## `amount` is an int because health is an int; a float argument would
## silently truncate, so we convert explicitly and document it.
func take_damage(amount: int) -> void:
	if is_dead:
		return  # already dying - do not re-trigger

	current_health -= amount
	# Never show a negative number in the health bar.
	current_health = maxi(current_health, 0)

	# Debug line for the Output dock: 30 -> 20 -> 10 -> 0.
	print("[Slime] ", name, " took ", amount, " damage  ->  HP ",
		current_health, "/", max_health)

	# Play the higher-pitched impact pop ONLY here (when damage actually
	# lands), distinct from the player's lower-pitched swing sound.
	hit_sfx.play()

	_update_health_bar()
	health_changed.emit(current_health, max_health)
	visuals.play_hurt()
	flash_white(flash_duration)

	if current_health <= 0:
		die()


## Briefly paints the slime pure white so a hit is unmistakable.
##
## The flash is NOT a colour multiply: `slime_visuals.gd` swaps to the
## white silhouette row of the sheet (frame + 12) for a blink. That keeps
## the exact rounded outline of the pose instead of washing a texture out.
func flash_white(duration: float) -> void:
	if _is_flashing or is_dead:
		return

	_is_flashing = true
	visuals.flash(duration)
	await get_tree().create_timer(duration).timeout

	# The node may have died while we waited.
	if not is_instance_valid(visuals):
		return
	_is_flashing = false


## True while the white silhouette is showing (used by the tests).
func is_flashing() -> bool:
	return _is_flashing


## Flatten into a goo puddle, leave a decal, fade out, then queue_free()
## after `death_duration` seconds.
func die() -> void:
	if is_dead:
		return
	is_dead = true

	print("[Slime] ", name, " died")

	# Play the 0.3 s descending defeat tone right as the death squash begins
	# (matching `death_duration = 0.3` so it finishes right before queue_free()).
	death_sfx.play()

	# Stop colliding immediately so the corpse cannot block the player
	# during the death animation.
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	attack_area.set_deferred("monitoring", false)
	attack_area.set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	# The slime flattens into a puddle, spits goo and leaves a decal.
	# slime_visuals.gd owns the pose + particles; this tween only fades the
	# leftover puddle out so the node can be freed cleanly.
	visuals.play_death()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "modulate:a", 0.0, death_duration)
	if health_bar != null:
		tween.tween_property(health_bar, "modulate:a", 0.0, death_duration)

	# Tell listeners (loot drops, score, wave counters, ...) - BEFORE we
	# disappear, while the node is still valid.
	died.emit()

	# Variant death mechanic (acid pool / ember fuse). Runs while we are
	# still in the tree so the FX can use our position.
	_on_death_effect()

	# Wait, then remove ourselves from the scene tree for good.
	# queue_free() deletes the node at the end of the current frame,
	# which is the safe way to delete a node from inside its own code.
	await get_tree().create_timer(death_duration).timeout
	queue_free()


# =====================================================================
# SLIME FAMILY (variant data + the three per-variant hooks)
# =====================================================================

## Read `variant_id`, scale the stats the wave spawner already wrote, and
## tell the visuals which row of the sheet to draw.
##
## ORDERING MATTERS: the spawner adds its wave bonus BEFORE add_child(), so
## that bonus is already in max_health / move_speed / attack_damage here.
## Multiplying on top means a wave-10 Basalt is "tanky wave-10 slime", not
## "wave-1 tanky slime" - the same rule the elite helper follows.
func _apply_variant() -> void:
	variant_data = SlimeVariant.get_data(variant_id)
	if variant_data.is_empty():
		push_warning("[Slime] unknown variant_id '%s' - falling back to grass"
				% variant_id)
		variant_id = SlimeVariant.DEFAULT_ID
		variant_data = SlimeVariant.get_data(variant_id)

	max_health = maxi(1, int(round(float(max_health)
			* float(variant_data.get("hp", 1.0)))))
	current_health = max_health

	move_speed *= float(variant_data.get("speed", 1.0))
	max_move_speed *= float(variant_data.get("speed", 1.0))

	attack_damage = maxi(1, int(round(float(attack_damage)
			* float(variant_data.get("damage", 1.0)))))
	telegraph_duration *= float(variant_data.get("telegraph", 1.0))

	contact_damage = int(variant_data.get("contact_damage", 0))
	mechanic = int(variant_data.get("mechanic", SlimeVariant.Mechanic.NONE))

	# Colour + sheet row: the variant's identity is the art, not a tint.
	body_color = SlimeVariant.goo_color(variant_id)
	visuals.set_variant(SlimeVariant.row_for(variant_id))
	visuals.set_goo_color(body_color)


## Basalt's spiked shell: standing next to it hurts, on a fixed tick so the
## player can learn the rhythm and step out between ticks.
func _update_contact_damage(delta: float) -> void:
	_contact_cooldown = maxf(0.0, _contact_cooldown - delta)
	if contact_damage <= 0 or is_dead or _contact_cooldown > 0.0:
		return
	if not _is_player_alive():
		return
	if global_position.distance_to(player.global_position) > contact_range:
		return

	_contact_cooldown = contact_interval
	HitStop.freeze(0.02)
	ScreenShake.shake(1.8, 0.1)
	hit_sfx.play()
	player.take_damage(contact_damage, global_position)


## The variant's parting gift. Called from die() while we are still in the
## tree, so `get_parent()` is the arena and our position is still valid.
func _on_death_effect() -> void:
	match mechanic:
		SlimeVariant.Mechanic.ACID_POOL:
			_spawn_acid_pool()
		SlimeVariant.Mechanic.EMBER_FUSE:
			_spawn_ember_blast()
		_:
			pass


func _spawn_acid_pool() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var pool: Node2D = AcidPoolScene.instantiate()
	parent.add_child(pool)
	pool.global_position = visuals.global_position


func _spawn_ember_blast() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var blast: Node2D = EmberBlastScene.instantiate()
	parent.add_child(blast)
	blast.global_position = visuals.global_position


# =====================================================================
# HEALTH BAR
# =====================================================================

func _update_health_bar() -> void:
	if health_bar == null:
		return
	# The bar node draws itself (see scripts/ui/health_bar.gd); we only
	# have to hand it the new numbers.
	health_bar.set_health(current_health, max_health)
