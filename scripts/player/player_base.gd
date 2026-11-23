extends CharacterBody2D
class_name PlayerBase
## Shared base controller for all 4 playable 96x96 medieval heroes.
##
## Owns universal movement, combat, Energy, Hurt animation, and Shift hooks:
##  - Centralized `_read_input()` (multiplayer-ready rule #1),
##  - Health + Green Energy bar signals (`health_changed`, `energy_changed`,
##    `hurt_triggered`, `damage_mitigated`),
##  - Dedicated `"hurt"` hit-reaction animation on every hero when taking damage,
##  - Distinct per-hero `Shift` abilities (`"charge"` animation + subclass hooks).


# =====================================================================
# SIGNALS (HUD / Main listens to these - never touch UI directly)
# =====================================================================

signal attack_hit(enemy)
signal health_changed(current_health: int, max_health: int)
signal energy_changed(current_energy: float, max_energy: float)
signal hurt_triggered(damage_taken: int)
signal player_died
signal dash_cooldown_changed(remaining: float, duration: float)
signal damage_mitigated(blocked_amount: int, final_amount: int)


# =====================================================================
# EXPORTED SETTINGS
# =====================================================================

@export var character_id: String = "behemoth"
@export var character_name: String = "Behemoth"

@export var move_speed: float = 92.0
@export var attack_duration: float = 0.44
@export var attack_damage: int = 18
@export var attack_windup: float = 0.14
@export var hitbox_active_time: float = 0.14

@export var max_health: int = 120
@export var max_energy: float = 100.0
@export var energy_regen_per_sec: float = 28.0
@export var dash_energy_cost: float = 18.0

@export var invulnerability_time: float = 0.75
@export var knockback_speed: float = 180.0
@export var footstep_interval: float = 0.25

## --- Shift Ability (1.0s cooldown; distinct per hero!) -----------------
@export var dash_speed: float = 350.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 1.0
@export var dash_deals_damage: bool = false
@export var dash_phases_enemies: bool = false
@export var dash_damage: int = 0
@export var dash_hit_radius: float = 18.0
@export var dash_knockback_px: float = 12.0
@export var dash_spawns_ghosts: bool = true
@export var dash_tint: Color = Color(0.55, 0.9, 1.0, 0.72)

## Local offset of AttackPoint + melee Hitbox when facing right.
@export var attack_point_offset_x: float = 16.0


# =====================================================================
# STATE
# =====================================================================

var input_enabled: bool = true

var is_attacking: bool = false
var is_dead: bool = false
var is_dashing: bool = false

var current_health: int = 120
var current_energy: float = 100.0
var facing: float = 1.0
var facing_dir: Vector2 = Vector2.RIGHT
var facing_cardinal: String = "side" # "side" | "up" | "down"

var last_dealt_damage: int = 18
var last_hit_was_dash: bool = false
var last_health_change_was_self_cost: bool = false
var last_mitigation_label: String = "BLOCK"

var dash_cooldown_left: float = 0.0
var _dash_time_left: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _dash_start_pos: Vector2 = Vector2.ZERO
var _dash_ghost_timer: float = 0.0
var _enemies_hit_this_dash: Dictionary = {}

var _base_visual_scale: Vector2 = Vector2.ONE
var _hurt_anim_left: float = 0.0
var _invulnerable: bool = false
var _knockback: Vector2 = Vector2.ZERO
var _move_vel: Vector2 = Vector2.ZERO
var _is_flashing: bool = false
var _enemies_hit_this_swing: Dictionary = {}
var _footstep_timer: float = 0.0
var _attack_token: int = 0
var _last_attack_used_mouse: bool = false

const HIT_SPARK_SCENE := preload("res://scenes/fx/HitSpark.tscn")
const _BODY_LAYER_NORMAL: int = 2
const _BODY_MASK_NORMAL: int = 5   # layer 1 (walls) + layer 3 (enemy bodies)
const _BODY_MASK_DASH: int = 1     # layer 1 (walls only) -> phase through enemies!


