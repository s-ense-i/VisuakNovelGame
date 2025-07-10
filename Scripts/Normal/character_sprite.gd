# ENHANCED character_sprite.gd with consistent character facing
extends Node2D

@onready var protoganist = %protoganist
@onready var kami = %kami
@onready var fujiwara = %Fujiwara
@onready var Yatufusta = %Yatufusta
@onready var PigEnemy = %PigEnemy
@onready var BirdEnemy = %BirdEnemy

# Enhanced Animation settings - increased slide distance for off-screen effect
var slide_duration: float = 0.4 # Slightly longer for better effect
var slide_distance: float = 400.0  # Increased from 200 to ensure off-screen
var slide_ease_type: Tween.EaseType = Tween.EASE_OUT
var slide_transition_type: Tween.TransitionType = Tween.TRANS_CUBIC

# Get screen width for proper off-screen calculation
var screen_width: float

# Track if characters have already appeared in the scene
var kami_has_appeared: bool = false
var fujiwara_has_appeared: bool = false
var yatufusta_has_appeared: bool = false
var PigEnemy_has_appeared: bool = false
var BirdEnemy_has_appeared: bool = false
var protagonist_frames_set: bool = false
var kami_frames_set: bool = false
var fujiwara_frames_set: bool = false
var yatufusta_frames_set: bool = false
var PigEnemy_frames_set: bool = false
var BirdEnemy_frames_set: bool = false
# Track recent speakers for narration mode
var recent_speakers = []

# Store original positions for proper replacement
var original_protagonist_position: Vector2
var original_kami_position: Vector2
var original_fujiwara_position: Vector2
var original_yatufusta_position: Vector2
var original_PigEnemy_position: Vector2
var original_BirdEnemy_position: Vector2

# Track which characters have been replaced and what replaced them
var character_replacements = {}
var replaced_characters = {}

# Track animation tweens to prevent conflicts
var active_tweens = {}
var dialogue_ui: Node = null

func set_dialogue_ui(ui: Node):
	dialogue_ui = ui

func _ready() -> void:
	self.modulate.a=0
	screen_width = get_viewport().get_visible_rect().size.x
	
	# Store original positions
	original_protagonist_position = protoganist.position
	original_kami_position = kami.position
	original_fujiwara_position = fujiwara.position
	original_yatufusta_position = Yatufusta.position
	original_PigEnemy_position = PigEnemy.position
	original_BirdEnemy_position = BirdEnemy.position
	
	# Ensure initial state
	hide_all_characters()
	protoganist.visible = true
	protoganist.modulate = Color.WHITE
	kami_has_appeared = false
	fujiwara_has_appeared = false
	yatufusta_has_appeared = false
	recent_speakers.clear()
	character_replacements.clear()
	replaced_characters.clear()
	active_tweens.clear()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

# FIXED: Consistent auto-facing system - left characters unflipped, right characters flipped
func update_character_facing():
	var visible_chars = get_visible_character_nodes()
	var screen_center = screen_width / 2
	
	for char_node in visible_chars:
		var char_name = get_character_name_from_node(char_node)
		var char_x = char_node.global_position.x
		
		# Special case for BirdEnemy - always face left (unflipped)
		if char_name == "BirdEnemy":
			char_node.flip_h = false
		else:
			# Normal facing logic for other characters
			char_node.flip_h = char_x >= screen_center
		
		print("Character ", char_name, " at x:", char_x, 
			  " (", "right" if char_node.flip_h else "left", " side)",
			  " flip_h:", char_node.flip_h)

func is_current_line_narration() -> bool:
	var main_dialogue = get_parent()
	if main_dialogue and main_dialogue.has_method("get") and main_dialogue.get("current_line_is_narration"):
		return main_dialogue.current_line_is_narration
	return false

# Add this helper function to ensure narration UI stays hidden
func ensure_narration_ui_hidden():
	if is_current_line_narration() and dialogue_ui:
		dialogue_ui.hide_speaker_box()
		dialogue_ui.hide_speaker_name()
		
func get_visible_character_nodes() -> Array[AnimatedSprite2D]:
	"""Get array of currently visible character nodes"""
	var visible_chars: Array[AnimatedSprite2D] = []
	
	if protoganist.visible:
		visible_chars.append(protoganist)
	if kami.visible:
		visible_chars.append(kami)
	if fujiwara.visible:
		visible_chars.append(fujiwara)
	if Yatufusta.visible:
		visible_chars.append(Yatufusta)
	if PigEnemy.visible:
		visible_chars.append(PigEnemy)
	if BirdEnemy.visible:
		visible_chars.append(BirdEnemy)	
	
	return visible_chars

# ENHANCED: Determine slide direction based on character position
func get_character_slide_direction(character_node: AnimatedSprite2D) -> bool:
	"""Returns true if character should slide right (off right side of screen), false for left"""
	var screen_center = screen_width / 2
	return character_node.global_position.x >= screen_center

