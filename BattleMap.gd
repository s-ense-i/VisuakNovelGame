extends Node2D
# Character Nodes
@onready var player1 = %Player
@onready var player2 = %Player2
@onready var player3 = %Player3

# Enemy Sprite Nodes (for visibility control)
@onready var yatufusta = $Enemy3/AnimatedSprite2D2
@onready var bird = $Enemy2/animatedsprite2d
@onready var pig = $Enemy1/animatedsprite2d

# Enemy Game Nodes (for movement control)
@onready var yatufusta_inGame = %Enemy3
@onready var bird_inGame = %Enemy2
@onready var pig_inGame = %Enemy1

# Dialogue System Nodes
@onready var character = %CharacterSprite
@onready var dialogue_ui = %DialogueUi
@onready var command_menu = $CommandMenu

# TileMap
@onready var tile_map = $TileMap

var fight_scene_path = "res://battle.tscn" # Update with actual path
var dialogue_paused_for_fight = false
var current_enemy_data: BattleEnemyData_1 = null

# Dialogue System Variables
var dialogue_index: int = 0
var DialogueLines: Array = []
var waiting_for_choice: bool = false
var visible_characters: Array[int] = []
var scene_initialized: bool = false
var dialogue_file: String = "res://project assets/Story/third_scene.json"

# Game Variables
var selected_player: CharacterBody2D = null
var current_action_complete: bool = true

# Movement tracking for move_start
var movement_queue: Array = []
var processing_movement: bool = false

func _ready():
	Fade.fade_in()
	# Initialize game characters
	initialize_characters()
	
	# Set up dialogue system
	initialize_dialogue()
	
	debug_character_positions()

	
	# Connect signals
	command_menu.move_selected.connect(_on_move_pressed)
	command_menu.end_turn_selected.connect(_on_end_turn_pressed)
	
	# Start the scene
	start_scene_sequence()

	if GameManager.has_battle_state():
		call_deferred("_on_return_from_fight")
		
	SceneManager.transition_in()	
		
func initialize_characters():
	# Hide all enemies initially
	yatufusta.visible = false
	bird.visible = false
	pig.visible = false
	
	# Set players to default state
	player1.visible = true
	player2.visible = true
	player3.visible = true

func initialize_dialogue():
	character.hide_all_characters()
	dialogue_ui.hide_speaker_box()
	dialogue_ui.hide_speaker_name()
	
	dialogue_ui.choice_selected.connect(_on_choice_selected)
	
	if FileAccess.file_exists(dialogue_file):
		DialogueLines = load_dialogue(dialogue_file)
	else:
		push_warning("Dialogue file not found: " + dialogue_file)

func start_scene_sequence():
	scene_initialized = true
	process_current_line()

func world_to_map(world_position: Vector2) -> Vector2i:
	return tile_map.local_to_map(tile_map.to_local(world_position))

func map_to_world(map_position: Vector2i) -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(map_position))

func is_walkable(tile_pos: Vector2i) -> bool:
	var data = tile_map.get_cell_tile_data(0, tile_pos)
	if not data:
		return false
	return data.get_custom_data("walkable") == true

func _on_move_pressed():
	if selected_player:
		selected_player._on_move_selected()

func _on_end_turn_pressed():
	if selected_player:
		selected_player._on_end_turn_selected()

func get_players() -> Array:
	return get_tree().get_nodes_in_group("players")

func trigger_enemy_movement():
	yatufusta_inGame.start_movement([Vector2i(47, 23)])
	bird_inGame.start_movement([Vector2i(7, 11)])
	pig_inGame.start_movement([Vector2i(11, 10)])

# Handle move_start action
func handle_move_start(line: Dictionary):
	processing_movement = true
	var move_data = line["move_start"]
	
	# Handle single character movement
	if move_data is Dictionary:
		await execute_single_movement(move_data)
	# Handle multiple character movements
	elif move_data is Array:
		await execute_multiple_movements(move_data)
	
	processing_movement = false
	dialogue_index += 1
	process_current_line()

func handle_fight_trigger(line: Dictionary):
	var enemy_name = line.get("fight", "")
	var fight_scene_path_override = line.get("fight_scene", "")
	
	# If a specific fight scene is specified, use it
	if fight_scene_path_override != "":
		fight_scene_path = fight_scene_path_override
	
	dialogue_index += 1  # Move to next line for when we return
	trigger_fight(enemy_name)
	
