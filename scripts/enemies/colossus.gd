extends CharacterBody2D
## Forest Colossus - the FIRST BOSS (Phase 8, ROADMAP.md).
##
## Design in one line: a slow mountain whose three attacks cover all
## DISTANCES, so no position is safe forever - and every attack is
## loud enough to dodge (pillar 4: hard but fair).
##
## The three attacks (faz 8 = "3 attack phases"):
##   SLAM   close AOE ring, 70 px    - huge damage, huge recover
##   SWEEP  full-circle slap, 52 px  - big knockback, medium all
##   ROOTS  targeted burst at the player's CURRENT spot - punishes
##          standing still at range: roots sprout where you WERE
##
## Attack choice: close -> alternate SLAM / SWEEP (parity counter).
##                  far  (<= roots_cast_range) -> ROOTS, with a separate
##                  cooldown, so kiting never becomes a cheese.
##
## ENRAGE (the "enrage phase"): below 30% HP the colossus once turns
## red-tinted, moves 1.4x faster and telegraphs 0.6x shorter - the
## fight's last act. On top of the boss health bar you can SEE it.
##
## Same combat contract as every enemy: the player's hitbox calls
## take_damage() both ways; damage logic lives in one place per side.

# =====================================================================
# SIGNALS
# =====================================================================

signal health_changed(current_health: int, max_health: int)
signal died


# =====================================================================
# EXPORTED SETTINGS
# =====================================================================

@export var max_health: int = 400
@export var current_health: int = 400

## The boss walks like a threat, not like a race opponent.
@export var move_speed: float = 26.0

@export var flash_duration: float = 0.1
@export var death_duration: float = 0.6

## --- SLAM --------------------------------------------------------------
@export var slam_radius: float = 70.0
@export var slam_damage: int = 18
@export var slam_telegraph: float = 1.0
@export var slam_active_duration: float = 0.08
@export var slam_recover: float = 1.2

## --- SWEEP -------------------------------------------------------------
@export var sweep_radius: float = 52.0
@export var sweep_damage: int = 14
@export var sweep_telegraph: float = 0.7
@export var sweep_recover: float = 0.6

## --- ROOTS (the far-range answer) ---------------------------------------
## Cast from this far away and closer.
@export var roots_cast_range: float = 340.0
@export var roots_radius: float = 30.0
@export var roots_damage: int = 12
## The red ring grows for this long BEFORE the roots burst.
@export var roots_telegraph: float = 0.9
## Cannot re-cast roots for this long after one - forces melee time.
@export var roots_cooldown: float = 2.5

## Distance (centre to centre) closer than which melee attacks fire.
@export var melee_trigger_range: float = 60.0
@export var attack_cooldown: float = 0.4

## Below this HP fraction the ENRAGE phase flips on, once.
@export var enrage_at_fraction: float = 0.3
@export var enrage_speed_factor: float = 1.4
@export var enrage_telegraph_factor: float = 0.6


# =====================================================================
# STATE
# =====================================================================

var is_dead: bool = false
var _is_flashing: bool = false
var is_enraged: bool = false
var _has_hit_this_strike: bool = false
var _roots_timer: float = 0.0        # > 0 = roots on cooldown
var _melee_counter: int = 0          # parity: even = SLAM, odd = SWEEP

enum ColossusState { CHASE, TELEGRAPH, STRIKE, RECOVER, COOLDOWN }
enum BossAttack { SLAM, SWEEP, ROOTS }

var _state: ColossusState = ColossusState.CHASE
var _current_attack: BossAttack = BossAttack.SLAM
var _timer: float = 0.0

## Where the ROOTS burst will happen (captured at telegraph START,
## painted with a growing red ring - move and you live).
var _roots_target: Vector2 = Vector2.INF
## The painted ground ring (spawned at telegraph, freed at the burst).
var _roots_ring: Line2D = null

# =====================================================================
# NODE REFERENCES
# =====================================================================

@onready var visuals: Sprite2D = $Visuals
@onready var anim_player: AnimationPlayer = $AnimPlayer
@onready var hurtbox: Area2D = $Hurtbox
@onready var slam_area: Area2D = $SlamArea
@onready var sweep_area: Area2D = $SweepArea
@onready var health_bar: Node2D = $HealthBar
@onready var hit_sfx: AudioStreamPlayer = $HitSFX
@onready var death_sfx: AudioStreamPlayer = $DeathSFX

var player: Node2D = null


# =====================================================================
# SETUP + MAIN LOOP
# =====================================================================

