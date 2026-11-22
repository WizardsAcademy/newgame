extends Node
## Headless verification suite for the SLIME FAMILY (Phase V1: acid / ember /
## basalt). Run it from the repo root with:
##
##   godot --headless --path . tests/slime_variants_test.tscn
##
## Like archer_test.gd this builds tiny worlds by hand (one real slime + a
## fake player from tests/fake_player.gd) instead of booting Main, so the wave
## spawner's timing can never make these checks flaky.
##
## What it proves:
##   1. the registry is complete and the sheet rows are 0..3
##   2. the wave weight table unlocks acid@3, ember@6, basalt@9 and sums to 100
##   3. every variant scales health / speed / damage / telegraph and draws
##      from its own row of slime.png
##   4. acid death leaves a pool that damages on a 0.5 s tick, only inside
##      its radius, and expires
##   5. ember death fuses (pixel-art charge frames) then hits once for 14
##   6. basalt damages on contact on a 0.8 s tick; grass never does
##   7. the acid pool cap holds at 6
##
## Exit code 0 only when every check passed.

const FAKE_PLAYER := preload("res://tests/fake_player.gd")
const SLIME_SCENE := preload("res://scenes/enemies/Slime.tscn")
const ACID_POOL_SCENE := preload("res://scenes/fx/AcidPool.tscn")

var _failures: int = 0
var _checks: int = 0


