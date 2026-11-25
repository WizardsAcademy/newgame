extends Node2D
## Universal Enemy Status Overlay & Controller (`"EnemyStatusNode"`).
##
## Supports:
##   1. **Stun** (Behemoth / Knight / Sylvara): pauses movement & orbits golden stars.
##   2. **Slow** (Sylvara): slows enemy movement with emerald wind wisps.
##   3. **Burn DoT** (Behemoth Volcanic Warlord): ticks fire damage over time.
##   4. **Vampire 2-Fang + 8-Attack Crimson Circle Debuff** (Noa):
##      Requires **8 attacks (`FANG_STACKS_TO_BURST = 8`)** to fill!
##      When `8/8` fills, it detonates for `30%` of enemy Max HP (or boosted by
##      Noa's Hemomancer branch) AND **lifesteals `10%` of the HP damage dealt**!

const FANG_STACKS_TO_BURST: int = 8
const FANG_DECAY_SECONDS: float = 8.0
const FANG_MAX_HP_RATIO: float = 0.30
const FANG_LIFESTEAL_RATIO: float = 0.10
const NOA_FX_PATH: String = "res://assets/textures/noa_fx.png"

var stun_left: float = 0.0
var _boss_stun_dr_left: float = 0.0
var _paused_enemy_physics: bool = false

var slow_left: float = 0.0
var _saved_move_speed: float = -1.0

var burn_left: float = 0.0
var burn_dps: int = 0
var _burn_tick_accum: float = 0.0
var _burn_attacker: Node = null

var sunder_stacks: int = 0

var fang_stacks: int = 0
var fang_decay_left: float = 0.0
var _orbit_time: float = 0.0
var _burst_flash_left: float = 0.0
var _in_burst: bool = false


static func ensure_on(enemy: Node):
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
		return null
	var existing := enemy.get_node_or_null("EnemyStatusNode")
	if existing != null:
		return existing
	var script_res: Script = load("res://scripts/enemies/enemy_status.gd")
	var node: Node2D = script_res.new()
	node.name = "EnemyStatusNode"
	node.z_index = 6
	enemy.add_child(node)
	return node


static func apply_stun(enemy: Node, duration: float) -> bool:
	if duration <= 0.0 or enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.get("is_dead") == true:
		return false
	var st = ensure_on(enemy)
	if st == null:
		return false
	return bool(st._start_stun(duration))