func _ready() -> void:
	current_health = clampi(current_health, 0, max_health)

	hit_sfx.stream = SFXGenerator.create_hit_sfx()
	death_sfx.stream = SFXGenerator.create_death_sfx()

	player = get_tree().get_first_node_in_group("player")

	# Both strike areas sleep until the exact strike window
	# (same "deliberate hit" pattern as the golem's slam).
	for area in [slam_area, sweep_area]:
		area.monitoring = false
		area.monitorable = false
		area.area_entered.connect(_on_strike_area_area_entered)

	# Boss-grade health bar: twice as wide, sits above the big sprite.
	health_bar.bar_size = Vector2(56, 6)
	health_bar.bar_offset = Vector2(0, -30)

	_update_health_bar()
	health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	_roots_timer = maxf(_roots_timer - delta, 0.0)
	_timer -= delta

	match _state:
		ColossusState.CHASE:
			_chase_or_pick_attack()
		ColossusState.TELEGRAPH:
			velocity = Vector2.ZERO
			move_and_slide()
			_set_walking(false)
			if _timer <= 0.0:
				_perform_strike()
		ColossusState.STRIKE:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_end_strike()
		ColossusState.RECOVER:
			velocity = Vector2.ZERO
			move_and_slide()
			_set_walking(false)
			if _timer <= 0.0:
				_state = ColossusState.COOLDOWN
				_timer = attack_cooldown
		ColossusState.COOLDOWN:
			_chase_or_pick_attack()

	# Face the player (our texture looks to the RIGHT).
	if player != null and is_instance_valid(player):
		visuals.flip_h = player.global_position.x < global_position.x


# =====================================================================
# ATTACK PICKING
# =====================================================================

func _chase_or_pick_attack() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player == null or player.get("is_dead"):
		velocity = Vector2.ZERO
		_set_walking(false)
		move_and_slide()
		return

	var distance := global_position.distance_to(player.global_position)

	if distance <= melee_trigger_range:
		# Close: alternate SLAM (even) / SWEEP (odd) - never the same
		# heavy hit twice in a row, so the fight stays a read.
		_start_telegraph(
			BossAttack.SLAM if _melee_counter % 2 == 0 else BossAttack.SWEEP)
		_melee_counter += 1
		return

	# Far: reachable and roots ready? Cast at the player's CURRENT spot.
	if distance <= roots_cast_range and _roots_timer <= 0.0:
		_start_roots_telegraph(player.global_position)
		return

	# Otherwise: close the distance, slowly but surely.
	velocity = (player.global_position - global_position).normalized() * move_speed
	_set_walking(true)
	move_and_slide()


# =====================================================================
# TELEGRAPHS  (pillar 4: the dodge is always advertised)
# =====================================================================

func _attack_telegraph_time(attack: BossAttack) -> float:
	var t: float = slam_telegraph
	if attack == BossAttack.SWEEP:
		t = sweep_telegraph
	elif attack == BossAttack.ROOTS:
		t = roots_telegraph
	return t * (enrage_telegraph_factor if is_enraged else 1.0)


func _start_telegraph(attack: BossAttack) -> void:
	_current_attack = attack
	_state = ColossusState.TELEGRAPH
	_timer = _attack_telegraph_time(attack)
	velocity = Vector2.ZERO
	_set_walking(false)
	_show_telegraph(0.5)


## ROOTS locks a SPOT, not the player: paint an expanding red ring on
## the ground and burst there. Stored outside the body (arena-space)
## so pulling the boss around cannot drag the danger zone with it.
func _start_roots_telegraph(target: Vector2) -> void:
	_current_attack = BossAttack.ROOTS
	_state = ColossusState.TELEGRAPH
	_timer = _attack_telegraph_time(BossAttack.ROOTS)
	_roots_target = target
	_roots_timer = roots_cooldown
	velocity = Vector2.ZERO
	_set_walking(false)
	_spawn_roots_ring(target)
	_show_telegraph(0.6)


## Body warn: swell up + red glow (while the attack draws).
func _show_telegraph(strength: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "scale",
		Vector2(1.0 + 0.10 * strength, 1.0 - 0.08 * strength), _timer)
	tween.tween_property(visuals, "modulate", Color(1.0, 0.55, 0.45), _timer)


## The painted ring: expanding red circle exactly where roots will
## erupt. Same z-order lesson as the archer's risk line (z 0 wins over
## the background by tree order; NOT -1, which hides behind opaque sky).
func _spawn_roots_ring(target: Vector2) -> void:
	var ring := Line2D.new()
	var segments := 28
	var points := PackedVector2Array()
	for i in segments + 1:
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * roots_radius)
	ring.points = points
	ring.width = 2.0
	ring.default_color = Color(1.0, 0.3, 0.25, 0.5)
	_install_ring(ring, target)
	_roots_ring = ring
	# Grow from nothing to full size over the whole telegraph: read the
	# growth rate and you know exactly how long you have.
	ring.scale = Vector2(0.2, 0.2)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE, _timer)


