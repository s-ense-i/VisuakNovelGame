# main_dialogue.gd - ENHANCED VERSION WITH END SCENE SUPPORT
extends Node2D

@onready var Background= %Background
@onready var character = %CharacterSprite
@onready var dialogue_ui = %DialogueUi
@onready var BackgroundEffect1 = $CanvasLayer/Background/BackgroundEffect1
@onready var BackgroundEffect2 = $CanvasLayer/Background/BackgroundEffect2
@onready var BackgroundEffect3 = $CanvasLayer/Background/BackgroundEffect3

var dialogue_index: int = 0
var DialogueLines: Array = []
var waiting_for_choice: bool = false
var visible_characters: Array[int] = []
var transition_effect: String = "fade"
var dialogue_file: String = "res://project assets/Story/first_scene.json"
var scene_initialized: bool = false
var target_scene: String = "" 
var processing_line: bool = false
var current_line_is_narration: bool = false

func _ready() -> void:
	# Hide everything initially
	character.hide_all_characters()
	dialogue_ui.hide_speaker_box()
	dialogue_ui.hide_speaker_name()
	
	# Make sure protagonist is completely hidden initially
	character.protoganist.visible = false
	
	# Load dialogue data
	DialogueLines = load_dialogue(dialogue_file)
	dialogue_index = 0
	dialogue_ui.choice_selected.connect(_on_choice_selected)
	
	# Connect transition signals
	SceneManager.transition_out_completed.connect(_on_transition_out_cpmpleted)
	SceneManager.transition_in_completed.connect(_on_transition_in_cpmpleted)
	
	# Start the sequence: fade in background first
	Fade.fade_in()
	await get_tree().process_frame
	SceneManager.transition_in()
	# خفيهم على طول
	BackgroundEffect1.visible = false
	BackgroundEffect2.visible = false
	BackgroundEffect3.visible = false

	
	character.set_dialogue_ui(dialogue_ui)

func start_scene_sequence():
	"""Start the visual sequence: background -> character -> dialogue"""
	scene_initialized = true
	
	# Step 1: Show background (already visible from transition)
	# Wait a moment to let player see the background
	await get_tree().create_timer(0.5).timeout
	
	# Step 2: NEW - Reset character system for new scene
	character.reset_for_new_scene()
	
	# Step 3: Slide in initial character (protagonist by default)
	await slide_in_initial_character()
	
	# Step 4: Start dialogue
	process_current_line()

func slide_in_initial_character():
	"""Slide the protagonist in from off-screen horizontally"""
	# Make sure protagonist is visible but will be positioned off-screen
	character.protoganist.visible = true
	character.protoganist.modulate = Color.WHITE
	character.kami.visible = false
	character.fujiwara.visible = false
	
	# Store the original/target position
	var target_position = character.protoganist.position
	
	# Calculate sprite width for proper off-screen positioning
	var sprite_width = 100.0  # Default fallback
	if character.protoganist.sprite_frames and character.protoganist.sprite_frames.has_animation(character.protoganist.animation):
		var texture = character.protoganist.sprite_frames.get_frame_texture(character.protoganist.animation, character.protoganist.frame)
		if texture:
			sprite_width = texture.get_width() * character.protoganist.scale.x
	else:
		sprite_width = 100.0 * character.protoganist.scale.x  # Fallback width
	
	# Determine slide direction based on target position (same side approach)
	var screen_width = get_viewport().get_visible_rect().size.x
	var screen_center = screen_width / 2
	var slide_from_right = target_position.x >= screen_center
	
	# Calculate start position (completely off-screen)
	var start_position = target_position
	if slide_from_right:
		# Start from right edge of screen plus sprite width
		start_position.x = screen_width + sprite_width
	else:
		# Start from left edge of screen minus sprite width
		start_position.x = -sprite_width
	
	# Set initial off-screen position
	character.protoganist.position = start_position
	
	# Create and configure tween with similar settings
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	
	# Animate to target position
	tween.tween_property(character.protoganist, "position", target_position, 0.8)
	
	# Wait for the slide animation to complete
	await tween.finished

