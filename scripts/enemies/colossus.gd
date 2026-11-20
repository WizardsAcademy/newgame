extends CharacterBody2D
## Forest Colossus - the FIRST BOSS (Phase 8, ROADMAP.md).
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
## The painted danger circle on the floor (ALL three attacks now paint
## one; freed at the strike). Stored outside the body in arena space
## so a painted zone never moves once shown.
var _danger_zone: Node2D = null
## Full telegraph length of the current attack - the denominator the
## danger zone's charge fill divides time against.
var _telegraph_total: float = 1.0
## The bouncing "!" warning that pops above the boss's head while an
## attack charges. One look, and you know: MOVE.
var _warn_marker: Label = null

# =====================================================================
# NODE REFERENCES
# =====================================================================

## The reusable floor-painter every attack telegraphs with (see
## ground_telegraph.gd). Preloaded, not class_name: one less entry in
## Godot's class cache to forget.
const GroundTelegraphScript := preload("res://scripts/enemies/ground_telegraph.gd")

@onready var visuals: Sprite2D = $Visuals
@onready var anim_player: AnimationPlayer = $AnimPlayer
@onready var hurtbox: Area2D = $Hurtbox
@onready var slam_area: Area2D = $SlamArea
@onready var sweep_area: Area2D = $SweepArea
@onready var health_bar: Node2D = $HealthBar
@onready var hit_sfx: AudioStreamPlayer = $HitSFX
@onready var death_sfx: AudioStreamPlayer = $DeathSFX
@onready var telegraph_sfx: AudioStreamPlayer = $TelegraphSFX

var player: Node2D = null


# =====================================================================
# SETUP + MAIN LOOP
# =====================================================================

func _ready() -> void:
	current_health = clampi(current_health, 0, max_health)

	hit_sfx.stream = SFXGenerator.create_hit_sfx()
	death_sfx.stream = SFXGenerator.create_death_sfx()
	# One shared "something is coming" sound; the PITCH tells you which.
	telegraph_sfx.stream = SFXGenerator.create_punch_sfx()

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
			_update_danger_zone()
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
	_telegraph_total = maxf(_timer, 0.01)
	velocity = Vector2.ZERO
	_set_walking(false)
	_paint_danger_zone(attack, global_position)
	_play_attack_pose(attack)
	_show_warn_marker(attack)
	_play_telegraph_sound(attack)


## ROOTS locks a SPOT, not the player: paint a growing green ring on
## the ground and burst there. Stored outside the body (arena-space)
## so pulling the boss around cannot drag the danger zone with it.
func _start_roots_telegraph(target: Vector2) -> void:
	_current_attack = BossAttack.ROOTS
	_state = ColossusState.TELEGRAPH
	_timer = _attack_telegraph_time(BossAttack.ROOTS)
	_telegraph_total = maxf(_timer, 0.01)
	_roots_target = target
	_roots_timer = roots_cooldown
	velocity = Vector2.ZERO
	_set_walking(false)
	_paint_danger_zone(BossAttack.ROOTS, target)
	_play_attack_pose(BossAttack.ROOTS)
	_show_warn_marker(BossAttack.ROOTS)
	_play_telegraph_sound(BossAttack.ROOTS)


# =====================================================================
# READABILITY LAYERS - the first playtest verdict was "I can't tell
# what the boss is about to do". A sprite tint is a MOOD, not a warning,
# so every attack now shouts in three channels at once:
#   LAYER 1  the FLOOR   - a danger circle with a filling charge meter
#   LAYER 2  the BODY    - a DIFFERENT pose per attack (read silhouette)
#   LAYER 3  the MARKER  - a bouncing "!" tinted per attack
#   (plus a distinct telegraph SFX pitch - see _play_telegraph_sound)
# =====================================================================

## LAYER 1 - paint the attack's radius on the floor, colour-coded.
## The charge fill (set every physics frame while TELEGRAPH) shows how
## much time is left; the outline shows exactly where it will hurt.
func _paint_danger_zone(attack: BossAttack, at: Vector2) -> void:
	var zone: Node2D = GroundTelegraphScript.new()
	match attack:
		BossAttack.SLAM:
			zone.radius = slam_radius
			zone.fill_color = Color(1.0, 0.25, 0.20, 0.20)   # deep red
			zone.edge_color = Color(1.0, 0.35, 0.25, 0.95)
		BossAttack.SWEEP:
			zone.radius = sweep_radius
			zone.fill_color = Color(1.0, 0.55, 0.15, 0.20)   # orange
			zone.edge_color = Color(1.0, 0.65, 0.25, 0.95)
		BossAttack.ROOTS:
			zone.radius = roots_radius
			zone.fill_color = Color(0.45, 1.0, 0.40, 0.20)   # thorn green
			zone.edge_color = Color(0.55, 1.0, 0.40, 0.95)
	# Same z-order lesson as the archer's risk line: z 0 in tree order
	# wins over the background (NOT -1, which hides behind opaque sky).
	zone.add_to_group("boss_telegraph")   # tests + tooling find it here
	var parent := get_parent()
	if parent != null:
		parent.add_child(zone)
		zone.global_position = at
	_danger_zone = zone


## Called every physics frame during TELEGRAPH so the fill tracks the
## real timer (enrage shrinks it without any extra bookkeeping).
func _update_danger_zone() -> void:
	if _danger_zone != null and is_instance_valid(_danger_zone):
		_danger_zone.set_charge(1.0 - _timer / _telegraph_total)


