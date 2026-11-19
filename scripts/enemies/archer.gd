extends CharacterBody2D
## Skeleton Archer - the first RANGED enemy.
##
## Opposite personality of the slime:
##   - the slime runs AT you, the archer runs AWAY;
##   - the slime wants to be next to you, the archer wants distance;
##   - the slime's attack is a dodge-or-die lunge, the archer's attack is
##     a single arrow you can sidestep WHILE it flies.
##
## State machine:
##   REPOSITION -> keep a comfortable shooting distance
##   AIM        -> telegraph: draw the bow, glow red (DODGE ME warning)
##   SHOOT      -> spawn the arrow, done
##   COOLDOWN   -> walk around, cannot shoot yet
##
## Same combat contract as the slime (docs/ARCHITECTURE.md):
##   * the PLAYER'S hitbox calls our take_damage()            (we get hurt)
##   * our ARROW calls the player's take_damage()         (we deal damage)
## Damage logic lives in exactly one place per direction.

# =====================================================================
# SIGNALS
# =====================================================================

signal health_changed(current_health: int, max_health: int)
signal died


# =====================================================================
# EXPORTED SETTINGS
# =====================================================================

@export var max_health: int = 24
@export var current_health: int = 24

## Speed while shuffling to keep its favourite distance.
@export var move_speed: float = 55.0

## Hard cap the wave spawner may push us to (golem/archer stay slower
## than slimes - that is their personality).
@export var max_move_speed: float = 80.0

## Closer than this = uncomfortable, walk BACKWARDS.
@export var retreat_distance: float = 90.0

## At this distance or nearer, we stand still and start aiming.
## (Also the maximum distance at which we bother to shoot.)
@export var shooting_distance: float = 260.0

## Damage of one arrow.
@export var attack_damage: int = 5

## Aim (telegraph) duration: LONGER than slime wind-up on purpose -
## you see the red glow early enough to step aside.
@export var aim_duration: float = 0.55

## No shooting again for this long after an arrow.
@export var attack_cooldown: float = 2.0

## Flash duration when hit.
@export var flash_duration: float = 0.1

## Death squash/fade duration.
@export var death_duration: float = 0.3

## The arrow scene we spawn. Set in the scene file so Archer.tscn keeps
## working even if Arrow.tscn's path changes in one place only.
@export var arrow_scene: PackedScene

# =====================================================================
# STATE
# =====================================================================

var is_dead: bool = false
var _is_flashing: bool = false

enum AttackState { REPOSITION, AIM, SHOOT, COOLDOWN }
var _attack_state: AttackState = AttackState.REPOSITION
var _attack_timer: float = 0.0

# =====================================================================
# NODE REFERENCES
# =====================================================================

@onready var visuals: Sprite2D = $Visuals
@onready var anim_player: AnimationPlayer = $AnimPlayer
@onready var hurtbox: Area2D = $Hurtbox
@onready var health_bar: Node2D = $HealthBar
@onready var hit_sfx: AudioStreamPlayer = $HitSFX
@onready var death_sfx: AudioStreamPlayer = $DeathSFX

var player: Node2D = null


# =====================================================================
# SETUP + MAIN LOOP
# =====================================================================

func _ready() -> void:
	current_health = clampi(current_health, 0, max_health)

	hit_sfx.stream = SFXGenerator.create_hit_sfx()
	death_sfx.stream = SFXGenerator.create_death_sfx()

	player = get_tree().get_first_node_in_group("player")
	_update_health_bar()
	health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	_update_attack_state(delta)

	match _attack_state:
		AttackState.REPOSITION:
			_keep_distance()
		AttackState.AIM:
			velocity = Vector2.ZERO   # planted feet while drawing the bow
			move_and_slide()
			_set_walking(false)
		AttackState.SHOOT:
			# One physics frame of "release": spawn and move on.
			_fire()
			_attack_state = AttackState.COOLDOWN
			_attack_timer = attack_cooldown
		AttackState.COOLDOWN:
			# While cooling down, drift to a comfortable distance if the
			# player got closer - this is what makes him FEEL skittish.
			_keep_distance()

	# Face the player whenever he exists: sprite flip is cheap and
	# reads instantly. (Our texture looks to the RIGHT by default.)
	if player != null and is_instance_valid(player):
		visuals.flip_h = player.global_position.x < global_position.x


## Advance the small state machine.
func _update_attack_state(delta: float) -> void:
	_attack_timer -= delta

	match _attack_state:
		AttackState.AIM:
			if _attack_timer <= 0.0:
				_attack_state = AttackState.SHOOT
		AttackState.COOLDOWN:
			if _attack_timer <= 0.0:
				_attack_state = AttackState.REPOSITION
		_:
			pass

	# In REPOSITION a valid target within range begins the aim.
	if _attack_state == AttackState.REPOSITION and _is_player_alive():
		var distance := global_position.distance_to(player.global_position)
		if distance <= shooting_distance:
			_start_aim()


