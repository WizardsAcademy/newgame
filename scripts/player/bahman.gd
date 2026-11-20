extends PlayerBase
## Knight - the Armored Shield & Greatsword Tank (Hero 2 of 4, docs/CHARACTERS.md).
##
## Role: Main armored tank (120 HP), wide steel greatsword cleave + Kite Shield.
## Signature mechanic: **Iron Kite Shield (`Right-Click` or `E`)**
##   - Hold `Right-Click` or `E` to raise the Kite Shield (`is_shielding = true`).
##   - Reduces incoming damage by **60%** (never 100% block: e.g. a `10` damage
##     hit blocks `6` and deals `4` damage!), cuts knockback by 65%, and rings
##     with a steel shield clang!
##   - Shift Dash: **Shield-Bash Charge** (1.0s CD, deals 14 Shift damage!).

@export_range(0.1, 0.85, 0.05) var shield_damage_reduction: float = 0.60
@export var shield_move_multiplier: float = 0.58

var is_shielding: bool = false
var _manual_shield_hold: bool = false
var _shield_arc: ShieldArcVisual = null
var _shield_sfx: AudioStreamPlayer = null
var _shield_flash_timer: float = 0.0


class ShieldArcVisual extends Node2D:
	var facing_dir: float = 1.0
	var flash_ratio: float = 0.0

	func _draw() -> void:
		var base_col := Color(0.56, 0.82, 1.0, 0.65).lerp(Color(1.0, 0.96, 0.68, 0.98), flash_ratio)
		var rim_col := Color(0.98, 0.84, 0.36, 0.92).lerp(Color.WHITE, flash_ratio)
		var center := Vector2(4.0 * facing_dir, 1.0)
		var start_a := -0.82 if facing_dir > 0.0 else PI - 0.82
		var end_a := 0.82 if facing_dir > 0.0 else PI + 0.82
		draw_arc(center, 15.0, start_a, end_a, 14, base_col, 3.0)
		draw_arc(center, 16.5, start_a * 0.88, end_a * 0.88, 14, rim_col, 1.4)


func _create_attack_sfx() -> AudioStreamWAV:
	return SFXGenerator.create_blade_sfx()


func _character_ready() -> void:
	character_id = "knight"
	character_name = "Knight"
	attack_point_offset_x = 18.0
	dash_deals_damage = true
	dash_phases_enemies = true
	dash_damage = 14
	dash_tint = Color(0.58, 0.84, 1.0, 0.80)

	_shield_arc = ShieldArcVisual.new()
	_shield_arc.name = "ShieldArc"
	_shield_arc.visible = false
	add_child(_shield_arc)

	_shield_sfx = AudioStreamPlayer.new()
	_shield_sfx.name = "ShieldSFX"
	_shield_sfx.bus = &"SFX"
	_shield_sfx.stream = SFXGenerator.create_shield_block_sfx()
	add_child(_shield_sfx)


## Allows tests or callers to explicitly hold/release the shield in addition
## to live `"shield"` (`Right-Click` / `E`) player input.
func set_shielding(active: bool) -> void:
	_manual_shield_hold = active
	_refresh_shield_state()


func _refresh_shield_state() -> void:
	if is_dead or is_dashing or is_attacking:
		is_shielding = false
	else:
		var held := bool(_read_input().get("shield_held", false))
		is_shielding = _manual_shield_hold or held
	if _shield_arc != null:
		_shield_arc.visible = is_shielding
		_shield_arc.facing_dir = facing
		_shield_arc.flash_ratio = clampf(_shield_flash_timer / 0.16, 0.0, 1.0)
		if is_shielding:
			_shield_arc.queue_redraw()


func _character_physics_process(delta: float) -> void:
	if _shield_flash_timer > 0.0:
		_shield_flash_timer = maxf(_shield_flash_timer - delta, 0.0)
	_refresh_shield_state()


func _get_stance_move_multiplier() -> float:
	return shield_move_multiplier if is_shielding else 1.0


func _update_animation() -> void:
	if is_attacking:
		return
	if is_shielding and anim_player.has_animation("guard"):
		if anim_player.current_animation != "guard":
			anim_player.play("guard")
		return
	super._update_animation()


func _mitigate_incoming_damage(amount: int, _from_position: Vector2) -> int:
	_refresh_shield_state()
	if not is_shielding or amount <= 0:
		return amount

	# 60% damage reduction (e.g. 10 incoming -> blocks 6, takes 4!).
	# Never blocks 100% of a hit: always takes at least 1 damage.
	var blocked := int(roundf(float(amount) * shield_damage_reduction))
	var reduced := maxi(amount - blocked, 1)

	_shield_flash_timer = 0.16
	if _shield_arc != null:
		_shield_arc.flash_ratio = 1.0
		_shield_arc.queue_redraw()
	if _shield_sfx != null:
		_shield_sfx.play()
	_spawn_hit_spark_at(global_position + Vector2(facing * 12.0, 0.0))
	return reduced


func _get_incoming_knockback_multiplier() -> float:
	return 0.35 if is_shielding else 1.0


func _compute_melee_knockback_px() -> float:
	return super._compute_melee_knockback_px() + 14.0


## Sweeping steel-gold greatsword crescent arc on swing!
func _on_melee_strike_active() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var slash := Line2D.new()
	slash.width = 3.5
	slash.default_color = Color(0.86, 0.92, 1.0, 0.94)
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
