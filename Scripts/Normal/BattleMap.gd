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
@onready var move_overlay = $MoveOverlay




var fight_scene_path = "res://battle.tscn" # Update with actual path
var dialogue_paused_for_fight = false
var current_enemy_data: BattleEnemyData_1 = null


var current_player_controlled: String = ""
var movement_grid_visible: bool = false
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
var processing_animation: bool = false
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
	command_menu.move_selected.connect(_on_move_selected) # Change this line
	command_menu.attack_selected.connect(_on_attack_selected)
	command_menu.end_turn_selected.connect(_on_end_turn_pressed)
	
	# Start the scene
	start_scene_sequence()

	if GameManager.has_battle_state():
		call_deferred("_on_return_from_fight")
		
	SceneManager.transition_in()	
	
func _on_move_selected(player_name: String):
	print("Move selected for player: ", player_name)
	var player = get_player_node(player_name)
	if not player:
		print("Player not found: ", player_name)
		return
	
	# Store the current player for later use
	current_player_controlled = player_name
	
	# Clear any existing movement grid
	if move_overlay:
		move_overlay.hide_movement_grid()
	
	# Calculate walkable cells for the player
	var player_world_pos = player.global_position
	var player_cell = move_overlay.local_to_map(move_overlay.to_local(player_world_pos))
	
	print("Player world position: ", player_world_pos)
	print("Player cell: ", player_cell)
	
	# Calculate movement range
	var movement_range = 3  # Default movement range
	if player.has_method("get_move_range"):
		movement_range = player.get_move_range()
	elif "move_range" in player:
		movement_range = player.move_range
	
	print("Movement range: ", movement_range)
	
	# Get all cells in the movement range
	var walkable_cells = []
	for x in range(player_cell.x - movement_range, player_cell.x + movement_range + 1):
		for y in range(player_cell.y - movement_range, player_cell.y + movement_range + 1):
			var cell = Vector2i(x, y)
			var distance = abs(x - player_cell.x) + abs(y - player_cell.y)
			
			# Only include cells within the movement range
			if distance <= movement_range and distance > 0:  # Don't include current position
				if is_walkable(cell):
					walkable_cells.append(cell)
	
	print("Found ", walkable_cells.size(), " walkable cells")
	
	# Show movement grid using move_overlay
	if move_overlay and walkable_cells.size() > 0:
		# Connect to tile click signal BEFORE showing the grid
		if not move_overlay.tile_clicked.is_connected(_on_movement_tile_clicked):
			move_overlay.tile_clicked.connect(_on_movement_tile_clicked)
		
		# Show the movement grid
		move_overlay.show_movement_grid(walkable_cells, player)
		
		print("Movement grid shown with ", walkable_cells.size(), " cells")
	else:
		print("No walkable cells found or move_overlay not available")
		
func _on_movement_tile_clicked(tile_pos: Vector2i, player: Node):
	print("Tile clicked: ", tile_pos)
	
	# Convert tile position to world position
	var target_world_pos = move_overlay.to_global(move_overlay.map_to_local(tile_pos))
	
	# Move the player smoothly
	var tween = create_tween()
	tween.tween_property(player, "global_position", target_world_pos, 0.5)
	
	# Wait for movement to complete
	await tween.finished
	
	# Hide movement grid
	if move_overlay:
		move_overlay.hide_movement_grid()
	
	# Disconnect the signal to prevent multiple connections
	if move_overlay.tile_clicked.is_connected(_on_movement_tile_clicked):
		move_overlay.tile_clicked.disconnect(_on_movement_tile_clicked)
	
	# Update player's current tile
	if player.has_method("set_current_tile"):
		player.set_current_tile(tile_pos)
	elif "current_tile" in player:
		player.current_tile = tile_pos
	
	print("Player moved to: ", tile_pos)
					
func initialize_characters():
	# Hide all enemies initially
	yatufusta.visible = false
	bird.visible = false
	pig.visible = false
	
	# Set players to default state
	player1.visible = true
	player2.visible = true
	player3.visible = true

func show_for_player(player_name: String):
	# Position the menu near the appropriate player
	var player_pos = get_player_position(player_name)
	self.position = player_pos + Vector2(50, -100)
	self.show()

func get_player_position(player_name: String) -> Vector2:
	match player_name:
		"protagonist":
			return player1.global_position  # player1 from battle scene
		"player2":
			return player2.global_position  # player2 from battle scene
		"player3":
			return player3.global_position  # player3 from battle scene
		_:
			return Vector2.ZERO	
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
	return move_overlay.local_to_map(move_overlay.to_local(world_position))

func map_to_world(map_position: Vector2i) -> Vector2:
	return move_overlay.to_global(move_overlay.map_to_local(map_position))

