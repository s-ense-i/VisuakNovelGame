class_name PathFinder
extends RefCounted

var astar := AStarGrid2D.new()

func _init(tile_map: TileMap, walkable_cells: Array[Vector2i]):
	var tile_size = tile_map.tile_set.tile_size
	var used_rect := tile_map.get_used_rect()

	astar.region = used_rect
	astar.cell_size = tile_size
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

	for cell in walkable_cells:
		astar.set_point_solid(cell, false)

func find_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var raw_path := astar.get_id_path(start, end)
	var result: Array[Vector2i] = []
	for point in raw_path:
		result.append(Vector2i(point))
	return result