# =====================================================================
# NODE REFERENCES
# =====================================================================

@onready var visuals: Sprite2D = $Visuals
@onready var anim_player: AnimationPlayer = $AnimPlayer
@onready var attack_point: Marker2D = $AttackPoint
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var punch_sfx: AudioStreamPlayer = $PunchSFX
@onready var footstep_sfx: AudioStreamPlayer = $FootstepSFX
@onready var hurt_sfx: AudioStreamPlayer = $HurtSFX
@onready var dust: CPUParticles2D = $Dust

var _dash_hitbox: Area2D = null
var _dash_sfx: AudioStreamPlayer = null


# =====================================================================
# SETUP
# =====================================================================

func _ready() -> void:
	_ensure_input_actions()
	if visuals != null:
		_base_visual_scale = Vector2(absf(visuals.scale.x), visuals.scale.y)
	_disable_hitbox()
	_setup_dash_nodes()

	punch_sfx.stream = _create_attack_sfx()
	footstep_sfx.stream = SFXGenerator.create_footstep_sfx()
	hurt_sfx.stream = SFXGenerator.create_hurt_sfx()

	current_health = max_health
	current_energy = max_energy
	last_dealt_damage = attack_damage

	if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)

	_character_ready()
	energy_changed.emit(current_energy, max_energy)


func _character_ready() -> void:
	pass


func _create_attack_sfx() -> AudioStreamWAV:
	return SFXGenerator.create_punch_sfx()


static func _ensure_input_actions() -> void:
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
	var has_shift := false
	for ev in InputMap.action_get_events("dash"):
		if ev is InputEventKey and ((ev as InputEventKey).keycode == KEY_SHIFT or (ev as InputEventKey).physical_keycode == KEY_SHIFT):
			has_shift = true
			break
	if not has_shift:
		var shift_ev := InputEventKey.new()
		shift_ev.keycode = KEY_SHIFT
		InputMap.action_add_event("dash", shift_ev)

	if not InputMap.has_action("shield"):
		InputMap.add_action("shield")
	if InputMap.action_get_events("shield").is_empty():
		var rmb := InputEventMouseButton.new()
		rmb.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("shield", rmb)
		var key_e := InputEventKey.new()
		key_e.keycode = KEY_E
		InputMap.action_add_event("shield", key_e)

	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
	if InputMap.action_get_events("interact").is_empty():
		var key_f := InputEventKey.new()
		key_f.keycode = KEY_F
		InputMap.action_add_event("interact", key_f)


func _setup_dash_nodes() -> void:
	_dash_hitbox = get_node_or_null("DashHitbox") as Area2D
	if _dash_hitbox == null:
		_dash_hitbox = Area2D.new()
		_dash_hitbox.name = "DashHitbox"
		_dash_hitbox.collision_layer = 8
		_dash_hitbox.collision_mask = 16
		_dash_hitbox.monitoring = false
		_dash_hitbox.monitorable = false
		var shape_node := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = dash_hit_radius
		shape_node.shape = circle
		_dash_hitbox.add_child(shape_node)
		add_child(_dash_hitbox)

	if not _dash_hitbox.area_entered.is_connected(_on_dash_hitbox_area_entered):
		_dash_hitbox.area_entered.connect(_on_dash_hitbox_area_entered)
	if not _dash_hitbox.body_entered.is_connected(_on_dash_hitbox_body_entered):
		_dash_hitbox.body_entered.connect(_on_dash_hitbox_body_entered)

	_dash_sfx = get_node_or_null("DashSFX") as AudioStreamPlayer
	if _dash_sfx == null:
		_dash_sfx = AudioStreamPlayer.new()
		_dash_sfx.name = "DashSFX"
		_dash_sfx.bus = &"SFX"
		add_child(_dash_sfx)
	_dash_sfx.stream = SFXGenerator.create_dash_sfx()


