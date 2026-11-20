extends Node2D
## Fake player for headless boss tests: records every hit.
##
## Plain Node2D stands in for everything except damage - this tiny
## script adds a take_damage() that MATCHES the real player's signature
## (amount, from_position) so enemy attacks can call it, but instead of
## subtracting from a health bar it just counts.

var hit_count: int = 0
var last_damage: int = 0
var last_from: Vector2 = Vector2.ZERO


func take_damage(amount: int, from_position: Vector2 = Vector2.ZERO) -> void:
	hit_count += 1
	last_damage = amount
	last_from = from_position