# ENHANCED: Function to create sliding entrance animation with consistent facing
func slide_character_in(character_node: AnimatedSprite2D, target_position: Vector2, from_right: bool = true):
	
	if dialogue_ui:
		dialogue_ui.force_hide_for_animation()
	# Calculate sprite width properly for AnimatedSprite2D
	var sprite_width = 100.0  # Default fallback width
	if character_node.sprite_frames and character_node.sprite_frames.has_animation(character_node.animation):
		var frame_texture = character_node.sprite_frames.get_frame_texture(character_node.animation, character_node.frame)
		if frame_texture:
			sprite_width = frame_texture.get_width() * character_node.scale.x
	
	var screen_center = screen_width / 2
	var is_target_on_right = target_position.x >= screen_center
	character_node.flip_h = is_target_on_right
	
	var character_name = get_character_name_from_node(character_node)
	if active_tweens.has(character_name):
		active_tweens[character_name].kill()

	# Calculate start position (completely off-screen)
	var start_position = target_position
	var slide_from_right = target_position.x >= screen_center
	
	if slide_from_right:
		start_position.x = screen_width + sprite_width
	else:
		start_position.x = -sprite_width

	# Set initial position and make visible
	character_node.position = start_position
	character_node.visible = true

	# Create and configure tween
	var tween = create_tween()
	active_tweens[character_name] = tween
	
	tween.set_ease(slide_ease_type)
	tween.set_trans(slide_transition_type)
	
	tween.tween_property(character_node, "position", target_position, slide_duration)
	
	tween.finished.connect(func(): 
		active_tweens.erase(character_name)
		ensure_narration_ui_hidden()
		update_character_facing()
	)

# ENHANCED: Function to slide character out based on their screen position
func slide_character_out(character_node: AnimatedSprite2D, force_direction: String = "auto"):
	if dialogue_ui:
		dialogue_ui.force_hide_for_animation()
		
	var char_name = get_character_name_from_node(character_node)
	if active_tweens.has(char_name):
		return
	
	# Calculate sprite width properly for AnimatedSprite2D
	var sprite_width = 100.0  # Default fallback width
	if character_node.sprite_frames and character_node.sprite_frames.has_animation(character_node.animation):
		var frame_texture = character_node.sprite_frames.get_frame_texture(character_node.animation, character_node.frame)
		if frame_texture:
			sprite_width = frame_texture.get_width() * character_node.scale.x
	
	var current_position = character_node.position
	var slide_right: bool
	
	# Determine slide direction
	match force_direction:
		"left":
			slide_right = false
		"right":
			slide_right = true
		"auto", _:
			slide_right = get_character_slide_direction(character_node)
	
	# Calculate end position
	var end_position = current_position
	if slide_right:
		end_position.x = screen_width + sprite_width
	else:
		end_position.x = -sprite_width
	
	var tween = create_tween()
	active_tweens[char_name] = tween
	
	tween.set_ease(slide_ease_type)
	tween.set_trans(slide_transition_type)
	
	tween.tween_property(character_node, "position", end_position, slide_duration)
	
	tween.finished.connect(func(): 
		character_node.visible = false
		active_tweens.erase(char_name)
		ensure_narration_ui_hidden()
		update_character_facing()
	)
# Helper function to get character name from node
func get_character_name_from_node(node: AnimatedSprite2D) -> String:
	if node == protoganist:
		return "protagonist"
	elif node == kami:
		return "kami"
	elif node == fujiwara:
		return "fujiwara"
	elif node == Yatufusta:
		return "yatufusta"
	elif node == PigEnemy:
		return "PigEnemy"
	elif node == BirdEnemy:
		return "BirdEnemy"	
	return ""

# ENHANCED: Hide all characters with directional sliding based on position
func hide_all_characters(animate: bool = false):
	if animate:
		# Slide out visible characters based on their position
		if protoganist.visible:
			slide_character_out(protoganist, "auto")
		if kami.visible:
			slide_character_out(kami, "auto")
		if fujiwara.visible:
			slide_character_out(fujiwara, "auto")
		if Yatufusta.visible:
			slide_character_out(Yatufusta, "auto")
		if PigEnemy.visible:
			slide_character_out(PigEnemy, "auto")	
		if BirdEnemy.visible:
			slide_character_out(BirdEnemy, "auto")	
	else:
		# Immediate hide
		protoganist.visible = false
		kami.visible = false
		fujiwara.visible = false
		Yatufusta.visible = false
		PigEnemy.visible = false
		BirdEnemy.visible = false
	
	# Reset modulation
	protoganist.modulate = Color.WHITE
	kami.modulate = Color.WHITE
	fujiwara.modulate = Color.WHITE
	Yatufusta.modulate = Color.WHITE
	PigEnemy.modulate = Color.WHITE
	BirdEnemy.modulate = Color.WHITE