# =====================================================================
# CENTRALIZED INPUT (docs/ARCHITECTURE.md rule #1)
# =====================================================================

func _read_input() -> Dictionary:
	if not input_enabled or is_dead:
		return {
			"move": Vector2.ZERO,
			"attack_held": false,
			"shield_held": false,
			"aim_world": global_position + Vector2(facing * 64.0, 0.0),
		}
	return {
		"move": Input.get_vector("move_left", "move_right", "move_up", "move_down"),
		"attack_held": Input.is_action_pressed("attack"),
		"shield_held": Input.is_action_pressed("shield"),
		"aim_world": get_global_mouse_position(),
	}


func _unhandled_input(event: InputEvent) -> void:
	if is_dead or not input_enabled:
		return
	if event.is_action_pressed("dash"):
		_try_start_dash()
		return
	if event.is_action_pressed("attack"):
		_last_attack_used_mouse = event is InputEventMouseButton
		_on_attack_pressed(event)
	elif event.is_action_released("attack"):
		_on_attack_released(event)


func _on_attack_pressed(_event: InputEvent) -> void:
	_start_attack()


func _on_attack_released(_event: InputEvent) -> void:
	pass


# =====================================================================
# ENERGY HELPERS
# =====================================================================

func _can_regenerate_energy() -> bool:
	return not is_dashing


func _update_energy(delta: float) -> void:
	if is_dead:
		return
	if _can_regenerate_energy() and current_energy < max_energy:
		var prev := current_energy
		current_energy = minf(current_energy + energy_regen_per_sec * delta, max_energy)
		if absf(current_energy - prev) > 0.01:
			energy_changed.emit(current_energy, max_energy)
			_on_energy_regenerated()


func _on_energy_regenerated() -> void:
	pass


