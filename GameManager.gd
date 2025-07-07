# GameManager.gd - Create this as an autoload
extends Node

var stored_battle_state: Dictionary = {}

func store_battle_state(state: Dictionary):
	stored_battle_state = state
	print("Battle state stored: ", state.keys())

func get_battle_state() -> Dictionary:
	return stored_battle_state

func clear_battle_state():
	stored_battle_state.clear()
	print("Battle state cleared")

func has_battle_state() -> bool:
	return not stored_battle_state.is_empty()

# Add functions to store/restore character visibility
func store_character_visibility(character_states: Dictionary):
	if not stored_battle_state.has("character_visibility"):
		stored_battle_state["character_visibility"] = {}
	stored_battle_state["character_visibility"] = character_states
	print("Character visibility stored: ", character_states)

func get_character_visibility() -> Dictionary:
	return stored_battle_state.get("character_visibility", {})