# Track speakers for narration mode
func update_recent_speakers(speaker_name: Character.Name):
	if speaker_name in recent_speakers:
		recent_speakers.erase(speaker_name)
	
	recent_speakers.append(speaker_name)
	
	if recent_speakers.size() > 5:
		recent_speakers.pop_front()
	
	print("Recent speakers updated: ", recent_speakers, " - Latest speaker: ", Character.Name.keys()[speaker_name])

# ENHANCED: Replace character with consistent facing
func replace_character(character_to_replace: Character.Name, new_character: Character.Name, animation: String = "idle"):
	print("Replacing ", Character.Name.keys()[character_to_replace], " with ", Character.Name.keys()[new_character])
	
	if dialogue_ui:
		dialogue_ui.force_hide_for_animation()
		
	ensure_narration_ui_hidden()
	# Track the replacement
	character_replacements[character_to_replace] = new_character
	replaced_characters[new_character] = character_to_replace
	
	# Get the CURRENT position of the character being replaced
	var replacement_position: Vector2
	var slide_from_right: bool = true
	
	# Slide out the old character based on their position and get replacement info
	match character_to_replace:
		Character.Name.protoganist:
			if protoganist.visible:
				replacement_position = protoganist.position
				slide_character_out(protoganist, "auto")
			else:
				replacement_position = original_protagonist_position
			slide_from_right = replacement_position.x < screen_width / 2
		
		Character.Name.kami:
			if kami.visible:
				replacement_position = kami.position
				slide_character_out(kami, "auto")
			else:
				replacement_position = original_kami_position
			slide_from_right = replacement_position.x < screen_width / 2
		
		Character.Name.fujiwara:
			if fujiwara.visible:
				replacement_position = fujiwara.position
				slide_character_out(fujiwara, "auto")
			else:
				replacement_position = original_fujiwara_position
			slide_from_right = replacement_position.x < screen_width / 2
		
		Character.Name.yatufusta:
			if Yatufusta.visible:
				replacement_position = Yatufusta.position
				slide_character_out(Yatufusta, "auto")
			else:
				replacement_position = original_yatufusta_position
			slide_from_right = replacement_position.x < screen_width / 2
			
		Character.Name.PigEnemy:
			if PigEnemy.visible:
				replacement_position = PigEnemy.position
				slide_character_out(PigEnemy, "auto")
			else:
				replacement_position = original_PigEnemy_position
			slide_from_right = replacement_position.x < screen_width / 2	
			
		Character.Name.BirdEnemy:
			if BirdEnemy.visible:
				replacement_position = BirdEnemy.position
				slide_character_out(BirdEnemy, "auto")
			else:
				replacement_position = original_BirdEnemy_position
			slide_from_right = replacement_position.x < screen_width / 2		
	
	# Wait for the slide out to progress, then slide in the new character
	await get_tree().create_timer(slide_duration * 0.4).timeout
	
	ensure_narration_ui_hidden()
	
	# Show the new character with sliding animation from appropriate direction
	match new_character:
		Character.Name.protoganist:
			protoganist.modulate = Color.WHITE
			protoganist.frames = Character.CHARACTER_DETAILS[Character.Name.protoganist]["animation"]
			protagonist_frames_set = true
			protoganist.play(animation)
			slide_character_in(protoganist, replacement_position, slide_from_right)
		
		Character.Name.kami:
			kami.modulate = Color.WHITE
			kami_has_appeared = true
			kami.frames = Character.CHARACTER_DETAILS[Character.Name.kami]["animation"]
			kami_frames_set = true
			kami.play(animation)
			slide_character_in(kami, replacement_position, slide_from_right)
		
		Character.Name.fujiwara:
			fujiwara.modulate = Color.WHITE
			fujiwara_has_appeared = true
			fujiwara.frames = Character.CHARACTER_DETAILS[Character.Name.fujiwara]["animation"]
			fujiwara_frames_set = true
			fujiwara.play(animation)
			slide_character_in(fujiwara, replacement_position, slide_from_right)
		
		Character.Name.yatufusta:
			Yatufusta.modulate = Color.WHITE
			yatufusta_has_appeared = true
			Yatufusta.frames = Character.CHARACTER_DETAILS[Character.Name.yatufusta]["animation"]
			yatufusta_frames_set = true
			Yatufusta.play(animation)
			slide_character_in(Yatufusta, replacement_position, slide_from_right)
			
		Character.Name.PigEnemy:
			PigEnemy.modulate = Color.WHITE
			PigEnemy_has_appeared = true
			PigEnemy.frames = Character.CHARACTER_DETAILS[Character.Name.PigEnemy]["animation"]
			PigEnemy_frames_set = true
			PigEnemy.play(animation)
			slide_character_in(PigEnemy, replacement_position, slide_from_right)
			
		Character.Name.BirdEnemy:
			BirdEnemy.modulate = Color.WHITE
			BirdEnemy_has_appeared = true
			BirdEnemy.frames = Character.CHARACTER_DETAILS[Character.Name.BirdEnemy]["animation"]
			BirdEnemy_frames_set = true
			BirdEnemy.play(animation)
			slide_character_in(BirdEnemy, replacement_position, slide_from_right)
	
	# Update appearance flags
	if new_character == Character.Name.kami:
		kami_has_appeared = true
	elif new_character == Character.Name.fujiwara:
		fujiwara_has_appeared = true
	elif new_character == Character.Name.yatufusta:
		yatufusta_has_appeared = true
	elif new_character == Character.Name.PigEnemy:
		PigEnemy_has_appeared = true
	elif new_character == Character.Name.BirdEnemy:
		BirdEnemy_has_appeared = true	
		
	# Wait for slide in to complete, then dim other characters
	await get_tree().create_timer(slide_duration).timeout
	ensure_narration_ui_hidden()
	dim_non_speakers(new_character)