func consume_energy(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var prev := current_energy
	current_energy = maxf(current_energy - amount, 0.0)
	if absf(current_energy - prev) > 0.001:
		energy_changed.emit(current_energy, max_energy)
	return prev - current_energy


func restore_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	var prev := current_energy
	current_energy = minf(current_energy + amount, max_energy)
	if absf(current_energy - prev) > 0.001:
		energy_changed.emit(current_energy, max_energy)
		_on_energy_regenerated()


# =====================================================================
# MAIN LOOP
# =====================================================================

func _physics_process(delta: float) -> void:
	if _hurt_anim_left > 0.0:
		_hurt_anim_left = maxf(_hurt_anim_left - delta, 0.0)
	_update_dash_timers(delta)
	if is_dashing:
		_process_dash(delta)
	else:
		_handle_movement()
	_character_physics_process(delta)
	_update_energy(delta)
	_update_animation()
	_update_footsteps(delta)


func _character_physics_process(_delta: float) -> void:
	pass


func _get_attack_move_multiplier() -> float:
	return 0.0


func _get_stance_move_multiplier() -> float:
	return 1.0


func _get_bonus_speed_multiplier() -> float:
	return 1.0


# =====================================================================
# MOVEMENT
# =====================================================================

func _handle_movement() -> void:
	if is_dead or not input_enabled:
		_move_vel = Vector2.ZERO
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dt := get_physics_process_delta_time()
	var input_state := _read_input()
	var raw_move: Vector2 = input_state["move"]
	var input_dir: Vector2 = raw_move
	if is_attacking:
		input_dir *= _get_attack_move_multiplier()
	else:
		input_dir *= _get_stance_move_multiplier()

	_knockback = _knockback.move_toward(Vector2.ZERO, 800.0 * dt)

	var target_vel := input_dir * (move_speed * _get_bonus_speed_multiplier())
	if is_attacking and _get_attack_move_multiplier() <= 0.001:
		_move_vel = Vector2.ZERO
	else:
		var accel := 960.0 if target_vel.length() > 0.1 else 1120.0
		_move_vel = _move_vel.move_toward(target_vel, accel * dt)

	velocity = _move_vel + _knockback
	move_and_slide()

	if not is_attacking and raw_move.length() > 0.05:
		set_move_facing(raw_move)

	_sync_facing_nodes()


## Updates 4-directional facing (`"up"`, `"down"`, `"side"` + `facing` + `facing_dir`).
func set_move_facing(dir: Vector2) -> void:
	if dir.length() <= 0.05:
		return
	facing_dir = dir.normalized()
	if absf(dir.y) > absf(dir.x) * 1.05:
		facing_cardinal = "up" if dir.y < 0.0 else "down"
	else:
		facing_cardinal = "side"
		facing = 1.0 if dir.x >= 0.0 else -1.0
	_sync_facing_nodes()


func _sync_facing_nodes() -> void:
	if visuals != null:
		var use_side_flip := (facing_cardinal == "side") or is_attacking or is_dashing
		var sx := (_base_visual_scale.x * facing) if use_side_flip else absf(_base_visual_scale.x)
		visuals.scale = Vector2(sx, _base_visual_scale.y)
	var aim_vec := facing_dir.normalized() if facing_dir.length() > 0.05 else Vector2(facing, 0.0)
	attack_point.position = aim_vec * attack_point_offset_x
	hitbox.position = aim_vec * attack_point_offset_x
	hitbox.rotation = aim_vec.angle() if facing_cardinal != "side" else 0.0


# =====================================================================
# DISTINCT HERO SHIFT ABILITY (1.0s cooldown)
# =====================================================================

func can_dash() -> bool:
	return input_enabled and (not is_dead) and (not is_dashing) and dash_cooldown_left <= 0.0 and current_energy >= dash_energy_cost


func _try_start_dash() -> bool:
	if not can_dash():
		return false

	var move_dir: Vector2 = _read_input()["move"]
	if move_dir.length() > 0.05:
		set_move_facing(move_dir)
		_dash_dir = move_dir.normalized()
	elif facing_dir.length() > 0.05:
		_dash_dir = facing_dir.normalized()
		if absf(_dash_dir.x) > 0.05:
			facing = 1.0 if _dash_dir.x > 0.0 else -1.0
	else:
		_dash_dir = Vector2(facing, 0.0)

	if is_attacking:
		_attack_token += 1
		is_attacking = false
		_disable_hitbox()

	consume_energy(dash_energy_cost)
	_sync_facing_nodes()
	_dash_start_pos = global_position
	is_dashing = true
	_hurt_anim_left = 0.0
	_dash_time_left = dash_duration
	dash_cooldown_left = dash_cooldown
	_dash_ghost_timer = 0.0
	_enemies_hit_this_dash.clear()
	_knockback = Vector2.ZERO

	if dash_phases_enemies:
		collision_layer = 0
		collision_mask = _BODY_MASK_DASH
	else:
		collision_layer = _BODY_LAYER_NORMAL
		collision_mask = _BODY_MASK_NORMAL

	_dash_hitbox.monitoring = dash_deals_damage and dash_damage > 0
	_dash_sfx.play()
	dust.restart()
	ScreenShake.shake(2.2, 0.09)
	if dash_spawns_ghosts:
		_spawn_dash_ghost()
	if anim_player != null and anim_player.has_animation("charge"):
		anim_player.play("charge")
	_on_dash_started()
	dash_cooldown_changed.emit(dash_cooldown_left, dash_cooldown)
	return true


func _update_dash_timers(delta: float) -> void:
	if dash_cooldown_left > 0.0:
		dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)
		dash_cooldown_changed.emit(dash_cooldown_left, dash_cooldown)


