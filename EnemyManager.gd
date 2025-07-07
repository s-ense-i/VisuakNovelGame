# EnemyManager.gd
extends Node

var enemy_states: Dictionary = {}

func _ready():
	# Initialize enemy states on first run
	initialize_enemy_states()

func initialize_enemy_states():
	if enemy_states.is_empty():
		# Create persistent enemy data
		var yatufusta_data = BattleEnemyData_1.new()
		yatufusta_data.enemy_name = "Yatufusta"
		yatufusta_data.max_health = 24
		yatufusta_data.current_health = 24
		yatufusta_data.damage = 15
		enemy_states["yatufusta"] = yatufusta_data
		
		var bird_data = BattleEnemyData_1.new()
		bird_data.enemy_name = "Bird"
		bird_data.max_health = 22
		bird_data.current_health = 22
		bird_data.damage = 10
		enemy_states["bird"] = bird_data
		
		var pig_data = BattleEnemyData_1.new()
		pig_data.enemy_name = "Pig"
		pig_data.max_health = 55
		pig_data.current_health = 55
		pig_data.damage = 10
		enemy_states["pig"] = pig_data
		
		print("Enemy states initialized")

func get_enemy_data(enemy_name: String) -> BattleEnemyData_1:
	var key = enemy_name.to_lower()
	if enemy_states.has(key):
		return enemy_states[key]
	else:
		push_warning("Enemy not found: " + enemy_name)
		return null

func update_enemy_health(enemy_name: String, new_health: int):
	var key = enemy_name.to_lower()
	if enemy_states.has(key):
		enemy_states[key].current_health = max(0, new_health)
		if enemy_states[key].current_health <= 0:
			enemy_states[key].is_defeated = true
		print("Updated ", enemy_name, " health to: ", new_health)

func is_enemy_defeated(enemy_name: String) -> bool:
	var key = enemy_name.to_lower()
	if enemy_states.has(key):
		return enemy_states[key].is_defeated
	return false

func reset_enemy_health(enemy_name: String):
	var key = enemy_name.to_lower()
	if enemy_states.has(key):
		enemy_states[key].reset_health()

func reset_all_enemies():
	for enemy_data in enemy_states.values():
		enemy_data.reset_health()
