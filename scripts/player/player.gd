extends CharacterBody2D
## Player controller for the top-down roguelike brawler.
##
## Handles:
##  - 8-directional top-down movement (WASD / arrow keys),
##  - idle/walk/attack animation switching + horizontal sprite flipping,
##  - a melee attack (Space / left click) that damages enemies in front of
##    the player through the `Hitbox` Area2D.
##
## Only Godot 4.x APIs are used (CharacterBody2D + move_and_slide(),
## Input.get_vector(), AnimationPlayer, Area2D signals, SceneTreeTimer, ...).
##
## =========================================================================
## HOW THE MELEE COMBAT WORKS (beginner-friendly overview)
## =========================================================================
## 1. PRESS  -> _unhandled_input() sees the "attack" action and calls
##              _start_attack().
## 2. SWING  -> is_attacking becomes true (movement locks), the "attack"
##              animation plays, and after a tiny wind-up the `Hitbox`
##              Area2D is switched on for a few frames.
## 3. TOUCH  -> While the Hitbox is on, the physics engine reports every
##              Area2D / body that overlaps it (`area_entered`). We turn
##              that overlap into "this enemy was hit".
## 4. DAMAGE -> We call enemy.take_damage(attack_damage) and emit the
##              `attack_hit(enemy)` signal, so other nodes (UI, sound,
##              camera shake, ...) can react WITHOUT the player script
##              needing to know they exist. That is the "signal-based"
##              part: the player broadcasts facts, other nodes listen.
##
## Areas vs bodies: `Hitbox` is an Area2D, a sensor - it does not push
## anything, it only reports overlaps. Enemies expose their own `Hurtbox`
## Area2D, so the fist only ever sees hurtboxes and never walls:
##
##   Player/Hitbox  collision_layer = 8   collision_mask = 16   (layer 4 -> 5)
##   Slime/Hurtbox  collision_layer = 16  collision_mask = 8    (layer 5 -> 4)
##
## See slime.gd for the other half of the story and a full layer table.


# =====================================================================
# SIGNALS
# =====================================================================
# Emitted once per enemy per swing, right after the damage has been
# applied. `enemy` is the node that received the hit (e.g. a Slime).
#
# Anyone can listen to it:
#     player.attack_hit.connect(_on_player_attack_hit)
signal attack_hit(enemy)

## Emitted every time the player takes damage (HP already updated).
## HUD listens to drive the health bar.
signal health_changed(current_health: int, max_health: int)

## Emitted exactly once, at the moment death is confirmed.
## Main listens to show the Game Over screen.
signal player_died


# =====================================================================
# EXPORTED SETTINGS (editable per-instance in the Inspector)
# =====================================================================

## How fast the player moves, in pixels per second. Borzo is heavy:
## slower than a nimble character, but every punch counts.
@export var move_speed: float = 90.0

## How long an attack lasts, in seconds (0.45 s = heavy haymaker).
## Movement is locked for this long, and it matches the "attack"
## animation length. Long recovery = commit to your punches.
@export var attack_duration: float = 0.45

## How much health an enemy loses per hit. Slow and heavy: big damage.
@export var attack_damage: int = 18

## Delay between "attack pressed" and "hitbox turns on", in seconds.
## This is the wind-up: the punch is only dangerous once the arm is out
## (fist-extended pose in animation frame 4 at 0.18 s).
@export var attack_windup: float = 0.18

## How long the hitbox stays switched on, in seconds (0.12 s = 7 physics
## frames at 60 Hz). Keep it short, otherwise one swing hits twice.
@export var hitbox_active_time: float = 0.12

## Total player health. The player starts every scene at full health.
@export var max_health: int = 100

## Seconds of invulnerability after taking a hit (i-frames). While true
## the player cannot be damaged again and the sprite blinks.
@export var invulnerability_time: float = 0.8

## Push speed applied away from the attacker when hit (pixels per second).
## Decays to zero over a few frames - see _knockback and _handle_movement().
@export var knockback_speed: float = 180.0

