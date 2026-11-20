extends RefCounted
class_name PixelShapes
## Pixel-grid drawing helpers for ground hazards.
##
## THE PROBLEM
##   `draw_circle()` and `draw_arc()` are VECTOR shapes: Godot rasterises them
##   at the WINDOW resolution, not at the game's 640x360 resolution. On a
##   1440p monitor that produces a razor-smooth ring - which reads as a vector
##   UI element floating under a pixel-art world. Exactly the complaint that
##   made the acid pool and the ember fuse get real sprites.
##
## THE FIX
##   Every shape here is drawn as a stack of 1-pixel-high rectangles snapped to
##   whole canvas pixels. The project renders with `canvas_items` stretch and a
##   nearest filter, so one canvas pixel becomes a chunky NxN block on screen -
##   the primitive equivalent of the sprites the generators produce.
##
##   Shapes that deserve more than a circle (the acid puddle, the detonation)
##   are pre-rendered textures instead; see `tools/make_fx_sprites.py`. These
##   helpers are for the shapes that must follow a live number, like the boss's
##   charge fill.

## Solid stepped disc centred on the canvas origin.
static func filled_disc(canvas: CanvasItem, radius: float, colour: Color) -> void:
	_rows(canvas, radius, 0.0, colour)


## Hollow stepped ring with the given wall thickness.
static func ring(canvas: CanvasItem, radius: float, thickness: float,
		colour: Color) -> void:
	_rows(canvas, radius, maxf(radius - thickness, 0.0), colour)


static func _rows(canvas: CanvasItem, outer_radius: float,
		inner_radius: float, colour: Color) -> void:
	if outer_radius <= 0.0:
		return
	var rows := int(ceil(outer_radius))
	for i in range(-rows, rows):
		var dy := float(i) + 0.5
		var outer := _half_width(dy, outer_radius)
		if outer <= 0.0:
			continue
		var inner := _half_width(dy, inner_radius)
		if inner <= 0.0:
			_run(canvas, -outer, outer, i, colour)
		else:
			_run(canvas, -outer, -inner, i, colour)
			_run(canvas, inner, outer, i, colour)


static func _half_width(dy: float, radius: float) -> float:
	var squared := radius * radius - dy * dy
	return sqrt(squared) if squared > 0.0 else 0.0


static func _run(canvas: CanvasItem, x0: float, x1: float, row: int,
		colour: Color) -> void:
	var left := floorf(x0)
	var right := ceilf(x1)
	if right - left < 1.0:
		# A run thinner than a pixel (the top/bottom of a thin ring) still
		# gets one pixel, otherwise the ring develops holes at its poles.
		right = left + 1.0
	canvas.draw_rect(Rect2(left, float(row), right - left, 1.0), colour)