func execute_single_movement(move_data: Dictionary):
	var character_name = move_data.get("character", "")
	var path = move_data.get("path", [])
	var duration = move_data.get("duration", 1.0)
	var wait_for_completion = move_data.get("wait", true)
	var trigger_fight_after = move_data.get("fight_after", false)
	
	var character_node = get_map_character_node(character_name)
	if character_node and character_node.has_method("start_movement"):
		# Convert path coordinates to Vector2i
		var converted_path = []
		for pos in path:
			if pos is Array and pos.size() >= 2:
				converted_path.append(Vector2i(pos[0], pos[1]))
			elif pos is Vector2i:
				converted_path.append(pos)
		
		# Start movement
		if duration > 0:
			character_node.start_movement(converted_path, duration)
		else:
			character_node.start_movement(converted_path)
		
		# Wait for completion if needed
		if wait_for_completion:
			await character_node.movement_completed
		
		# Trigger fight after movement if specified
		if trigger_fight_after:
			trigger_fight(character_name)

func execute_multiple_movements(move_array: Array):
	var simultaneous_movements = []
	
	for move_data in move_array:
		if move_data is Dictionary:
			var character_name = move_data.get("character", "")
			var path = move_data.get("path", [])
			var duration = move_data.get("duration", 1.0)
			var delay = move_data.get("delay", 0.0)
			
			# Add delay if specified
			if delay > 0:
				await get_tree().create_timer(delay).timeout
			
			var character_node = get_map_character_node(character_name)
			if character_node and character_node.has_method("start_movement"):
				# Convert path coordinates
				var converted_path = []
				for pos in path:
					if pos is Array and pos.size() >= 2:
						converted_path.append(Vector2i(pos[0], pos[1]))
					elif pos is Vector2i:
						converted_path.append(pos)
				
				character_node.start_movement(converted_path, duration)
				simultaneous_movements.append(character_node)
				
				print("Started movement for ", character_name, " along path: ", converted_path)
	
	# Wait for all movements to complete
	for character_node in simultaneous_movements:
		if character_node.has_signal("movement_completed"):
			await character_node.movement_completed

func get_map_character_node(character_name: String) -> Node:
	"""Get the on-map character node by name - NOW USES PARENT NODES FOR MOVEMENT"""
	match character_name.to_lower():
		"yatufusta", "yatsufusa":
			return yatufusta_inGame  # Changed from yatufusta to yatufusta_inGame
		"bird", "birdenemy":
			return bird_inGame      # Changed from bird to bird_inGame
		"pig", "pigenemy":
			return pig_inGame       # Changed from pig to pig_inGame
		"player1", "protagonist":
			return player1
		"player2":
			return player2
		"player3":
			return player3
		_:
			push_warning("Unknown map character: " + character_name)
			return null

# Dialogue System Functions
func load_dialogue(file_path):
	if not FileAccess.file_exists(file_path):
		push_warning("Dialogue file not found: " + file_path)
		return []

	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	var json_content = JSON.parse_string(content)
	if json_content == null:
		push_warning("Failed to parse dialogue JSON")
		return []

	return json_content

func process_current_line():
	if not scene_initialized or dialogue_index >= DialogueLines.size():
		return

	var line = DialogueLines[dialogue_index]
	
	# Handle choices first
	if line.has("choices"):
		handle_choice_section(line)
		return
	
	if line.has("goto"):
		var anchor_pos = get_anchor_position(line["goto"])
		if anchor_pos != -1:
			dialogue_index = anchor_pos
			process_current_line()
		return
		
	if line.has("anchor"):
		dialogue_index += 1
		process_current_line()
		return
	
	if line.has("fight"):
		handle_fight_trigger(line)
		return
	
	# Handle move_start before other actions
	if line.has("move_start"):
		handle_move_start(line)
		return
	
	# Handle actions before dialogue
	if line.has("action"):
		handle_action(line)
		return
	elif line.has("move"):
		handle_move_action(line)
		return
	elif line.has("hide_character"):
		handle_hide_action(line)
		return
	
	# Handle show_only first
	if line.has("show_only"):
		var show_only_char = line["show_only"]
		var show_only_enum = Character.get_enum_from_string(show_only_char)
		if show_only_enum != -1:
			character.show_only_character(show_only_enum, line.get("animation", "idle"))
		else:
			push_warning("Unknown character in show_only: " + show_only_char)

	# Handle character display for regular dialogue lines
	if line["speaker"] == "Narration":
		if not line.has("show_only"):
			character.show_narration_mode()
		dialogue_ui.hide_speaker_box()
		dialogue_ui.hide_speaker_name()
	else:
		dialogue_ui.show_speaker_box()
		dialogue_ui.show_speaker_name()

		var character_enum = Character.get_enum_from_string(line["speaker"])

		if character_enum != -1:
			if not visible_characters.has(character_enum):
				visible_characters.append(character_enum)
				if visible_characters.size() > 2:
					visible_characters.pop_front()

			if not line.has("show_only"):
				if line.has("replace_character"):
					var replace_enum = Character.get_enum_from_string(line["replace_character"])
					if replace_enum != -1:
						character.replace_character(replace_enum, character_enum, line.get("animation", "idle"))
					else:
						character.show_speaker(character_enum, line.get("animation", "idle"))
				else:
					character.show_speaker(character_enum, line.get("animation", "idle"))
		else:
			push_warning("Unknown character name in dialogue: " + line["speaker"])

	# Display the dialogue text
	dialogue_ui.change_line(line["speaker"], line["text"])
	dialogue_index += 1