## Seconds between footstep ticks while the player is walking.
@export var footstep_interval: float = 0.25


# =====================================================================
# STATE
# =====================================================================

## True while the player is mid-swing. Movement is locked while this is
## true so attacks feel deliberate.
var is_attacking: bool = false

## True once death is confirmed. The player ignores all input, the
## hitbox/hurtbox switch off, and the death animation plays out.
var is_dead: bool = false

## Current health, 0 .. max_health. Changed ONLY in take_damage().
var current_health: int = 100

## True during i-frames after a hit; take_damage() bails out early.
var _invulnerable: bool = false

## Residual push from the last hit, in pixels per second. Decays in
## _handle_movement so getting punched moves you a bit and then settles.
var _knockback: Vector2 = Vector2.ZERO

## True while the white/red hit flash is showing (used to not restart it).
var _is_flashing: bool = false

## Horizontal facing direction: 1.0 = right, -1.0 = left.
## Stored separately from velocity so the player keeps looking the way
## they last walked while standing still.
var facing: float = 1.0

## Enemies already damaged by the CURRENT swing.
## Key = enemy instance id, value = true.
##
## WHY: Area2D reports the overlap once, but the enemy can stay inside
## the hitbox for several physics frames, and it is also possible for
## both its Hurtbox AND its body to be reported. Without this guard a
## single punch would deal 20-30 damage instead of 10.
## It is cleared at the start of every new attack.
var _enemies_hit_this_swing: Dictionary = {}

## Countdown until the next footstep sound while walking.
var _footstep_timer: float = 0.0


# =====================================================================
# NODE REFERENCES
# =====================================================================
# @onready waits until the node (and its children) are inside the
# SceneTree before running the $ lookups, so the paths are valid.

@onready var visuals: Sprite2D = $Visuals                   # single character sprite we flip + animate
@onready var anim_player: AnimationPlayer = $AnimPlayer     # plays "idle" / "walk" / "attack"
@onready var attack_point: Marker2D = $AttackPoint          # local point in front of the player
@onready var hitbox: Area2D = $Hitbox                       # the damaging sensor
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var punch_sfx: AudioStreamPlayer = $PunchSFX       # swing / whiff sound
@onready var footstep_sfx: AudioStreamPlayer = $FootstepSFX # subtle walking tick
@onready var hurt_sfx: AudioStreamPlayer = $HurtSFX         # "oof" when damaged
@onready var dust: CPUParticles2D = $Dust                   # little kick-up puffs

## Local offset of the AttackPoint marker when facing right.
## It gets mirrored on the X axis whenever the player faces left.
## Borzo's reach is long — his fist sticks out past the visual body.
const ATTACK_POINT_OFFSET := Vector2(14.0, 0.0)

## Small 6x6 fist-colored impact spark spawned ONLY when a punch lands on an enemy.
const HIT_SPARK_SCENE := preload("res://scenes/fx/HitSpark.tscn")


# =====================================================================
# SETUP
# =====================================================================

func _ready() -> void:
	# The hitbox is OFF until a swing happens. This is what makes the
	# attack feel like a deliberate punch instead of a permanent aura.
	_disable_hitbox()

	# Synthesize procedural placeholder waveforms once and route through the
	# "SFX" audio bus (see scripts/audio/sfx_generator.gd).
	punch_sfx.stream = SFXGenerator.create_punch_sfx()
	footstep_sfx.stream = SFXGenerator.create_footstep_sfx()
	hurt_sfx.stream = SFXGenerator.create_hurt_sfx()

	# Health starts (and restarts) at full.
	current_health = max_health

	# Signals are connected here in code so you can see, in one place,
	# exactly which events this script listens to.
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)


# =====================================================================
# MAIN LOOP
# =====================================================================

