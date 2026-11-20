extends CharacterBody2D
## Stone Golem - the first "heavy" enemy (mini-elite).
##
## Personality: a walking wall.
##   - VERY slow (you can always outwalk it),
##   - LOTS of health (punching it is a commitment),
##   - but its ground slam HURTS and shakes the whole room.
##
## State machine:
##   CHASE    -> slow walk toward the player
##   TELEGRAPH-> raise both arms + red glow (DODGE-ME warning, generous)
##   SLAM     -> AOE shockwave: hitbox live for the blink of an eye
##   RECOVER  -> the golem is stuck in the ground: free hits (that is
##               the fair trade - big damage paid with big vulnerability)
##   COOLDOWN -> back to chasing
##
## Fairness rules from docs/VISION.md pillar 4:
##   - the telegraph is LONG (0.8 s),
##   - the slam covers a FIXED radius you can learn,
##   - a slam that misses = a long punish window.

# =====================================================================
# SIGNALS
# =====================================================================

signal health_changed(current_health: int, max_health: int)
signal died


# =====================================================================
# EXPORTED SETTINGS
# =====================================================================

@export var max_health: int = 90
@export var current_health: int = 90

## Deliberately glacial.
@export var move_speed: float = 30.0

## Cap for the wave spawner: a fast golem would be unfair AND weird.
@export var max_move_speed: float = 45.0

## Slam starts when the player is at least this close (centre to centre).
@export var slam_trigger_range: float = 44.0

## Radius of the slam shockwave (his AttackArea shape should match).
@export var slam_radius: float = 46.0

## Slam damage.
@export var attack_damage: int = 15

## Arm-raise duration: THE dodge window.
@export var telegraph_duration: float = 0.8

## Seconds the shockwave hitbox is live (basically one frame of contact).
@export var slam_active_duration: float = 0.08

## Stuck-in-the-ground recovery after the slam (the punish window).
@export var recover_duration: float = 0.9

## Breather before the next chase.
@export var attack_cooldown: float = 0.6

@export var flash_duration: float = 0.1
@export var death_duration: float = 0.45

# =====================================================================
# STATE
# =====================================================================

var is_dead: bool = false
var _is_flashing: bool = false
var _has_hit_this_slam: bool = false

## Set by the wave spawner for hero versions (golden ring, 3x HP).
var is_elite: bool = false

enum AttackState { CHASE, TELEGRAPH, SLAM, RECOVER, COOLDOWN }
var _attack_state: AttackState = AttackState.CHASE
var _attack_timer: float = 0.0

# =====================================================================
# NODE REFERENCES
# =====================================================================

@onready var visuals: Sprite2D = $Visuals
@onready var anim_player: AnimationPlayer = $AnimPlayer
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_area: Area2D = $AttackArea
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

	# Same "deliberate hit" pattern as the slime: the slam sensor is
	# switched ON only during the SLAM window.
	attack_area.monitoring = false
	attack_area.monitorable = false
	attack_area.area_entered.connect(_on_attack_area_area_entered)

	_update_health_bar()
	health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	_update_attack_state(delta)

	match _attack_state:
		AttackState.CHASE, AttackState.COOLDOWN:
			_chase_player()
		AttackState.TELEGRAPH, AttackState.RECOVER:
			velocity = Vector2.ZERO
			move_and_slide()
			_set_walking(false)
			# Rubber-banding slam: the shockwave stays live during SLAM
			# only; nothing to do per-frame here, timers do the work.
		AttackState.SLAM:
			# Slam is instant: hitbox was already toggled; wait it out.
			velocity = Vector2.ZERO


## Advance the state machine timers.
func _update_attack_state(delta: float) -> void:
	_attack_timer -= delta

	match _attack_state:
		AttackState.TELEGRAPH:
			if _attack_timer <= 0.0:
				_start_slam()
		AttackState.SLAM:
			if _attack_timer <= 0.0:
				_end_slam()
		AttackState.RECOVER:
			if _attack_timer <= 0.0:
				_attack_state = AttackState.COOLDOWN
				_attack_timer = attack_cooldown
		AttackState.COOLDOWN:
			if _attack_timer <= 0.0:
				_attack_state = AttackState.CHASE
		_:
			pass

	if _attack_state == AttackState.CHASE:
		_maybe_start_attack()