func handle_action(action_data: Dictionary):
	match action_data["action"]:
		"show_character":
			var char_name = action_data["character"]
			if char_name is String:
				show_in_game_character(char_name)
			elif char_name is Array:
				for name in char_name:
					show_in_game_character(name)
					await get_tree().create_timer(0.2).timeout  # Small delay between characters
			await get_tree().create_timer(0.3).timeout
			dialogue_index += 1
			process_current_line()
		"move_character":
			var char_name = action_data["character"]
			var path = action_data.get("path", [])
			var duration = action_data.get("duration", 1.0)
			move_in_game_character(char_name, path, duration)
			dialogue_index += 1
		"hide_character":
			var char_name = action_data["character"]
			hide_in_game_character(char_name)
			dialogue_index += 1
			process_current_line()
		_:
			push_warning("Unknown action: " + action_data["action"])
			dialogue_index += 1
			process_current_line()

func handle_move_action(line: Dictionary):
	var char_name = line["move"]
	if char_name is String:
		move_in_game_character(char_name)
	elif char_name is Array:
		for name in char_name:
			move_in_game_character(name)
	dialogue_index += 1
	process_current_line()

func handle_hide_action(line: Dictionary):
	var char_name = line["hide_character"]
	hide_in_game_character(char_name)
	dialogue_index += 1
	process_current_line()

func show_in_game_character(char_name: String):
	match char_name:
		"yatufusta":
			yatufusta.visible = true
			yatufusta.play("spawn")
		"Bird", "BirdEnemy", "bird":
			bird.visible = true
			if bird.sprite_frames.has_animation("spawn"):
				bird.play("spawn")
			else:
				bird.play("idle")
		"Pig", "PigEnemy", "pig":
			pig.visible = true
			if pig.sprite_frames.has_animation("spawn"):
				pig.play("spawn")
			else:
				pig.play("idle")
		_:
			push_warning("Unknown in-game character: " + char_name)

func move_in_game_character(char_name: String, path: Array = [], duration: float = 1.0):
	# Use the parent nodes for movement instead of sprite nodes
	var character_node = get_map_character_node(char_name)
	if character_node and character_node.has_method("start_movement"):
		if path.is_empty():
			# Default movement paths if none specified
			match char_name:
				"yatufusta":
					path = [Vector2i(47,23), Vector2i(45,22), Vector2i(43,21)]
				"Bird", "BirdEnemy":
					path = [Vector2i(7,11), Vector2i(8,10), Vector2i(9,9)]
				"Pig", "PigEnemy":
					path = [Vector2i(11,10), Vector2i(12,9), Vector2i(13,8)]
		
		character_node.start_movement(path, duration)
		await character_node.movement_completed
	else:
		push_warning("Character " + char_name + " can't move or doesn't exist")

func hide_in_game_character(char_name: String):
	match char_name:
		"yatufusta":
			yatufusta.visible = false
		"Bird", "BirdEnemy":
			bird.visible = false
		"Pig", "PigEnemy":
			pig.visible = false
		_:
			push_warning("Unknown in-game character: " + char_name)

func get_in_game_character(char_name: String) -> Node:
	# Return the parent game nodes for movement, not the sprite nodes
	match char_name:
		"yatufusta":
			return yatufusta_inGame
		"Bird", "BirdEnemy":
			return bird_inGame
		"Pig", "PigEnemy":
			return pig_inGame
		_:
			return null

func get_anchor_position(anchor: String) -> int:
	for i in range(DialogueLines.size()):
		if DialogueLines[i].has("anchor") and DialogueLines[i]["anchor"] == anchor:
			return i
	return -1