func _physics_process(delta: float) -> void:
	# Movement must run in _physics_process: CharacterBody2D's
	# move_and_slide() is designed to be called once per physics tick.
	_handle_movement()
	_update_animation()
	_update_footsteps(delta)


func _unhandled_input(event: InputEvent) -> void:
	# Space or left mouse (both bound to the "attack" action in
	# Project Settings > Input Map) starts an attack.
	# _unhandled_input (instead of _input) lets UI elements consume
	# clicks first.
	if is_dead:
		return  # no punching from beyond the grave
	if event.is_action_pressed("attack"):
		_start_attack()


# =====================================================================
# MOVEMENT
# =====================================================================

func _handle_movement() -> void:
	# A dead player stays put: zero velocity, no input, no facing flips.
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Input.get_vector() reads the four actions defined in
	# Project Settings > Input Map (move_left/right/up/down) and returns
	# a normalized direction, so diagonals are not faster than straights.
	var input_dir := Vector2.ZERO
	if not is_attacking:
		input_dir = Input.get_vector(
			"move_left", "move_right", "move_up", "move_down"
		)

	# Knockback decays toward zero at a fixed rate (180 => ~0.25 s of
	# movement from a 180 px/s push). Added on TOP of input, so you can
	# fight the push a little while you slide from a slime's lunge.
	_knockback = _knockback.move_toward(
		Vector2.ZERO, 800.0 * get_physics_process_delta_time()
	)

	# CharacterBody2D pattern: write the desired velocity, then let
	# move_and_slide() move the body and resolve collisions for us.
	velocity = input_dir * move_speed + _knockback
	move_and_slide()

	# Remember which way we are facing. Only update while actually
	# moving sideways, so standing still keeps the last direction.
	if velocity.x > 0.0:
		facing = 1.0
	elif velocity.x < 0.0:
		facing = -1.0

	# Flip the single character sprite horizontally: a negative scale.x
	# mirrors Visuals around its centre, so the right-facing extended fist
	# in frame 3 automatically punches left when facing == -1.0.
	visuals.scale.x = facing

	# Keep the melee marker AND the hitbox in front of the player, so the
	# attack always lands on the side we are looking at.
	attack_point.position.x = ATTACK_POINT_OFFSET.x * facing
	hitbox.position.x = ATTACK_POINT_OFFSET.x * facing


# =====================================================================
# ANIMATION
# =====================================================================

# ANIMATION NOTES (for beginner devs):
# 1. HOW THE 4-FRAME SPRITE SHEET WORKS (`assets/textures/player_placeholder.png`):
#    The sheet is 64x16 pixels = four 16x16 frames side by side (left to right):
#      - Frame 0 (`Rect2( 0, 0, 16, 16)`): idle (neutral standing body)
#      - Frame 1 (`Rect2(16, 0, 16, 16)`): walk step A (left foot down)
#      - Frame 2 (`Rect2(32, 0, 16, 16)`): walk step B (right foot down + 1px bob)
#      - Frame 3 (`Rect2(48, 0, 16, 16)`): punch pose (lunged forward + extended fist)
#    In `Player.tscn`, each 16x16 slice is wrapped in an `AtlasTexture`
#    sub-resource (`AtlasTexture_frame0` .. `AtlasTexture_frame3`), and the
#    `AnimationPlayer` swaps `Visuals:texture` between them using discrete
#    keyframes (`update = 1`, meaning instant snap instead of blending).
# 2. WHY FRAME-BASED ATTACK BEATS AN OVERLAY SPRITE:
#    Drawing a second sprite at `AttackPoint` makes the player look doubled
#    ("twin bodies" side by side). Swapping `Visuals:texture` to Frame 3
#    replaces the ONE character sprite with a pose that already has the
#    lunging body and extended arm/fist drawn in, so there is ever only a
#    single character body on screen.
# 3. Track paths inside the .tscn ("Visuals:texture") are resolved relative
#    to the AnimationPlayer's *root node*, which defaults to its parent -
#    the Player root here. So "Visuals:texture" is correct; "../Visuals"
#    would NOT resolve (the mixer prints a "couldn't resolve track" warning).
# 4. If the sprite ever looks "frozen" again, check the Output dock for the
#    debug print below: if "Playing: walk" shows but the picture never
#    changes, the track path or the animation's keys are the problem -
#    NOT this script.
func _update_animation() -> void:
	# While swinging, the "attack" animation owns the sprite. If we did
	# not bail out here, the next physics frame would immediately ask for
	# "idle" (the player is standing still) and cancel the punch.
	if is_attacking:
		return

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