# Helper functions remain the same
func should_character_be_visible(character_name: Character.Name) -> bool:
	return not character_replacements.has(character_name)

func get_actual_character_to_show(character_name: Character.Name) -> Character.Name:
	if character_replacements.has(character_name):
		return character_replacements[character_name]
	return character_name

func dim_non_speakers(current_speaker: Character.Name):
	if protoganist.visible and current_speaker != Character.Name.protoganist:
		protoganist.modulate = Color(0.7, 0.7, 0.7)
	if kami.visible and current_speaker != Character.Name.kami:
		kami.modulate = Color(0.7, 0.7, 0.7)
	if fujiwara.visible and current_speaker != Character.Name.fujiwara:
		fujiwara.modulate = Color(0.7, 0.7, 0.7)
	if Yatufusta.visible and current_speaker != Character.Name.yatufusta:
		Yatufusta.modulate = Color(0.7, 0.7, 0.7)
	if PigEnemy.visible and current_speaker != Character.Name.PigEnemy:
		PigEnemy.modulate = Color(0.7, 0.7, 0.7)	
	if BirdEnemy.visible and current_speaker != Character.Name.BirdEnemy:
		BirdEnemy.modulate = Color(0.7, 0.7, 0.7)	

# ENHANCED: Show speaker with consistent auto-facing
func show_speaker(character_name: Character.Name, animation: String = "idle"):
	print("show_speaker called with: ", Character.Name.keys()[character_name], " animation: ", animation)
	
	ensure_narration_ui_hidden()
	
	update_recent_speakers(character_name)
	
	match character_name:
		Character.Name.protoganist:
			if should_character_be_visible(Character.Name.protoganist):
				# Only slide in protagonist if not visible
				if not protoganist.visible:
					slide_character_in(protoganist, original_protagonist_position, false)
				else:
					protoganist.visible = true
				
				# Keep other characters static if already visible
				if kami.visible and should_character_be_visible(Character.Name.kami):
					kami.visible = true
				if fujiwara.visible and should_character_be_visible(Character.Name.fujiwara):
					fujiwara.visible = true
				if Yatufusta.visible and should_character_be_visible(Character.Name.yatufusta):
					Yatufusta.visible = true
				if PigEnemy.visible and should_character_be_visible(Character.Name.PigEnemy):
					PigEnemy.visible = true	
				if BirdEnemy.visible and should_character_be_visible(Character.Name.BirdEnemy):
					BirdEnemy.visible = true		
				
				highlight_speaker(Character.Name.protoganist)
				
				protoganist.frames = Character.CHARACTER_DETAILS[Character.Name.protoganist]["animation"]
				protagonist_frames_set = true
				protoganist.play(animation)
				
				# Update facing after delay
				await get_tree().create_timer(0.1).timeout
				if dialogue_ui:
						dialogue_ui.force_hide_for_animation()
				update_character_facing()
			else:
				var replacement = get_actual_character_to_show(Character.Name.protoganist)
				show_speaker(replacement, animation)
				return
		
		Character.Name.kami:
			kami_has_appeared = true
			
			# Only slide in kami if not visible
			if should_character_be_visible(Character.Name.kami):
				if not kami.visible:
					slide_character_in(kami, original_kami_position, true)
				else:
					kami.visible = true
			
			# Keep other characters static if already visible
			if protoganist.visible and should_character_be_visible(Character.Name.protoganist):
				protoganist.visible = true
			if fujiwara.visible and should_character_be_visible(Character.Name.fujiwara):
				fujiwara.visible = true
			if Yatufusta.visible and should_character_be_visible(Character.Name.yatufusta):
				Yatufusta.visible = true
			if PigEnemy.visible and should_character_be_visible(Character.Name.PigEnemy):
				PigEnemy.visible = true	
			if BirdEnemy.visible and should_character_be_visible(Character.Name.BirdEnemy):
				BirdEnemy.visible = true			
			
			highlight_speaker(Character.Name.kami)
			
			kami.frames = Character.CHARACTER_DETAILS[Character.Name.kami]["animation"]
			kami_frames_set = true
			kami.play(animation)
			
			if protoganist.visible and not protagonist_frames_set:
				protoganist.frames = Character.CHARACTER_DETAILS[Character.Name.protoganist]["animation"]
				protagonist_frames_set = true
				protoganist.play("idle")
			
			# Update facing after delay
			await get_tree().create_timer(0.1).timeout
			if dialogue_ui:
				dialogue_ui.force_hide_for_animation()
			update_character_facing()
		
		Character.Name.fujiwara:
			fujiwara_has_appeared = true
			
			# Only slide in fujiwara if not visible
			if should_character_be_visible(Character.Name.fujiwara):
				if not fujiwara.visible:
					slide_character_in(fujiwara, original_fujiwara_position, true)
				else:
					fujiwara.visible = true
			
			# Keep other characters static if already visible
			if protoganist.visible and should_character_be_visible(Character.Name.protoganist):
				protoganist.visible = true
			if kami.visible and should_character_be_visible(Character.Name.kami):
				kami.visible = true
			if Yatufusta.visible and should_character_be_visible(Character.Name.yatufusta):
				Yatufusta.visible = true
			if PigEnemy.visible and should_character_be_visible(Character.Name.PigEnemy):
				PigEnemy.visible = true	
			if BirdEnemy.visible and should_character_be_visible(Character.Name.BirdEnemy):
				BirdEnemy.visible = true			
			
			highlight_speaker(Character.Name.fujiwara)
			
			fujiwara.frames = Character.CHARACTER_DETAILS[Character.Name.fujiwara]["animation"]
			fujiwara_frames_set = true
			fujiwara.play(animation)
			
			if protoganist.visible and not protagonist_frames_set:
				protoganist.frames = Character.CHARACTER_DETAILS[Character.Name.protoganist]["animation"]
				protagonist_frames_set = true
				protoganist.play("idle")
			if kami.visible and not kami_frames_set:
				kami.frames = Character.CHARACTER_DETAILS[Character.Name.kami]["animation"]
				kami_frames_set = true
				kami.play("idle")
			
			# Update facing after delay
			await get_tree().create_timer(0.1).timeout
			if dialogue_ui:
				dialogue_ui.force_hide_for_animation()
			update_character_facing()
		
		Character.Name.yatufusta:
			yatufusta_has_appeared = true
			
			# Only slide in Yatufusta if not visible
			if should_character_be_visible(Character.Name.yatufusta):
				if not Yatufusta.visible:
					slide_character_in(Yatufusta, original_yatufusta_position, true)
				else:
					Yatufusta.visible = true
			
			# Keep other characters static if already visible
			if protoganist.visible and should_character_be_visible(Character.Name.protoganist):
				protoganist.visible = true
			if kami.visible and should_character_be_visible(Character.Name.kami):
				kami.visible = true
			if fujiwara.visible and should_character_be_visible(Character.Name.fujiwara):
				fujiwara.visible = true
			if PigEnemy.visible and should_character_be_visible(Character.Name.PigEnemy):
				PigEnemy.visible = true	
			if BirdEnemy.visible and should_character_be_visible(Character.Name.BirdEnemy):
				BirdEnemy.visible = true			
			
			highlight_speaker(Character.Name.yatufusta)
			
			Yatufusta.frames = Character.CHARACTER_DETAILS[Character.Name.yatufusta]["animation"]
			yatufusta_frames_set = true
			Yatufusta.play(animation)
			
			if protoganist.visible and not protagonist_frames_set:
				protoganist.frames = Character.CHARACTER_DETAILS[Character.Name.protoganist]["animation"]
				protagonist_frames_set = true
				protoganist.play("idle")
			if kami.visible and not kami_frames_set:
				kami.frames = Character.CHARACTER_DETAILS[Character.Name.kami]["animation"]
				kami_frames_set = true
				kami.play("idle")
			if fujiwara.visible and not fujiwara_frames_set:
				fujiwara.frames = Character.CHARACTER_DETAILS[Character.Name.fujiwara]["animation"]
				fujiwara_frames_set = true
				fujiwara.play("idle")
				
			await get_tree().create_timer(0.1).timeout
			if dialogue_ui:
				dialogue_ui.force_hide_for_animation()
			update_character_facing()
			
		Character.Name.PigEnemy:
			PigEnemy_has_appeared = true
			
			# Only slide in Yatufusta if not visible
			if should_character_be_visible(Character.Name.PigEnemy):
				if not PigEnemy.visible:
					slide_character_in(PigEnemy, original_PigEnemy_position, true)
				else:
					PigEnemy.visible = true
			
			# Keep other characters static if already visible
			if protoganist.visible and should_character_be_visible(Character.Name.protoganist):
				protoganist.visible = true
			if kami.visible and should_character_be_visible(Character.Name.kami):
				kami.visible = true
			if fujiwara.visible and should_character_be_visible(Character.Name.fujiwara):
				fujiwara.visible = true
			if Yatufusta.visible and should_character_be_visible(Character.Name.yatufusta):
				Yatufusta.visible = true	
			if BirdEnemy.visible and should_character_be_visible(Character.Name.BirdEnemy):
				BirdEnemy.visible = true			
			
			highlight_speaker(Character.Name.PigEnemy)
			
			PigEnemy.frames = Character.CHARACTER_DETAILS[Character.Name.PigEnemy]["animation"]
			PigEnemy_frames_set = true
			PigEnemy.play(animation)
			
			if protoganist.visible and not protagonist_frames_set:
				protoganist.frames = Character.CHARACTER_DETAILS[Character.Name.protoganist]["animation"]
				protagonist_frames_set = true
				protoganist.play("idle")
			if kami.visible and not kami_frames_set:
				kami.frames = Character.CHARACTER_DETAILS[Character.Name.kami]["animation"]
				kami_frames_set = true
				kami.play("idle")
			if fujiwara.visible and not fujiwara_frames_set:
				fujiwara.frames = Character.CHARACTER_DETAILS[Character.Name.fujiwara]["animation"]
				fujiwara_frames_set = true
				fujiwara.play("idle")
			if Yatufusta.visible and not yatufusta_frames_set:
				Yatufusta.frames = Character.CHARACTER_DETAILS[Character.Name.yatufusta]["animation"]
				yatufusta_frames_set = true
				Yatufusta.play("idle")	
				
			# Update facing after delay
			await get_tree().create_timer(0.1).timeout
			if dialogue_ui:
				dialogue_ui.force_hide_for_animation()
			update_character_facing()
			
		Character.Name.BirdEnemy:
			BirdEnemy_has_appeared = true
			
			# Only slide in Yatufusta if not visible
			if should_character_be_visible(Character.Name.BirdEnemy):
				if not BirdEnemy.visible:
					slide_character_in(BirdEnemy, original_BirdEnemy_position, true)
				else:
					BirdEnemy.visible = true
			
			# Keep other characters static if already visible
			if protoganist.visible and should_character_be_visible(Character.Name.protoganist):
				protoganist.visible = true
			if kami.visible and should_character_be_visible(Character.Name.kami):
				kami.visible = true
			if fujiwara.visible and should_character_be_visible(Character.Name.fujiwara):
				fujiwara.visible = true
			if Yatufusta.visible and should_character_be_visible(Character.Name.yatufusta):
				Yatufusta.visible = true	
			if PigEnemy.visible and should_character_be_visible(Character.Name.PigEnemy):
				PigEnemy.visible = true			
			
			highlight_speaker(Character.Name.BirdEnemy)
			
			BirdEnemy.frames = Character.CHARACTER_DETAILS[Character.Name.BirdEnemy]["animation"]
			BirdEnemy_frames_set = true
			BirdEnemy.play(animation)
			
			if protoganist.visible and not protagonist_frames_set:
				protoganist.frames = Character.CHARACTER_DETAILS[Character.Name.protoganist]["animation"]
				protagonist_frames_set = true
				protoganist.play("idle")
			if kami.visible and not kami_frames_set:
				kami.frames = Character.CHARACTER_DETAILS[Character.Name.kami]["animation"]
				kami_frames_set = true
				kami.play("idle")
			if fujiwara.visible and not fujiwara_frames_set:
				fujiwara.frames = Character.CHARACTER_DETAILS[Character.Name.fujiwara]["animation"]
				fujiwara_frames_set = true
				fujiwara.play("idle")
			if Yatufusta.visible and not yatufusta_frames_set:
				Yatufusta.frames = Character.CHARACTER_DETAILS[Character.Name.yatufusta]["animation"]
				yatufusta_frames_set = true
				Yatufusta.play("idle")			
			if PigEnemy.visible and not PigEnemy_frames_set:
				PigEnemy.frames = Character.CHARACTER_DETAILS[Character.Name.PigEnemy]["animation"]
				PigEnemy_frames_set  = true
				PigEnemy.play("idle")		
				
			# Update facing after delay
			await get_tree().create_timer(0.1).timeout
			if dialogue_ui:
				dialogue_ui.force_hide_for_animation()
			update_character_facing()	

