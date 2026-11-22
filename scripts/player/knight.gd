extends PlayerBase
## Knight - the Betrayed Fallen Knight (Hero 2 of 4).
##
## Stats & Kit:
##   - 150 HP (highest!), 68 Move Speed (slowest — heavy dark-steel plate!).
##   - **Colossal Greatsword Spin Cleave (`attack`)**:
##       * Swings and spins his giant Zweihander in a wide steel-ember arc (26 DMG).
##   - **Fallen Plate Armor (Passive)**:
##       * Permanently blocks flat `armor_flat_block = 3` damage on every enemy hit
##         (min 1 damage when unshielded) with steel spark feedback!
##   - **Energy-Powered Tower Shield (`Right-Click` / `E`)**:
##       * Holding Shield raises his scarred Tower Shield (`guard` pose) WITHOUT
##         draining Energy over time (`shield_hold_drain_per_sec = 0.0`).
##       * **ONLY when an attack hits the raised shield** does Energy drain
##         (`20 + incoming * 1.2` per blocked hit), blocking **100% of HP damage**!
##       * If Energy reaches **`0`**, the Shield **breaks / exhausts**
##         (`shield_exhausted = true`) and **cannot be raised again until Energy
##         recovers all the way back to `100%`**!
##   - **Shield-Wall Charge (`Shift`)**:
##       * Locks his Tower Shield out in front (`charge` pose) and rams forward
##         for 16 damage + heavy knockback!

@export var armor_flat_block: int = 3
@export var shield_move_multiplier: float = 0.56
@export var shield_hold_drain_per_sec: float = 0.0
@export var shield_hit_energy_base: float = 20.0
@export var shield_hit_energy_per_dmg: float = 1.2

var is_shielding: bool = false
var shield_exhausted: bool = false
var _manual_shield_hold: bool = false
var _shield_arc: ShieldArcVisual = null
var _shield_sfx: AudioStreamPlayer = null
var _shield_flash_timer: float = 0.0


class ShieldArcVisual extends Node2D:
	var facing_dir: float = 1.0
	var flash_ratio: float = 0.0
	var energy_ratio: float = 1.0
	var charging: bool = false

	func _draw() -> void:
		var base_col := Color(0.46, 0.84, 1.0, 0.72).lerp(Color(1.0, 0.96, 0.68, 0.98), flash_ratio)
		if energy_ratio < 0.30 and not charging:
			base_col = Color(1.0, 0.48, 0.28, 0.78).lerp(Color.WHITE, flash_ratio)
		var rim_col := Color(0.96, 0.80, 0.34, 0.92).lerp(Color.WHITE, flash_ratio)
		var center := Vector2((8.0 if charging else 5.0) * facing_dir, 1.0)
		var start_a := -0.90 if facing_dir > 0.0 else PI - 0.90
		var end_a := 0.90 if facing_dir > 0.0 else PI + 0.90
		draw_arc(center, 16.5, start_a, end_a, 14, base_col, 3.2)
		draw_arc(center, 18.2, start_a * 0.88, end_a * 0.88, 14, rim_col, 1.5)


func _create_attack_sfx() -> AudioStreamWAV:
	return SFXGenerator.create_blade_sfx()


func _character_ready() -> void:
	character_id = "knight"
	character_name = "Knight"
	attack_point_offset_x = 22.0
	dash_deals_damage = true
	dash_phases_enemies = true
	dash_damage = 16
	dash_knockback_px = 22.0
	dash_tint = Color(0.48, 0.82, 1.0, 0.82)

	_shield_arc = ShieldArcVisual.new()
	_shield_arc.name = "ShieldArc"
	_shield_arc.visible = false
	add_child(_shield_arc)

	_shield_sfx = AudioStreamPlayer.new()
	_shield_sfx.name = "ShieldSFX"
	_shield_sfx.bus = &"SFX"
	_shield_sfx.stream = SFXGenerator.create_shield_block_sfx()
	add_child(_shield_sfx)


func can_use_shield() -> bool:
	return (not is_dead) and (not shield_exhausted) and current_energy > 0.05


func set_shielding(active: bool) -> void:
	_manual_shield_hold = active
	_refresh_shield_state()


func _can_regenerate_energy() -> bool:
	return (not is_dashing) and (not is_shielding)


func _on_energy_regenerated() -> void:
	if shield_exhausted and current_energy >= max_energy - 0.01:
		shield_exhausted = false


func _trigger_shield_exhaustion() -> void:
	current_energy = 0.0
	shield_exhausted = true
	is_shielding = false
	energy_changed.emit(current_energy, max_energy)