func is_walkable(tile_pos: Vector2i) -> bool:
	# Get the tile map reference
	var tile_map = $TileMap # or however you reference your main tilemap
	
	# Check if the tile exists
	var source_id = tile_map.get_cell_source_id(0, tile_pos)
	if source_id == -1:
		return false
	
	# Get tile data
	var data = tile_map.get_cell_tile_data(0, tile_pos)
	if not data:
		return false
	
	# Check if tile is walkable
	var is_walkable_tile = data.get_custom_data("walkable") == true
	if not is_walkable_tile:
		return false
	
	# Check if any player is on this tile
	for player in get_tree().get_nodes_in_group("players"):
		if player.has_method("get_current_tile"):
			if player.get_current_tile() == tile_pos:
				return false
		elif "current_tile" in player:
			if player.current_tile == tile_pos:
				return false
	
	return true

func get_player_node(player_name: String) -> Node:
	match player_name:
		"protagonist":
			return player1
		"player2":
			return player2
		"player3":
			return player3
		_:
			push_warning("Unknown player name: " + player_name)
			return null
			
# In battle_scene.gd:

func _on_move_pressed(player_name: String):
	var player = get_player_node(player_name)
	if player:
		# Clear any existing movement grid
		move_overlay.clear_layer(move_overlay.MOVEMENT_GRID_LAYER)
		
		# Calculate walkable cells
		var walkable_cells = []
		var player_cell = move_overlay.local_to_map(player.position)
		
		for x in range(player_cell.x - player.move_range, player_cell.x + player.move_range + 1):
			for y in range(player_cell.y - player.move_range, player_cell.y + player.move_range + 1):
				var cell = Vector2i(x, y)
				if player.is_walkable(cell):
					walkable_cells.append(cell)
		
		# Show movement grid
		move_overlay.show_movement_grid(walkable_cells)
		
		# Connect click handler
		move_overlay.tile_clicked.connect(player.handle_movement_click)

func _on_tile_clicked(tile_pos: Vector2i):
	# This will now be handled by each player individually
	pass

	
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

func slide_ui_out():
	# Slide down dialogue UI
	var tween = create_tween()
	tween.tween_property(dialogue_ui, "position:y", dialogue_ui.position.y + 200, 0.3)
	await tween.finished
	dialogue_ui.hide()

func slide_characters_out():
	# Get all character nodes from the CharacterSprite scene
	var characters = [
		character.protoganist,  # Note: Using the reference from CharacterSprite
		character.kami,
		character.fujiwara,
		character.Yatufusta,
		character.PigEnemy,
		character.BirdEnemy
	]
	
	var tweens = []
	for char_node in characters:
		if char_node.visible:
			var tween = create_tween()
			var viewport_center = get_viewport().size.x / 2
			var slide_right = char_node.global_position.x > viewport_center
			var slide_distance = 300 * (1 if slide_right else -1)
			
			tweens.append(tween)
			tween.tween_property(char_node, "position:x", 
				char_node.position.x + slide_distance, 
				0.3)
	
	# Wait for all character slides to complete
	for t in tweens:
		await t.finished
	
	# Hide all characters through the CharacterSprite controller
	character.hide_all_characters(false)
	
func process_current_line():
	set_input_blocked(true)
	dialogue_ui.DialogueLines.text = ""
	dialogue_ui.SpeakerName.text = ""
	
	dialogue_ui.hide_speaker_box()
	dialogue_ui.hide_speaker_name()
	
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
	
	if line.has("fade_out_enemy"):
		handle_fade_out_enemy(line)
		return
	# Handle actions before dialogue
	if line.has("PlayerMovement"):
		current_player_controlled = line["PlayerMovement"]
		
		# Slide out UI and characters
		await slide_ui_out()
		await slide_characters_out()
		
		# Show command menu for specified player
		command_menu.show_for_player(current_player_controlled)
		return
		
	
	
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
	set_input_blocked(false)
# Add this to your battle scene script

# Add fade-out handling in your process_current_line() function
# Insert this after the existing action handlers, around line 250


# Add this new function to handle fade-out
func handle_fade_out_enemy(line: Dictionary):
	var enemy_name = line["fade_out_enemy"]
	var duration = line.get("duration", 1.0)  # Default 1 second fade
	var wait_for_completion = line.get("wait", true)  # Wait for fade to complete
	
	if enemy_name is String:
		if wait_for_completion:
			await fade_out_enemy_character(enemy_name, duration)
		else:
			# Call without await but still need to handle the coroutine
			fade_out_enemy_character(enemy_name, duration)
	elif enemy_name is Array:
		# Handle multiple enemies fading out
		if wait_for_completion:
			# Wait for all fade-outs to complete sequentially
			for name in enemy_name:
				await fade_out_enemy_character(name, duration)
		else:
			# Start all fade-outs without waiting
			for name in enemy_name:
				fade_out_enemy_character(name, duration)
	
	dialogue_index += 1
	process_current_line()
	