## Put the ring in the world (arena child so it does not move with us).
func _install_ring(ring: Line2D, target: Vector2) -> void:
	var parent := get_parent()
	if parent != null:
		parent.add_child(ring)
		ring.global_position = target


## Free the painted ring. fade=false for an instant cut (boss died
## mid-cast); fade=true for the consumed-after-burst outro.
func _kill_roots_ring(fade: bool = false) -> void:
	if _roots_ring == null:
		return
	var ring := _roots_ring
	_roots_ring = null
	if not is_instance_valid(ring) or not is_inside_tree():
		return
	if fade:
		var tween := create_tween()
		tween.tween_property(ring, "modulate:a", 0.0, 0.12)
		tween.tween_callback(ring.queue_free)
	else:
		ring.queue_free()


# =====================================================================
# STRIKES  (one physical place per attack's damage - contract rule)
# =====================================================================

func _perform_strike() -> void:
	match _current_attack:
		BossAttack.SLAM:
			_begin_area_strike(slam_area, "Slam")
		BossAttack.SWEEP:
			_begin_area_strike(sweep_area, "Sweep")
		BossAttack.ROOTS:
			_burst_roots()


func _begin_area_strike(area: Area2D, label: String) -> void:
	if player == null or not is_instance_valid(player) or player.get("is_dead"):
		# Player gone mid-telegraph: skip the swing, small pause.
		_set_state_cooldown()
		return
	_has_hit_this_strike = false
	area.set_deferred("monitoring", true)

	# --- JUICE (pillar 1) -------------------------------------------
	if _current_attack == BossAttack.SLAM:
		ScreenShake.shake(9.0, 0.4)     # boss-high score
		HitStop.freeze(0.08)
		_spawn_slam_ring(slam_radius)
		visuals.position = Vector2(0, 3)
		visuals.scale = Vector2(1.25, 0.8)
	else:
		ScreenShake.shake(5.0, 0.25)
		visuals.scale = Vector2(1.12, 1.06)
	visuals.modulate = _rest_tint()

	_state = ColossusState.STRIKE
	_timer = slam_active_duration
	print("[Colossus] ", name, " performs ", label)


## ROOTS damage check is manual (no Area2D dance): at burst time, if the
## player still stands inside the painted circle, the thorns catch them.
func _burst_roots() -> void:
	_spawn_thorn_burst(_roots_target)
	ScreenShake.shake(4.0, 0.2)
	# The warning's job is done: consume the ring with a short fade.
	_kill_roots_ring(true)

	if player != null and is_instance_valid(player) and not player.get("is_dead"):
		var distance: float = player.global_position.distance_to(_roots_target)
		if distance <= roots_radius:
			player.take_damage(roots_damage, _roots_target)
			print("[Colossus] roots caught the player for ", roots_damage)

	_state = ColossusState.RECOVER
	_timer = 0.4


func _end_strike() -> void:
	slam_area.set_deferred("monitoring", false)
	sweep_area.set_deferred("monitoring", false)
	_state = ColossusState.RECOVER

	match _current_attack:
		BossAttack.SLAM:
			_timer = slam_recover     # stuck in the ground - punish me
		BossAttack.SWEEP:
			_timer = sweep_recover
		_:
			_timer = 0.2
	_reset_visuals()


func _set_state_cooldown() -> void:
	_state = ColossusState.COOLDOWN
	_timer = attack_cooldown
	_reset_visuals()


# =====================================================================
# VISUALS
# =====================================================================

## Resting tint: normal mossy green - or a permanent angry red while
## ENRAGED (the tell never leaves, the player always knows the phase).
func _rest_tint() -> Color:
	return Color(1.0, 0.7, 0.65) if is_enraged else Color.WHITE


func _reset_visuals() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "position:y", 0.0, 0.25)
	tween.tween_property(visuals, "scale", Vector2.ONE, 0.25)
	tween.tween_property(visuals, "modulate", _rest_tint(), 0.25)


## Stone-and-earth ring flying outward (bigger sibling of the golem's).
func _spawn_slam_ring(radius: float) -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.amount = 34
	burst.lifetime = 0.5
	burst.explosiveness = 1.0
	burst.direction = Vector2.UP
	burst.spread = 90.0
	burst.initial_velocity_min = radius * 1.4
	burst.initial_velocity_max = radius * 2.4
	burst.gravity = Vector2(0, 340)
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	burst.color = Color(0.45, 0.42, 0.33)
	burst.emitting = false
	get_parent().add_child(burst)
	burst.global_position = global_position + Vector2(0, 8)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)