## WHY FOOTSTEP SOUNDS NEED WALK-STATE CHECKING (beginner-friendly):
## `_physics_process()` runs 60 times every second whether the player is
## moving or standing completely still. Two mistakes happen if you do not
## gate footsteps on BOTH walk state AND a cadence timer:
##   1. Without checking `velocity.length() > 0.0` (and `not is_attacking`),
##      footsteps keep ticking while the character is idle or frozen mid-punch.
##   2. Without `_footstep_timer`, `play()` restarts the clip 60 times per
##      second, turning a soft tap into a harsh buzz.
## When the player stops walking, we reset `_footstep_timer = 0.0` (so the
## next step feels instant when they move again) and stop any leftover tick.
func _update_footsteps(delta: float) -> void:
	var is_walking := (not is_attacking) and velocity.length() > 0.0
	if not is_walking:
		_footstep_timer = 0.0
		if footstep_sfx.playing:
			footstep_sfx.stop()
		return

	if _footstep_timer <= 0.0:
		footstep_sfx.play()
		# One small puff per footstep, in sync with the sound. `restart()`
		# makes a one-shot emitter replay its burst from scratch - calling
		# `emitting = true` again would do nothing while it is still
		# playing its previous burst.
		dust.restart()
		_footstep_timer = footstep_interval
	else:
		_footstep_timer -= delta


# =====================================================================
# COMBAT - THE SWING
# =====================================================================

func _start_attack() -> void:
	# Ignore extra presses while an attack is already running.
	if is_attacking or is_dead:
		return

	is_attacking = true

	# Fresh swing -> fresh "already hit" list. This is what stops one
	# punch from damaging the same slime several times.
	_enemies_hit_this_swing.clear()

	# Play the non-looping 0.2 s "attack" animation on `Visuals:texture`:
	#   0.00 s -> Frame 0 (idle wind-up)
	#   0.05 s -> Frame 3 (lunged punch pose, synced with Hitbox ON)
	#   0.15 s -> Frame 0 (retract to idle, synced with Hitbox OFF)
	# Movement unlocks at 0.20 s once recovery finishes.
	anim_player.play("attack")

	# Play the low "whoosh-thump" swing sound immediately on attack start,
	# even if the punch whiffs empty air. If the fist actually connects with
	# an enemy later, the enemy plays its own higher-pitched `HitSFX` on top.
	punch_sfx.play()

	# --- 1. Wind-up ----------------------------------------------------
	# get_tree().create_timer() returns a SceneTreeTimer; `await` pauses
	# only THIS function until the timer's timeout signal fires, without
	# freezing the game.
	await get_tree().create_timer(attack_windup).timeout

	# --- 2. The punch is out: hitbox live ------------------------------
	_enable_hitbox()

	# Some physics setups report a newly enabled Area2D one frame late,
	# so we wait a beat and then also ask directly who is inside. That
	# catches enemies that were already touching us before the swing.
	# _try_hit() de-duplicates, so this can never double-damage.
	await get_tree().physics_frame
	await get_tree().physics_frame
	for area in hitbox.get_overlapping_areas():
		_try_hit(area)
	for body in hitbox.get_overlapping_bodies():
		_try_hit(body)

	await get_tree().create_timer(hitbox_active_time).timeout

	# --- 3. Recovery ---------------------------------------------------
	_disable_hitbox()

	# Wait out the rest of the swing so movement stays locked until the
	# animation has fully finished. The timers above can overshoot
	# slightly, so this is clamped to "never negative".
	var remaining := attack_duration - attack_windup - hitbox_active_time
	remaining = maxf(remaining, 0.0)
	await get_tree().create_timer(remaining).timeout

	is_attacking = false