func _maybe_start_attack() -> void:
	if not _is_player_alive():
		return
	var distance := global_position.distance_to(player.global_position)
	if distance <= slam_trigger_range:
		_attack_state = AttackState.TELEGRAPH
		_attack_timer = telegraph_duration
		velocity = Vector2.ZERO
		_set_walking(false)
		_show_telegraph()


## The warning: arms UP (sprite lifts + stretches) and glows red.
func _show_telegraph() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "position:y", -4.0, telegraph_duration)
	tween.tween_property(visuals, "scale", Vector2(0.92, 1.08), telegraph_duration)
	tween.tween_property(visuals, "modulate", Color(1.0, 0.4, 0.35), telegraph_duration)


## The moment of impact: hitbox ON, room-shaking juice, ring of dust.
func _start_slam() -> void:
	if not _is_player_alive():
		_reset_visuals()
		_attack_state = AttackState.COOLDOWN
		_attack_timer = attack_cooldown
		return

	_has_hit_this_slam = false
	attack_area.set_deferred("monitoring", true)

	# --- JUICE (docs/VISION.md pillar 1: every hit must be FELT) -----
	ScreenShake.shake(6.0, 0.3)      # the biggest shake in the game so far
	HitStop.freeze(0.05)
	_spawn_slam_ring()

	visuals.position = Vector2(0, 2)   # arms crash down
	visuals.scale = Vector2(1.2, 0.85)
	visuals.modulate = Color.WHITE

	_attack_state = AttackState.SLAM
	_attack_timer = slam_active_duration


## Shockwave over: hitbox off, golem is stuck - the punish window opens.
func _end_slam() -> void:
	attack_area.set_deferred("monitoring", false)
	_attack_state = AttackState.RECOVER
	_attack_timer = recover_duration
	_reset_visuals()


## Called by the wave spawner for hero versions of this enemy.
## Shared package (3x HP + golden ring) lives in Elite. The golem's
## own extra: UPRISING - a much bigger slam (radius x1.5) and +5
## damage. (The slam's live hitbox is the AttackArea circle from the
## scene file - `slam_radius` is the exported reference value.)
func become_elite() -> void:
	is_elite = true
	Elite.make_enemy_elite(self)
	attack_damage += 5

	# Enlarge the slam AOE. CAREFUL: the CircleShape2D from Golem.tscn
	# is a SHARED resource - editing its radius directly would secretly
	# buff every golem in the arena. Duplicate first, enlarge the copy.
	var shape_node: CollisionShape2D = attack_area.get_node("CollisionShape2D")
	var circle := shape_node.shape as CircleShape2D
	if circle != null:
		var elite_circle: CircleShape2D = circle.duplicate()
		elite_circle.radius *= 1.5
		shape_node.shape = elite_circle


func _reset_visuals() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "position:y", 0.0, 0.25)
	tween.tween_property(visuals, "scale", Vector2.ONE, 0.25)
	tween.tween_property(visuals, "modulate", Color.WHITE, 0.25)


## Ring of stone dust flying outward: AOE attacks need to SHOW their
## radius, otherwise players cannot learn to dodge them fairly.
func _spawn_slam_ring() -> void:
	var ring := CPUParticles2D.new()
	ring.one_shot = true
	ring.amount = 22
	ring.lifetime = 0.4
	ring.explosiveness = 1.0
	ring.direction = Vector2.UP
	ring.spread = 90.0
	ring.initial_velocity_min = 90.0
	ring.initial_velocity_max = 170.0
	ring.gravity = Vector2(0, 300)
	ring.scale_amount_min = 1.5
	ring.scale_amount_max = 3.5
	ring.color = Color(0.45, 0.44, 0.5)   # stone grey dust
	ring.emitting = false
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector2(0, 6)
	ring.emitting = true
	ring.finished.connect(ring.queue_free)