func highlight_speaker(character_name: Character.Name):
	# First, dim all visible characters
	if protoganist.visible:
		protoganist.modulate = Color(0.7, 0.7, 0.7)
	if kami.visible:
		kami.modulate = Color(0.7, 0.7, 0.7)
	if fujiwara.visible:
		fujiwara.modulate = Color(0.7, 0.7, 0.7)
	if Yatufusta.visible:
		Yatufusta.modulate = Color(0.7, 0.7, 0.7)	
	if PigEnemy.visible:
		PigEnemy.modulate = Color(0.7, 0.7, 0.7)	
	if BirdEnemy.visible:
		BirdEnemy.modulate = Color(0.7, 0.7, 0.7)		
	
	# Then highlight the speaker
	match character_name:
		Character.Name.protoganist:
			protoganist.modulate = Color.WHITE
		Character.Name.kami:
			kami.modulate = Color.WHITE
		Character.Name.fujiwara:
			fujiwara.modulate = Color.WHITE
		Character.Name.yatufusta:
			Yatufusta.modulate = Color.WHITE
		Character.Name.PigEnemy:
			PigEnemy.modulate = Color.WHITE	
		Character.Name.BirdEnemy:
			BirdEnemy.modulate = Color.WHITE		

func show_narration_mode():
	print("Narration mode: preserving current character visibility and dimming all")
	
	if dialogue_ui:
		dialogue_ui.hide_speaker_box()
		dialogue_ui.hide_speaker_name()
		
	if protoganist.visible:
		protoganist.modulate = Color(0.7, 0.7, 0.7)
		if not protagonist_frames_set:
			protoganist.frames = Character.CHARACTER_DETAILS[Character.Name.protoganist]["animation"]
			protagonist_frames_set = true
			protoganist.play("idle")
	
	if kami.visible:
		kami.modulate = Color(0.7, 0.7, 0.7)
		if not kami_frames_set:
			kami.frames = Character.CHARACTER_DETAILS[Character.Name.kami]["animation"]
			kami_frames_set = true
			kami.play("idle")
	
	if fujiwara.visible:
		fujiwara.modulate = Color(0.7, 0.7, 0.7)
		if not fujiwara_frames_set:
			fujiwara.frames = Character.CHARACTER_DETAILS[Character.Name.fujiwara]["animation"]
			fujiwara_frames_set = true
			fujiwara.play("idle")
	
	if Yatufusta.visible:
		Yatufusta.modulate = Color(0.7, 0.7, 0.7)
		if not yatufusta_frames_set:
			Yatufusta.frames = Character.CHARACTER_DETAILS[Character.Name.yatufusta]["animation"]
			yatufusta_frames_set = true
			Yatufusta.play("idle")
			
	if PigEnemy.visible:
		PigEnemy.modulate = Color(0.7, 0.7, 0.7)
		if not PigEnemy_frames_set:
			PigEnemy.frames = Character.CHARACTER_DETAILS[Character.Name.PigEnemy]["animation"]
			PigEnemy_frames_set = true
			PigEnemy.play("idle")		
	
	if BirdEnemy.visible:
		BirdEnemy.modulate = Color(0.7, 0.7, 0.7)
		if not BirdEnemy_frames_set:
			BirdEnemy.frames = Character.CHARACTER_DETAILS[Character.Name.BirdEnemy]["animation"]
			BirdEnemy_frames_set = true
			BirdEnemy.play("idle")		
			
	# Update facing even in narration mode
	update_character_facing()
	
	print("Narration mode: all visible characters dimmed")

