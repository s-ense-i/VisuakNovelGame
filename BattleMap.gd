extends  Node2D
# Character Nodes
@onready var player1 = %Player
@onready var player2 = %Player2
@onready var player3 = %Player3

# Enemy Nodes
@onready var yatufusta = $Enemy3/AnimatedSprite2D2
@onready var bird = $Enemy2/animatedsprite2d
@onready var pig = $Enemy1/animatedsprite2d

# Dialogue System Nodes
@onready var character = %CharacterSprite
@onready var dialogue_ui = %DialogueUi
@onready var command_menu = $CommandMenu

# TileMap
@onready var tile_map = $TileMap

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

func _ready():
	# Initialize game characters
	initialize_characters()
	
	# Set up dialogue system
	initialize_dialogue()
	
	# Connect signals
	command_menu.move_selected.connect(_on_move_pressed)
	command_menu.end_turn_selected.connect(_on_end_turn_pressed)
	
	# Start the scene
	start_scene_sequence()

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
	yatufusta.start_movement([Vector2i(47, 23)])
	bird.start_movement([Vector2i(7, 11)])
	pig.start_movement([Vector2i(11, 10)])

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
	var character_node = get_in_game_character(char_name)
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
	match char_name:
		"yatufusta":
			return yatufusta
		"Bird", "BirdEnemy":
			return bird
		"Pig", "PigEnemy":
			return pig
		_:
			return null

func get_anchor_position(anchor: String) -> int:
	for i in range(DialogueLines.size()):
		if DialogueLines[i].has("anchor") and DialogueLines[i]["anchor"] == anchor:
			return i
	return -1

func _input(event):
	if not scene_initialized or waiting_for_choice:
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