func _input(event):
	# Don't process input until scene is properly initialized
	if not scene_initialized:
		return
		
	# Ignore all input if we're waiting for a choice
	if waiting_for_choice:
		return
	
	# Only process the "next_line" action presses (ignore releases and other inputs)
	if not event.is_action_pressed("next_line"):
		return
	
	var line = DialogueLines[dialogue_index]
	var has_choices = line.has("choices")
	var is_narration = current_line_is_narration
	
	# Case 1: If text is currently animating, allow skipping the animation
	if dialogue_ui.animate_text:
		# For narration lines, ensure speaker box stays hidden when skipping
		if is_narration:
			dialogue_ui.hide_speaker_box()
			dialogue_ui.hide_speaker_name()
		dialogue_ui.skip_animation_text()
		return
	
	# Case 2: If we're still processing a line (character animations, etc.), ignore input
	if processing_line:
		# For narration lines, ensure speaker box stays hidden during rapid clicks
		if is_narration:
			dialogue_ui.hide_speaker_box()
			dialogue_ui.hide_speaker_name()
		print("Still processing line - ignoring input")
		return
	
	# Case 3: If there are choices, don't advance (should be handled by choice selection)
	if has_choices:
		return
	
	# Case 4: Normal line advancement
	if dialogue_index < len(DialogueLines) - 1:
		# Immediately block further input until processing is complete
		processing_line = true
		
		# For narration lines, ensure speaker box stays hidden
		if is_narration:
			dialogue_ui.hide_speaker_box()
			dialogue_ui.hide_speaker_name()
		
		# Advance to next line
		dialogue_index += 1
		
		# Process the next line (this will reset processing_line when done)
		process_current_line()
	else:
		# End of dialogue
		print("End of dialogue")
		dialogue_ui.hide_speaker_box()
		dialogue_ui.hide_speaker_name()
		character.hide_all_characters()

func load_dialogue(file_path):
	if not FileAccess.file_exists(file_path):
		print("Error: The file doesn't exist ", file_path)
		return []

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("Failed to open the file ", file_path)
		return []

	var content = file.get_as_text()
	file.close()

	var json_content = JSON.parse_string(content)
	if json_content == null:
		print("Failed to parse json from file ", file_path)
		return []

	return json_content

