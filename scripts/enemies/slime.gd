extends CharacterBody2D
## "Dummy Slime" - the first enemy of the game.
##
## It is deliberately simple:
##  - harmless target practice (it does not damage the player yet),
##  - slowly slides toward the player when they are close,
##  - stops once it is standing right next to them,
##  - takes damage, flashes white, and pops when its health runs out.
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

## Colour used for the placeholder square sprite.
@export var body_color: Color = Color("6ec866")


# =====================================================================
# STATE
# =====================================================================

## True as soon as the last hit landed. The slime stops moving,
## stops accepting damage, and starts its death animation.
var is_dead: bool = false

## True while the white flash is showing (used to not restart it).
var _is_flashing: bool = false


# =====================================================================
# NODE REFERENCES
# =====================================================================

@onready var visuals: Sprite2D = $Visuals
@onready var anim_player: AnimationPlayer = $AnimPlayer
@onready var hurtbox: Area2D = $Hurtbox
@onready var health_bar: Node2D = $HealthBar  # custom-drawn bar, see health_bar.gd

## The player is looked up once at spawn time. `group: "player"` is set
## by Player.tscn, so this keeps working no matter where the player is in
## the scene tree.
var player: Node2D = null


# =====================================================================
# SETUP
# =====================================================================

func _ready() -> void:
	# Remember our spawn point so the idle animation can bob around it,
	# and so a dead slime is removed exactly where it fell.
	visuals.self_modulate = body_color

	# Clamp health so an accidental Inspector value cannot create a
	# slime that starts dead or over-healed.
	current_health = clampi(current_health, 0, max_health)

	# Find the player. `get_first_node_in_group` returns null if there is
	# no player yet; the check in _physics_process() then simply makes
	# the slime idle instead of crashing.
	player = get_tree().get_first_node_in_group("player")

	_update_health_bar()
	health_changed.emit(current_health, max_health)


# =====================================================================
# MAIN LOOP
# =====================================================================

func _physics_process(_delta: float) -> void:
	if is_dead:
		# A dead slime must not keep sliding around. move_and_slide()
		# with a zero velocity also stops it from being pushed.
		velocity = Vector2.ZERO
		return

	_chase_player()


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
		_set_walking(false)
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

	# Only animate "walk" while we are actually moving.
	_set_walking(velocity.length() > 0.0)


# =====================================================================
# ANIMATION
# =====================================================================

## Switches between the looping "idle" bounce and the "walk" wobble.
## play() is only called on a real change, otherwise the animation would
## restart from frame 0 every physics frame.
func _set_walking(walking: bool) -> void:
	var desired := "walk" if walking else "idle"
	if anim_player.current_animation != desired:
		anim_player.play(desired)


# =====================================================================
# DAMAGE
# =====================================================================

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

	_update_health_bar()
	health_changed.emit(current_health, max_health)
	flash_white(flash_duration)

	if current_health <= 0:
		die()


## Briefly paints the sprite pure white so a hit is unmistakable.
## (sprite `self_modulate` is a color multiplier over the texture.)
func flash_white(duration: float) -> void:
	if _is_flashing or is_dead:
		return

	_is_flashing = true
	var original := body_color
	visuals.self_modulate = Color(1, 1, 1, 1)  # white = max brightness
	await get_tree().create_timer(duration).timeout

	# The node may have died while we waited.
	if not is_instance_valid(visuals):
		return
	visuals.self_modulate = original
	_is_flashing = false


## Shrink + fade, then remove the node after `death_duration` seconds.
func die() -> void:
	if is_dead:
		return
	is_dead = true

	print("[Slime] ", name, " died")

	# Stop colliding immediately so the corpse cannot block the player
	# during the death animation.
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	# A Tween animates properties over time without writing any
	# per-frame code. tween_property(object, "property", final_value, seconds)
	var tween := create_tween()
	tween.set_parallel(true)  # both properties animate at the same time
	tween.tween_property(visuals, "scale", Vector2.ZERO, death_duration)
	tween.tween_property(visuals, "modulate:a", 0.0, death_duration)
	if health_bar != null:
		tween.tween_property(health_bar, "modulate:a", 0.0, death_duration)

	# Tell listeners (loot drops, score, wave counters, ...) - BEFORE we
	# disappear, while the node is still valid.
	died.emit()

	# Wait, then remove ourselves from the scene tree for good.
	# queue_free() deletes the node at the end of the current frame,
	# which is the safe way to delete a node from inside its own code.
	await get_tree().create_timer(death_duration).timeout
	queue_free()


# =====================================================================
# HEALTH BAR
# =====================================================================

func _update_health_bar() -> void:
	if health_bar == null:
		return
	# The bar node draws itself (see scripts/ui/health_bar.gd); we only
	# have to hand it the new numbers.
	health_bar.set_health(current_health, max_health)
