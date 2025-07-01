extends Node2D

@onready var tile_map = $TileMap

var selected_player: CharacterBody2D = null

func world_to_map(world_position: Vector2) -> Vector2i:
	return tile_map.local_to_map(tile_map.to_local(world_position))

func map_to_world(map_position: Vector2i) -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(map_position))

func is_walkable(tile_pos: Vector2i) -> bool:
	var data = tile_map.get_cell_tile_data(0, tile_pos)
	if not data:
		return false
	return data.get_custom_data("walkable") == true
@onready var command_menu = $CommandMenu

func _ready():
	command_menu.move_selected.connect(_on_move_pressed)
	command_menu.end_turn_selected.connect(_on_end_turn_pressed)
	
func _on_move_pressed():
	if selected_player:
		selected_player._on_move_selected()

func _on_end_turn_pressed():
	if selected_player:
		selected_player._on_end_turn_selected()

func get_players() -> Array:
	return get_tree().get_nodes_in_group("players")
###
func trigger_enemy_movement():
	
	$Enemy1.start_movement([
		Vector2i(47, 23)
])


	$Enemy2.start_movement([
		Vector2i(7, 11)
	])

	$Enemy3.start_movement([
		Vector2i(11, 10)
		#$TileMap.map_to_local(Vector2i(7, 2)),
		#$TileMap.map_to_local(Vector2i(7, 3))
	])
