extends Node2D
## Level root for the arena.
##
## Its ONLY job is wiring: it listens to signals broadcast by the player
## and the enemies and shows them on screen. It never touches health,
## hitboxes or AI - that is the whole point of the signal-based design.
##
##   Player.attack_hit(enemy)     -> floating "-10" + "damage dealt" label
##   Slime.died                   -> kill counter
##   Slime.health_changed(hp,max) -> (nothing yet - a good place for a
##                                   target health bar in a later phase)
##
## Because the level connects these signals, deleting the HUD cannot
## break combat, and adding a combo counter does not touch player.gd.


# =====================================================================
# NODE REFERENCES
# =====================================================================

@onready var player: Node2D = $Player
@onready var enemies_root: Node2D = $Enemies
@onready var stats_label: Label = $UI/Stats


# =====================================================================
# STATE (shown in the debug label)
# =====================================================================

var total_damage_dealt: int = 0
var last_hit_damage: int = 0
var kills: int = 0


# =====================================================================
# SETUP
# =====================================================================

func _ready() -> void:
	# `connect` only stores a reference to the callable; nothing happens
	# until the signal is emitted. If the signal already exists (it is
	# declared with `signal attack_hit(enemy)` in player.gd), passing a
	# Callable with the wrong number of arguments is an error, so the
	# signatures must match.
	player.attack_hit.connect(_on_player_attack_hit)

	for enemy in enemies_root.get_children():
		_watch_enemy(enemy)

	_update_stats_label()


## Called for enemies that appear later (spawners, waves, ...).
func _watch_enemy(enemy: Node) -> void:
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)


# =====================================================================
# SIGNAL HANDLERS
# =====================================================================

func _on_player_attack_hit(enemy: Node) -> void:
	# The player already applied the damage; we just present it.
	last_hit_damage = player.attack_damage
	total_damage_dealt += last_hit_damage

	_spawn_damage_number(enemy.global_position, last_hit_damage)
	_update_stats_label()


func _on_enemy_died() -> void:
	kills += 1
	_update_stats_label()


func _update_stats_label() -> void:
	if stats_label == null:
		return
	stats_label.text = "damage dealt: %d   last hit: %d   kills: %d / %d" % [
		total_damage_dealt,
		last_hit_damage,
		kills,
		enemies_root.get_child_count(),
	]


# =====================================================================
# FLOATING DAMAGE NUMBERS
# =====================================================================

## A Label that pops out of the enemy, drifts up and fades, then frees
## itself - the classic "-10" you see in every action game.
## Created in code (no extra scene file) to keep this example compact.
func _spawn_damage_number(at: Vector2, amount: int) -> void:
	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
	label.add_theme_font_size_override("font_size", 10)
	# Centre the text so it appears to grow out of the enemy's head.
	label.position = at + Vector2(-8, -22)
	# Labels inside a Node2D world need to be behind the UI canvas;
	# adding it to the level root puts it in world space.
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 14.0, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)