# ENHANCED: Show only character with consistent auto-facing
func show_only_character(character_name: Character.Name, animation: String = "idle"):
	print("Showing only: ", Character.Name.keys()[character_name])
	
	if dialogue_ui:
		dialogue_ui.force_hide_for_animation()
		
	ensure_narration_ui_hidden()
	# Hide others with sliding animation based on their positions
	hide_all_characters(true)
	
	# Wait for hide animations to start
	await get_tree().create_timer(slide_duration * 0.4).timeout
	
	ensure_narration_ui_hidden()
	# Show and highlight only the specified character
	match character_name:
		Character.Name.protoganist:
			protoganist.modulate = Color.WHITE
			protoganist.frames = Character.CHARACTER_DETAILS[Character.Name.protoganist]["animation"]
			protagonist_frames_set = true
			protoganist.play(animation)
			slide_character_in(protoganist, original_protagonist_position, false)
		
		Character.Name.kami:
			kami.modulate = Color.WHITE
			kami.frames = Character.CHARACTER_DETAILS[Character.Name.kami]["animation"]
			kami_frames_set = true
			kami.play(animation)
			slide_character_in(kami, original_kami_position, true)
		
		Character.Name.fujiwara:
			fujiwara.modulate = Color.WHITE
			fujiwara.frames = Character.CHARACTER_DETAILS[Character.Name.fujiwara]["animation"]
			fujiwara_frames_set = true
			fujiwara.play(animation)
			slide_character_in(fujiwara, original_fujiwara_position, true)
		
		Character.Name.yatufusta:
			Yatufusta.modulate = Color.WHITE
			Yatufusta.frames = Character.CHARACTER_DETAILS[Character.Name.yatufusta]["animation"]
			yatufusta_frames_set = true
			Yatufusta.play(animation)
			slide_character_in(Yatufusta, original_yatufusta_position, true)
			
		Character.Name.PigEnemy:
			PigEnemy.modulate = Color.WHITE
			PigEnemy.frames = Character.CHARACTER_DETAILS[Character.Name.PigEnemy]["animation"]
			PigEnemy_frames_set = true
			PigEnemy.play(animation)
			slide_character_in(PigEnemy, original_PigEnemy_position, true)	
			
		Character.Name.BirdEnemy:
			BirdEnemy.modulate = Color.WHITE
			BirdEnemy.frames = Character.CHARACTER_DETAILS[Character.Name.BirdEnemy]["animation"]
			BirdEnemy_frames_set = true
			BirdEnemy.play(animation)
			slide_character_in(BirdEnemy, original_BirdEnemy_position, true)						
	
	# Wait for slide in to complete, then update facing
	await get_tree().create_timer(slide_duration).timeout
	ensure_narration_ui_hidden()
	update_character_facing()

