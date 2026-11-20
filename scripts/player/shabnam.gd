extends PlayerBase
## Velmira - the Crimson Vampire (Hero 4 of 4, docs/CHARACTERS.md).
##
## Role: Agile mid-range vampire predator (85 HP, sustained by Life Leech!).
## Signature mechanic: **Blood Blade Boomerang + Life Leech & Blood Pool**
##   - Throws a spinning crimson crescent that slices enemies going OUT and
##     curves back to slice them AGAIN on the return!
##   - Every hit leeches HP (+2 on blade hit, +3 on Bat-Mist Shift Dash) and
##     builds 1 Blood Orb (up to 5).
##   - At 5 Blood Orbs, unleashes a **Crimson Blood Nova** around Velmira!

const BLOOD_BLADE_SCENE := preload("res://scenes/player/BloodBlade.tscn")

@export var leech_per_hit: int = 2
@export var dash_leech_per_hit: int = 3
@export var max_blood_orbs: int = 5
@export var blood_nova_radius: float = 58.0
@export var blood_nova_damage: int = 16

var blood_orbs: int = 0
var _orb_angle: float = 0.0
var _orb_drawer: Node2D = null
var _in_blood_nova: bool = false


class BloodOrbRing extends Node2D:
	var count: int = 0
	var max_count: int = 5
	var angle: float = 0.0

	func _draw() -> void:
		if count <= 0:
			return
		for i in range(count):
			var a := angle + TAU * float(i) / float(max_count)
			var pos := Vector2(cos(a) * 14.0, sin(a) * 9.0 - 2.0)
			draw_circle(pos, 2.2, Color(0.45, 0.04, 0.12, 0.85))
			draw_circle(pos, 1.4, Color(1.0, 0.25, 0.38, 0.95))


func _create_attack_sfx() -> AudioStreamWAV:
	return SFXGenerator.create_blade_sfx()


func _character_ready() -> void:
	character_id = "velmira"
	character_name = "Velmira"
	dash_speed = 365.0
	dash_damage = 15
	dash_tint = Color(0.95, 0.18, 0.34, 0.84)

	_orb_drawer = BloodOrbRing.new()
	_orb_drawer.name = "BloodOrbs"
	add_child(_orb_drawer)


func _character_physics_process(delta: float) -> void:
	if _orb_drawer != null:
		_orb_angle += delta * 3.0
		_orb_drawer.count = 0 if is_dead else blood_orbs
		_orb_drawer.max_count = max_blood_orbs
		_orb_drawer.angle = _orb_angle
		_orb_drawer.queue_redraw()


func _get_attack_move_multiplier() -> float:
	# Nimble thrower: brief 40% glide while tossing a Blood Blade.
	return 0.40


func _start_attack() -> void:
	if is_attacking or is_dashing or is_dead:
		return

	_attack_token += 1
	var my_token := _attack_token
	is_attacking = true

	var dir := get_aim_direction()
	if absf(dir.x) > 0.05:
		facing = 1.0 if dir.x > 0.0 else -1.0
		_sync_facing_nodes()

	anim_player.stop()
	anim_player.play("attack")
	punch_sfx.pitch_scale = 1.12
	punch_sfx.play()

	await get_tree().create_timer(attack_windup).timeout
	if my_token != _attack_token or is_dead:
		return

	_throw_blood_blade(dir)

	var remaining := maxf(attack_duration - attack_windup, 0.08)
	await get_tree().create_timer(remaining).timeout
	if my_token != _attack_token or is_dead:
		return

	is_attacking = false


func _throw_blood_blade(dir: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var blade: Area2D = BLOOD_BLADE_SCENE.instantiate()
	parent.add_child(blade)
	blade.launch(global_position + dir.normalized() * 12.0, dir, self, attack_damage)


func _on_dash_started() -> void:
	# Crimson bat-mist burst on dash start!
	var parent := get_parent()
	if parent == null:
		return
	var bats := CPUParticles2D.new()
	bats.one_shot = true
	bats.amount = 10
	bats.lifetime = 0.25
	bats.explosiveness = 1.0
	bats.spread = 180.0
	bats.initial_velocity_min = 35.0
	bats.initial_velocity_max = 85.0
	bats.scale_amount_min = 1.5
	bats.scale_amount_max = 3.0
	bats.color = Color(0.92, 0.15, 0.30, 0.9)
	bats.emitting = false
	parent.add_child(bats)
	bats.global_position = global_position
	bats.emitting = true
	bats.finished.connect(bats.queue_free)


func _on_dealt_damage(_enemy: Node, _amount: int, from_dash: bool) -> void:
	if _in_blood_nova or is_dead:
		return

	heal(dash_leech_per_hit if from_dash else leech_per_hit)

	blood_orbs += 1
	if blood_orbs >= max_blood_orbs:
		blood_orbs = 0
		call_deferred("_detonate_blood_nova")


func _detonate_blood_nova() -> void:
	if is_dead or not is_inside_tree():
		return
	_in_blood_nova = true
	heal(5)
	ScreenShake.shake(4.2, 0.18)

	var parent := get_parent()
	if parent != null:
		var ring := Line2D.new()
		ring.width = 2.5
		ring.default_color = Color(1.0, 0.2, 0.35, 0.92)
		var pts := PackedVector2Array()
		var segs := 28
		for i in segs + 1:
			var a := TAU * float(i) / float(segs)
			pts.append(Vector2(cos(a), sin(a)) * blood_nova_radius)
		ring.points = pts
		parent.add_child(ring)
		ring.global_position = global_position
		ring.scale = Vector2(0.25, 0.25)
		var tw := ring.create_tween()
		tw.set_parallel(true)
		tw.tween_property(ring, "scale", Vector2.ONE, 0.22)
		tw.tween_property(ring, "modulate:a", 0.0, 0.26)
		tw.chain().tween_callback(ring.queue_free)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		if global_position.distance_to((enemy as Node2D).global_position) <= blood_nova_radius:
			deal_combat_damage(enemy, blood_nova_damage, false, 14.0, (enemy as Node2D).global_position)

	_in_blood_nova = false
