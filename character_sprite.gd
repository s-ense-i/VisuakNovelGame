# ENHANCED character_sprite.gd with consistent character facing
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

# FIXED: Consistent auto-facing system - left characters unflipped, right characters flipped
func update_character_facing():
	"""Update all visible characters to face consistently: left=unflipped, right=flipped"""
	var visible_chars = get_visible_character_nodes()
	var screen_center = screen_width / 2
	
	print("Updating character facing for ", visible_chars.size(), " visible characters")
	
	for char_node in visible_chars:
		var char_name = get_character_name_from_node(char_node)
		var char_x = char_node.global_position.x
		var is_on_right_side = char_x >= screen_center
		
		# CONSISTENT RULE: Left side = no flip (false), Right side = flip (true)
		char_node.flip_h = is_on_right_side
		
		print("Character ", char_name, " at x:", char_x, 
			  " (", "right" if is_on_right_side else "left", " side)",
			  " flip_h set to:", char_node.flip_h)

func get_visible_character_nodes() -> Array[AnimatedSprite2D]:
	"""Get array of currently visible character nodes"""
	var visible_chars: Array[AnimatedSprite2D] = []
	
	if protoganist.visible:
		visible_chars.append(protoganist)
	if kami.visible:
		visible_chars.append(kami)
	if fujiwara.visible:
		visible_chars.append(fujiwara)
	
	return visible_chars

# ENHANCED: Determine slide direction based on character position
func get_character_slide_direction(character_node: AnimatedSprite2D) -> bool:
	"""Returns true if character should slide right (off right side of screen), false for left"""
	var screen_center = screen_width / 2
	return character_node.global_position.x >= screen_center

# ENHANCED: Function to create sliding entrance animation with consistent facing
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

	# Determine slide direction based on target position
	var screen_center = screen_width / 2
	var slide_from_right = target_position.x >= screen_center
	
	# CONSISTENT FACING: Set based on final position, not slide direction
	var is_target_on_right = target_position.x >= screen_center
	character_node.flip_h = is_target_on_right
	
	print("Sliding in ", character_name, " to position x:", target_position.x,
		  " (", "right" if is_target_on_right else "left", " side)",
		  " flip_h:", character_node.flip_h)
	
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
	
	# Clean up when animation completes
	tween.finished.connect(func(): 
		active_tweens.erase(character_name)
		# Final facing update to ensure consistency
		update_character_facing()
	)

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
	
	# Hide when tween finishes and update facing for remaining characters
	tween.finished.connect(func(): 
		character_node.visible = false
		active_tweens.erase(character_name)
		# Update facing for remaining visible characters
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

# ENHANCED: Replace character with consistent facing
func replace_character(character_to_replace: Character.Name, new_character: Character.Name, animation: String = "idle"):
	print("Replacing ", Character.Name.keys()[character_to_replace], " with ", Character.Name.keys()[new_character])
	
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
	
	# Wait for the slide out to progress, then slide in the new character
	await get_tree().create_timer(slide_duration * 0.4).timeout
	
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

# ENHANCED: Show speaker with consistent auto-facing
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
				
				# Update facing after a short delay to ensure positioning is complete
				await get_tree().create_timer(0.1).timeout
				update_character_facing()
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
			
			# Update facing after a short delay
			await get_tree().create_timer(0.1).timeout
			update_character_facing()
		
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
			
			# Update facing after a short delay
			await get_tree().create_timer(0.1).timeout
			update_character_facing()

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
	
	# Update facing even in narration mode
	update_character_facing()
	
	print("Narration mode: all visible characters dimmed")

# ENHANCED: Show only character with consistent auto-facing
func show_only_character(character_name: Character.Name, animation: String = "idle"):
	print("Showing only: ", Character.Name.keys()[character_name])
	
	# Hide others with sliding animation based on their positions
	hide_all_characters(true)
	
	# Wait for hide animations to start
	await get_tree().create_timer(slide_duration * 0.4).timeout
	
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
	
	# Wait for slide in to complete, then update facing
	await get_tree().create_timer(slide_duration).timeout
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
	
	# Reset positions
	protoganist.position = original_protagonist_position
	kami.position = original_kami_position
	fujiwara.position = original_fujiwara_position
	
	# IMPORTANT: Reset flipping to default state
	protoganist.flip_h = false
	kami.flip_h = false
	fujiwara.flip_h = false
	
	# Reset appearance flags
	kami_has_appeared = false
	fujiwara_has_appeared = false
	protagonist_frames_set = false
	kami_frames_set = false
	fujiwara_frames_set = false
	
	# Reset modulation
	protoganist.modulate = Color.WHITE
	kami.modulate = Color.WHITE
	fujiwara.modulate = Color.WHITE

# ENHANCED: Hide character with consistent auto-facing update
func hide_character(character_name: Character.Name, animate: bool = true):
	print("Hiding character: ", Character.Name.keys()[character_name])
	
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
