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

## Colour used for the placeholder square sprite.
@export var body_color: Color = Color("6ec866")

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

@onready var visuals: Sprite2D = $Visuals
@onready var anim_player: AnimationPlayer = $AnimPlayer
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_area: Area2D = $AttackArea
@onready var health_bar: Node2D = $HealthBar  # custom-drawn bar, see health_bar.gd
@onready var hit_sfx: AudioStreamPlayer = $HitSFX
@onready var death_sfx: AudioStreamPlayer = $DeathSFX

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

	# Movement per state: only CHASE and LUNGE make the slime move.
	match _attack_state:
		AttackState.CHASE, AttackState.COOLDOWN:
			_chase_player()
		AttackState.TELEGRAPH, AttackState.RECOVER:
			velocity = Vector2.ZERO
			move_and_slide()
			_set_walking(false)
		AttackState.LUNGE:
			velocity = _lunge_dir * lunge_speed
			move_and_slide()
			_set_walking(true)


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
		_set_walking(false)
		_show_telegraph()


## The warning: squash down and glow red, like winding up a jump.
func _show_telegraph() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "scale", Vector2(1.3, 0.7), telegraph_duration)
	tween.tween_property(visuals, "modulate", Color(1.0, 0.45, 0.45), telegraph_duration)


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

	# Un-squash into the jump shape.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "scale", Vector2(0.85, 1.25), 0.08)
	tween.tween_property(visuals, "modulate", Color.WHITE, 0.08)


## Lunge over: hitbox off, brief slide to a stop.
func _end_lunge() -> void:
	attack_area.set_deferred("monitoring", false)
	_attack_state = AttackState.RECOVER
	_attack_timer = 0.35
	velocity = Vector2.ZERO

	# Return to the resting shape.
	var tween := create_tween()
	tween.tween_property(visuals, "scale", Vector2.ONE, 0.15)


## Abort an in-progress telegraph (safety valve for edge cases).
func _cancel_telegraph() -> void:
	_attack_state = AttackState.COOLDOWN
	_attack_timer = attack_cooldown * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "scale", Vector2.ONE, 0.15)
	tween.tween_property(visuals, "modulate", Color.WHITE, 0.15)


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
		_set_walking(false)
		return

	# The player is dead: stop pestering the corpse and just idle.
	if player.get("is_dead"):
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

	# A Tween animates properties over time without writing any
	# per-frame code. tween_property(object, "property", final_value, seconds)
	var tween := create_tween()
	tween.set_parallel(true)  # both properties animate at the same time
	tween.tween_property(visuals, "scale", Vector2.ZERO, death_duration)
	tween.tween_property(visuals, "modulate:a", 0.0, death_duration)
	if health_bar != null:
		tween.tween_property(health_bar, "modulate:a", 0.0, death_duration)

	# Splash! The shrink+fade alone reads as "mistake"; a burst of
	# droplets the same colour as the body reads as "the slime popped".
	_spawn_death_burst()

	# Tell listeners (loot drops, score, wave counters, ...) - BEFORE we
	# disappear, while the node is still valid.
	died.emit()

	# Wait, then remove ourselves from the scene tree for good.
	# queue_free() deletes the node at the end of the current frame,
	# which is the safe way to delete a node from inside its own code.
	await get_tree().create_timer(death_duration).timeout
	queue_free()


## One-shot burst of small squares in the slime's colour, flying outward
## and falling back down - the classic "goo splat".
##
## Created in CODE (not in the scene file) because we only ever need it
## once per slime, at the moment of death. KEY DETAIL: the burst is added
## to this slime's PARENT, not to the slime itself - the slime frees
## itself 0.3 s after dying, which would cut the particles short.
func _spawn_death_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true        # fire once, then stop on its own
	burst.amount = 14            # how many droplets
	burst.lifetime = 0.45        # how long each droplet lives (seconds)
	burst.explosiveness = 1.0    # 1.0 = all droplets spawn at once (a pop)
	burst.direction = Vector2.UP # base direction; `spread` scatters it
	burst.spread = 180.0         # so droplets can fly in ANY direction
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 140.0
	burst.gravity = Vector2(0, 240)  # droplets arc back down like goo
	burst.scale_amount_min = 1.5     # tiny 1-2 px squares, ...
	burst.scale_amount_max = 3.5     # ... big enough to see
	burst.color = body_color.darkened(0.1)
	burst.emitting = false       # position it first, THEN fire

	# Parent it next to us (we are kept as a node but dying).
	get_parent().add_child(burst)
	burst.global_position = global_position + Vector2(0, 4)
	burst.emitting = true

	# CPUParticles2D emits `finished` when a one-shot emission completes;
	# use it to clean the burst node up automatically.
	burst.finished.connect(burst.queue_free)


# =====================================================================
# HEALTH BAR
# =====================================================================

func _update_health_bar() -> void:
	if health_bar == null:
		return
	# The bar node draws itself (see scripts/ui/health_bar.gd); we only
	# have to hand it the new numbers.
	health_bar.set_health(current_health, max_health)