## Telegraph: red glow + tiny step forward like pulling an arrow out.
func _start_aim() -> void:
	_attack_state = AttackState.AIM
	_attack_timer = aim_duration
	velocity = Vector2.ZERO
	_set_walking(false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "modulate", Color(1.0, 0.5, 0.5), aim_duration)
	tween.tween_property(visuals, "scale", Vector2(1.1, 0.95), aim_duration)


## Spawn the arrow aimed at where the player IS NOW (a small grace:
## strafing during the aim already makes the shot miss).
func _fire() -> void:
	# Reset visuals in case the player died mid-aim.
	visuals.modulate = Color.WHITE
	visuals.scale = Vector2.ONE

	if not _is_player_alive() or arrow_scene == null:
		return

	var arrow := arrow_scene.instantiate()
	arrow.damage = attack_damage
	get_parent().add_child(arrow)
	arrow.launch(global_position + Vector2(0, -2),
		player.global_position - global_position)

	# Whoosh/job juice: a quick lunge-lean opposite to the shot.
	var tween := create_tween()
	tween.tween_property(visuals, "scale", Vector2.ONE, 0.12)


## The skittish part: stand at <= retreat_distance? Walk away.
## Inside shooting range? Hold ground (and let _update_attack_state aim).
func _keep_distance() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player == null or player.get("is_dead"):
		velocity = Vector2.ZERO
		move_and_slide()
		_set_walking(false)
		return

	var to_player: Vector2 = player.global_position - global_position
	var distance := to_player.length()

	if distance < retreat_distance:
		# Too close! Back away (opposite direction, same speed).
		velocity = -to_player.normalized() * move_speed
		_set_walking(true)
	elif distance > shooting_distance:
		# Too far to shoot from: shuffle in a bit.
		velocity = to_player.normalized() * move_speed * 0.8
		_set_walking(true)
	else:
		velocity = Vector2.ZERO
		_set_walking(false)

	move_and_slide()


func _is_player_alive() -> bool:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	return not player.get("is_dead")


# =====================================================================
# ANIMATION
# =====================================================================

func _set_walking(walking: bool) -> void:
	var desired := "walk" if walking else "idle"
	if anim_player.current_animation != desired:
		anim_player.play(desired)


# =====================================================================
# DAMAGE  (called BY the player's hitbox)
# =====================================================================

func take_damage(amount: int) -> void:
	if is_dead:
		return

	current_health -= amount
	current_health = maxi(current_health, 0)
	print("[Archer] ", name, " took ", amount, " damage  ->  HP ",
		current_health, "/", max_health)

	hit_sfx.play()
	_update_health_bar()
	health_changed.emit(current_health, max_health)
	flash_white(flash_duration)

	if current_health <= 0:
		die()


## Tint RED (not white): the sprite has real pixels, so multiplying to
## pure white would just show the original colours - red reads as "hit".
func flash_white(duration: float) -> void:
	if _is_flashing or is_dead:
		return
	_is_flashing = true
	visuals.modulate = Color(1, 0.35, 0.35)
	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(visuals) or is_dead:
		return
	visuals.modulate = Color.WHITE
	_is_flashing = false


func die() -> void:
	if is_dead:
		return
	is_dead = true

	print("[Archer] ", name, " died (skeleton collapses)")
	death_sfx.play()

	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	var tween := create_tween()
	tween.set_parallel(true)
	# Skeletons don't squash - they topple: rotate and drop.
	tween.tween_property(visuals, "rotation_degrees", 90.0, death_duration)
	tween.tween_property(visuals, "position:y", visuals.position.y + 6.0, death_duration)
	tween.tween_property(visuals, "modulate:a", 0.0, death_duration)
	if health_bar != null:
		tween.tween_property(health_bar, "modulate:a", 0.0, death_duration)

	# Bone-white dust puff instead of goo.
	_spawn_death_burst()

	died.emit()

	await get_tree().create_timer(death_duration).timeout
	queue_free()


func _spawn_death_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.amount = 12
	burst.lifetime = 0.4
	burst.explosiveness = 1.0
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.initial_velocity_min = 50.0
	burst.initial_velocity_max = 110.0
	burst.gravity = Vector2(0, 240)
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 2.0
	burst.color = Color(0.87, 0.85, 0.75)  # bone chips
	burst.emitting = false
	get_parent().add_child(burst)
	burst.global_position = global_position + Vector2(0, 4)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)


# =====================================================================
# HEALTH BAR
# =====================================================================

func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.set_health(current_health, max_health)