func _is_player_alive() -> bool:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	return not player.get("is_dead")


## Slow, relentless straight-line walk (same naive AI as the slime - the
## arena is open; real pathfinding can come later if a maze appears).
func _chase_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player == null or player.get("is_dead"):
		velocity = Vector2.ZERO
		move_and_slide()
		_set_walking(false)
		return

	var to_player: Vector2 = player.global_position - global_position
	if to_player.length() > slam_trigger_range * 0.9:
		velocity = to_player.normalized() * move_speed
		_set_walking(true)
	else:
		velocity = Vector2.ZERO
		_set_walking(false)
	move_and_slide()


# =====================================================================
# ANIMATION
# =====================================================================

func _set_walking(walking: bool) -> void:
	var desired := "walk" if walking else "idle"
	if anim_player.current_animation != desired:
		anim_player.play(desired)


# =====================================================================
# DAMAGE
# =====================================================================

## The slam's AttackArea touched the player's hurtbox.
func _on_attack_area_area_entered(area: Area2D) -> void:
	if _has_hit_this_slam or is_dead:
		return
	var current: Node = area
	var guard := 4
	while current != null and guard > 0:
		if current != self and current.has_method("take_damage"):
			_has_hit_this_slam = true
			hit_sfx.play()
			current.take_damage(attack_damage, global_position)
			print("[Golem] ", name, " slammed the player for ", attack_damage)
			return
		current = current.get_parent()
		guard -= 1


## Called by the player's hitbox.
func take_damage(amount: int) -> void:
	if is_dead:
		return
	current_health -= amount
	current_health = maxi(current_health, 0)
	print("[Golem] ", name, " took ", amount, " damage  ->  HP ",
		current_health, "/", max_health)

	hit_sfx.play()
	_update_health_bar()
	health_changed.emit(current_health, max_health)
	flash_white(flash_duration)

	if current_health <= 0:
		die()


func flash_white(duration: float) -> void:
	if _is_flashing or is_dead:
		return
	_is_flashing = true
	visuals.modulate = Color(1, 0.4, 0.4)
	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(visuals) or is_dead:
		return
	if not is_dead and _attack_state != AttackState.TELEGRAPH:
		visuals.modulate = Color.WHITE
	_is_flashing = false


func die() -> void:
	if is_dead:
		return
	is_dead = true
	print("[Golem] ", name, " died (crumbles)")

	death_sfx.play()

	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	attack_area.set_deferred("monitoring", false)
	attack_area.set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	var tween := create_tween()
	tween.set_parallel(true)
	# Golems crumble: sink into the ground and fade.
	tween.tween_property(visuals, "scale:y", 0.15, death_duration)
	tween.tween_property(visuals, "position:y", 6.0, death_duration)
	tween.tween_property(visuals, "modulate:a", 0.0, death_duration)
	if health_bar != null:
		tween.tween_property(health_bar, "modulate:a", 0.0, death_duration)

	_spawn_death_burst()
	died.emit()

	await get_tree().create_timer(death_duration).timeout
	queue_free()


## Rubble shower: grey chunks falling around the corpse.
func _spawn_death_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.amount = 20
	burst.lifetime = 0.55
	burst.explosiveness = 1.0
	burst.direction = Vector2.UP
	burst.spread = 80.0
	burst.initial_velocity_min = 70.0
	burst.initial_velocity_max = 150.0
	burst.gravity = Vector2(0, 320)
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	burst.color = Color(0.42, 0.42, 0.48)
	burst.emitting = false
	get_parent().add_child(burst)
	burst.global_position = global_position
	burst.emitting = true
	burst.finished.connect(burst.queue_free)


# =====================================================================
# HEALTH BAR
# =====================================================================

func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.set_health(current_health, max_health)
