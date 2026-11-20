extends Node2D
## Visual ground ring for the Knight's signature **Winter Aura**.
##
## Uses `show_behind_parent = true` at `z_index = 0` so it paints on top
## of `Level/Background` while staying tucked under character sprites.

var radius: float = 56.0
var charge: float = 0.0
var _spin: float = 0.0


func _ready() -> void:
	show_behind_parent = true
	z_index = 0


func set_aura_state(new_radius: float, new_charge: float, delta: float) -> void:
	radius = new_radius
	charge = clampf(new_charge, 0.0, 1.0)
	_spin += delta * lerpf(0.7, 2.2, charge)
	queue_redraw()


func _draw() -> void:
	var center := Vector2(0.0, 6.0)
	var fill_alpha := lerpf(0.08, 0.20, charge)
	var edge_alpha := lerpf(0.38, 0.85, charge)

	draw_circle(center, radius, Color(0.42, 0.82, 1.0, fill_alpha))
	if charge > 0.05:
		draw_circle(center, radius * (0.45 + 0.45 * charge),
			Color(0.62, 0.92, 1.0, 0.08 * charge))

	draw_arc(center, radius, 0.0, TAU, 40,
		Color(0.58, 0.92, 1.0, edge_alpha), 1.5)

	# Six rotating frost crystal ticks around the perimeter.
	for i in range(6):
		var a := _spin + TAU * float(i) / 6.0
		var inner := center + Vector2(cos(a), sin(a)) * (radius - 4.0)
		var outer := center + Vector2(cos(a), sin(a)) * (radius + 2.0)
		draw_line(inner, outer, Color(0.82, 0.97, 1.0, edge_alpha), 1.5)