## LAYER 2 - body language. SLAM rises up (a fist pulled to the sky),
## SWEEP goes low and sways (a coiling swing), ROOTS stretches tall and
## green (summoning). Three different silhouettes = three fast reads.
func _play_attack_pose(attack: BossAttack) -> void:
	visuals.rotation = 0.0   # sweep's later swings start clean
	var pose_tween := create_tween()
	pose_tween.set_parallel(true)
	match attack:
		BossAttack.SLAM:
			var tn: float = _telegraph_total * 0.9
			pose_tween.tween_property(visuals, "scale",
				Vector2(0.88, 1.20), tn)
			pose_tween.tween_property(visuals, "position:y", -4.0, tn)
			pose_tween.tween_property(visuals, "modulate",
				Color(1.0, 0.55, 0.45), tn * 0.6)
		BossAttack.SWEEP:
			pose_tween.tween_property(visuals, "scale",
				Vector2(1.16, 0.90), _telegraph_total * 0.9)
			pose_tween.tween_property(visuals, "modulate",
				Color(1.0, 0.7, 0.4), _telegraph_total * 0.6)
			# The coil/sway rotation is a SEPARATE tween below - running
			# two tweens on one property makes them fight for it.
		BossAttack.ROOTS:
			pose_tween.tween_property(visuals, "scale",
				Vector2(0.94, 1.24), _telegraph_total * 0.9)
			pose_tween.tween_property(visuals, "modulate",
				Color(0.65, 1.0, 0.65), _telegraph_total * 0.6)
	if attack == BossAttack.SWEEP:
		var sway := create_tween()
		sway.tween_interval(_telegraph_total * 0.3)
		sway.tween_property(visuals, "rotation", -0.14, 0.15)
		sway.tween_property(visuals, "rotation", 0.10, 0.15)


## LAYER 3 - the bouncing "!" above the head, tinted per attack. Even a
## brand-new player reads this instantly: something happens NOW.
func _show_warn_marker(attack: BossAttack) -> void:
	_hide_warn_marker()
	var marker := Label.new()
	marker.text = "!"
	var settings := LabelSettings.new()
	settings.font_size = 10
	match attack:
		BossAttack.SLAM:  settings.font_color = Color(1.0, 0.35, 0.3)
		BossAttack.SWEEP: settings.font_color = Color(1.0, 0.7, 0.3)
		BossAttack.ROOTS: settings.font_color = Color(0.6, 1.0, 0.5)
	marker.label_settings = settings
	add_child(marker)
	# -34 sits the "!" just over the crown; the bob keeps it magnetic.
	marker.position = Vector2(-3, -34)
	var bob := marker.create_tween().set_loops()
	bob.tween_property(marker, "position:y", -39.0, 0.16) \
		.set_trans(Tween.TRANS_SINE)
	bob.tween_property(marker, "position:y", -33.0, 0.16) \
		.set_trans(Tween.TRANS_SINE)
	_warn_marker = marker


func _hide_warn_marker() -> void:
	if _warn_marker == null or not is_instance_valid(_warn_marker):
		_warn_marker = null
		return
	var marker := _warn_marker
	_warn_marker = null
	var tween := create_tween()
	tween.tween_property(marker, "modulate:a", 0.0, 0.1)
	tween.tween_callback(marker.queue_free)


## A distinct PITCH per attack (SLAM low roar, SWEEP mid, ROOTS high
## chime): you can hear the difference before you even turn around.
func _play_telegraph_sound(attack: BossAttack) -> void:
	if telegraph_sfx == null or telegraph_sfx.stream == null:
		return
	match attack:
		BossAttack.SLAM:  telegraph_sfx.pitch_scale = 0.65
		BossAttack.SWEEP: telegraph_sfx.pitch_scale = 1.0
		BossAttack.ROOTS: telegraph_sfx.pitch_scale = 1.45
	telegraph_sfx.play()


## Free the painted zone. consume=true for the kept-promise flash
## after the hit; false for an instant cut (boss died mid-cast).
func _kill_danger_zone(consume: bool = false) -> void:
	if _danger_zone == null:
		return
	var zone := _danger_zone
	_danger_zone = null
	if not is_instance_valid(zone) or not is_inside_tree():
		return
	if consume and zone.has_method("flash_and_free"):
		zone.flash_and_free()
	else:
		zone.queue_free()


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

	# The promise was kept: consume the danger zone with a bright flash
	# so the zone's disappearance CONFIRMS the hit window opened.
	_kill_danger_zone(true)
	_hide_warn_marker()

	# --- JUICE (pillar 1) -------------------------------------------
	if _current_attack == BossAttack.SLAM:
		ScreenShake.shake(9.0, 0.4)     # boss-high score
		HitStop.freeze(0.08)
		_spawn_slam_ring(slam_radius)
		visuals.position = Vector2(0, 3)
		visuals.scale = Vector2(1.25, 0.8)
	elif _current_attack == BossAttack.SWEEP:
		ScreenShake.shake(5.0, 0.25)
		visuals.scale = Vector2(1.12, 1.06)
		# Finish the wind-up coil with the actual swing...
		var swing := create_tween()
		swing.tween_property(visuals, "rotation", -0.35, 0.06)
		swing.tween_property(visuals, "rotation", 0.0, 0.12)
	visuals.modulate = _rest_tint()

	_state = ColossusState.STRIKE
	_timer = slam_active_duration
	print("[Colossus] ", name, " performs ", label)


## ROOTS damage check is manual (no Area2D dance): at burst time, if the
## player still stands inside the painted circle, the thorns catch them.
func _burst_roots() -> void:
	_spawn_thorn_burst(_roots_target)
	ScreenShake.shake(4.0, 0.2)
	# The warning's job is done: consume the zone with a short flash,
	# and take the "!" down with it.
	_kill_danger_zone(true)
	_hide_warn_marker()

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
	tween.tween_property(visuals, "rotation", 0.0, 0.25)
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
	_kill_danger_zone(false)
	_hide_warn_marker()

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
