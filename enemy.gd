extends CharacterBody2D

var movement_path: Array[Vector2] = []
var movement_speed: float = 100.0
var current_tile_position: Vector2i
var tile_map: TileMap
var current_path_index: int = 0
var is_moving: bool = false
signal movement_completed


func _ready():
	tile_map = get_parent().get_node("TileMap") if get_parent().has_node("TileMap") else null
	if tile_map == null:
		push_error("TileMap not found!")
	current_tile_position = get_current_tile_position()

func get_current_tile_position() -> Vector2i:
	if tile_map:
		return tile_map.local_to_map(tile_map.to_local(global_position))
	return Vector2i.ZERO

func start_movement(grid_path: Array, duration: float = -1.0):
	if tile_map == null:
		push_error("TileMap missing - cannot move")
		return
	
	# Clear previous path
	movement_path.clear()
	
	# Convert path to world positions with proper type handling
	for point in grid_path:
		var grid_point = Vector2i(point)
		var world_pos = tile_map.map_to_local(grid_point)
		movement_path.append(world_pos)
	
	# Adjust speed if duration is specified
	if duration > 0:
		var total_distance = calculate_path_distance(movement_path)
		if total_distance > 0 and duration > 0:
			movement_speed = total_distance / duration
	
	current_path_index = 0
	is_moving = true

func calculate_path_distance(path: Array[Vector2]) -> float:
	var distance = 0.0
	for i in range(1, path.size()):
		distance += path[i-1].distance_to(path[i])
	return distance

func _physics_process(delta):
	if not is_moving or current_path_index >= movement_path.size():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var target = movement_path[current_path_index]
	velocity = (target - global_position).normalized() * movement_speed
	move_and_slide()
	
	if global_position.distance_to(target) < 4:
		global_position = target
		current_tile_position = get_current_tile_position()
		current_path_index += 1
		if current_path_index >= movement_path.size():
			is_moving = false
			velocity = Vector2.ZERO
			emit_signal("movement_completed")
