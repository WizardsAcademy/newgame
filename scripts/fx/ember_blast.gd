extends Node2D
## EmberBlast - the Ember Slime's parting gift.
##
## The Ember Slime is the only enemy in the game whose DEATH is the attack:
## it flashes, hisses for `fuse_time`, then explodes. Killing it next to
## yourself is a mistake, and that single sentence is the whole variant.
##
## WHY THIS IS A SEPARATE NODE
##   The slime queue_free()s itself 0.3 s after dying, so it cannot own a
##   fuse that lasts 0.55 s (a coroutine on a freed node never resumes).
##   This node is parented by the arena and owns its own timer.
##
## HOW IT READS
##   * LAYER 1: the same painted danger circle the boss uses
##     (scripts/enemies/ground_telegraph.gd), colour-coded orange, with its
##     charge meter filling as the fuse burns - the player can read exactly
##     when and where it will hurt.
##   * LAYER 2: the blob itself flashes white-hot at ~12 Hz and gets bigger.
##   * LAYER 3: the blast (expanding ring + particles) on detonation.
##   Nothing is instant: there is always >= 0.55 s to walk or dash out.

const GroundTelegraphScript := preload("res://scripts/enemies/ground_telegraph.gd")

## Seconds between the slime dying and the detonation.
@export var fuse_time: float = 0.55

## Blast radius in pixels (the union of all slimes' trigger circles).
@export var radius: float = 44.0

## Damage dealt to a player inside the blast.
@export var damage: int = 14

## Seconds the blast visuals (ring, fade) take before the node frees itself.
@export var blast_time: float = 0.35

## Whether this blast lights the fuse of other Ember Slimes inside its
## radius. Fire spreads fire - the one "combo" in the family, and the reason
## a cluster of embers is worth killing from a distance instead of up close.
@export var ignite_others: bool = true

@export var fill_color: Color = Color(1.0, 0.45, 0.12, 0.18)
@export var edge_color: Color = Color(1.0, 0.55, 0.18, 0.95)

var _timer: float = 0.0
var _exploded: bool = false
var _zone: Node2D = null


func _ready() -> void:
	add_to_group("ember_blasts")
	# Own the danger circle as a child so it can never outlive the fuse.
	_zone = GroundTelegraphScript.new()
	_zone.radius = radius
	_zone.fill_color = fill_color
	_zone.edge_color = edge_color
	add_child(_zone)
	_zone.position = Vector2.ZERO


func _process(delta: float) -> void:
	_timer += delta

	if not _exploded:
		var progress: float = clampf(_timer / maxf(fuse_time, 0.001), 0.0, 1.0)
		if _zone != null and is_instance_valid(_zone):
			_zone.set_charge(progress)
		# White-hot pulse that speeds up as the fuse runs out. The body
		# PULSES but never grows: the painted circle is the promise, and a
		# telegraph that visually outgrows its real radius would lie.
		var pulse_rate: float = 26.0 + 30.0 * progress
		modulate.a = 0.55 + 0.45 * absf(sin(_timer * pulse_rate))
		if _timer >= fuse_time:
			_explode()
	else:
		modulate.a = maxf(0.0, modulate.a - delta * 6.0)
		queue_redraw()
		if _timer >= blast_time:
			queue_free()


func _explode() -> void:
	_exploded = true
	_timer = 0.0
	modulate.a = 1.0
	if _zone != null and is_instance_valid(_zone):
		_zone.queue_free()
		_zone = null

	_damage_players_inside()
	if ignite_others:
		_ignite_other_embers()
	_spawn_particles()
	ScreenShake.shake(5.0, 0.22)
	HitStop.freeze(0.03)
	queue_redraw()


func _damage_players_inside() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if not (node is Node2D):
			continue
		if node.get("is_dead") == true:
			continue
		if global_position.distance_to((node as Node2D).global_position) <= radius:
			node.take_damage(damage, global_position)


## Light every other living Ember Slime inside the blast.
##
## `die()` sets `is_dead` before anything else, so a chained ember cannot be
## ignited twice: the cascade is bounded by the number of embers in the pile
## and always terminates.
func _ignite_other_embers() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		var variant: Variant = node.get("variant_id")
		if typeof(variant) != TYPE_STRING or String(variant) != "ember":
			continue
		if bool(node.get("is_dead")):
			continue
		if global_position.distance_to((node as Node2D).global_position) > radius:
			continue
		node.call("die")


func _spawn_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.position = Vector2.ZERO
	particles.amount = 18
	particles.lifetime = 0.35
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 120)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 110.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = Color(1.0, 0.72, 0.28, 0.95)
	add_child(particles)
	particles.emitting = true


func _draw() -> void:
	if not _exploded:
		return
	var progress: float = clampf(_timer / maxf(blast_time, 0.001), 0.0, 1.0)
	var ring: float = radius * (0.45 + 0.75 * progress)
	var fade: float = 1.0 - progress
	draw_circle(Vector2.ZERO, ring, Color(1.0, 0.60, 0.20, 0.30 * fade))
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 32,
			Color(1.0, 0.80, 0.40, 0.95 * fade), 2.0)