func _refresh_shield_state() -> void:
	if is_dead or is_dashing or is_attacking or not can_use_shield():
		is_shielding = false
	else:
		var held := bool(_read_input().get("shield_held", false))
		is_shielding = _manual_shield_hold or held

	if _shield_arc != null:
		var show_arc := is_shielding or is_dashing
		_shield_arc.visible = show_arc
		_shield_arc.facing_dir = facing
		_shield_arc.charging = is_dashing
		_shield_arc.energy_ratio = clampf(current_energy / maxf(max_energy, 1.0), 0.0, 1.0)
		_shield_arc.flash_ratio = clampf(_shield_flash_timer / 0.18, 0.0, 1.0)
		if show_arc:
			_shield_arc.queue_redraw()


func _character_physics_process(delta: float) -> void:
	if _shield_flash_timer > 0.0:
		_shield_flash_timer = maxf(_shield_flash_timer - delta, 0.0)

	_refresh_shield_state()
	if is_shielding and shield_hold_drain_per_sec > 0.0:
		consume_energy(shield_hold_drain_per_sec * delta)
		if current_energy <= 0.01:
			_trigger_shield_exhaustion()
			_refresh_shield_state()


func _get_stance_move_multiplier() -> float:
	return shield_move_multiplier if is_shielding else 1.0


func _update_animation() -> void:
	if is_dashing:
		if anim_player.has_animation("charge") and anim_player.current_animation != "charge":
			anim_player.play("charge")
		return
	if is_attacking:
		return
	if is_shielding and anim_player.has_animation("guard"):
		if anim_player.current_animation != "guard":
			anim_player.play("guard")
		return
	super._update_animation()


func _mitigate_incoming_damage(amount: int, _from_position: Vector2) -> int:
	if amount <= 0:
		return 0
	_refresh_shield_state()

	# 1. ACTIVE TOWER SHIELD: 100% HP Damage Block powered by Green Energy!
	if is_shielding and can_use_shield():
		var energy_cost := shield_hit_energy_base + float(amount) * shield_hit_energy_per_dmg
		consume_energy(energy_cost)
		if current_energy <= 0.01:
			_trigger_shield_exhaustion()

		_shield_flash_timer = 0.18
		if _shield_sfx != null:
			_shield_sfx.pitch_scale = 1.0
			_shield_sfx.play()
		_spawn_hit_spark_at(global_position + Vector2(facing * 14.0, 0.0))
		ScreenShake.shake(1.8, 0.09)
		last_mitigation_label = "SHIELD BREAK!" if shield_exhausted else "SHIELD"
		_refresh_shield_state()
		return 0

	# 2. PASSIVE FALLEN PLATE ARMOR: Flat damage block on all hits!
	if armor_flat_block > 0:
		var reduced := maxi(amount - armor_flat_block, 1)
		if reduced < amount:
			last_mitigation_label = "ARMOR"
			if _shield_sfx != null and not _shield_sfx.playing:
				_shield_sfx.pitch_scale = 0.78
				_shield_sfx.play()
		return reduced

	return amount


func _get_incoming_knockback_multiplier() -> float:
	return 0.25 if is_shielding else 0.72


func _compute_melee_knockback_px() -> float:
	return super._compute_melee_knockback_px() + 16.0


## Giant 290-degree spinning Zweihander Greatsword crescent slash!
func _on_melee_strike_active() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ring := Node2D.new()
	parent.add_child(ring)
	ring.global_position = global_position + Vector2(4.0 * facing, 0.0)

	var outer := Line2D.new()
	outer.width = 4.5
	outer.default_color = Color(0.84, 0.92, 1.0, 0.94)
	var inner := Line2D.new()
	inner.width = 2.2
	inner.default_color = Color(1.0, 0.48, 0.24, 0.85)
	var pts_o := PackedVector2Array()
	var pts_i := PackedVector2Array()
	var steps := 20
	for i in steps + 1:
		var t := lerpf(-2.1, 2.1, float(i) / float(steps))
		pts_o.append(Vector2(cos(t) * 32.0 * facing, sin(t) * 24.0))
		pts_i.append(Vector2(cos(t) * 24.0 * facing, sin(t) * 18.0))
	outer.points = pts_o
	inner.points = pts_i
	ring.add_child(outer)
	ring.add_child(inner)

	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "rotation", 0.75 * facing, 0.20)
	tw.tween_property(ring, "scale", Vector2(1.20, 1.16), 0.20)
	tw.tween_property(ring, "modulate:a", 0.0, 0.20)
	tw.chain().tween_callback(ring.queue_free)
