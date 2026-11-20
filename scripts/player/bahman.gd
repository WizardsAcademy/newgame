extends PlayerBase
## Knight - the Frost Greatsword Knight (Hero 2 of 4, docs/CHARACTERS.md).
##
## Role: Main armored tank (120 HP), wide greatsword cleave, "aura farmer".
## Signature mechanic: **Winter Aura**
##   - Enemies near Knight are chilled & slowed (30% -> 55% slow).
##   - Standing your ground charges the Winter Aura (wider frost ring +
##     periodic icy pulse damage to enemies inside the field!).
##   - Shift Dash: heavy **Shield-Ram Dash** (1.0s cooldown, 16 dash damage).

const WinterAuraVisualScript := preload("res://scripts/player/winter_aura_visual.gd")

@export var aura_base_radius: float = 56.0
@export var aura_max_radius: float = 82.0
@export var aura_pulse_damage: int = 5
@export var aura_pulse_interval: float = 1.0

var aura_charge: float = 0.0
var _aura_visual: Node2D = null
var _aura_pulse_timer: float = 0.6
## Maps enemy_instance_id -> { "node": Node, "mult": float } so chill slows
## commute cleanly with wave scaling and boss enrage multipliers.
var _chilled_enemies: Dictionary = {}


func _create_attack_sfx() -> AudioStreamWAV:
	return SFXGenerator.create_blade_sfx()


func _character_ready() -> void:
	character_id = "knight"
	character_name = "Knight"
	attack_point_offset_x = 18.0
	dash_damage = 16
	dash_tint = Color(0.55, 0.88, 1.0, 0.80)

	_aura_visual = WinterAuraVisualScript.new()
	_aura_visual.name = "WinterAura"
	add_child(_aura_visual)


func _character_physics_process(delta: float) -> void:
	if is_dead:
		_clear_all_chills()
		if _aura_visual != null:
			_aura_visual.visible = false
		return

	# Standing still ("aura farming"!) charges the frost field; walking relaxes it.
	if velocity.length() < 6.0 and not is_dashing:
		aura_charge = minf(aura_charge + delta / 1.4, 1.0)
	else:
		aura_charge = maxf(aura_charge - delta / 1.2, 0.0)

	var current_radius := lerpf(aura_base_radius, aura_max_radius, aura_charge)
	if _aura_visual != null:
		_aura_visual.set_aura_state(current_radius, aura_charge, delta)

	_update_winter_chill(current_radius, delta)


func _update_winter_chill(radius: float, delta: float) -> void:
	var target_mult := lerpf(0.70, 0.45, aura_charge)
	var seen_ids: Dictionary = {}

	var do_frost_pulse := false
	if aura_charge >= 0.88 and input_enabled:
		_aura_pulse_timer -= delta
		if _aura_pulse_timer <= 0.0:
			_aura_pulse_timer = aura_pulse_interval
			do_frost_pulse = true
	else:
		_aura_pulse_timer = minf(_aura_pulse_timer, 0.45)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		var dist := global_position.distance_to((enemy as Node2D).global_position)
		if dist <= radius:
			var eid := enemy.get_instance_id()
			seen_ids[eid] = true
			_apply_chill(enemy, eid, target_mult)
			if do_frost_pulse:
				deal_combat_damage(enemy, aura_pulse_damage, false, 0.0, (enemy as Node2D).global_position)

	# Release enemies that stepped outside the Winter Aura (or died).
	var stale_ids: Array = []
	for eid in _chilled_enemies.keys():
		if not seen_ids.has(eid):
			stale_ids.append(eid)
	for eid in stale_ids:
		_remove_chill(eid)


func _apply_chill(enemy: Node, eid: int, new_mult: float) -> void:
	if _chilled_enemies.has(eid):
		var prev_mult: float = float(_chilled_enemies[eid]["mult"])
		if absf(prev_mult - new_mult) > 0.01 and "move_speed" in enemy:
			enemy.move_speed = (enemy.move_speed / prev_mult) * new_mult
			_chilled_enemies[eid]["mult"] = new_mult
	else:
		if "move_speed" in enemy:
			enemy.move_speed = enemy.move_speed * new_mult
		_chilled_enemies[eid] = { "node": enemy, "mult": new_mult }


func _remove_chill(eid: int) -> void:
	if not _chilled_enemies.has(eid):
		return
	var entry: Dictionary = _chilled_enemies[eid]
	var enemy: Variant = entry["node"]
	var mult: float = float(entry["mult"])
	if enemy != null and is_instance_valid(enemy) and "move_speed" in enemy and mult > 0.01:
		enemy.move_speed = enemy.move_speed / mult
	_chilled_enemies.erase(eid)


func _clear_all_chills() -> void:
	for eid in _chilled_enemies.keys():
		_remove_chill(eid)
	_chilled_enemies.clear()


func _exit_tree() -> void:
	_clear_all_chills()


func _compute_melee_knockback_px() -> float:
	return super._compute_melee_knockback_px() + 14.0


## Sweeping frost-silver greatsword crescent arc on swing!
func _on_melee_strike_active() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var slash := Line2D.new()
	slash.width = 3.5
	slash.default_color = Color(0.75, 0.94, 1.0, 0.92)
	var pts := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var t := lerpf(-1.15, 1.15, float(i) / float(steps))
		pts.append(Vector2(cos(t) * 24.0 * facing, sin(t) * 18.0))
	slash.points = pts
	parent.add_child(slash)
	slash.global_position = global_position + Vector2(4.0 * facing, 0.0)
	var tw := slash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(slash, "scale", Vector2(1.22, 1.15), 0.16)
	tw.tween_property(slash, "modulate:a", 0.0, 0.16)
	tw.chain().tween_callback(slash.queue_free)
