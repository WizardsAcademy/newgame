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
##   * it is PIXEL ART, not a `_draw()` circle. `draw_circle()` rasterises at
##     the window resolution, so the old puddle looked like a smooth vector
##     disc floating under a pixel-art world. `fx_acid_pool.png` is a
##     4-frame strip drawn at 1 texture pixel = 1 game pixel by
##     `tools/make_fx_sprites.py`; the pool just plays it.
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

## Hard cap on how many pools may exist at once.
const MAX_POOLS: int = 6

const GROUP: String = "acid_pools"

## Generated art: 4 x 64x64 frames of bubbling violet goo (see
## tools/make_fx_sprites.py). Drawn at exactly the damage radius.
const POOL_TEXTURE := preload("res://assets/textures/fx_acid_pool.png")
const POOL_FRAMES: int = 4

## Animation speed of the bubble loop (frames per second).
const POOL_FPS: float = 7.0

var _age: float = 0.0
var _tick_timer: float = 0.0

## The puddle sprite. Every pool starts on a random frame so a wave full of
## acid deaths does not bubble in lockstep.
var _sprite: Sprite2D = null
var _start_frame: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	_tick_timer = tick_interval * 0.5   # first tick lands quickly
	_build_sprite()
	_trim_old_pools()


## One Sprite2D, one strip: no AnimationPlayer, no extra scene resources.
func _build_sprite() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Art"
	_sprite.texture = POOL_TEXTURE
	_sprite.hframes = POOL_FRAMES
	_sprite.vframes = 1
	_start_frame = randi() % POOL_FRAMES
	_sprite.frame = _start_frame
	# No z tricks: this project paints with tree order (z_index -1 tucks a
	# node behind the opaque sky, the bug the archer's risk line hit).
	add_child(_sprite)


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


func _process(delta: float) -> void:
	_age += delta
	_tick_timer -= delta

	if _tick_timer <= 0.0 and _age < lifetime - fade_time:
		_tick_timer = tick_interval
		_damage_players_inside()

	if _age >= lifetime - fade_time:
		modulate.a = clampf((lifetime - _age) / maxf(fade_time, 0.001), 0.0, 1.0)

	if _sprite != null:
		_sprite.frame = (_start_frame + int(_age * POOL_FPS)) % POOL_FRAMES

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