func _process_dash(delta: float) -> void:
	if is_dead:
		_end_dash()
		return

	velocity = _dash_dir * dash_speed
	move_and_slide()
	_on_dash_tick(delta)

	if dash_deals_damage and dash_damage > 0 and _dash_hitbox != null and _dash_hitbox.monitoring:
		for area in _dash_hitbox.get_overlapping_areas():
			_try_dash_hit(area)
		for body in _dash_hitbox.get_overlapping_bodies():
			_try_dash_hit(body)

	if dash_spawns_ghosts:
		_dash_ghost_timer -= delta
		if _dash_ghost_timer <= 0.0:
			_spawn_dash_ghost()
			_dash_ghost_timer = 0.045

	_dash_time_left -= delta
	if _dash_time_left <= 0.0:
		_end_dash()


func _end_dash() -> void:
	if not is_dashing:
		return
	is_dashing = false
	velocity = Vector2.ZERO
	if _dash_hitbox != null:
		_dash_hitbox.set_deferred("monitoring", false)
	if not is_dead:
		collision_layer = _BODY_LAYER_NORMAL
		collision_mask = _BODY_MASK_NORMAL
	_on_dash_ended()


func _on_dash_started() -> void:
	pass


func _on_dash_tick(_delta: float) -> void:
	pass


func _on_dash_ended() -> void:
	pass


func _on_dash_hit_enemy(_enemy: Node) -> void:
	pass


func _on_dash_hitbox_area_entered(area: Area2D) -> void:
	_try_dash_hit(area)


func _on_dash_hitbox_body_entered(body: Node2D) -> void:
	_try_dash_hit(body)


func _try_dash_hit(touched: Node) -> void:
	if not is_dashing or is_dead or not dash_deals_damage or dash_damage <= 0:
		return
	var enemy := _find_damageable(touched)
	if enemy == null:
		return
	var enemy_id := enemy.get_instance_id()
	if _enemies_hit_this_dash.has(enemy_id):
		return
	_enemies_hit_this_dash[enemy_id] = true
	deal_combat_damage(enemy, dash_damage, true, dash_knockback_px)
	_on_dash_hit_enemy(enemy)


func _spawn_dash_ghost() -> void:
	var parent := get_parent()
	if parent == null or visuals == null or visuals.texture == null or not visuals.visible:
		return
	var ghost := Sprite2D.new()
	ghost.texture = visuals.texture
	ghost.global_position = visuals.global_position
	ghost.scale = visuals.scale
	ghost.modulate = dash_tint
	parent.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.18)
	tween.tween_callback(ghost.queue_free)


# =====================================================================
# ANIMATION & FOOTSTEPS
# =====================================================================

func _exit_tree() -> void:
	if is_dashing:
		_end_dash()


func _update_animation() -> void:
	if is_dead:
		return
	if is_dashing:
		if anim_player.has_animation("charge") and anim_player.current_animation != "charge":
			anim_player.play("charge")
		return
	if is_attacking:
		return
	if _hurt_anim_left > 0.0 and anim_player.has_animation("hurt"):
		if anim_player.current_animation != "hurt":
			anim_player.play("hurt")
		return
	var moving := velocity.length() > 0.5
	var desired := "walk" if moving else "idle"
	if facing_cardinal == "up":
		var cand_up := "walk_up" if moving else "idle_up"
		if anim_player.has_animation(cand_up):
			desired = cand_up
	elif facing_cardinal == "down":
		var cand_dn := "walk_down" if moving else "idle_down"
		if anim_player.has_animation(cand_dn):
			desired = cand_dn
	if anim_player.current_animation != desired:
		anim_player.play(desired)


func _update_footsteps(delta: float) -> void:
	var is_walking := (not is_attacking) and (not is_dashing) and velocity.length() > 0.5
	if not is_walking:
		_footstep_timer = 0.0
		if footstep_sfx.playing:
			footstep_sfx.stop()
		return

	if _footstep_timer <= 0.0:
		footstep_sfx.play()
		dust.restart()
		_footstep_timer = footstep_interval
	else:
		_footstep_timer -= delta


# =====================================================================
# DEFAULT MELEE COMBAT
# =====================================================================