func process_current_line():
	if dialogue_index >= DialogueLines.size():
		print("Dialogue index out of bounds")
		return

	# NEW: Set processing flag to block input
	processing_line = true
	
	var line = DialogueLines[dialogue_index]
	
	current_line_is_narration = (line.get("speaker", "") == "Narration")
	# NEW: Handle end scene transitions
	if line.has("endscene"):
		target_scene = line["endscene"]
		transition_effect = line.get("transition", "fade")
		scene_initialized = false  # Reset for scene transition
		
		# Hide dialogue UI and characters before transitioning
		dialogue_ui.hide_speaker_box()
		dialogue_ui.hide_speaker_name()
		character.hide_all_characters()
		
		print("Transitioning to scene: ", target_scene)
		SceneManager.transition_out(transition_effect)
		processing_line = false  # Reset processing flag
		return
	
	if line.has("next_scene"):
		var next_scene= line["next_scene"]
		dialogue_file= "res://project assets/Story/" + next_scene + ".json" if !next_scene.is_empty() else ""
		transition_effect= line.get("transition", "fade")
		scene_initialized = false  # Reset for next scene
		SceneManager.transition_out(transition_effect)
		processing_line = false  # Reset processing flag
		return
	
	if line.has("location"):
		var background_file= "res://project assets/Assets only for a demo/Backgrounds/" + line["location"] + ".png"
		Background.texture= load(background_file)
		dialogue_index+= 1
		process_current_line()
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

	if line.has("choices"):
		waiting_for_choice = true
		
		# Handle character replacement for choices
		if line.has("replace_character") and line.has("speaker"):
			var character_to_replace_enum = Character.get_enum_from_string(line["replace_character"])
			var new_character_enum = Character.get_enum_from_string(line["speaker"])
			
			if character_to_replace_enum != -1 and new_character_enum != -1:
				var animation = line.get("animation", "idle")
				await character.replace_character(character_to_replace_enum, new_character_enum, animation)
		elif line.has("replace_character") and line.has("new_character"):
			var character_to_replace_enum = Character.get_enum_from_string(line["replace_character"])
			var new_character_enum = Character.get_enum_from_string(line["new_character"])
			
			if character_to_replace_enum != -1 and new_character_enum != -1:
				var animation = line.get("animation", "idle")
				await character.replace_character(character_to_replace_enum, new_character_enum, animation)
		
		dialogue_ui.display_choices(line["choices"])
		processing_line = false  # Reset processing flag after choices are displayed
	else:
		waiting_for_choice = false
		print("Processing line: ", dialogue_index, " - ", line)

		var animation = line.get("animation", "idle")

		# Handle show_only first, regardless of speaker
		if line.has("show_only"):
			var show_only_char = line["show_only"]
			var show_only_enum = Character.get_enum_from_string(show_only_char)
			if show_only_enum != -1:
				await character.show_only_character(show_only_enum, animation)
			else:
				push_warning("Unknown character in show_only: " + show_only_char)

		if line["speaker"] == "Narration":
			# Only show narration mode if we're not showing a specific character
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

				# Only process speaker display if we're not showing a specific character
				if not line.has("show_only"):
					if line.has("replace_character"):
						var replace_enum = Character.get_enum_from_string(line["replace_character"])
						if replace_enum != -1:
							print("Replacing ", line["replace_character"], " with ", line["speaker"])
							await character.replace_character(replace_enum, character_enum, animation)
						else:
							await character.show_speaker(character_enum, animation)
					else:
						await character.show_speaker(character_enum, animation)
			else:
				push_warning("Unknown character name in dialogue: " + line["speaker"])

		dialogue_ui.change_line(line["speaker"], line["text"])
		
		# NEW: Reset processing flag after all animations are complete
		processing_line = false

func get_anchor_position(anchor: String) -> int:
	for i in range(DialogueLines.size()):
		if DialogueLines[i].has("anchor") and DialogueLines[i]["anchor"] == anchor:
			return i

	printerr("Couldn't find anchor '" + anchor + "'")
	return -1

func _on_choice_selected(anchor: String):
	waiting_for_choice = false
	processing_line = false  # NEW: Reset processing flag when choice is selected
	if dialogue_ui:
		dialogue_ui.force_hide_for_animation()
	var anchor_pos = get_anchor_position(anchor)
	if anchor_pos != -1:
		dialogue_index = anchor_pos
		process_current_line()
	else:
		printerr("Failed to find anchor: " + anchor)

func _on_transition_out_cpmpleted():
	# NEW: Handle end scene transitions
	if not target_scene.is_empty():
		print("Changing to scene: ", target_scene)
		get_tree().change_scene_to_file(target_scene)
		target_scene = ""  # Reset target scene
		return
	
	if dialogue_file.is_empty():
		print("End")
		return

	# حمّل كل سطور الحوار
	DialogueLines = load_dialogue(dialogue_file)
	dialogue_index = 0
	var first_line = DialogueLines[dialogue_index]

	# غيّر الخلفية لو فيه location
	if first_line.has("location"):
		Background.texture = load("res://project assets/Assets only for a demo/Backgrounds/" + first_line["location"] + ".png")

	# لو هذا هو ملف المشهد التاني
	if dialogue_file.ends_with("second_scene.json"):
		show_background_characters()

	dialogue_index += 1
	SceneManager.transition_in(transition_effect)

func show_background_characters():
	BackgroundEffect1.visible = true
	BackgroundEffect1.play("default")

	BackgroundEffect2.visible = true
	BackgroundEffect2.play("default")

	BackgroundEffect3.visible = true
	BackgroundEffect3.play("default")

func _on_transition_in_cpmpleted():
	# Start the visual sequence instead of immediately processing dialogue
	start_scene_sequence()
