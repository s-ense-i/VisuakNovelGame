# ENHANCED character_sprite.gd with improved directional sliding animations
extends Node2D

@onready var protoganist = %protoganist
@onready var kami = %kami
@onready var fujiwara = %Fujiwara

# Enhanced Animation settings - increased slide distance for off-screen effect
var slide_duration: float = 0.6  # Slightly longer for better effect
var slide_distance: float = 400.0  # Increased from 200 to ensure off-screen
var slide_ease_type: Tween.EaseType = Tween.EASE_OUT
var slide_transition_type: Tween.TransitionType = Tween.TRANS_CUBIC

# Get screen width for proper off-screen calculation
var screen_width: float

# Track if characters have already appeared in the scene
var kami_has_appeared: bool = false
var fujiwara_has_appeared: bool = false
var protagonist_frames_set: bool = false
var kami_frames_set: bool = false
var fujiwara_frames_set: bool = false

# Track recent speakers for narration mode
var recent_speakers = []

# Store original positions for proper replacement
var original_protagonist_position: Vector2
var original_kami_position: Vector2
var original_fujiwara_position: Vector2

# Track which characters have been replaced and what replaced them
var character_replacements = {}
var replaced_characters = {}

# Track animation tweens to prevent conflicts
var active_tweens = {}

func _ready() -> void:
	self.modulate.a=0
	Fade.fade_in()	# Get screen width for off-screen calculations
	screen_width = get_viewport().get_visible_rect().size.x
	
	# Store original positions
	original_protagonist_position = protoganist.position
	original_kami_position = kami.position
	original_fujiwara_position = fujiwara.position
	
	kami.flip_h = true
	fujiwara.flip_h = true
	
	# Ensure initial state
	hide_all_characters()
	protoganist.visible = true
	protoganist.modulate = Color.WHITE
	kami_has_appeared = false
	fujiwara_has_appeared = false
	recent_speakers.clear()
	character_replacements.clear()
	replaced_characters.clear()
	active_tweens.clear()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


# ENHANCED: Determine slide direction based on character position
func get_character_slide_direction(character_node: AnimatedSprite2D) -> bool:
	"""Returns true if character should slide right (off right side of screen), false for left"""
	var screen_center = screen_width / 2
	return character_node.global_position.x >= screen_center

# ENHANCED: Function to create sliding entrance animation with proper positioning
func slide_character_in(character_node: AnimatedSprite2D, target_position: Vector2, from_right: bool = true):
	# Stop any existing tween for this character
	var character_name = get_character_name_from_node(character_node)
	if active_tweens.has(character_name):
		active_tweens[character_name].kill()
	
	# Calculate start position (completely off-screen)
	var start_position = target_position
	var sprite_width = 100.0  # Default fallback
	if character_node.sprite_frames and character_node.sprite_frames.has_animation(character_node.animation):
		var texture = character_node.sprite_frames.get_frame_texture(character_node.animation, character_node.frame)
		if texture:
			sprite_width = texture.get_width() * character_node.scale.x
	else:
		sprite_width = 100.0 * character_node.scale.x  # Fallback width
	
	# Determine slide direction based on target position (same side approach)
	var screen_center = screen_width / 2
	var slide_from_right = target_position.x >= screen_center
	
	if slide_from_right:
		# Start from right edge of screen plus sprite width
		start_position.x = screen_width + sprite_width
	else:
		# Start from left edge of screen minus sprite width
		start_position.x = -sprite_width
	
	# Set initial position and make visible
	character_node.position = start_position
	character_node.visible = true
	
	# Create and configure tween
	var tween = create_tween()
	active_tweens[character_name] = tween
	
	tween.set_ease(slide_ease_type)
	tween.set_trans(slide_transition_type)
	
	# Animate to target position
	tween.tween_property(character_node, "position", target_position, slide_duration)
	
	# Clean up tween reference when done
	tween.finished.connect(func(): active_tweens.erase(character_name))

