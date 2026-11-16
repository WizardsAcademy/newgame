extends Node2D
## A one-shot "hit spark": a tiny 6x6 fist-colored particle that pops at the
## impact point and fades out in ~0.15 s, then deletes itself.
##
## IMPORTANT (for beginner devs):
##  - `Visual` slices a 6x6 region (`region_rect = Rect2(0, 0, 6, 6)`) out of
##    `white_pixel.png` and tints it with the player's warm gold fist color,
##    so it looks like a crisp impact flash rather than a second character body.
##  - It is spawned ONLY inside `player.gd`'s `_try_hit()` when an attack
##    actually connects with an enemy - never during an empty-air swing.
##  - Keeping it in a standalone scene (`res://scenes/fx/HitSpark.tscn`) lets
##    any weapon or enemy reuse the same impact effect in three lines:
##
##     var spark := preload("res://scenes/fx/HitSpark.tscn").instantiate()
##     get_parent().add_child(spark)
##     spark.global_position = hit_position

@export var start_scale: Vector2 = Vector2(0.8, 0.8)
@export var end_scale: Vector2 = Vector2(1.25, 1.25)
@export var lifetime: float = 0.15
## Matches the warm gold highlight on the player's fist (#ffcd75).
@export var spark_color: Color = Color(1.0, 0.804, 0.459, 1.0)


func _ready() -> void:
	var visual: Sprite2D = $Visual
	visual.self_modulate = spark_color
	visual.scale = start_scale

	# A short tween: pop slightly + fade at the same time, then free the node.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", end_scale, lifetime)
	tween.tween_property(visual, "modulate:a", 0.0, lifetime)

	# queue_free() runs after the tween finishes. `tween.finished` is a
	# signal; `await` on it pauses just this function.
	await tween.finished
	queue_free()