func _start_attack() -> void:
	if is_attacking or is_dashing or is_dead:
		return

	_attack_token += 1
	var my_token := _attack_token
	is_attacking = true
	_hurt_anim_left = 0.0
	_enemies_hit_this_swing.clear()

	anim_player.stop()
	anim_player.play("attack")
	punch_sfx.play()

	await get_tree().create_timer(attack_windup).timeout
	if my_token != _attack_token or is_dead:
		return

	_enable_hitbox()
	_on_melee_strike_active()

	await get_tree().physics_frame
	await get_tree().physics_frame
	if my_token != _attack_token or is_dead:
		return
	for area in hitbox.get_overlapping_areas():
		_try_hit(area)
	for body in hitbox.get_overlapping_bodies():
		_try_hit(body)

	await get_tree().create_timer(hitbox_active_time).timeout
	if my_token != _attack_token or is_dead:
		return

	_disable_hitbox()

	var remaining := maxf(attack_duration - attack_windup - hitbox_active_time, 0.0)
	await get_tree().create_timer(remaining).timeout
	if my_token != _attack_token or is_dead:
		return

	is_attacking = false


func _on_melee_strike_active() -> void:
	pass


func _enable_hitbox() -> void:
	hitbox.monitoring = true
	hitbox.monitorable = false
	ScreenShake.shake(2.0, 0.1)


func _disable_hitbox() -> void:
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)


func _on_hitbox_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _on_hitbox_body_entered(body: Node2D) -> void:
	_try_hit(body)


func _try_hit(touched: Node) -> void:
	if not is_attacking or is_dead:
		return

	var enemy := _find_damageable(touched)
	if enemy == null:
		return

	var enemy_id := enemy.get_instance_id()
	if _enemies_hit_this_swing.has(enemy_id):
		return
	_enemies_hit_this_swing[enemy_id] = true

	var dmg := _compute_melee_damage()
	var kb := _compute_melee_knockback_px()
	deal_combat_damage(enemy, dmg, false, kb)


func _compute_melee_damage() -> int:
	return attack_damage


func _compute_melee_knockback_px() -> float:
	return maxf((knockback_speed - 180.0) * 0.06, 0.0)


func deal_combat_damage(enemy: Node, amount: int, from_dash: bool = false, knockback_px: float = 0.0, spark_pos: Vector2 = Vector2.INF) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.get("is_dead") == true:
		return

	var final_damage := maxi(amount, 1)
	last_dealt_damage = final_damage
	last_hit_was_dash = from_dash

	HitStop.freeze(0.035 if from_dash else 0.05)
	ScreenShake.shake(2.8 if from_dash else 3.0, 0.14)

	enemy.take_damage(final_damage)

	if knockback_px > 0.0 and enemy is CharacterBody2D and enemy.get("is_dead") != true and enemy.get("immovable_dummy") != true:
		var away: Vector2 = (enemy.global_position - global_position)
		if away.length() > 0.5:
			(enemy as CharacterBody2D).move_and_collide(away.normalized() * knockback_px)

	var impact_at := spark_pos
	if impact_at == Vector2.INF:
		impact_at = enemy.global_position if from_dash else hitbox.global_position
	_spawn_hit_spark_at(impact_at)

	_on_dealt_damage(enemy, final_damage, from_dash)
	attack_hit.emit(enemy)


func _on_dealt_damage(_enemy: Node, _amount: int, _from_dash: bool) -> void:
	pass


func _find_damageable(node: Node) -> Node:
	var current: Node = node
	var guard := 4
	while current != null and guard > 0:
		if current != self and current.has_method("take_damage") and not current.is_in_group("player"):
			return current
		current = current.get_parent()
		guard -= 1
	return null


func _spawn_hit_spark_at(world_pos: Vector2) -> void:
	var spark := HIT_SPARK_SCENE.instantiate()
	var parent := get_parent()
	if parent == null:
		spark.queue_free()
		return
	parent.add_child(spark)
	spark.global_position = world_pos