func _input(event):
	if not scene_initialized or waiting_for_choice or processing_movement:
		return

	if event.is_action_pressed("next_line"):
		if dialogue_ui.animate_text:
			dialogue_ui.skip_animation_text()
		elif dialogue_index < len(DialogueLines) - 1:
			process_current_line()
		else:
			end_dialogue_sequence()

func end_dialogue_sequence():
	print("Dialogue sequence ended")
	dialogue_ui.hide_speaker_box()
	dialogue_ui.hide_speaker_name()
	character.hide_all_characters()
	# Transition to battle gameplay
	command_menu.visible = true
	
func handle_choice_section(line: Dictionary):
	waiting_for_choice = true
	
	# Handle character replacement for choice prompt
	if line.has("replace_character") and line.has("new_character"):
		var character_to_replace_enum = Character.get_enum_from_string(line["replace_character"])
		var new_character_enum = Character.get_enum_from_string(line["new_character"])
		
		if character_to_replace_enum != -1 and new_character_enum != -1:
			character.replace_character(
				character_to_replace_enum, 
				new_character_enum, 
				line.get("animation", "idle")
			)
	# Fallback to show_only if specified
	elif line.has("replace_character") and line.has("show_only"):
		var character_to_replace_enum = Character.get_enum_from_string(line["replace_character"])
		var new_character_enum = Character.get_enum_from_string(line["show_only"])
		
		if character_to_replace_enum != -1 and new_character_enum != -1:
			character.replace_character(
				character_to_replace_enum, 
				new_character_enum, 
				line.get("animation", "idle")
			)
	
	# Show the choices
	dialogue_ui.display_choices(line["choices"])

func _on_choice_selected(anchor: String):
	waiting_for_choice = false
	var anchor_pos = get_anchor_position(anchor)
	if anchor_pos != -1:
		dialogue_index = anchor_pos
		process_current_line()
	else:
		printerr("Failed to find anchor: " + anchor)

func debug_character_positions():
	print("=== CHARACTER POSITIONS ===")
	
	# Yatufusta
	var yatu_world_pos = yatufusta_inGame.global_position
	var yatu_tile_pos = world_to_map(yatu_world_pos)
	print("Yatufusta - World: ", yatu_world_pos, " Tile: ", yatu_tile_pos)
	
	# Bird
	var bird_world_pos = bird_inGame.global_position
	var bird_tile_pos = world_to_map(bird_world_pos)
	print("Bird - World: ", bird_world_pos, " Tile: ", bird_tile_pos)
	
	# Pig
	var pig_world_pos = pig_inGame.global_position
	var pig_tile_pos = world_to_map(pig_world_pos)
	print("Pig - World: ", pig_world_pos, " Tile: ", pig_tile_pos)

func trigger_fight(enemy_name: String):
	print("Triggering fight with: ", enemy_name)
	dialogue_paused_for_fight = true
	
	# Set the enemy data based on the enemy name
	current_enemy_data = get_enemy_data(enemy_name)
	
	if current_enemy_data:
		call_fight_scene()
	else:
		push_warning("No enemy data found for: " + enemy_name)
		resume_dialogue()

# 6. Add support for multiple fight scenes
var fight_scenes = {
	"default":"res://battle_2.tscn" ,
	"yatufusta": "res://battle_2.tscn",
	"bird": "res://battle_bird.tscn",  # If you have different fight scenes
	"pig": "res://battle_pig.tscn"
}

func get_fight_scene_path(enemy_name: String) -> String:
	return fight_scenes.get(enemy_name.to_lower(), fight_scenes["default"])
	
func get_enemy_data(enemy_name: String) -> BattleEnemyData_1:
	var enemy_data = BattleEnemyData_1.new()
	
	match enemy_name.to_lower():
		"yatufusta", "yatsufusa":
			enemy_data.enemy_name = "Yatufusta"
			enemy_data.health = 30
			enemy_data.damage = 15
		"bird", "birdenemy":
			enemy_data.enemy_name = "Bird"
			enemy_data.health = 30
			enemy_data.damage = 15
		"pig", "pigenemy":
			enemy_data.enemy_name = "Pig"
			enemy_data.health = 30
			enemy_data.damage = 15
		_:
			push_warning("Unknown enemy: " + enemy_name)
			return null
	
	return enemy_data