# ENHANCED: Function to slide character out based on their screen position
func slide_character_out(character_node: AnimatedSprite2D, force_direction: String = "auto"):
	"""
	Slides character out of screen
	force_direction: "auto" (based on position), "left", "right"
	"""
	var character_name = get_character_name_from_node(character_node)
	if active_tweens.has(character_name):
		active_tweens[character_name].kill()
	
	var current_position = character_node.position
	var sprite_width = 100.0  # Default fallback
	if character_node.sprite_frames and character_node.sprite_frames.has_animation(character_node.animation):
		var texture = character_node.sprite_frames.get_frame_texture(character_node.animation, character_node.frame)
		if texture:
			sprite_width = texture.get_width() * character_node.scale.x
	else:
		sprite_width = 100.0 * character_node.scale.x  # Fallback width
	var slide_right: bool
	
	# Determine slide direction
	match force_direction:
		"left":
			slide_right = false
		"right":
			slide_right = true
		"auto", _:
			slide_right = get_character_slide_direction(character_node)
	
	# Calculate end position (completely off-screen)
	var end_position = current_position
	if slide_right:
		# Slide to right edge of screen plus sprite width
		end_position.x = screen_width + sprite_width
	else:
		# Slide to left edge of screen minus sprite width
		end_position.x = -sprite_width
	
	var tween = create_tween()
	active_tweens[character_name] = tween
	
	tween.set_ease(slide_ease_type)
	tween.set_trans(slide_transition_type)
	
	# Animate to off-screen position
	tween.tween_property(character_node, "position", end_position, slide_duration)
	
	# Hide when tween finishes
	tween.finished.connect(func(): 
		character_node.visible = false
		active_tweens.erase(character_name)
	)

# Helper function to get character name from node
func get_character_name_from_node(node: AnimatedSprite2D) -> String:
	if node == protoganist:
		return "protagonist"
	elif node == kami:
		return "kami"
	elif node == fujiwara:
		return "fujiwara"
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
	else:
		# Immediate hide
		protoganist.visible = false
		kami.visible = false
		fujiwara.visible = false
	
	# Reset modulation
	protoganist.modulate = Color.WHITE
	kami.modulate = Color.WHITE
	fujiwara.modulate = Color.WHITE

# Track speakers for narration mode
func update_recent_speakers(speaker_name: Character.Name):
	if speaker_name in recent_speakers:
		recent_speakers.erase(speaker_name)
	
	recent_speakers.append(speaker_name)
	
	if recent_speakers.size() > 5:
		recent_speakers.pop_front()
	
	print("Recent speakers updated: ", recent_speakers, " - Latest speaker: ", Character.Name.keys()[speaker_name])