# Keep your existing parse_dialogue_line function
func parse_dialogue_line(dialogue_line: String):
	var parts = dialogue_line.split(":", 3)
	
	if parts.size() < 2:
		show_narration_mode()
		return
	
	var character_name_str = parts[0].strip_edges()
	var character_enum = Character.get_enum_from_string(character_name_str)
	
	if character_enum == -1:
		show_narration_mode()
		return
	
	var animation = "idle"
	
	if parts.size() >= 3 and parts[1].strip_edges() != "":
		animation = parts[1].strip_edges()
	
	show_speaker(character_enum, animation)

func reset_for_new_scene():
	# Stop all animations
	for tween in active_tweens.values():
		tween.kill()
	active_tweens.clear()
	
	# Reset all characters
	protoganist.visible = false
	kami.visible = false
	fujiwara.visible = false
	Yatufusta.visible = false
	BirdEnemy.visible = false
	PigEnemy.visible = false	
	
	# Reset positions
	protoganist.position = original_protagonist_position
	kami.position = original_kami_position
	fujiwara.position = original_fujiwara_position
	Yatufusta.position = original_yatufusta_position
	PigEnemy.position = original_PigEnemy_position
	BirdEnemy.position = original_BirdEnemy_position	
	
	# IMPORTANT: Reset flipping to default state
	protoganist.flip_h = false
	kami.flip_h = false
	fujiwara.flip_h = false
	Yatufusta.flip_h = false
	PigEnemy.flip_h = false
	BirdEnemy.flip_h = false

	
	# Reset appearance flags
	kami_has_appeared = false
	fujiwara_has_appeared = false
	yatufusta_has_appeared = false
	PigEnemy_has_appeared = false
	BirdEnemy_has_appeared = false
	protagonist_frames_set = false
	kami_frames_set = false
	fujiwara_frames_set = false
	yatufusta_frames_set = false
	PigEnemy_frames_set = false	
	BirdEnemy_frames_set = false	
	
	# Reset modulation
	protoganist.modulate = Color.WHITE
	kami.modulate = Color.WHITE
	fujiwara.modulate = Color.WHITE
	Yatufusta.modulate = Color.WHITE
	PigEnemy.modulate = Color.WHITE	
	BirdEnemy.modulate = Color.WHITE	