# =====================================================================
# COMBAT - THE HITBOX
# =====================================================================

func _enable_hitbox() -> void:
	# `monitoring` = "do I look for other areas/bodies?"
	# `monitorable` = "can others find ME?"
	# The hitbox only needs to look, never to be found, so it stays
	# monitorable = false forever.
	hitbox.monitoring = true
	hitbox.monitorable = false
	# Subtle camera nudge right as the fist snaps out at 0.05 s.
	ScreenShake.shake(2.0, 0.1)
	# Debug lines so you can watch the 0.1 s window in the Output dock.
	print("[Combat] Hitbox ON")


func _disable_hitbox() -> void:
	# set_deferred because this can run INSIDE a physics signal callback
	# (punch lands -> enemy dies -> ... ), and Godot forbids flipping
	# monitoring/monitorable on an Area2D while that signal is in-flight.
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	print("[Combat] Hitbox OFF")


## Called by the physics engine for every Area2D that enters the hitbox.
## This is how the enemy's `Hurtbox` reaches us.
func _on_hitbox_area_entered(area: Area2D) -> void:
	_try_hit(area)


## Called for every physics BODY (CharacterBody2D/StaticBody2D/...) that
## enters the hitbox. Enemy bodies are on the same layer as their
## Hurtbox, so this is a second way to notice a hit; _try_hit() makes
## sure the enemy is still only damaged once per swing.
func _on_hitbox_body_entered(body: Node2D) -> void:
	_try_hit(body)


## Resolve "whatever the hitbox touched" into "an enemy that can take
## damage", apply the damage, and emit the signal. Safe to call several
## times per swing for the same enemy.
func _try_hit(touched: Node) -> void:
	if not is_attacking:
		return

	var enemy := _find_damageable(touched)
	if enemy == null:
		return  # a wall, or something that is not an enemy

	# Already punched this enemy during this swing? Ignore.
	var enemy_id := enemy.get_instance_id()
	if _enemies_hit_this_swing.has(enemy_id):
		return
	_enemies_hit_this_swing[enemy_id] = true

	# Phase 3 combat juice on confirmed impact:
	#  - 50 ms hit-stop freeze gives the punch physical weight,
	#  - stronger 3.0 px / 0.15 s camera shake stacks onto the swing nudge.
	HitStop.freeze(0.05)
	ScreenShake.shake(3.0, 0.15)

	# Deal the damage. `take_damage` is the one method every enemy must
	# implement - that "duck-typed contract" keeps the player from having
	# to know about Slime, Bat, Boss, ... individually.
	enemy.take_damage(attack_damage)
	print("[Combat] Hit ", enemy.name, " for ", attack_damage, " damage")

	# Visual feedback at the point of impact.
	_spawn_hit_spark()

	# Broadcast the event. UI / audio / achievements can listen to this
	# without the player knowing anything about them.
	attack_hit.emit(enemy)


## Walk up from the node the hitbox touched until we find something that
## implements take_damage(). For a Slime the chain is
## Hurtbox (Area2D) -> Slime (CharacterBody2D).
func _find_damageable(node: Node) -> Node:
	var current: Node = node
	var guard := 4  # never walk further than a few parents up
	while current != null and guard > 0:
		if current.has_method("take_damage"):
			return current
		current = current.get_parent()
		guard -= 1
	return null