func fade_out_enemy_character(enemy_name: String, duration: float = 1.0):
	var enemy_sprite = get_enemy_sprite_node(enemy_name)
	if not enemy_sprite:
		push_warning("Enemy sprite not found for fade-out: " + enemy_name)
		return
	
	print("Fading out enemy: ", enemy_name, " over ", duration, " seconds")
	
	# Create tween for smooth fade
	var tween = create_tween()
	tween.tween_property(enemy_sprite, "modulate:a", 0.0, duration)
	
	# Wait for tween to complete
	await tween.finished
	
	# Hide the enemy after fade completes
	enemy_sprite.visible = false
	
	# Reset alpha for future use
	enemy_sprite.modulate.a = 1.0
	
	print("Fade-out complete for: ", enemy_name)
	
func get_enemy_sprite_node(enemy_name: String) -> AnimatedSprite2D:
	match enemy_name.to_lower():
		"yatufusta", "yatsufusa":
			return yatufusta
		"bird", "birdenemy":
			return bird
		"pig", "pigenemy":
			return pig
		_:
			push_warning("Unknown enemy sprite: " + enemy_name)
			return null

# Optional: Add a fade-in function if you want to bring enemies back
func fade_in_enemy_character(enemy_name: String, duration: float = 1.0):
	var enemy_sprite = get_enemy_sprite_node(enemy_name)
	if not enemy_sprite:
		push_warning("Enemy sprite not found for fade-in: " + enemy_name)
		return
	
	print("Fading in enemy: ", enemy_name, " over ", duration, " seconds")
	
	# Make visible and start from transparent
	enemy_sprite.visible = true
	enemy_sprite.modulate.a = 0.0
	
	# Create tween for smooth fade
	var tween = create_tween()
	tween.tween_property(enemy_sprite, "modulate:a", 1.0, duration)
	
	# Wait for tween to complete
	await tween.finished
	
	print("Fade-in complete for: ", enemy_name)		

func show_command_menu(player_name: String):
	# Get the player's position from the battle scene
	var player_pos = get_player_position(player_name)
	
	# Position the command menu relative to the player
	command_menu.position = player_pos + Vector2(50, -100)
	
	# Call the menu's show function
	command_menu.show_for_player(player_name)
		
func handle_action(action_data: Dictionary):
	processing_animation = true
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
	processing_animation = false
func handle_move_action(line: Dictionary):
	processing_animation = true
	var char_name = line["move"]
	if char_name is String:
		move_in_game_character(char_name)
	elif char_name is Array:
		for name in char_name:
			move_in_game_character(name)
	dialogue_index += 1
	process_current_line()
	processing_animation = false
func handle_hide_action(line: Dictionary):
	var char_name = line["hide_character"]
	hide_in_game_character(char_name)
	dialogue_index += 1
	process_current_line()

func show_in_game_character(char_name: String):
	set_input_blocked(true)
	match char_name:
		"yatufusta":
			yatufusta.visible = true
			yatufusta.play("spawn")
			await yatufusta.animation_finished
		"Bird", "BirdEnemy", "bird":
			bird.visible = true
			if bird.sprite_frames.has_animation("spawn"):
				bird.play("spawn")
				await bird.animation_finished
			else:
				bird.play("idle")
		"Pig", "PigEnemy", "pig":
			pig.visible = true
			if pig.sprite_frames.has_animation("spawn"):
				pig.play("spawn")
				await pig.animation_finished
			else:
				pig.play("idle")
		_:
			push_warning("Unknown in-game character: " + char_name)
	set_input_blocked(false)	

func move_in_game_character(char_name: String, path: Array = [], duration: float = 1.0):
	set_input_blocked(true)
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
	set_input_blocked(false)
	
func set_input_blocked(blocked: bool) -> void:
	processing_animation = blocked
	if blocked:
		dialogue_ui.hide_speaker_box()
		dialogue_ui.hide_speaker_name()	
		
