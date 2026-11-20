extends Node2D
## GroundTelegraph - a painted DANGER CIRCLE on the floor (boss's read).
##
## Lesson from the first boss playtest: a red tint on the boss's sprite
## is a mood, not a warning. The player reads warnings from the FLOOR -
## "where will it hurt, and how long do I have?" This node answers both:
##
##   * the OUTLINE circle shows WHERE the attack will land,
##   * the inner FILL grows 0 -> 1 while the attack charges, so the
##     fill's speed literally shows HOW LONG you have (same trick as
##     the roots ring: watch the growth rate, not a countdown).
##
## Reused by all three boss attacks, just tinted differently:
##   SLAM  deep red  - big circle, slow charge
##   SWEEP orange    - smaller circle, faster charge
##   ROOTS green     - drawn on the player's captured spot
##
## This is a plain Node2D child of the ARENA (not the boss), so the
## danger zone never moves once painted - roots taught us that the
## zone must lock a PLACE, not follow a body.
##
## PIXEL GRID: every shape is drawn through `PixelShapes`, i.e. as 1-px rows
## snapped to the game canvas. `draw_circle()` would be rasterised at the
## WINDOW resolution and show up as a smooth vector ring under a pixel-art
## world (the same bug the acid pool and the ember fuse had).

## Attack radius in pixels (the outline and the full fill).
@export var radius: float = 60.0

## Colors. Fill is translucent so the ground still reads under it;
## the edge is almost opaque so the silhouette is crisp at a glance.
@export var fill_color: Color = Color(1.0, 0.3, 0.22, 0.18)
@export var edge_color: Color = Color(1.0, 0.38, 0.3, 0.95)

## How "charged" the circle is, 0.0 (just painted) to 1.0 (striking).
## The boss sets this every physics frame; we only draw it here.
var charge: float = 0.0

## Inner pulse (a slow brightness breathing so the zone feels alive).
var _pulse_time: float = 0.0


func _process(delta: float) -> void:
	# Cheap idle animation for the edge so a static circle never
	# blends into the background: redraw every frame (a 48-point arc
	# is nothing). Pure cosmetics - no gameplay logic lives here.
	_pulse_time += delta
	queue_redraw()


func _draw() -> void:
	# 1) The soft danger fill under everything.
	PixelShapes.filled_disc(self, radius, fill_color)

	# 2) The charge fill: grows with `charge`. A slightly brighter, more
	#    opaque red on top of the soft fill = "time is running out".
	if charge > 0.01:
		var charged_color := Color(fill_color.r, fill_color.g, fill_color.b,
			fill_color.a + charge * 0.35)
		PixelShapes.filled_disc(self, radius * charge, charged_color)

	# 3) The crisp outline. Alpha breathes on a 1.2s sine so the zone
	#    pulses without any tween machinery.
	var pulse := 0.7 + 0.3 * absf(sin(_pulse_time * TAU / 1.2))
	var edge := edge_color
	edge.a *= pulse
	PixelShapes.ring(self, radius, maxf(2.0, radius * 0.045), edge)

	# 4) Tick marks across the outline at 50% / 100% charge - a subtle
	#    ruler so the growth reads even from far away.
	if charge >= 0.5:
		PixelShapes.ring(self, radius * 0.5, 1.0,
			Color(edge_color.r, edge_color.g, edge_color.b, 0.25 * pulse))


## Redraw whenever anything changes (charge is set every physics frame).
func set_charge(value: float) -> void:
	charge = clampf(value, 0.0, 1.0)
	queue_redraw()


## Brief white flash, then free - the classic "the promise was kept"
## outro so the zone disappears BECAUSE the hit landed.
func flash_and_free(fade_time: float = 0.12) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(2.5, 2.5, 2.5, 0.0), fade_time)
	tween.tween_callback(queue_free)
