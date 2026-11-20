extends RefCounted
class_name Elite
## Elite - the "hero version" of an enemy (Phase 7):
## a golden ring at the feet, 3x HP, and one extra ability of its own.
##
## WHY a static helper instead of copy-pasting into every enemy script?
## Every enemy agrees on the same combat contract (docs/ARCHITECTURE.md):
## max_health / current_health / _update_health_bar(). So the parts that
## are IDENTICAL for all enemies live here once, and each enemy script
## only adds its one exclusive extra in its own become_elite().
##
## Spawner contract: only call the enemy's become_elite() - never this
## class directly - so each enemy stays in charge of its own extras.

## Golden ring life: pulses between these alpha levels, forever.
const _AURA_ALPHA_LOW: float = 0.4
const _AURA_ALPHA_HIGH: float = 0.85

## Elite HP multiplier. 3x on top of wave scaling: an elite is meant to
## be a mini-boss encounter, not a redder slime.
const HP_FACTOR: int = 3


## The shared elite package: 3x HP + the golden ring under the feet.
## (HP is tripled AFTER the spawner's wave bonus, so an elite really
## is three enemies' worth of health for its wave.)
static func make_enemy_elite(enemy: Node) -> void:
	enemy.max_health = int(enemy.max_health) * HP_FACTOR
	enemy.current_health = enemy.max_health
	if enemy.has_method("_update_health_bar"):
		enemy._update_health_bar()
	_spawn_gold_aura(enemy)


## A pulsing golden ring drawn in one Line2D loop - zero new art files.
## Same z-order lesson as the archer's risk line: keep z_index 0, use
## show_behind_parent so the ring reads as painted on the floor.
static func _spawn_gold_aura(enemy: Node) -> void:
	var segments := 24
	var radius := 14.0
	var ring := Line2D.new()
	var points := PackedVector2Array()
	for i in segments + 1:
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	ring.points = points
	ring.width = 2.0
	ring.position = Vector2(0, 6)   # at the feet, not around the torso
	ring.default_color = Color(1.0, 0.85, 0.25, _AURA_ALPHA_HIGH)
	ring.show_behind_parent = true
	enemy.add_child(ring)

	# "Breathe" between bright and dim - bound to the ring, so Godot
	# kills the tween automatically if the enemy dies mid-glow.
	var pulse := ring.create_tween()
	pulse.set_loops()
	pulse.tween_property(ring, "default_color:a", _AURA_ALPHA_LOW, 0.6)
	pulse.tween_property(ring, "default_color:a", _AURA_ALPHA_HIGH, 0.6)
