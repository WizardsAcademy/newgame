extends Node2D
## Universal Enemy Status Overlay & Controller (`"EnemyStatusNode"`).
##
## Attaches cleanly onto ANY enemy (`Slime`, `Archer`, `Golem`, `Colossus`,
## `TrainingDummy`) without modifying enemy scene hierarchies:
##   1. **Stun** (Behemoth's punches & Shoulder Charge):
##      Pauses enemy movement/attacks and orbits 3 golden stars overhead.
##   2. **Sylvan Slow** (Sylvara's Wind-Vault gust):
##      Temporarily slows pursuing enemies with emerald wind wisps.
##   3. **Vampire 2-Fang + Filling Crimson Circle Debuff** (Velmira):
##      Draws 2 crisp Vampire Fangs + a crimson circular gauge (`0..4` stacks).
##      When the circle fills (`4/4`), it EXPLODES for **30% of enemy Max HP**!

const FANG_STACKS_TO_BURST: int = 4
const FANG_DECAY_SECONDS: float = 6.0
const FANG_MAX_HP_RATIO: float = 0.30
const BOSS_BURST_CAP: int = 55
const VELMIRA_FX_PATH: String = "res://assets/textures/velmira_fx.png"

var stun_left: float = 0.0
var _boss_stun_dr_left: float = 0.0
var _paused_enemy_physics: bool = false

var slow_left: float = 0.0
var _saved_move_speed: float = -1.0

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
		st._start_slow(clampf(factor, 0.25, 0.95), duration)


static func add_vampire_fang_stack(enemy: Node, attacker: Node) -> int:
	if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead") == true:
		return 0
	var st = ensure_on(enemy)
	if st == null:
		return 0
	return int(st._push_fang_stack(attacker))


