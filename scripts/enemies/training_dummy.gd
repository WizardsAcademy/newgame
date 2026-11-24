extends CharacterBody2D
## Medieval Straw & Iron Training Dummy (`DummyTarget`) in the Lobby Training Room.
##
## Joins group `"enemies"` with a standard Layer-5 (`16`) `Hurtbox` so EVERY hero
## attack, projectile, stun, and Noa's 2-Fang 30% Curse works natively on it!
##   - `max_health = 100` (so Noa's 30% Fang Curse pops for an exact `-30`!).
##   - Clamps at `1 HP` minimum (never permanently dies) and smoothly refills
##     back to `100 / 100` after `2.2s` out of combat.

signal health_changed(current_health: int, max_health: int)
signal died

const HealthBarScript := preload("res://scripts/ui/health_bar.gd")
const DUMMY_SHEET_PATH := "res://assets/textures/training_dummy.png"

@export var max_health: int = 100
@export var current_health: int = 100

var is_dead: bool = false
var is_elite: bool = false
var immovable_dummy: bool = true
var keep_physics_when_stunned: bool = true

var total_hits_taken: int = 0
var _frames: Array[AtlasTexture] = []
var _wobble_left: float = 0.0
var _wobble_side: int = 1
var _refill_delay_left: float = 0.0

var visuals: Sprite2D = null
var hurtbox: Area2D = null
var health_bar: Node2D = null
var hit_sfx: AudioStreamPlayer = null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("training_dummy")
	collision_layer = 4
	collision_mask = 1

	var body_col := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(18.0, 18.0)
	body_col.shape = body_rect
	add_child(body_col)

	visuals = Sprite2D.new()
	visuals.name = "Visuals"
	visuals.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visuals.position = Vector2(0.0, -5.0)
	visuals.scale = Vector2(0.5, 0.5)
	add_child(visuals)

	if ResourceLoader.exists(DUMMY_SHEET_PATH):
		var sheet: Texture2D = load(DUMMY_SHEET_PATH)
		if sheet != null:
			for i in range(4):
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(float(i * 64), 0.0, 64.0, 64.0)
				_frames.append(at)
			if not _frames.is_empty():
				visuals.texture = _frames[0]

	hurtbox = Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 8
	var hb_col := CollisionShape2D.new()
	var hb_shape := RectangleShape2D.new()
	hb_shape.size = Vector2(26.0, 34.0)
	hb_col.shape = hb_shape
	hb_col.position = Vector2(0.0, -6.0)
	hurtbox.add_child(hb_col)
	add_child(hurtbox)

	health_bar = HealthBarScript.new()
	health_bar.name = "HealthBar"
	health_bar.bar_size = Vector2(28.0, 4.0)
	health_bar.bar_offset = Vector2(0.0, -34.0)
	add_child(health_bar)
	health_bar.set_health(current_health, max_health)

	var tag := Label.new()
	tag.text = "DUMMY"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 7)
	tag.add_theme_color_override("font_color", Color(0.96, 0.88, 0.68, 0.90))
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	tag.add_theme_constant_override("outline_size", 2)
	tag.position = Vector2(-24.0, 14.0)
	tag.size = Vector2(48.0, 12.0)
	add_child(tag)

	hit_sfx = AudioStreamPlayer.new()
	hit_sfx.bus = &"SFX"
	hit_sfx.stream = SFXGenerator.create_hit_sfx()
	add_child(hit_sfx)


func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	total_hits_taken += 1
	current_health = maxi(current_health - amount, 1)
	_refill_delay_left = 2.2
	_wobble_left = 0.22
	_wobble_side = -_wobble_side

	if _frames.size() >= 3 and visuals != null:
		visuals.texture = _frames[1 if _wobble_side < 0 else 2]
		visuals.modulate = Color(1.0, 0.92, 0.80)

	if hit_sfx != null:
		hit_sfx.pitch_scale = randf_range(0.92, 1.12)
		hit_sfx.play()

	if health_bar != null:
		health_bar.set_health(current_health, max_health)
	health_changed.emit(current_health, max_health)


func _process(delta: float) -> void:
	if _wobble_left > 0.0:
		_wobble_left = maxf(_wobble_left - delta, 0.0)
		if visuals != null:
			visuals.rotation = sin(_wobble_left * 42.0) * 0.14 * float(_wobble_side)
			if _wobble_left <= 0.0:
				visuals.rotation = 0.0
				visuals.modulate = Color.WHITE
				if not _frames.is_empty():
					visuals.texture = _frames[0]

	if _refill_delay_left > 0.0:
		_refill_delay_left = maxf(_refill_delay_left - delta, 0.0)
	elif current_health < max_health:
		current_health = mini(current_health + maxi(int(ceil(60.0 * delta)), 1), max_health)
		if health_bar != null:
			health_bar.set_health(current_health, max_health)
		health_changed.emit(current_health, max_health)