func hide_in_game_character(char_name: String):
	set_input_blocked(true)
	match char_name:
		"yatufusta":
			yatufusta.visible = false
		"Bird", "BirdEnemy":
			bird.visible = false
		"Pig", "PigEnemy":
			pig.visible = false
		_:
			push_warning("Unknown in-game character: " + char_name)
	set_input_blocked(false)		

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
	if not scene_initialized or waiting_for_choice or processing_movement or processing_animation:
		return

	if event.is_action_pressed("next_line"):
		if dialogue_ui.animate_text:
			dialogue_ui.skip_animation_text()
		elif dialogue_index < len(DialogueLines) - 1:
			set_input_blocked(true)  # Block input
			await process_current_line()
			set_input_blocked(false)  # Unblock
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
	
	# Get enemy data
	var enemy_data = EnemyManager.get_enemy_data(enemy_name)
	if enemy_data:
		if enemy_data.is_defeated:
			enemy_data.reset_health()
		current_enemy_data = enemy_data
	
	# Check if current dialogue line specifies a fight scene
	if dialogue_index > 0 && dialogue_index <= DialogueLines.size():
		var current_line = DialogueLines[dialogue_index - 1]
		if current_line.has("fight_scene"):
			fight_scene_path = current_line["fight_scene"]
		else:
			# Fallback to default path
			fight_scene_path = "res://Scenes/Fights/battle_2.tscn"  # Your default scene
	
	call_fight_scene()
	
	
	
func get_enemy_data(enemy_name: String) -> BattleEnemyData_1:
	var enemy_data = BattleEnemyData_1.new()
	
	match enemy_name.to_lower():
		"yatufusta", "yatsufusa":
			enemy_data.enemy_name = "Yatufusta"
			enemy_data.health = 24
			enemy_data.damage = 15
		"bird", "birdenemy":
			enemy_data.enemy_name = "Bird"
			enemy_data.health = 22
			enemy_data.damage = 10
		"pig", "pigenemy":
			enemy_data.enemy_name = "Pig"
			enemy_data.health = 55
			enemy_data.damage = 10
		_:
			push_warning("Unknown enemy: " + enemy_name)
			return null
	
	return enemy_data

func _on_player_movement_completed():
	movement_grid_visible = false
	move_overlay.hide_movement_grid()
	command_menu.show_for_player(current_player_controlled)
# FIXED: Proper scene switching that only shows the fight scene
func call_fight_scene():
	
	set_input_blocked(true)
	dialogue_ui.hide_all_ui()
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
	
	dialogue_ui.DialogueLines.text = ""
	dialogue_ui.SpeakerName.text = ""
	await get_tree().process_frame
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
	var scene_path = "res://Scenes/Fights/battle_2.tscn"  # Update this to match your actual scene file
	
	if FileAccess.file_exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("Could not find battle scene file: " + scene_path)
		# Fallback - create a new instance of this scene
		var new_scene = preload("res://Scenes/Fights/battle_2.tscn").instantiate()  # Update path
		get_tree().current_scene = new_scene
		get_tree().root.add_child(new_scene)
	
	# The scene will be reloaded, so we need to handle state restoration
	# You may want to use an autoload singleton to preserve dialogue state
func _on_attack_selected(player_name: String):
	print("Attack selected for player: ", player_name)
	
	# Check if current dialogue line has a fight scene specified
	if dialogue_index > 0 && dialogue_index <= DialogueLines.size():
		var current_line = DialogueLines[dialogue_index - 1]  # Get the line that opened the menu
		if current_line.has("fight_scene"):
			fight_scene_path = current_line["fight_scene"]
			print("Using specified fight scene: ", fight_scene_path)
	
	# Trigger the fight with the current enemy (you may need to adjust this)
	trigger_fight("")  # Pass empty string or get enemy from current line
	
func resume_dialogue():
	dialogue_paused_for_fight = false
	current_enemy_data = null
	
	# Continue dialogue from current position
	process_current_line()
func _on_return_from_fight():
	# Immediately block inputs and hide UI during transition
	set_input_blocked(true)
	dialogue_ui.hide_all_ui()
	
	# Get stored state
	var stored_state = GameManager.get_battle_state()
	if stored_state:
		# Clear the dialogue UI completely before loading new state
		dialogue_ui.DialogueLines.text = ""
		dialogue_ui.SpeakerName.text = ""
		
		# Load state data
		dialogue_index = stored_state.get("dialogue_index", 0)
		DialogueLines = stored_state.get("dialogue_lines", [])
		current_enemy_data = stored_state.get("enemy_data", null)
		
		# Restore character states before showing anything
		restore_character_visibility_states()
		
		# Clear stored state
		GameManager.clear_battle_state()
	
	# Wait one frame to ensure everything is settled
	await get_tree().process_frame
	
	# Process current line fresh (don't replay previous line)
	if dialogue_index < DialogueLines.size():
		# Force reset the dialogue UI
		dialogue_ui.DialogueLines.visible_ratio = 0
		dialogue_ui.animate_text = false
		
		# Process the current line properly
		await process_current_line()
	
	set_input_blocked(false)
	
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
