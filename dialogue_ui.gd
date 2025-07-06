extends Control
const ChoiceButtonScene = preload("res://PlayerChoice.tscn")
signal choice_selected
@onready var DialogueLines = %DialogeLines
@onready var SpeakerName = %SpeakerName
@onready var SpeakerBox = %SpeakerBox
@onready var choice_list = %Choiceslist
const ANIMATION_SPEED : int = 30
var animate_text : bool = false
var current_visible_characters : int = 0

func _ready() -> void:
	DialogueLines.text= ""
	SpeakerName.text= ""
	choice_list.hide()
	Fade.fade_in()

func _process(delta: float) -> void:
	if animate_text:
		if DialogueLines.visible_ratio < 1:
			DialogueLines.visible_ratio += (1.0/DialogueLines.text.length()) * (ANIMATION_SPEED * delta)
			current_visible_characters = DialogueLines.visible_characters
		else:
			animate_text = false	

func change_line(speaker: String, line: String):
	SpeakerName.text = speaker
	current_visible_characters = 0
	DialogueLines.text = line
	DialogueLines.visible_characters = 0
	animate_text = true
	# Make sure dialogue is visible when changing lines
	DialogueLines.show()
	
func skip_animation_text():
	DialogueLines.visible_ratio = 1	

# New functions to show/hide speaker name
func hide_speaker_name():
	SpeakerName.visible = false
	
func show_speaker_name():
	SpeakerName.visible = true
	
func hide_speaker_box():
	SpeakerBox.hide()
	
func show_speaker_box():
	SpeakerBox.show()
	
func display_choices(choices: Array):
	# FIXED: Hide dialogue text and speaker elements when showing choices
	DialogueLines.hide()
	SpeakerName.hide()
	SpeakerBox.hide()
	
	# Clear existing choice buttons
	for child in choice_list.get_children():
		child.queue_free()
	
	# Create new choice buttons
	for choice in choices:
		var choice_button = ChoiceButtonScene.instantiate()
		choice_button.text = choice["text"]
		choice_button.pressed.connect(on_choice_button_pressed.bind(choice["goto"]))
		choice_list.add_child(choice_button)
	
	choice_list.show()	

func on_choice_button_pressed(anchor: String):
	choice_selected.emit(anchor)
	choice_list.hide()
	# FIXED: Show dialogue elements again after choice is made
	DialogueLines.show()
	SpeakerName.show()
	SpeakerBox.show()

func hide_all_ui():
	hide_speaker_box()
	hide_speaker_name()
	%DialogeLines.text = ""
	%SpeakerName.text = ""

func show_all_ui():
	show_speaker_box()
	show_speaker_name()
