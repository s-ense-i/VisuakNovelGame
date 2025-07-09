# BattleEnemyData_1.gd
class_name BattleEnemyData_1
extends Node

@export var enemy_name: String = ""
@export var max_health: int = 50
@export var current_health: int = 50
@export var damage: int = 20
@export var is_defeated: bool = false

func _init():
	# Initialize current health to max health if not already set
	current_health = max_health

func take_damage(amount: int):
	current_health = max(0, current_health - amount)
	if current_health <= 0:
		is_defeated = true
	# Update EnemyManager with new health
	EnemyManager.update_enemy_health(enemy_name, current_health)

func heal(amount: int):
	current_health = min(max_health, current_health + amount)
	EnemyManager.update_enemy_health(enemy_name, current_health)

func reset_health():
	current_health = max_health
	is_defeated = false
	EnemyManager.update_enemy_health(enemy_name, current_health)

func get_health_percentage() -> float:
	if max_health == 0:
		return 0.0
	return float(current_health) / float(max_health)
