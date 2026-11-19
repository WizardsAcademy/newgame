extends Area2D
## Arrow - the projectile the Skeleton Archer fires.
##
## A projectile is the simplest kind of gameplay object:
##   1. it exists somewhere,
##   2. it moves in one direction every physics frame,
##   3. when it touches a player hurtbox, the damage is applied ONCE,
##   4. it removes itself when it hits something or flies far enough.
##
## NOTE the "authoritative" rule from docs/ARCHITECTURE.md: the ARROW
## only reports the hit to the player (`take_damage`). It never reads
## the player's health or edits HUD values itself.

# =====================================================================
# SIGNALS
# =====================================================================

## Main (or whoever spawned us) can listen to this for effects;
## currently unused but keeps the projectile self-documenting.
signal arrow_removed


# =====================================================================
# EXPORTED SETTINGS
# =====================================================================

## Flight speed in pixels per second.
@export var speed: float = 240.0

## Damage applied to what we hit.
@export var damage: int = 5

## How far (in pixels) we may fly before giving up and vanishing.
@export var max_range: float = 420.0

# =====================================================================
# STATE
# =====================================================================

var _direction: Vector2 = Vector2.RIGHT
var _distance_flown: float = 0.0
var _has_hit: bool = false


# =====================================================================
# SETUP + MAIN LOOP
# =====================================================================

## Called by the archer RIGHT BEFORE add_child(), so the very first
## frame the arrow already flies the right way.
func launch(from_position: Vector2, direction: Vector2) -> void:
	global_position = from_position
	_direction = direction.normalized()
	# Point the sprite along the flight path. rotation works because the
	# arrow texture is drawn pointing RIGHT (rotation = 0).
	rotation = _direction.angle()


func _ready() -> void:
	# `area_entered` fires when our Area overlaps ANOTHER area - here
	# that is the player's Hurtbox (layer 64 -> our mask 32 seen from
	# the other side; see the layer table in docs/ARCHITECTURE.md).
	area_entered.connect(_on_area_entered)
	# `body_entered` fires when we touch a real PHYSICS BODY - the arena
	# walls (layer 1). Arrows stick in walls instead of flying on out
	# of the world.
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	var step: Vector2 = _direction * speed * delta
	global_position += step
	_distance_flown += step.length()

	# Out of fuel: nobody will ever see this arrow again, so remove it.
	if _distance_flown >= max_range:
		_remove()


## Once is a rule: the same arrow never deals two hits, even if its
## overlap signal fires several frames in a row.
func _on_area_entered(area: Area2D) -> void:
	if _has_hit:
		return

	# Walk up from the touched area to find something with take_damage()
	# (the player's hurtbox sits inside the Player body node).
	var current: Node = area
	var guard := 4
	while current != null and guard > 0:
		if current.has_method("take_damage"):
			_has_hit = true
			current.take_damage(damage, global_position)
			_remove()
			return
		current = current.get_parent()
		guard -= 1


## A wall stopped us: puff at the impact point and remove ourselves.
func _on_body_entered(_body: Node2D) -> void:
	if not _has_hit:
		_has_hit = true
		_remove()


## Small "stick" puff of dust where the arrow died, then free.
func _remove() -> void:
	arrow_removed.emit()

	# A tiny grey burst sells "hit the wall / hit flesh".
	var puff := CPUParticles2D.new()
	puff.one_shot = true
	puff.amount = 6
	puff.lifetime = 0.2
	puff.explosiveness = 1.0
	puff.spread = 180.0
	puff.initial_velocity_min = 30.0
	puff.initial_velocity_max = 70.0
	puff.scale_amount_min = 1.0
	puff.scale_amount_max = 2.0
	puff.color = Color(0.85, 0.8, 0.65)
	puff.emitting = false

	get_parent().add_child(puff)
	puff.global_position = global_position
	puff.emitting = true
	puff.finished.connect(puff.queue_free)

	queue_free()
