extends CharacterBody2D

var path: Array[Vector2] = []  # ← لاحظ دي Array of Vector2 (مش Vector2i)
var move_speed := 100
var current_tile: Vector2i
var tile_map: TileMap
var step := 0
var moving := false

func _ready():
	tile_map = get_parent().get_node("TileMap")
	current_tile = tile_map.local_to_map(tile_map.to_local(global_position))

func start_movement(grid_path):
	path.clear()

	for point in grid_path:
		# تأكد إنه Vector2i لو مش كده
		var grid_point = Vector2i(point)
		var world_pos = tile_map.map_to_local(grid_point)
		path.append(world_pos)

	step = 0
	moving = true


func _physics_process(delta):
	if moving and step < path.size():
		var target = path[step]
		var direction = (target - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()

		if global_position.distance_to(target) < 4:
			global_position = target
			current_tile = tile_map.local_to_map(tile_map.to_local(global_position))
			step += 1

			if step >= path.size():
				moving = false
				velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
		move_and_slide()
