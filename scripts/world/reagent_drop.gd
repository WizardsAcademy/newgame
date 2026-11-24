extends Node2D
class_name ReagentDrop
## Collectible Witch Alchemy Ingredient dropped by slain monsters & cleared waves!
##
## Give collected Reagents (`REAGENTS_PER_POTION = 3`) to the Witch at the Cottage
## Cauldron so she brews Potions (`Majon` = Skill Points) for your Hero!

signal collected(amount: int, item_name: String, world_pos: Vector2)

const REAGENTS_TEX_PATH := "res://assets/textures/witch_reagents.png"

var reagent_amount: int = 1
var item_label: String = "Moonshade Herb"
var magnet_radius: float = 110.0
var pickup_radius: float = 24.0
var target_player: Node2D = null

var _sprite: Sprite2D = null
var _time: float = 0.0
var _pop_vel: Vector2 = Vector2.ZERO
var _collected_done: bool = false


func setup(at_pos: Vector2, amount: int, frame_idx: int, label_str: String, player_node: Node2D) -> void:
	global_position = at_pos
	reagent_amount = maxi(amount, 1)
	item_label = label_str
	target_player = player_node
	add_to_group("reagent_drops")

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(0.62, 0.62)
	if ResourceLoader.exists(REAGENTS_TEX_PATH):
		var strip: Texture2D = load(REAGENTS_TEX_PATH)
		if strip != null:
			var at := AtlasTexture.new()
			at.atlas = strip
			at.region = Rect2(float(clampi(frame_idx, 0, 2) * 32), 0.0, 32.0, 32.0)
			_sprite.texture = at
	add_child(_sprite)

	var ang := randf_range(0.0, TAU)
	_pop_vel = Vector2(cos(ang), sin(ang)) * randf_range(26.0, 52.0)


func _process(delta: float) -> void:
	if _collected_done:
		return
	_time += delta

	if _pop_vel.length() > 1.0:
		global_position += _pop_vel * delta
		_pop_vel = _pop_vel.move_toward(Vector2.ZERO, 180.0 * delta)

	if _sprite != null:
		_sprite.position.y = sin(_time * 5.5) * 2.5

	if target_player == null or not is_instance_valid(target_player):
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty() and players[0] is Node2D:
			target_player = players[0] as Node2D

	if target_player != null and is_instance_valid(target_player) and target_player.get("is_dead") != true:
		var to_p := target_player.global_position - global_position
		var dist := to_p.length()
		if dist <= pickup_radius:
			collect_now()
			return
		if dist <= magnet_radius:
			var pull_spd := lerpf(260.0, 95.0, clampf(dist / magnet_radius, 0.0, 1.0))
			global_position += to_p.normalized() * pull_spd * delta
	queue_redraw()


func collect_now() -> void:
	if _collected_done:
		return
	_collected_done = true
	collected.emit(reagent_amount, item_label, global_position)
	queue_free()


func _draw() -> void:
	var pulse := 0.28 + 0.12 * sin(_time * 6.0)
	var glow_col := Color(0.42, 1.0, 0.68, pulse) if reagent_amount == 1 else (
		Color(1.0, 0.36, 0.62, pulse) if reagent_amount == 2 else Color(0.84, 0.56, 1.0, pulse + 0.08)
	)
	draw_circle(Vector2(0.0, 2.0), 8.5, glow_col)