# ENHANCED: Hide character with consistent auto-facing update
func hide_character(character_name: Character.Name, animate: bool = true):
	print("Hiding character: ", Character.Name.keys()[character_name])
	
	if dialogue_ui:
		dialogue_ui.force_hide_for_animation()
		
	ensure_narration_ui_hidden()
	
	match character_name:
		Character.Name.protoganist:
			if animate:
				slide_character_out(protoganist, "auto")
			else:
				protoganist.visible = false
				update_character_facing()
		Character.Name.kami:
			if animate:
				slide_character_out(kami, "auto")
			else:
				kami.visible = false
				update_character_facing()
		Character.Name.fujiwara:
			if animate:
				slide_character_out(fujiwara, "auto")
			else:
				fujiwara.visible = false
				update_character_facing()
		Character.Name.yatufusta:
			if animate:
				slide_character_out(Yatufusta, "auto")
			else:
				Yatufusta.visible = false
				update_character_facing()

		Character.Name.PigEnemy:
			if animate:
				slide_character_out(PigEnemy, "auto")
			else:
				PigEnemy.visible = false
				update_character_facing()
				
		Character.Name.BirdEnemy:
			if animate:
				slide_character_out(BirdEnemy, "auto")
			else:
				BirdEnemy.visible = false
				update_character_facing()			