static func is_stunned(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var st := enemy.get_node_or_null("EnemyStatusNode")
	return st != null and float(st.get("stun_left")) > 0.0


static func apply_slow(enemy: Node, factor: float, duration: float) -> void:
	if duration <= 0.0 or enemy == null or not is_instance_valid(enemy):
		return
	if enemy.get("is_dead") == true:
		return
	var st = ensure_on(enemy)
	if st != null:
		st._start_slow(clampf(factor, 0.20, 0.95), duration)


static func apply_burn(enemy: Node, dps: int, duration: float, attacker: Node = null) -> void:
	if dps <= 0 or duration <= 0.0 or enemy == null or not is_instance_valid(enemy):
		return
	if enemy.get("is_dead") == true:
		return
	var st = ensure_on(enemy)
	if st != null:
		st.burn_dps = maxi(int(st.burn_dps), dps)
		st.burn_left = maxf(float(st.burn_left), duration)
		st._burn_attacker = attacker
		st.queue_redraw()


static func add_sunder_stack(enemy: Node, max_stacks: int = 5) -> int:
	if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead") == true:
		return 0
	var st = ensure_on(enemy)
	if st == null:
		return 0
	st.sunder_stacks = mini(int(st.sunder_stacks) + 1, max_stacks)
	return int(st.sunder_stacks)


static func get_sunder_stacks(enemy: Node) -> int:
	if enemy == null or not is_instance_valid(enemy):
		return 0
	var st := enemy.get_node_or_null("EnemyStatusNode")
	return int(st.get("sunder_stacks")) if st != null else 0


static func get_sunder_multiplier(enemy: Node) -> float:
	return 1.0 + 0.14 * float(get_sunder_stacks(enemy))


static func get_slow_multiplier(_enemy: Node) -> float:
	# `_start_slow` already scales `host.move_speed` directly and restores it on expiry!
	return 1.0


static func add_vampire_fang_stack(enemy: Node, attacker: Node, count: int = 1) -> int:
	if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead") == true:
		return 0
	var st = ensure_on(enemy)
	if st == null:
		return 0
	var total_burst: int = 0
	for _i in range(maxi(count, 1)):
		if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			break
		total_burst += int(st._push_fang_stack(attacker))
	return total_burst


static func get_fang_stacks(enemy: Node) -> int:
	if enemy == null or not is_instance_valid(enemy):
		return 0
	var st := enemy.get_node_or_null("EnemyStatusNode")
	return int(st.get("fang_stacks")) if st != null else 0


func _start_stun(duration: float) -> bool:
	var host := get_parent()
	if host == null or host.get("is_dead") == true:
		return false
	var is_boss_host: bool = ("is_enraged" in host)
	var actual := duration
	if is_boss_host:
		if _boss_stun_dr_left > 0.0:
			return false
		actual = duration * 0.35
		_boss_stun_dr_left = 1.4

	stun_left = maxf(stun_left, actual)
	host.set_meta("is_stunned", true)
	if host is CharacterBody2D:
		(host as CharacterBody2D).velocity = Vector2.ZERO
	if host.get("keep_physics_when_stunned") != true:
		host.set_physics_process(false)
		_paused_enemy_physics = true
	queue_redraw()
	return true


func _clear_stun() -> void:
	stun_left = 0.0
	var host := get_parent()
	if host != null and is_instance_valid(host):
		host.set_meta("is_stunned", false)
		if _paused_enemy_physics:
			host.set_physics_process(true)
	_paused_enemy_physics = false


func _start_slow(factor: float, duration: float) -> void:
	var host := get_parent()
	if host == null or not ("move_speed" in host):
		return
	if _saved_move_speed < 0.0:
		_saved_move_speed = float(host.move_speed)
		host.move_speed = _saved_move_speed * factor
	slow_left = maxf(slow_left, duration)
	queue_redraw()


func _clear_slow() -> void:
	slow_left = 0.0
	var host := get_parent()
	if host != null and is_instance_valid(host) and _saved_move_speed >= 0.0 and ("move_speed" in host):
		host.move_speed = _saved_move_speed
	_saved_move_speed = -1.0


func _push_fang_stack(attacker: Node) -> int:
	if _in_burst:
		return 0
	var host := get_parent()
	if host == null or host.get("is_dead") == true:
		return 0

	fang_stacks = mini(fang_stacks + 1, FANG_STACKS_TO_BURST)
	fang_decay_left = FANG_DECAY_SECONDS
	queue_redraw()

	if fang_stacks < FANG_STACKS_TO_BURST:
		return 0

	# 8/8 FULL CIRCLE -> DETONATE BLOOD FOUNTAIN & LIFESTEAL 10% OF DAMAGE DEALT!
	fang_stacks = 0
	fang_decay_left = 0.0
	_burst_flash_left = 0.36

	var hp_ratio := FANG_MAX_HP_RATIO
	var ls_ratio := FANG_LIFESTEAL_RATIO
	if attacker != null and is_instance_valid(attacker):
		if attacker.has_method("get_fang_burst_hp_ratio"):
			hp_ratio = float(attacker.get_fang_burst_hp_ratio())
		if attacker.has_method("get_fang_burst_lifesteal_ratio"):
			ls_ratio = float(attacker.get_fang_burst_lifesteal_ratio())

	var enemy_max_hp := maxi(int(host.get("max_health")) if "max_health" in host else 30, 1)
	var is_boss_host: bool = ("is_enraged" in host)
	if is_boss_host:
		hp_ratio *= 0.45
	var burst_dmg := maxi(int(roundf(float(enemy_max_hp) * hp_ratio)), 1)
	var lifesteal_hp := maxi(int(roundf(float(burst_dmg) * ls_ratio)), 1)

	_in_burst = true
	_spawn_fang_explosion_fx()
	if attacker != null and is_instance_valid(attacker) and attacker.has_method("deal_combat_damage"):
		attacker.deal_combat_damage(host, burst_dmg, false, 6.0, (host as Node2D).global_position)
		if attacker.has_method("heal"):
			attacker.heal(lifesteal_hp)
	elif host.has_method("take_damage"):
		host.take_damage(burst_dmg)
	_in_burst = false
	queue_redraw()
	return burst_dmg


func _spawn_fang_explosion_fx() -> void:
	var host := get_parent() as Node2D
	if host == null or host.get_parent() == null:
		return
	var world := host.get_parent()

	var sfx := AudioStreamPlayer.new()
	sfx.bus = &"SFX"
	sfx.stream = SFXGenerator.create_fang_burst_sfx()
	world.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

	if ResourceLoader.exists(NOA_FX_PATH):
		var fx_tex: Texture2D = load(NOA_FX_PATH)
		if fx_tex != null:
			var fcell := float(maxi(fx_tex.get_height(), 1))
			var total_cols := maxi(int(fx_tex.get_width() / fcell), 1)
			var idx0 := mini(5, total_cols - 1)
			var idx1 := mini(6, total_cols - 1)
			var idx2 := mini(7, total_cols - 1)

			var at_surge := AtlasTexture.new()
			at_surge.atlas = fx_tex
			at_surge.region = Rect2(fcell * float(idx0), 0.0, fcell, fcell)
			var at_peak := AtlasTexture.new()
			at_peak.atlas = fx_tex
			at_peak.region = Rect2(fcell * float(idx1), 0.0, fcell, fcell)
			var at_rain := AtlasTexture.new()
			at_rain.atlas = fx_tex
			at_rain.region = Rect2(fcell * float(idx2), 0.0, fcell, fcell)

			var spire := Sprite2D.new()
			spire.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spire.texture = at_surge
			spire.offset = Vector2(0.0, -42.0)
			spire.scale = Vector2(0.38, 0.32)
			spire.z_index = 5
			world.add_child(spire)
			spire.global_position = host.global_position + Vector2(0.0, 8.0)

			var stw := spire.create_tween()
			stw.tween_property(spire, "scale", Vector2(0.50, 0.54), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			stw.tween_callback(func() -> void:
				if is_instance_valid(spire):
					spire.texture = at_peak
			)
			stw.tween_interval(0.14)
			stw.tween_callback(func() -> void:
				if is_instance_valid(spire):
					spire.texture = at_rain
			)
			stw.tween_property(spire, "modulate:a", 0.0, 0.20)
			stw.tween_callback(spire.queue_free)

	var ring := Line2D.new()
	ring.width = 2.6
	ring.default_color = Color(1.0, 0.16, 0.34, 0.95)
	var pts := PackedVector2Array()
	for i in range(21):
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a), sin(a)) * 9.0)
	ring.points = pts
	world.add_child(ring)
	ring.global_position = host.global_position
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(2.8, 2.8), 0.24)
	tw.tween_property(ring, "modulate:a", 0.0, 0.24)
	tw.chain().tween_callback(ring.queue_free)


