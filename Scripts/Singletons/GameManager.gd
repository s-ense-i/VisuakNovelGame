# GameManager.gd
extends Node

var battle_state: Dictionary = {}

func store_battle_state(state: Dictionary):
	
	battle_state = state.duplicate(true)

func get_battle_state() -> Dictionary:
	return battle_state.duplicate(true)

func clear_battle_state():
	battle_state.clear()

func has_battle_state() -> bool:
	return not battle_state.is_empty()

func store_character_visibility(character_states: Dictionary):
	if not battle_state.has("character_visibility"):
		battle_state["character_visibility"] = {}
	battle_state["character_visibility"] = character_states
	print("Character visibility stored: ", character_states)

func get_character_visibility() -> Dictionary:
	return battle_state.get("character_visibility", {})
	
func store_enemy_states():
	var enemy_data = {}
	for enemy_name in EnemyManager.enemy_states.keys():
		var enemy = EnemyManager.enemy_states[enemy_name]
		enemy_data[enemy_name] = {
			"current_health": enemy.current_health,
			"max_health": enemy.max_health,
			"damage": enemy.damage,
			"is_defeated": enemy.is_defeated
		}
	battle_state["enemy_states"] = enemy_data
	print("Enemy states stored")

func restore_enemy_states():
	if battle_state.has("enemy_states"):
		var enemy_data = battle_state["enemy_states"]
		for enemy_name in enemy_data.keys():
			var data = enemy_data[enemy_name]
			var enemy = EnemyManager.get_enemy_data(enemy_name)
			if enemy:
				enemy.current_health = data.get("current_health", enemy.max_health)
				enemy.is_defeated = data.get("is_defeated", false)
		print("Enemy states restored")
		
