extends Node2D
## A one-shot "hit spark": a small white square that pops outward and
## fades in about 0.15 s, then deletes itself.
##
## It is a separate scene (res://scenes/fx/HitSpark.tscn) so any attack
## in the game can spawn the exact same feedback with two lines:
##
##     var spark := preload("res://scenes/fx/HitSpark.tscn").instantiate()
##     get_parent().add_child(spark)
##     spark.global_position = hit_position

@export var start_scale: Vector2 = Vector2(0.35, 0.35)
@export var end_scale: Vector2 = Vector2(1.2, 1.2)
@export var lifetime: float = 0.15
@export var spark_color: Color = Color(1, 0.95, 0.55)


func _ready() -> void:
	var visual: Sprite2D = $Visual
	visual.self_modulate = spark_color
	visual.scale = start_scale

	# A short tween: grow + fade at the same time, then free the node.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", end_scale, lifetime)
	tween.tween_property(visual, "modulate:a", 0.0, lifetime)

	# queue_free() runs after the tween finishes. `tween.finished` is a
	# signal; `await` on it pauses just this function.
	await tween.finished
	queue_free()
