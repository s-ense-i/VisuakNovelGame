# Character.gd
class_name Character
extends Node

enum Name {
	protoganist,
	kami,
	fujiwara,
	yatufusta,
	PigEnemy,
	BirdEnemy
}

# Preload resources as separate variables
static var CHARACTER_DETAILS : Dictionary = {
	Name.protoganist: {
		"name" : "protoganist",
		"gender" : "male",
		"animation" : preload("res://Protoganist.tres")
	},
	
	Name.kami: {
		"name": "kami",
		"gender" : "female",
		"animation" : preload("res://Kami.tres")
	},
	Name.fujiwara: {
		"name": "fujiwara",
		"gender" : "male",
		"animation" : preload("res://fujiwara.tres")
	},
	Name.yatufusta: {
		"name": "yatufusta",
		"gender" : "male",
		"animation" : preload("res://yatufusta.tres")
	},
	Name.PigEnemy: {
		"name": "PigEnemy",
		"gender" : "male",
		"animation" : preload("res://PigEnemy.tres")
	},
	Name.BirdEnemy: {
		"name": "BirdEnemy",
		"gender" : "male",
		"animation" : preload("res://BirdEnemy.tres")
	},
}
static func get_enum_from_string(string_value: String) -> int:
	# Convert to lowercase to match enum names
	var lower_string = string_value.to_lower()
	
	# Check each enum value
	for character_name in Name.values():
		if Name.keys()[character_name].to_lower() == lower_string:
			return character_name
	
	push_error("Invalid character name: " + string_value)
	return -1
