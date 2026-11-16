extends Node2D
class_name HealthBar
## A tiny hand-drawn health bar that floats above an enemy.
##
## Why not a ProgressBar node? Because a custom `_draw()` bar is
## pixel-perfect, needs no theme, and shows exactly how immediate-mode
## drawing works in Godot:
##   1. change a value,
##   2. call queue_redraw() to ask for a repaint,
##   3. the engine calls _draw(), where you paint with draw_rect().
##
## NOTE for beginner devs: `value` and `max_value` are deliberately plain
## variables. Writing `value = x` inside a `set` block for `value` would
## call the setter again and recurse forever, so the numbers are changed
## through set_health() instead, which also asks for the repaint.

## Current health, 0 .. max_value.
var value: float = 30.0

## Health at 100 %.
var max_value: float = 30.0

## Bar size in pixels. 20x4 is readable at the game's 2x camera zoom.
@export var bar_size: Vector2 = Vector2(20, 4)

## Offset from the enemy's centre; negative Y = above the sprite.
@export var bar_offset: Vector2 = Vector2(0, -14)

@export var low_color: Color = Color("e04b4b")
@export var high_color: Color = Color("5ee06a")
@export var back_color: Color = Color(0.08, 0.08, 0.08, 0.85)
@export var border_color: Color = Color(0, 0, 0, 1)


func _ready() -> void:
	queue_redraw()


## The only way to change what the bar shows.
## `current` is clamped so the drawing code can never divide by zero or
## paint outside the frame.
func set_health(current: float, maximum: float) -> void:
	max_value = maxf(maximum, 1.0)
	value = clampf(current, 0.0, max_value)
	queue_redraw()


func _draw() -> void:
	var ratio: float = clampf(value / max_value, 0.0, 1.0)
	var top_left: Vector2 = bar_offset - bar_size * 0.5

	# 1 pixel black border, then the dark background, then the fill.
	draw_rect(Rect2(top_left - Vector2.ONE, bar_size + Vector2.ONE * 2.0), border_color)
	draw_rect(Rect2(top_left, bar_size), back_color)

	if ratio > 0.0:
		# Green while healthy, sliding to red as health drops.
		var fill_color: Color = high_color.lerp(low_color, 1.0 - ratio)
		draw_rect(Rect2(top_left, Vector2(bar_size.x * ratio, bar_size.y)), fill_color)
