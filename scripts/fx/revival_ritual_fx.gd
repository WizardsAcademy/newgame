extends Node2D
class_name RevivalRitualFX
## Celestial Light-Beam & Arcane Magic-Circle Revival Cinematic!
##
## Played on the fallen hero when clicking `NOT YET`:
##   1. Opens a rotating golden-cyan Arcane Magic Circle (`dayere jadoyi`)
##      directly beneath the hero's feet (`0.0s .. 1.25s`).
##   2. Strikes down a towering Pillar of Celestial Light (`nor`) from the sky
##      onto the hero (`0.28s .. 1.15s`), lifting & restoring the hero upright!
##   3. Emits `ritual_completed` at `duration` so `Main` transitions smoothly
##      back into the Guild Hub `LOBBY`!

signal ritual_completed

var target_hero: Node2D = null
var duration: float = 1.25
var elapsed: float = 0.0
var _hero_lifted: bool = false


func setup(hero: Node2D, total_duration: float = 1.25) -> void:
	target_hero = hero
	duration = maxf(total_duration, 0.4)
	z_index = 14
	if hero != null and is_instance_valid(hero):
		global_position = hero.global_position


func _ready() -> void:
	# Rising golden arcane embers inside the magic circle!
	var sparks := CPUParticles2D.new()
	sparks.amount = 24
	sparks.lifetime = 0.85
	sparks.position = Vector2(0.0, 10.0)
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 24.0
	sparks.direction = Vector2.UP
	sparks.spread = 18.0
	sparks.gravity = Vector2(0.0, -55.0)
	sparks.initial_velocity_min = 24.0
	sparks.initial_velocity_max = 68.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.2
	sparks.color = Color(1.0, 0.92, 0.56, 0.95)
	add_child(sparks)


func _process(delta: float) -> void:
	elapsed += delta
	if target_hero != null and is_instance_valid(target_hero):
		global_position = target_hero.global_position

	# Lift & restore the hero upright inside the celestial beam!
	if not _hero_lifted and elapsed >= duration * 0.44:
		_hero_lifted = true
		ScreenShake.shake(3.0, 0.22)
		if target_hero != null and is_instance_valid(target_hero):
			var vis := target_hero.get_node_or_null("Visuals") as Node2D
			var ap := target_hero.get_node_or_null("AnimPlayer") as AnimationPlayer
			if vis != null:
				vis.visible = true
				vis.rotation_degrees = 0.0
				vis.modulate = Color(1.35, 1.28, 1.05, 1.0)
			if ap != null:
				ap.stop()
				if ap.has_animation("idle_down"):
					ap.play("idle_down")
				elif ap.has_animation("idle"):
					ap.play("idle")

	queue_redraw()
	if elapsed >= duration:
		ritual_completed.emit()
		queue_free()


func _draw() -> void:
	var p := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
	var ground_c := Vector2(0.0, 10.0)

	# --- 1. ARCANE MAGIC CIRCLE BENEATH HERO (squashed 2:1 isometric ellipse!) ---
	var circle_open := clampf(p / 0.34, 0.0, 1.0)
	var circle_fade := clampf((1.0 - p) / 0.16, 0.0, 1.0) if p > 0.84 else 1.0
	var rad := 38.0 * (1.0 - pow(1.0 - circle_open, 3.0))
	var c_alpha := circle_open * circle_fade
	var rot := elapsed * 2.6

	# Squash transform so the magic circle lies flat on the floor under the hero's boots!
	draw_set_transform(ground_c, 0.0, Vector2(1.0, 0.48))

	var gold := Color(1.0, 0.86, 0.42, 0.94 * c_alpha)
	var cyan := Color(0.56, 0.96, 1.0, 0.88 * c_alpha)
	var glow := Color(1.0, 0.92, 0.62, 0.24 * c_alpha)

	draw_circle(Vector2.ZERO, rad * 1.05, glow)
	draw_arc(Vector2.ZERO, rad, 0.0, TAU, 40, gold, 2.4)
	draw_arc(Vector2.ZERO, rad * 0.78, 0.0, TAU, 36, cyan, 1.5)
	draw_arc(Vector2.ZERO, rad * 0.42, 0.0, TAU, 28, gold, 1.4)

	# Rotating 8-pointed arcane octagram (two counter-rotated squares + rune nodes!)
	for sq in range(2):
		var base_a := rot * (1.0 if sq == 0 else -1.0) + float(sq) * (PI * 0.25)
		var poly := PackedVector2Array()
		for k in range(5):
			var a := base_a + float(k % 4) * (PI * 0.5)
			poly.append(Vector2(cos(a), sin(a)) * (rad * 0.78))
		draw_polyline(poly, gold if sq == 0 else cyan, 1.6)

	for r_i in range(8):
		var ra := rot * 1.3 + float(r_i) * (TAU / 8.0)
		var rp := Vector2(cos(ra), sin(ra)) * (rad * 0.90)
		draw_circle(rp, 2.4, Color(1.0, 0.98, 0.84, c_alpha))

	# Reset transform for vertical Celestial Light Pillar!
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# --- 2. HEAVENLY PILLAR OF LIGHT STRIKING DOWN ONTO THE HERO! ---
	if p >= 0.22:
		var bp := clampf((p - 0.22) / 0.78, 0.0, 1.0)
		var beam_env := sin(bp * PI)
		var half_w := lerpf(4.0, 22.0, sin(minf(bp * 2.2, 1.0) * PI * 0.5)) * (1.0 - bp * 0.25)
		var top_y := -280.0
		var bot_y := 12.0

		# Soft outer golden-cyan halo shaft
		draw_rect(Rect2(-half_w * 1.65, top_y, half_w * 3.30, bot_y - top_y),
			Color(1.0, 0.88, 0.48, 0.20 * beam_env), true)
		# Mid warm golden light beam
		draw_rect(Rect2(-half_w, top_y, half_w * 2.0, bot_y - top_y),
			Color(1.0, 0.94, 0.66, 0.48 * beam_env), true)
		# Brilliant pure white-gold core shaft
		draw_rect(Rect2(-half_w * 0.42, top_y, half_w * 0.84, bot_y - top_y),
			Color(1.0, 0.99, 0.92, 0.88 * beam_env), true)

		# Impact light flare at hero's feet
		draw_circle(ground_c, half_w * 1.35, Color(1.0, 0.97, 0.84, 0.55 * beam_env))