## Spawns a tiny 6x6 fist-colored spark ONLY when `_try_hit()` confirms an
## enemy was struck (never on an empty swing, and never a body sprite copy).
## Added to the level root (our parent) so it stays at the impact spot even
## after the player moves, and frees itself after ~0.15 s.
func _spawn_hit_spark() -> void:
	var spark := HIT_SPARK_SCENE.instantiate()
	var parent := get_parent()
	if parent == null:
		spark.queue_free()
		return
	parent.add_child(spark)
	# A little in front of the player, at the centre of the hitbox.
	spark.global_position = hitbox.global_position


# =====================================================================
# TAKING DAMAGE - THE OTHER HALF OF THE STORY
# =====================================================================
# The player is a damageable just like the Slime: enemies call
# take_damage() on us. Mirror of the slime's contract:
#
#   Slime.AttackArea (layer 32, mask 64) notices the player's Hurtbox
#   Player.Hurtbox   (layer 64) - the ENEMY decides the damage and calls
#   player.take_damage(amount, from_position).
#
# `from_position` is where the hit came FROM, used to push the player
# away (knockback). A hit without a position simply does not push.

func take_damage(amount: int, from_position: Vector2 = Vector2.INF) -> void:
	# Dead men take no damage; i-frames make every hit an event instead
	# of a draining dribble when a slime touches you frame after frame.
	if is_dead or _invulnerable:
		return

	current_health = clampi(current_health - amount, 0, max_health)
	print("[Player] took ", amount, " damage  ->  HP ",
		current_health, "/", max_health)

	health_changed.emit(current_health, max_health)
	hurt_sfx.play()

	# Phase 3 juice, mirrored for hits RECEIVED: tiny freeze + shake.
	# The shake is stronger and red flash heavier than the punch, so
	# getting hit FEELS worse than landing a hit.
	HitStop.freeze(0.04)
	ScreenShake.shake(4.0, 0.2)

	# Knockback: slide away from where the hit came from.
	if from_position != Vector2.INF:
		var away := global_position - from_position
		if away.length() > 1.0:
			_knockback = away.normalized() * knockback_speed

	_flash_red()

	if current_health <= 0:
		_die()
	else:
		_start_invulnerability()


## Paints the sprite red for a fraction of a second, then restores it.
func _flash_red() -> void:
	if _is_flashing:
		return
	_is_flashing = true
	visuals.modulate = Color(1.0, 0.35, 0.35)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(visuals) and not is_dead:
		visuals.modulate = Color.WHITE
	_is_flashing = false


## i-frames: un-hittable for invulnerability_time seconds while the
## sprite blinks (alpha up/down about every 0.1 s) so the state is VISIBLE.
func _start_invulnerability() -> void:
	if _invulnerable:
		return
	_invulnerable = true

	var blink_time := 0.1  # seconds per alpha step
	var steps := maxi(int(invulnerability_time / (blink_time * 2.0)), 1)
	var tween := create_tween()
	for i in steps:
		tween.tween_property(visuals, "modulate:a", 0.3, blink_time)
		tween.tween_property(visuals, "modulate:a", 1.0, blink_time)
	await tween.finished

	if is_instance_valid(visuals):
		visuals.modulate.a = 1.0
	_invulnerable = false


## Death: stop everything, broadcast, and fall over dramatically.
func _die() -> void:
	if is_dead:
		return
	is_dead = true
	print("[Player] died - GAME OVER")

	_disable_hitbox()
	# Hurtbox must stop being findable, and the BODY must stop blocking
	# slimes' movement? No: the corpse stays solid (it did not leave the
	# room) - we only detach the sensors.
	$Hurtbox.set_deferred("monitoring", false)
	$Hurtbox.set_deferred("monitorable", false)
	footstep_sfx.stop()

	# Tell Main -> Game Over screen. BEFORE the animation, so the overlay
	# fades in while the body is still falling.
	player_died.emit()

	# Fall over + fade. Rotating the ONE sprite 90 degrees reads as
	# collapsing without needing a dedicated frames.
	anim_player.stop()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "rotation_degrees", 90.0 * facing, 0.5)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "modulate",
		Color(0.6, 0.6, 0.6, 0.9), 0.5)