# ENHANCED: Replace character with improved directional sliding
func replace_character(character_to_replace: Character.Name, new_character: Character.Name, animation: String = "idle"):
	print("Replacing ", Character.Name.keys()[character_to_replace], " with ", Character.Name.keys()[new_character])
	
	# Track the replacement
	character_replacements[character_to_replace] = new_character
	replaced_characters[new_character] = character_to_replace
	
	# Get the CURRENT position and flip state of the character being replaced
	var replacement_position: Vector2
	var should_flip: bool = false
	var slide_from_right: bool = true
	
	# Slide out the old character based on their position and get replacement info
	match character_to_replace:
		Character.Name.protoganist:
			if protoganist.visible:
				replacement_position = protoganist.position
				should_flip = protoganist.flip_h
				# Protagonist slides out based on current position
				slide_character_out(protoganist, "auto")
			else:
				replacement_position = original_protagonist_position
				should_flip = false
			# New character slides from opposite side
			slide_from_right = replacement_position.x < screen_width / 2
		
		Character.Name.kami:
			if kami.visible:
				replacement_position = kami.position
				should_flip = kami.flip_h
				# Kami slides out based on current position
				slide_character_out(kami, "auto")
			else:
				replacement_position = original_kami_position
				should_flip = true
			# New character slides from opposite side
			slide_from_right = replacement_position.x < screen_width / 2
		
		Character.Name.fujiwara:
			if fujiwara.visible:
				replacement_position = fujiwara.position
				should_flip = fujiwara.flip_h
				# Fujiwara slides out based on current position
				slide_character_out(fujiwara, "auto")
			else:
				replacement_position = original_fujiwara_position
				should_flip = true
			# New character slides from opposite side
			slide_from_right = replacement_position.x < screen_width / 2
	
	# Wait for the slide out to progress, then slide in the new character
	await get_tree().create_timer(slide_duration * 0.4).timeout
	
	# Show the new character with sliding animation from appropriate direction
	match new_character:
		Character.Name.protoganist:
			protoganist.modulate = Color.WHITE
			protoganist.flip_h = should_flip
			protoganist.frames = Character.CHARACTER_DETAILS[Character.Name.protoganist]["animation"]
			protagonist_frames_set = true
			protoganist.play(animation)
			slide_character_in(protoganist, replacement_position, slide_from_right)
		
		Character.Name.kami:
			kami.modulate = Color.WHITE
			kami.flip_h = should_flip
			kami_has_appeared = true
			kami.frames = Character.CHARACTER_DETAILS[Character.Name.kami]["animation"]
			kami_frames_set = true
			kami.play(animation)
			slide_character_in(kami, replacement_position, slide_from_right)
		
		Character.Name.fujiwara:
			fujiwara.modulate = Color.WHITE
			fujiwara.flip_h = should_flip
			fujiwara_has_appeared = true
			fujiwara.frames = Character.CHARACTER_DETAILS[Character.Name.fujiwara]["animation"]
			fujiwara_frames_set = true
			fujiwara.play(animation)
			slide_character_in(fujiwara, replacement_position, slide_from_right)
	
	# Update appearance flags
	if new_character == Character.Name.kami:
		kami_has_appeared = true
	elif new_character == Character.Name.fujiwara:
		fujiwara_has_appeared = true
	
	# Wait for slide in to complete, then dim other characters
	await get_tree().create_timer(slide_duration).timeout
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

# Show speaker with sliding animation for new characters (keeping your existing logic)
func show_speaker(character_name: Character.Name, animation: String = "idle"):
	print("show_speaker called with: ", Character.Name.keys()[character_name], " animation: ", animation)
	
	update_recent_speakers(character_name)
	
	match character_name:
		Character.Name.protoganist:
			if should_character_be_visible(Character.Name.protoganist):
				if kami_has_appeared or fujiwara_has_appeared:
					# Show other appeared characters, but respect replacements
					if not protoganist.visible:
						slide_character_in(protoganist, original_protagonist_position, false)
					else:
						protoganist.visible = true
					
					if kami_has_appeared and should_character_be_visible(Character.Name.kami):
						if not kami.visible:
							slide_character_in(kami, original_kami_position, true)
						else:
							kami.visible = true
					
					if fujiwara_has_appeared and should_character_be_visible(Character.Name.fujiwara):
						if not fujiwara.visible:
							slide_character_in(fujiwara, original_fujiwara_position, true)
						else:
							fujiwara.visible = true
					
					highlight_speaker(Character.Name.protoganist)
				else:
					hide_all_characters()
					if not protoganist.visible:
						slide_character_in(protoganist, original_protagonist_position, false)
					else:
						protoganist.visible = true
						protoganist.modulate = Color.WHITE
				
				protoganist.frames = Character.CHARACTER_DETAILS[Character.Name.protoganist]["animation"]
				protagonist_frames_set = true
				protoganist.play(animation)
			else:
				var replacement = get_actual_character_to_show(Character.Name.protoganist)
				show_speaker(replacement, animation)
				return
		
		Character.Name.kami:
			# Mark as appeared and show with animation if first time
			var first_appearance = not kami_has_appeared
			kami_has_appeared = true
			
			if should_character_be_visible(Character.Name.protoganist):
				if not protoganist.visible:
					slide_character_in(protoganist, original_protagonist_position, false)
				else:
					protoganist.visible = true
			
			if should_character_be_visible(Character.Name.kami):
				if not kami.visible:
					slide_character_in(kami, original_kami_position, true)
				else:
					kami.visible = true
			
			if fujiwara_has_appeared and should_character_be_visible(Character.Name.fujiwara):
				if not fujiwara.visible:
					slide_character_in(fujiwara, original_fujiwara_position, true)
				else:
					fujiwara.visible = true
			
			highlight_speaker(Character.Name.kami)
			
			kami.frames = Character.CHARACTER_DETAILS[Character.Name.kami]["animation"]
			kami_frames_set = true
			kami.play(animation)
			
			if protoganist.visible and not protagonist_frames_set:
				protoganist.frames = Character.CHARACTER_DETAILS[Character.Name.protoganist]["animation"]
				protagonist_frames_set = true
				protoganist.play("idle")
		
		Character.Name.fujiwara:
			# Mark as appeared and show with animation if first time
			var first_appearance = not fujiwara_has_appeared
			fujiwara_has_appeared = true
			
			if kami_has_appeared and should_character_be_visible(Character.Name.kami):
				if not kami.visible:
					slide_character_in(kami, original_kami_position, true)
				else:
					kami.visible = true
			
			if should_character_be_visible(Character.Name.protoganist):
				if not protoganist.visible:
					slide_character_in(protoganist, original_protagonist_position, false)
				else:
					protoganist.visible = true
			
			if should_character_be_visible(Character.Name.fujiwara):
				if not fujiwara.visible:
					slide_character_in(fujiwara, original_fujiwara_position, true)
				else:
					fujiwara.visible = true
			
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

