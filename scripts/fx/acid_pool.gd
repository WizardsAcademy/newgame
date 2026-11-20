extends Node2D
## AcidPool - what an Acid Slime leaves behind when it dies.
##
## The whole point of the Acid Slime is that killing it is not the end of the
## threat: the floor it died on stays dangerous for a few seconds, so the
## player has to *choose where to fight*. That makes it the first enemy in the
## game that punishes positioning instead of reflexes.
##
## HOW IT WORKS
##   * an Area2D-free hazard: every `tick_interval` it asks the tree for
##     nodes in the "player" group and damages the ones inside `radius`.
##     (Distance checks are enough for a round puddle, need no collision
##     layers, and cannot be fooled by the player's hurtbox being a child
##     of a moving body.)
##   * it is drawn with `_draw()` - no texture, no animation file, and the
##     bubble positions are seeded so every pool looks slightly different.
##   * it lives in the ARENA (parented by the slime, not carried by it), so
##     the slime's queue_free() cannot take the puddle away mid-fight.
##   * MAX_POOLS caps how much purple soup a wave can put on screen.

## Damage radius in pixels.
@export var radius: float = 26.0

## Damage per tick to anything standing in the puddle.
@export var damage_per_tick: int = 3

## Seconds between damage ticks.
@export var tick_interval: float = 0.5

## Total life in seconds.
@export var lifetime: float = 4.0

## The last part of the life is spent fading out (so it never pops).
@export var fade_time: float = 0.9

@export var fill_color: Color = Color(0.55, 0.25, 0.75, 0.32)
@export var inner_color: Color = Color(0.68, 0.38, 0.90, 0.22)
@export var edge_color: Color = Color(0.72, 0.42, 0.98, 0.90)

## Hard cap on how many pools may exist at once.
const MAX_POOLS: int = 6

const GROUP: String = "acid_pools"

var _age: float = 0.0
var _tick_timer: float = 0.0

## Seeded bubble look: (angle, distance, size, phase).
var _bubbles: Array = []


func _ready() -> void:
	add_to_group(GROUP)
	_tick_timer = tick_interval * 0.5   # first tick lands quickly
	_seed_bubbles()
	_trim_old_pools()


## Keep the arena readable: when a 7th pool appears, the oldest one dries up.
##
## Only pools that are still alive count - a pool whose queue_free() has
## already been queued is on its way out and must not be counted twice,
## otherwise eight deaths in one frame could wipe the whole floor.
func _trim_old_pools() -> void:
	var alive: Array = []
	for node in get_tree().get_nodes_in_group(GROUP):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			alive.append(node)

	var excess: int = alive.size() - MAX_POOLS
	for i in maxi(excess, 0):
		var oldest: Node = alive[i]
		if oldest == self:
			continue          # we are the newest, the rest are older
		oldest.queue_free()


func _seed_bubbles() -> void:
	_bubbles.clear()
	for i in 5:
		var angle: float = randf() * TAU
		var dist: float = sqrt(randf()) * radius * 0.72
		_bubbles.append(Vector4(angle, dist, 1.2 + randf() * 1.4, randf()))


func _process(delta: float) -> void:
	_age += delta
	_tick_timer -= delta

	if _tick_timer <= 0.0 and _age < lifetime - fade_time:
		_tick_timer = tick_interval
		_damage_players_inside()

	if _age >= lifetime - fade_time:
		modulate.a = clampf((lifetime - _age) / maxf(fade_time, 0.001), 0.0, 1.0)

	queue_redraw()

	if _age >= lifetime:
		queue_free()


func _damage_players_inside() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if not (node is Node2D):
			continue
		if node.get("is_dead") == true:
			continue
		if global_position.distance_to((node as Node2D).global_position) <= radius:
			node.take_damage(damage_per_tick, global_position)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_circle(Vector2.ZERO, radius * 0.62, inner_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, edge_color, 1.5)

	# Bubbles rise and pop: cheap, deterministic, no particles needed.
	for bubble in _bubbles:
		var angle: float = bubble.x
		var dist: float = bubble.y
		var size: float = bubble.z
		var phase: float = bubble.w
		var cycle: float = fmod(_age * 0.9 + phase, 1.0)
		var centre := Vector2(cos(angle), sin(angle)) * dist
		centre.y -= cycle * 5.0
		var alpha: float = (1.0 - cycle) * 0.8
		draw_circle(centre, size, Color(edge_color.r, edge_color.g, edge_color.b, alpha))