func _check(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("PASS  ", label, ("  (" + detail + ")") if detail != "" else "")
	else:
		_failures += 1
		print("FAIL  ", label, ("  (" + detail + ")") if detail != "" else "")


func _check_eq(label: String, actual: Variant, expected: Variant) -> void:
	_check(label, actual == expected, "got %s, expected %s" % [str(actual), str(expected)])


func _check_approx(label: String, actual: float, expected: float) -> void:
	_check(label, is_equal_approx(actual, expected),
			"got %.4f, expected %.4f" % [actual, expected])


func _tick(frames: int = 1) -> void:
	for i in frames:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## A tiny arena: one fake player at the origin + the slime under test.
func _make_world() -> Dictionary:
	var world := Node2D.new()
	add_child(world)
	var fake = FAKE_PLAYER.new()
	fake.add_to_group("player")
	fake.position = Vector2.ZERO
	world.add_child(fake)
	return {"world": world, "player": fake}


## Spawn a slime of one variant. `tame` kills its AI movement/attack triggers
## (detection 0) so it stands still and only the mechanic under test can
## damage the fake player.
func _spawn_slime(world: Node2D, variant: String, at: Vector2, tame: bool = true):
	var slime = SLIME_SCENE.instantiate()
	slime.variant_id = variant
	if tame:
		slime.detection_range = 0.0
		slime.attack_trigger_range = 0.0
	world.add_child(slime)
	slime.global_position = at
	return slime


func _nodes_in(group: String) -> Array:
	return get_tree().get_nodes_in_group(group)


func _first_in(group: String) -> Node:
	var all := _nodes_in(group)
	return all[0] if all.size() > 0 else null


func _drop_world(world: Node) -> void:
	world.queue_free()
	await _tick(2)


func _run() -> void:
	print("\n=== Slime variants (Phase V1) ===\n")
	await _test_registry()
	await _test_wave_table()
	await _test_variant_stats()
	await _test_acid_pool()
	await _test_ember_fuse()
	await _test_basalt_contact()
	await _test_pool_cap()

	print("\n%d/%d checks passed." % [_checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# 1. Registry
# ---------------------------------------------------------------------------
func _test_registry() -> void:
	print("-- registry")

	_check_eq("Four variants are registered", SlimeVariant.ids().size(), 4)
	for id in ["grass", "acid", "ember", "basalt"]:
		_check("Registry contains '%s'" % id, SlimeVariant.DATA.has(id))

	var rows: Array = []
	for id in ["grass", "acid", "ember", "basalt"]:
		rows.append(SlimeVariant.row_for(id))
	_check_eq("Sheet rows are 0,1,2,3", rows, [0, 1, 2, 3])
	_check_eq("display_tag(acid)", SlimeVariant.display_tag("acid"), "AcidSlime")
	_check("Unknown id returns {}",
			SlimeVariant.get_data("nope").is_empty())

	for id in ["grass", "acid", "ember", "basalt"]:
		var data := SlimeVariant.get_data(id)
		for key in ["hp", "speed", "damage", "telegraph", "mechanic", "goo"]:
			_check("'%s' has '%s'" % [id, key], data.has(key))


# ---------------------------------------------------------------------------
# 2. Wave table
# ---------------------------------------------------------------------------
func _test_wave_table() -> void:
	print("-- wave weights")

	for wave in [1, 3, 6, 9, 12, 18, 30]:
		_check_eq("Wave %d weights sum to 100" % wave,
				SlimeVariant.total_weight(wave), 100)

	_check_eq("Wave 1: grass only", SlimeVariant.weights_for_wave(1), {"grass": 100})
	_check_eq("Wave 3: acid unlocks",
			SlimeVariant.weights_for_wave(3), {"grass": 70, "acid": 30})
	_check_eq("Wave 6: ember unlocks",
			SlimeVariant.weights_for_wave(6),
			{"grass": 50, "acid": 25, "ember": 25})
	_check_eq("Wave 9: basalt unlocks",
			SlimeVariant.weights_for_wave(9),
			{"grass": 40, "acid": 20, "ember": 25, "basalt": 15})

	# Before wave 3 nobody may see acid, before 6 no ember, before 9 no basalt.
	var early_bad := 0
	for i in 200:
		var id := SlimeVariant.pick_for_wave(2)
		if id != "grass":
			early_bad += 1
	_check_eq("Waves 1-2 never roll a variant", early_bad, 0)

	var before_ember := 0
	for i in 200:
		var id := SlimeVariant.pick_for_wave(5)
		if id != "grass" and id != "acid":
			before_ember += 1
	_check_eq("Wave 5 never rolls ember/basalt", before_ember, 0)

	var before_basalt := 0
	for i in 200:
		var id := SlimeVariant.pick_for_wave(8)
		if id == "basalt":
			before_basalt += 1
	_check_eq("Wave 8 never rolls basalt", before_basalt, 0)

	# Late waves must produce every family member at least once in 400 rolls.
	var seen := {}
	for i in 400:
		seen[SlimeVariant.pick_for_wave(30)] = true
	for id in ["grass", "acid", "ember", "basalt"]:
		_check("Wave 30 can roll '%s'" % id, seen.has(id))


# ---------------------------------------------------------------------------
# 3. Stats + sheet row per variant
# ---------------------------------------------------------------------------
func _test_variant_stats() -> void:
	print("-- stats and rows")

	# Base slime: 30 HP, 40 speed, 8 damage, 0.35 s telegraph.
	var expected := {
		"grass": {"hp": 30, "speed": 40.0, "dmg": 8, "tele": 0.35, "row": 0},
		"acid": {"hp": 38, "speed": 36.0, "dmg": 8, "tele": 0.4025, "row": 1},
		"ember": {"hp": 23, "speed": 46.0, "dmg": 7, "tele": 0.2975, "row": 2},
		"basalt": {"hp": 48, "speed": 30.0, "dmg": 10, "tele": 0.455, "row": 3},
	}

	for id in ["grass", "acid", "ember", "basalt"]:
		var built := _make_world()
		var world: Node2D = built["world"]
		var slime = _spawn_slime(world, id, Vector2(0, 120))
		await _tick(2)

		var want: Dictionary = expected[id]
		_check_eq("[%s] max_health" % id, slime.max_health, want["hp"])
		_check_eq("[%s] current_health starts full" % id,
				slime.current_health, want["hp"])
		_check_approx("[%s] move_speed" % id, slime.move_speed, want["speed"])
		_check_eq("[%s] attack_damage" % id, slime.attack_damage, want["dmg"])
		_check_approx("[%s] telegraph_duration" % id,
				slime.telegraph_duration, want["tele"])

		var body: Sprite2D = slime.get_node("Visuals/Body")
		var row: int = int(slime.get("variant_data").get("row", -1))
		_check_eq("[%s] variant row" % id, row, want["row"])
		_check("[%s] draws from its own row block" % id,
				body.frame >= row * 24 and body.frame < row * 24 + 12,
				"frame=%d row=%d" % [body.frame, row])
		_check_eq("[%s] goo colour follows the variant" % id,
				slime.body_color, SlimeVariant.goo_color(id))

		await _drop_world(world)

	# Basalt is the only contact-damage variant.
	await _tick(1)
	var built2 := _make_world()
	var slime2 = _spawn_slime(built2["world"], "basalt", Vector2(0, 120))
	await _tick(1)
	_check_eq("[basalt] contact_damage is 4", slime2.contact_damage, 4)
	await _drop_world(built2["world"])


# ---------------------------------------------------------------------------
# 4. Acid: dies into a pool
# ---------------------------------------------------------------------------
func _test_acid_pool() -> void:
	print("-- acid pool")

	var built := _make_world()
	var world: Node2D = built["world"]
	var fake = built["player"]
	var slime = _spawn_slime(world, "acid", Vector2(0, 10))
	await _tick(2)

	slime.take_damage(9999)
	await _tick(2)

	var pool = _first_in("acid_pools")
	_check("Acid death spawns a pool", pool != null)
	if pool == null:
		await _drop_world(world)
		return

	_check("Pool drops at the slime's feet",
			pool.global_position.distance_to(Vector2(0, 18)) < 2.0,
			str(pool.global_position))
	_check("Pool is pixel art, not a drawn circle",
			pool._sprite != null and pool._sprite.texture != null
			and pool._sprite.hframes == 4)
	_check_eq("Pool damage per tick", pool.damage_per_tick, 3)
	_check_eq("Pool tick interval", pool.tick_interval, 0.5)
	_check("Pool paints a >20 px radius", pool.radius >= 20.0, str(pool.radius))
	_check_eq("No damage in the first frames", fake.hit_count, 0)

	await _wait(0.35)
	_check("Pool ticks the player standing in it", fake.hit_count >= 1,
			"hits=%d" % fake.hit_count)
	_check_eq("Pool tick damage is 3", fake.last_damage, 3)

	# Stepping out must stop the damage.
	fake.position = Vector2(300, 0)
	await _tick(2)
	var hits_before: int = fake.hit_count
	await _wait(0.7)
	_check_eq("Pool cannot hurt a player outside its radius",
			fake.hit_count, hits_before)

	# Lifetime: jump the pool's clock instead of waiting 4 real seconds.
	pool._age = pool.lifetime
	await _tick(3)
	_check("Pool expires after its lifetime",
			not is_instance_valid(pool) or pool.is_queued_for_deletion())

	await _drop_world(world)


# ---------------------------------------------------------------------------
# 5. Ember: fuses, then explodes once
# ---------------------------------------------------------------------------
func _test_ember_fuse() -> void:
	print("-- ember fuse")

	var built := _make_world()
	var world: Node2D = built["world"]
	var fake = built["player"]
	var slime = _spawn_slime(world, "ember", Vector2(0, 10))
	await _tick(2)

	slime.take_damage(9999)
	await _tick(2)

	var blast = _first_in("ember_blasts")
	_check("Ember death spawns a fuse", blast != null)
	if blast == null:
		await _drop_world(world)
		return

	_check_eq("Fuse is 0.55 s", blast.fuse_time, 0.55)
	_check_eq("Blast damage is 14", blast.damage, 14)
	_check("Blast radius is 44 px", is_equal_approx(blast.radius, 44.0),
			str(blast.radius))
	_check("Fuse paints the 8-frame pixel-art ring", blast._art != null
			and blast._art.texture != null and blast._art.hframes == 8)
	_check_eq("Nothing explodes instantly", fake.hit_count, 0)

	await _wait(0.25)
	var fuse_frame: int = blast._art.frame if blast._art != null else -1
	_check("The fuse strip advances during the fuse",
			fuse_frame > 0 and fuse_frame < 8, "frame=%d" % fuse_frame)
	_check("Player still untouched mid-fuse", fake.hit_count == 0)

	await _wait(0.5)
	_check_eq("Blast hits exactly once", fake.hit_count, 1)
	_check_eq("Blast damage is 14", fake.last_damage, 14)

	await _wait(0.5)
	_check_eq("A lone blast never hits twice", fake.hit_count, 1)
	_check("Blast node frees itself",
			not is_instance_valid(blast) or blast.is_queued_for_deletion())

	await _drop_world(world)

	# Fire spreads fire: a second ember inside the radius lights up too.
	var built3 := _make_world()
	var world3: Node2D = built3["world"]
	var fake3 = built3["player"]
	var ember_a = _spawn_slime(world3, "ember", Vector2(0, 10))
	var ember_b = _spawn_slime(world3, "ember", Vector2(30, 10))
	await _tick(2)
	ember_a.take_damage(9999)
	await _tick(2)
	await _wait(0.6)     # A fuses (0.55) and detonates
	_check("A blast ignites the ember next to it", ember_b.is_dead)
	_check_eq("The first blast already hit the player", fake3.hit_count, 1)
	await _wait(0.6)     # B's own fuse runs out
	_check_eq("The cascade hits the player a second time", fake3.hit_count, 2)
	await _drop_world(world3)

	# A player who walks out of the circle is safe.
	var built2 := _make_world()
	var world2: Node2D = built2["world"]
	var fake2 = built2["player"]
	var slime2 = _spawn_slime(world2, "ember", Vector2(0, 10))
	await _tick(2)
	slime2.take_damage(9999)
	await _tick(2)
	fake2.position = Vector2(400, 0)      # well outside the 44 px blast
	await _wait(0.8)
	_check_eq("Walking out of the blast is safe", fake2.hit_count, 0)
	await _drop_world(world2)


# ---------------------------------------------------------------------------
# 6. Basalt: contact damage on a fixed tick
# ---------------------------------------------------------------------------
func _test_basalt_contact() -> void:
	print("-- basalt contact")

	var built := _make_world()
	var world: Node2D = built["world"]
	var fake = built["player"]
	var slime = _spawn_slime(world, "basalt", Vector2(0, 12))
	await _tick(3)

	_check_eq("Basalt hurts on touch immediately", fake.hit_count, 1)
	_check_eq("Contact damage is 4", fake.last_damage, 4)

	await _wait(0.4)
	_check_eq("Contact damage does not spam", fake.hit_count, 1)

	await _wait(0.5)
	_check_eq("Second tick lands after ~0.8 s", fake.hit_count, 2)

	fake.position = Vector2(120, 0)
	await _tick(2)
	var hits_before: int = fake.hit_count
	await _wait(1.0)
	_check_eq("Spiked body is harmless from a distance",
			fake.hit_count, hits_before)
	await _drop_world(world)

	# Grass must stay passive - the whole family reads off this contrast.
	var built2 := _make_world()
	var fake2 = built2["player"]
	var grass = _spawn_slime(built2["world"], "grass", Vector2(0, 12))
	await _tick(3)
	_check_eq("Grass slime has no contact damage", grass.contact_damage, 0)
	await _wait(0.6)
	_check_eq("Standing on a grass slime is safe", fake2.hit_count, 0)
	await _drop_world(built2["world"])


# ---------------------------------------------------------------------------
# 7. Pool cap
# ---------------------------------------------------------------------------
func _test_pool_cap() -> void:
	print("-- pool cap")

	var world := Node2D.new()
	add_child(world)

	for i in 8:
		var pool = ACID_POOL_SCENE.instantiate()
		world.add_child(pool)
		pool.global_position = Vector2(i * 4, 0)

	await _tick(3)
	var live := _nodes_in("acid_pools").size()
	_check("Acid pools are capped at 6", live <= 6, "live=%d" % live)

	await _drop_world(world)


func _ready() -> void:
	_run()