func highlight_speaker(character_name: Character.Name):
	# First, dim all visible characters
	if protoganist.visible:
		protoganist.modulate = Color(0.7, 0.7, 0.7)
	if kami.visible:
		kami.modulate = Color(0.7, 0.7, 0.7)
	if fujiwara.visible:
		fujiwara.modulate = Color(0.7, 0.7, 0.7)
	
	# Then highlight the speaker
	match character_name:
		Character.Name.protoganist:
			protoganist.modulate = Color.WHITE
		Character.Name.kami:
			kami.modulate = Color.WHITE
		Character.Name.fujiwara:
			fujiwara.modulate = Color.WHITE

func show_narration_mode():
	print("Narration mode: preserving current character visibility and dimming all")
	
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
	
	print("Narration mode: all visible characters dimmed")

# ENHANCED: Show only character with proper directional sliding
func show_only_character(character_name: Character.Name, animation: String = "idle"):
	print("Showing only: ", Character.Name.keys()[character_name])
	
	# Hide others with sliding animation based on their positions
	hide_all_characters(true)
	
	# Wait for hide animations to start
	await get_tree().create_timer(slide_duration * 0.4).timeout
	
	# Show and highlight only the specified character with sliding from appropriate side
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
# ADD THIS METHOD TO YOUR character_sprite.gd script

func reset_for_new_scene():
	"""Reset character system state for a new scene"""
	print("Resetting character system for new scene")
	
	# Reset appearance flags
	kami_has_appeared = false
	fujiwara_has_appeared = false
	protagonist_frames_set = false
	kami_frames_set = false
	fujiwara_frames_set = false
	
	# Clear tracking arrays and dictionaries
	recent_speakers.clear()
	character_replacements.clear()
	replaced_characters.clear()
	
	# Stop all active tweens
	for tween_name in active_tweens.keys():
		if active_tweens[tween_name]:
			active_tweens[tween_name].kill()
	active_tweens.clear()
	
	# Reset positions to original
	protoganist.position = original_protagonist_position
	kami.position = original_kami_position
	fujiwara.position = original_fujiwara_position
	
	# Hide all characters initially
	hide_all_characters(false)  # No animation, immediate hide
	
	# Reset modulation
	protoganist.modulate = Color.WHITE
	kami.modulate = Color.WHITE  
	fujiwara.modulate = Color.WHITE
	
	print("Character system reset complete")