func _process(delta: float) -> void:
	var host := get_parent()
	if host == null or not is_instance_valid(host) or host.get("is_dead") == true:
		_clear_stun()
		_clear_slow()
		queue_free()
		return

	_orbit_time += delta
	var dirty := false

	if _boss_stun_dr_left > 0.0:
		_boss_stun_dr_left = maxf(_boss_stun_dr_left - delta, 0.0)

	if stun_left > 0.0:
		stun_left = maxf(stun_left - delta, 0.0)
		dirty = true
		if stun_left <= 0.0:
			_clear_stun()

	if slow_left > 0.0:
		slow_left = maxf(slow_left - delta, 0.0)
		dirty = true
		if slow_left <= 0.0:
			_clear_slow()

	if burn_left > 0.0:
		burn_left = maxf(burn_left - delta, 0.0)
		_burn_tick_accum += delta
		dirty = true
		if _burn_tick_accum >= 0.5:
			_burn_tick_accum -= 0.5
			var tick_dmg := maxi(int(roundf(float(burn_dps) * 0.5)), 1)
			if _burn_attacker != null and is_instance_valid(_burn_attacker) and _burn_attacker.has_method("deal_combat_damage"):
				_burn_attacker.deal_combat_damage(host, tick_dmg, false, 0.0, (host as Node2D).global_position)
			elif host.has_method("take_damage"):
				host.take_damage(tick_dmg)
		if burn_left <= 0.0:
			burn_dps = 0

	if fang_stacks > 0:
		fang_decay_left -= delta
		dirty = true
		if fang_decay_left <= 0.0:
			fang_stacks = 0

	if _burst_flash_left > 0.0:
		_burst_flash_left = maxf(_burst_flash_left - delta, 0.0)
		dirty = true

	if dirty:
		queue_redraw()