func _start_stun(duration: float) -> bool:
	var host := get_parent()
	if host == null or host.get("is_dead") == true:
		return false
	var max_hp := int(host.get("max_health")) if "max_health" in host else 30
	var actual := duration
	if max_hp >= 250:
		if _boss_stun_dr_left > 0.0:
			return false
		actual = duration * 0.35
		_boss_stun_dr_left = 1.2

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

	# 4/4 FULL CIRCLE -> DETONATE FOR 30% OF ENEMY MAX HP!
	fang_stacks = 0
	fang_decay_left = 0.0
	_burst_flash_left = 0.34

	var enemy_max_hp := maxi(int(host.get("max_health")) if "max_health" in host else 30, 1)
	var burst_dmg := maxi(int(roundf(float(enemy_max_hp) * FANG_MAX_HP_RATIO)), 1)
	if enemy_max_hp >= 250:
		burst_dmg = mini(burst_dmg, BOSS_BURST_CAP)

	_in_burst = true
	_spawn_fang_explosion_fx()
	if attacker != null and is_instance_valid(attacker) and attacker.has_method("deal_combat_damage"):
		attacker.deal_combat_damage(host, burst_dmg, false, 6.0, (host as Node2D).global_position)
		if attacker.has_method("heal"):
			attacker.heal(4)
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

	# Spawn authentic Row-6 Crimson Blood Spire Eruption (`frame 3`) + Vampire Crest (`frame 0`)!
	if ResourceLoader.exists(VELMIRA_FX_PATH):
		var fx_tex: Texture2D = load(VELMIRA_FX_PATH)
		if fx_tex != null:
			var spire := Sprite2D.new()
			spire.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			var at_spire := AtlasTexture.new()
			at_spire.atlas = fx_tex
			at_spire.region = Rect2(480.0, 0.0, 160.0, 160.0)
			spire.texture = at_spire
			spire.scale = Vector2(0.18, 0.08)
			spire.z_index = 5
			world.add_child(spire)
			spire.global_position = host.global_position + Vector2(0.0, -4.0)
			var stw := spire.create_tween()
			stw.set_parallel(true)
			stw.tween_property(spire, "scale", Vector2(0.34, 0.36), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			stw.tween_property(spire, "modulate:a", 0.0, 0.34).set_delay(0.10)
			stw.chain().tween_callback(spire.queue_free)

			var crest := Sprite2D.new()
			crest.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			var at_crest := AtlasTexture.new()
			at_crest.atlas = fx_tex
			at_crest.region = Rect2(0.0, 0.0, 160.0, 160.0)
			crest.texture = at_crest
			crest.scale = Vector2(0.16, 0.16)
			crest.z_index = 6
			world.add_child(crest)
			crest.global_position = host.global_position + Vector2(0.0, -24.0)
			var ctw := crest.create_tween()
			ctw.set_parallel(true)
			ctw.tween_property(crest, "scale", Vector2(0.26, 0.26), 0.26)
			ctw.tween_property(crest, "modulate:a", 0.0, 0.30)
			ctw.chain().tween_callback(crest.queue_free)

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

	# 1. Orbiting Golden Stun Stars (`✦`)
	if stun_left > 0.0:
		for i in range(3):
			var ang := _orbit_time * 7.5 + float(i) * (TAU / 3.0)
			var sc := Vector2(cos(ang) * 9.5, top_y + sin(ang) * 3.2)
			draw_circle(sc, 2.2, Color(0.12, 0.08, 0.04, 0.9))
			draw_line(sc + Vector2(-2.6, 0), sc + Vector2(2.6, 0), Color(1.0, 0.92, 0.32), 1.4)
			draw_line(sc + Vector2(0, -2.6), sc + Vector2(0, 2.6), Color(1.0, 0.96, 0.65), 1.4)

	# 2. Sylvan Wind Slow wisps at feet
	if slow_left > 0.0:
		var a0 := _orbit_time * 5.0
		draw_arc(Vector2(0.0, 8.0), 10.0, a0, a0 + 2.1, 10, Color(0.42, 0.98, 0.64, 0.78), 1.6)
		draw_arc(Vector2(0.0, 8.0), 10.0, a0 + PI, a0 + PI + 2.1, 10, Color(0.75, 1.0, 0.82, 0.68), 1.4)

	# 3. Velmira's 2-Fang + Filling Crimson Circle Debuff!
	if fang_stacks > 0 or _burst_flash_left > 0.0:
		var cy := top_y - (9.0 if stun_left > 0.0 else 2.0)
		var center := Vector2(0.0, cy)
		var radius := 6.5
		var ratio := 1.0 if _burst_flash_left > 0.0 else float(fang_stacks) / float(FANG_STACKS_TO_BURST)

		# Dark circle backing + outer crimson rim
		draw_circle(center, radius + 1.2, Color(0.06, 0.02, 0.04, 0.88))
		draw_arc(center, radius, 0.0, TAU, 18, Color(0.38, 0.06, 0.14, 0.92), 2.0)

		# Filling scarlet blood arc (`gerdi ke por mishe`!)
		var fill_col := Color(1.0, 0.45, 0.58, 0.98) if _burst_flash_left > 0.0 else Color(0.98, 0.14, 0.32, 0.96)
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * ratio, 18, fill_col, 2.4)

		# TWO VAMPIRE FANGS (`2 ta feng vampire`) poised inside/above the crimson ring!
		for fx in [-2.6, 2.6]:
			var f_top := center + Vector2(fx, -4.0)
			var fang_pts := PackedVector2Array([
				f_top + Vector2(-1.7, 0.0),
				f_top + Vector2(1.7, 0.0),
				f_top + Vector2(0.0, 5.4),
			])
			draw_colored_polygon(fang_pts, Color(0.98, 0.95, 0.98, 0.98))
			# Crimson blood tip on each fang!
			draw_circle(f_top + Vector2(0.0, 4.6), 1.0, Color(0.95, 0.12, 0.30, 0.98))
