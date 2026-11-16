extends CharacterBody2D
## Player controller for the top-down roguelike brawler.
##
## Handles:
##  - 8-directional top-down movement (WASD / arrow keys),
##  - idle/walk animation switching + horizontal sprite flipping,
##  - a minimal "attack in progress" flag that the real combat code
##    can build on later.
##
## Only Godot 4.x APIs are used (CharacterBody2D + move_and_slide(),
## Input.get_vector(), AnimationPlayer, SceneTreeTimer, ...).


# =====================================================================
# EXPORTED SETTINGS (editable per-instance in the Inspector)
# =====================================================================

## How fast the player moves, in pixels per second.
@export var move_speed: float = 120.0

## How long an attack lasts, in seconds (0.2 s = 200 ms).
@export var attack_duration: float = 0.2


# =====================================================================
# STATE
# =====================================================================

## True while the player is mid-swing. Movement is locked while this is
## true so attacks feel deliberate. Later you can also use it to enable
## the melee hitbox or play an "attack" animation.
var is_attacking: bool = false

## Horizontal facing direction: 1.0 = right, -1.0 = left.
## Stored separately from velocity so the player keeps looking the way
## they last walked while standing still.
var facing: float = 1.0


# =====================================================================
# NODE REFERENCES
# =====================================================================
# @onready waits until the node (and its children) are inside the
# SceneTree before running the $ lookups, so the paths are valid.

@onready var visuals: Sprite2D = $Visuals                 # sprite we flip + animate
@onready var anim_player: AnimationPlayer = $AnimPlayer   # plays "idle" / "walk"
@onready var attack_point: Marker2D = $AttackPoint        # where melee hits will spawn

## Local offset of the AttackPoint marker when facing right.
## It gets mirrored on the X axis whenever the player faces left.
const ATTACK_POINT_OFFSET := Vector2(12.0, 0.0)


# =====================================================================
# MAIN LOOP
# =====================================================================

func _physics_process(_delta: float) -> void:
	# Movement must run in _physics_process: CharacterBody2D's
	# move_and_slide() is designed to be called once per physics tick.
	_handle_movement()
	_update_animation()


func _unhandled_input(event: InputEvent) -> void:
	# Temporary test binding: Space or left mouse starts an attack.
	# _unhandled_input (instead of _input) lets UI elements consume
	# clicks first. Replace with your real combat system later.
	if event.is_action_pressed("attack"):
		_start_attack()


# =====================================================================
# MOVEMENT
# =====================================================================

func _handle_movement() -> void:
	# Input.get_vector() reads the four actions defined in
	# Project Settings > Input Map (move_left/right/up/down) and returns
	# a normalized direction, so diagonals are not faster than straights.
	var input_dir := Vector2.ZERO
	if not is_attacking:
		input_dir = Input.get_vector(
			"move_left", "move_right", "move_up", "move_down"
		)

	# CharacterBody2D pattern: write the desired velocity, then let
	# move_and_slide() move the body and resolve collisions for us.
	velocity = input_dir * move_speed
	move_and_slide()

	# Remember which way we are facing. Only update while actually
	# moving sideways, so standing still keeps the last direction.
	if velocity.x > 0.0:
		facing = 1.0
	elif velocity.x < 0.0:
		facing = -1.0

	# Flip the sprite horizontally: a negative scale.x mirrors it.
	visuals.scale.x = facing

	# Keep the melee marker in front of the player too, so future
	# attacks spawn on the side we are looking at.
	attack_point.position.x = ATTACK_POINT_OFFSET.x * facing


# =====================================================================
# ANIMATION
# =====================================================================

# ANIMATION NOTES (for beginner devs):
# 1. Track paths inside the .tscn ("Visuals:texture") are resolved relative
#    to the AnimationPlayer's *root node*, which defaults to its parent -
#    the Player root here. So "Visuals:texture" is correct; "../Visuals"
#    would NOT resolve (the mixer prints a "couldn't resolve track" warning).
# 2. If the sprite ever looks "frozen" again, check the Output dock for the
#    debug print below: if "Playing: walk" shows but the picture never
#    changes, the track path or the animation's keys are the problem -
#    NOT this script.
func _update_animation() -> void:
	# Pick the animation we WANT: walk while moving, idle while stopped.
	var desired := "walk" if velocity.length() > 0.0 else "idle"

	# Only call play() when the animation actually changes. Calling play()
	# every physics frame would restart it from frame 0 forever, which also
	# looks like "the animation is not playing".
	if anim_player.current_animation != desired:
		anim_player.play(desired)
		# Debug print so you can watch the switches in the Output dock.
		# Safe to delete once you trust the system.
		print("Playing: ", anim_player.current_animation)


# =====================================================================
# COMBAT (placeholder)
# =====================================================================

func _start_attack() -> void:
	# Ignore extra presses while an attack is already running.
	if is_attacking:
		return

	is_attacking = true

	# TODO (combat pass): play an "attack" animation here and enable an
	# Area2D hitbox positioned at attack_point.global_position.

	# Wait attack_duration seconds without freezing the game.
	# get_tree().create_timer() returns a SceneTreeTimer; `await` pauses
	# only THIS function until the timer's timeout signal fires.
	# (Alternatives: a Timer node with `await timer.timeout`, or a Tween.)
	await get_tree().create_timer(attack_duration).timeout

	is_attacking = false