# FIXED: Proper scene switching that only shows the fight scene
func call_fight_scene():
	print("Attempting to load fight scene from: ", fight_scene_path)
	
	# Check if file exists
	if not FileAccess.file_exists(fight_scene_path):
		push_error("Fight scene file does not exist: " + fight_scene_path)
		resume_dialogue()
		return
	
	# Store current character visibility states
	store_character_visibility_states()
	
	# Store current dialogue state in a singleton/autoload
	# You'll need to create a GameManager autoload for this
	GameManager.store_battle_state({
		"dialogue_index": dialogue_index,
		"scene_path": scene_file_path,  # Store current scene path
		"dialogue_lines": DialogueLines,
		"enemy_data": current_enemy_data
	})
	
	# Load and switch to fight scene using Godot's proper method
	var fight_scene_resource = load(fight_scene_path)
	if not fight_scene_resource:
		push_error("Failed to load fight scene resource: " + fight_scene_path)
		resume_dialogue()
		return
	
	# Use get_tree().change_scene_to_packed() - the proper way
	var result = get_tree().change_scene_to_packed(fight_scene_resource)
	if result != OK:
		push_error("Failed to change scene: " + str(result))
		resume_dialogue()
		return
	
	print("Fight scene loaded successfully")
	
# FIXED: Proper scene return handling
func _on_fight_ended():
	print("Fight ended, returning to battle scene")
	
	# Remove the fight scene
	var fight_scene = get_tree().current_scene
	fight_scene.queue_free()
	
	# Reload the current battle scene
	var battle_scene_path = get_script().get_path().get_base_dir() + ".tscn"
	
	# If we can't determine the path, use a stored reference
	# For now, let's assume the scene file name matches the script location
	var scene_path = "res://battle_2.tscn"  # Update this to match your actual scene file
	
	if FileAccess.file_exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("Could not find battle scene file: " + scene_path)
		# Fallback - create a new instance of this scene
		var new_scene = preload("res://battle_2.tscn").instantiate()  # Update path
		get_tree().current_scene = new_scene
		get_tree().root.add_child(new_scene)
	
	# The scene will be reloaded, so we need to handle state restoration
	# You may want to use an autoload singleton to preserve dialogue state

func resume_dialogue():
	dialogue_paused_for_fight = false
	current_enemy_data = null
	
	# Continue dialogue from current position
	process_current_line()
func _on_return_from_fight():
	print("Returned from fight, resuming dialogue")
	
	# Get stored state from GameManager
	var stored_state = GameManager.get_battle_state()
	if stored_state:
		dialogue_index = stored_state.get("dialogue_index", 0)
		DialogueLines = stored_state.get("dialogue_lines", [])
		current_enemy_data = stored_state.get("enemy_data", null)
		
		# FIXED: Restore character visibility states BEFORE clearing battle state
		restore_character_visibility_states()
		
		# Clear stored state
		GameManager.clear_battle_state()
	
	# Resume dialogue
	resume_dialogue()
	
func store_character_visibility_states():
	var visibility_states = {
		"yatufusta": yatufusta.visible,
		"bird": bird.visible,
		"pig": pig.visible,
		"player1": player1.visible,
		"player2": player2.visible,
		"player3": player3.visible
	}
	GameManager.store_character_visibility(visibility_states)

func restore_character_visibility_states():
	var visibility_states = GameManager.get_character_visibility()
	if visibility_states.is_empty():
		print("No character visibility states to restore")
		return
	
	print("Restoring character visibility states: ", visibility_states)
	
	# Restore enemy visibility
	if visibility_states.has("yatufusta"):
		yatufusta.visible = visibility_states["yatufusta"]
		if yatufusta.visible:
			# Play idle animation instead of spawn since they're already spawned
			if yatufusta.sprite_frames.has_animation("idle"):
				yatufusta.play("idle")
			else:
				yatufusta.play("default")  # Fallback to default animation
			print("Restored yatufusta visibility: ", yatufusta.visible)
	
	if visibility_states.has("bird"):
		bird.visible = visibility_states["bird"]
		if bird.visible:
			# Play idle animation instead of spawn
			if bird.sprite_frames.has_animation("idle"):
				bird.play("idle")
			else:
				bird.play("default")  # Fallback to default animation
			print("Restored bird visibility: ", bird.visible)
	
	if visibility_states.has("pig"):
		pig.visible = visibility_states["pig"]
		if pig.visible:
			# Play idle animation instead of spawn
			if pig.sprite_frames.has_animation("idle"):
				pig.play("idle")
			else:
				pig.play("default")  # Fallback to default animation
			print("Restored pig visibility: ", pig.visible)
	
	# Restore player visibility (usually always visible, but just in case)
	if visibility_states.has("player1"):
		player1.visible = visibility_states["player1"]
	if visibility_states.has("player2"):
		player2.visible = visibility_states["player2"]
	if visibility_states.has("player3"):
		player3.visible = visibility_states["player3"]