func _exit_tree() -> void:
	_clear_stun()
	_clear_slow()


func _draw() -> void:
	var host := get_parent()
	var max_hp := int(host.get("max_health")) if (host != null and "max_health" in host) else 30
	var top_y := -34.0 if max_hp >= 85 else -24.0

	if stun_left > 0.0:
		for i in range(3):
			var ang := _orbit_time * 7.5 + float(i) * (TAU / 3.0)
			var sc := Vector2(cos(ang) * 9.5, top_y + sin(ang) * 3.2)
			draw_circle(sc, 2.2, Color(0.12, 0.08, 0.04, 0.9))
			draw_line(sc + Vector2(-2.6, 0), sc + Vector2(2.6, 0), Color(1.0, 0.92, 0.32), 1.4)
			draw_line(sc + Vector2(0, -2.6), sc + Vector2(0, 2.6), Color(1.0, 0.96, 0.65), 1.4)

	if slow_left > 0.0:
		var a0 := _orbit_time * 5.0
		draw_arc(Vector2(0.0, 8.0), 10.0, a0, a0 + 2.1, 10, Color(0.42, 0.98, 0.64, 0.78), 1.6)
		draw_arc(Vector2(0.0, 8.0), 10.0, a0 + PI, a0 + PI + 2.1, 10, Color(0.75, 1.0, 0.82, 0.68), 1.4)

	if burn_left > 0.0:
		for fi in range(3):
			var fa := _orbit_time * 6.5 + float(fi) * 2.1
			var fp := Vector2(cos(fa) * 8.0, 2.0 + sin(fa * 1.7) * 4.0)
			draw_circle(fp, 2.2, Color(1.0, 0.44, 0.10, 0.88))
			draw_circle(fp + Vector2(0.0, -1.0), 1.2, Color(1.0, 0.92, 0.38, 0.92))

	if fang_stacks > 0 or _burst_flash_left > 0.0:
		var cy := top_y - (9.0 if stun_left > 0.0 else 2.0)
		var center := Vector2(0.0, cy)
		var radius := 6.8
		var ratio := 1.0 if _burst_flash_left > 0.0 else float(fang_stacks) / float(FANG_STACKS_TO_BURST)

		draw_circle(center, radius + 1.2, Color(0.06, 0.02, 0.04, 0.88))
		draw_arc(center, radius, 0.0, TAU, 20, Color(0.38, 0.06, 0.14, 0.92), 2.0)

		var fill_col := Color(1.0, 0.45, 0.58, 0.98) if _burst_flash_left > 0.0 else Color(0.98, 0.14, 0.32, 0.96)
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * ratio, 20, fill_col, 2.4)

		for fx in [-2.6, 2.6]:
			var f_top := center + Vector2(fx, -4.0)
			var fang_pts := PackedVector2Array([
				f_top + Vector2(-1.7, 0.0),
				f_top + Vector2(1.7, 0.0),
				f_top + Vector2(0.0, 5.4),
			])
			draw_colored_polygon(fang_pts, Color(0.98, 0.95, 0.98, 0.98))
			draw_circle(f_top + Vector2(0.0, 4.6), 1.0, Color(0.95, 0.12, 0.30, 0.98))
