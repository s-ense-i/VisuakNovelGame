extends Node2D

@onready var tile_map = $TileMap

func world_to_map(world_position: Vector2) -> Vector2i:
	# نحول من World → Local → Map
	return tile_map.local_to_map(tile_map.to_local(world_position))

func map_to_world(map_position: Vector2i) -> Vector2:
	# نحول من Map → Local → World
	return tile_map.to_global(tile_map.map_to_local(map_position))

func is_walkable(tile_pos: Vector2i) -> bool:
	var tile_id = tile_map.get_cell_source_id(0, tile_pos)
	return tile_id != -1
