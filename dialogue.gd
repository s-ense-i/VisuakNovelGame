# main_dialogue.gd
extends Node2D

@onready var character = %CharacterSprite
@onready var dialogue_ui = %DialogueUi

var dialogue_index: int = 0
var DialogueLines: Array = []
var waiting_for_choice: bool = false
var visible_characters: Array[int] = []
  # Tracks last speaker

func _ready() -> void:
	Fade.fade_in()
	DialogueLines = load_dialogue("res://project assets/Story/story.json")
	dialogue_index = 0
	dialogue_ui.choice_selected.connect(_on_choice_selected)

	character.hide_all_characters()
	character.protoganist.visible = true
	character.protoganist.modulate = Color.WHITE
	character.kami.visible = false
	await get_tree().process_frame
	process_current_line()

func _input(event):
	if waiting_for_choice:
		return

	var line = DialogueLines[dialogue_index]
	var has_choices = line.has("choices")

	if event.is_action_pressed("next_line") and not has_choices:
		if dialogue_ui.animate_text:
			dialogue_ui.skip_animation_text()
		elif dialogue_index < len(DialogueLines) - 1:
			dialogue_index += 1
			process_current_line()
		else:
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

# Replace your entire process_current_line() function with this complete version:

func process_current_line():
	if dialogue_index >= DialogueLines.size():
		print("Dialogue index out of bounds")
		return

	var line = DialogueLines[dialogue_index]

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
		
		# NEW: Handle character replacement for choices
		if line.has("replace_character") and line.has("speaker"):
			var character_to_replace_enum = Character.get_enum_from_string(line["replace_character"])
			var new_character_enum = Character.get_enum_from_string(line["speaker"])
			
			if character_to_replace_enum != -1 and new_character_enum != -1:
				var animation = line.get("animation", "idle")
				character.replace_character(character_to_replace_enum, new_character_enum, animation)
		# NEW: Handle simple character replacement without speaker
		elif line.has("replace_character") and line.has("new_character"):
			var character_to_replace_enum = Character.get_enum_from_string(line["replace_character"])
			var new_character_enum = Character.get_enum_from_string(line["new_character"])
			
			if character_to_replace_enum != -1 and new_character_enum != -1:
				var animation = line.get("animation", "idle")
				character.replace_character(character_to_replace_enum, new_character_enum, animation)
		
		dialogue_ui.display_choices(line["choices"])
	else:
		waiting_for_choice = false
		print("Processing line: ", dialogue_index, " - ", line)

		var animation = line.get("animation", "idle")

		if line["speaker"] == "Narration":
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
						visible_characters.pop_front()  # Keep only the last 2

				if line.has("replace_character"):
					var replace_enum = Character.get_enum_from_string(line["replace_character"])
					if replace_enum != -1:
						print("Replacing ", line["replace_character"], " with ", line["speaker"])
						character.replace_character(replace_enum, character_enum, animation)
					else:
						character.show_speaker(character_enum, animation)
				else:
					character.show_speaker(character_enum, animation)
			else:
				push_warning("Unknown character name in dialogue: " + line["speaker"])
				if line["speaker"] == "Narration":
					character.show_only(visible_characters)

		dialogue_ui.change_line(line["speaker"], line["text"])

func get_anchor_position(anchor: String) -> int:
	for i in range(DialogueLines.size()):
		if DialogueLines[i].has("anchor") and DialogueLines[i]["anchor"] == anchor:
			return i

	printerr("Couldn't find anchor '" + anchor + "'")
	return -1

func _on_choice_selected(anchor: String):
	waiting_for_choice = false
	var anchor_pos = get_anchor_position(anchor)
	if anchor_pos != -1:
		dialogue_index = anchor_pos
		process_current_line()
	else:
		printerr("Failed to find anchor: " + anchor)