func get_aim_direction() -> Vector2:
	var state := _read_input()
	if _last_attack_used_mouse:
		var to_mouse: Vector2 = (state["aim_world"] as Vector2) - global_position
		if to_mouse.length() > 4.0:
			var dir := to_mouse.normalized()
			set_move_facing(dir)
			return dir
	var move_dir: Vector2 = state["move"]
	if move_dir.length() > 0.05:
		set_move_facing(move_dir)
		return move_dir.normalized()
	if facing_dir.length() > 0.05:
		return facing_dir.normalized()
	return Vector2(facing, 0.0)


# =====================================================================
# HEALTH, HEALING, MITIGATION & TAKING DAMAGE
# =====================================================================

func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	var before := current_health
	current_health = clampi(current_health + amount, 0, max_health)
	if current_health != before:
		last_health_change_was_self_cost = false
		health_changed.emit(current_health, max_health)


func _mitigate_incoming_damage(amount: int, _from_position: Vector2) -> int:
	return amount


func _get_incoming_knockback_multiplier() -> float:
	return 1.0


func take_damage(amount: int, from_position: Vector2 = Vector2.INF) -> void:
	if is_dead or _invulnerable or is_dashing:
		return

	var final_amount := _mitigate_incoming_damage(amount, from_position)
	if final_amount < amount:
		damage_mitigated.emit(amount - final_amount, final_amount)
	if final_amount <= 0:
		return

	last_health_change_was_self_cost = false
	current_health = clampi(current_health - final_amount, 0, max_health)
	print("[", character_name, "] took ", final_amount, " damage  ->  HP ",
		current_health, "/", max_health)

	health_changed.emit(current_health, max_health)
	hurt_triggered.emit(final_amount)
	hurt_sfx.play()

	HitStop.freeze(0.04)
	ScreenShake.shake(4.0 * _get_incoming_knockback_multiplier(), 0.2)

	if from_position != Vector2.INF:
		var away := global_position - from_position
		if away.length() > 1.0:
			_knockback = away.normalized() * (knockback_speed * _get_incoming_knockback_multiplier())

	# Trigger hero body hurt animation!
	_hurt_anim_left = 0.24
	if not is_attacking and anim_player != null and anim_player.has_animation("hurt"):
		anim_player.play("hurt")

	_flash_red()

	if current_health <= 0:
		_die()
	else:
		_start_invulnerability()


func _flash_red() -> void:
	if _is_flashing:
		return
	_is_flashing = true
	visuals.modulate = Color(1.0, 0.35, 0.35)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(visuals) and not is_dead:
		visuals.modulate = Color.WHITE
	_is_flashing = false


func _start_invulnerability() -> void:
	if _invulnerable:
		return
	_invulnerable = true

	var blink_time := 0.1
	var steps := maxi(int(invulnerability_time / (blink_time * 2.0)), 1)
	var tween := create_tween()
	for i in steps:
		tween.tween_property(visuals, "modulate:a", 0.3, blink_time)
		tween.tween_property(visuals, "modulate:a", 1.0, blink_time)
	await tween.finished

	if is_instance_valid(visuals):
		visuals.modulate.a = 1.0
	_invulnerable = false


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	_attack_token += 1
	if is_dashing:
		_end_dash()
	print("[", character_name, "] died - GAME OVER")

	_disable_hitbox()
	$Hurtbox.set_deferred("monitoring", false)
	$Hurtbox.set_deferred("monitorable", false)
	footstep_sfx.stop()

	player_died.emit()

	anim_player.stop()
	if anim_player.has_animation("die"):
		visuals.rotation_degrees = 0.0
		anim_player.play("die")
		var dtw := create_tween()
		dtw.tween_property(visuals, "modulate", Color(0.82, 0.78, 0.84, 0.96), 0.5)
	else:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(visuals, "rotation_degrees", 90.0 * facing, 0.5)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(visuals, "modulate",
			Color(0.6, 0.6, 0.6, 0.9), 0.5)