## Roots erupt: dirt + green shards from the marked spot.
func _spawn_thorn_burst(target: Vector2) -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.amount = 26
	burst.lifetime = 0.45
	burst.explosiveness = 1.0
	burst.direction = Vector2.UP
	burst.spread = 45.0
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 260.0
	burst.gravity = Vector2(0, 420)
	burst.scale_amount_min = 1.5
	burst.scale_amount_max = 3.0
	# Half dirt, half leaf-green: alternate per particle for a two-tone
	# burst without a second node.
	burst.color_ramp = _make_two_color_gradient()
	burst.emitting = false
	get_parent().add_child(burst)
	burst.global_position = target
	burst.emitting = true
	burst.finished.connect(burst.queue_free)


func _make_two_color_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.36, 0.55, 0.3),   # leaf green tips
		Color(0.4, 0.32, 0.22),   # dirt
	])
	return gradient


# =====================================================================
# ANIMATION
# =====================================================================

func _set_walking(walking: bool) -> void:
	var desired := "walk" if walking else "idle"
	if anim_player.current_animation != desired:
		anim_player.play(desired)


# =====================================================================
# DAMAGE
# =====================================================================

## A strike area touched the player's hurtbox.
func _on_strike_area_area_entered(area: Area2D) -> void:
	if _has_hit_this_strike or is_dead:
		return
	var current: Node = area
	var guard := 4
	while current != null and guard > 0:
		if current != self and current.has_method("take_damage"):
			_has_hit_this_strike = true
			hit_sfx.play()
			var damage := slam_damage if _current_attack == BossAttack.SLAM \
				else sweep_damage
			current.take_damage(damage, global_position)
			print("[Colossus] ", name, " hit the player for ", damage)
			return
		current = current.get_parent()
		guard -= 1


## Called by the player's hitbox.
func take_damage(amount: int) -> void:
	if is_dead:
		return
	current_health -= amount
	current_health = maxi(current_health, 0)
	print("[Colossus] ", name, " took ", amount, " damage  ->  HP ",
		current_health, "/", max_health)

	hit_sfx.play()
	_update_health_bar()
	health_changed.emit(current_health, max_health)
	flash_white(flash_duration)

	if not is_enraged and current_health > 0 \
			and current_health <= float(max_health) * enrage_at_fraction:
		_enter_enrage()

	if current_health <= 0:
		die()


## ENRAGE: one-way flip. Faster, terser telegraphs, permanent red tint.
func _enter_enrage() -> void:
	is_enraged = true
	move_speed *= enrage_speed_factor
	print("[Colossus] ", name, " IS ENRAGED")
	ScreenShake.shake(4.0, 0.3)   # announce it with a rumble
	var tween := create_tween()
	tween.tween_property(visuals, "modulate", _rest_tint(), 0.4)


func flash_white(duration: float) -> void:
	if _is_flashing or is_dead:
		return
	_is_flashing = true
	visuals.modulate = Color(1, 0.4, 0.4)
	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(visuals) or is_dead:
		return
	if not is_dead and _state != ColossusState.TELEGRAPH:
		visuals.modulate = _rest_tint()
	_is_flashing = false


func die() -> void:
	if is_dead:
		return
	is_dead = true
	print("[Colossus] ", name, " fell (the forest holds its breath)")

	death_sfx.play()
	_kill_roots_ring(false)

	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	slam_area.set_deferred("monitoring", false)
	slam_area.set_deferred("monitorable", false)
	sweep_area.set_deferred("monitoring", false)
	sweep_area.set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "scale:y", 0.15, death_duration)
	tween.tween_property(visuals, "position:y", 10.0, death_duration)
	tween.tween_property(visuals, "modulate:a", 0.0, death_duration)
	if health_bar != null:
		tween.tween_property(health_bar, "modulate:a", 0.0, death_duration)

	# The biggest death burst in the game: leaves AND earth.
	_spawn_death_burst()
	died.emit()

	await get_tree().create_timer(death_duration).timeout
	queue_free()


func _spawn_death_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.amount = 46
	burst.lifetime = 0.8
	burst.explosiveness = 1.0
	burst.direction = Vector2.UP
	burst.spread = 80.0
	burst.initial_velocity_min = 90.0
	burst.initial_velocity_max = 220.0
	burst.gravity = Vector2(0, 380)
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 5.0
	burst.color = Color(0.38, 0.45, 0.28)
	burst.emitting = false
	get_parent().add_child(burst)
	burst.global_position = global_position
	burst.emitting = true
	burst.finished.connect(burst.queue_free)


# =====================================================================
# HEALTH BAR
# =====================================================================

func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.set_health(current_health, max_health)
