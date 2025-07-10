extends CharacterBody2D

enum PlayerState { IDLE, SELECTED, MOVING, WAITING, SCRIPTED_MOVING }
var state: PlayerState = PlayerState.IDLE
var move_path: Array[Vector2i] = []
var move_speed := 100
var move_range := 20
var move_clicks := 0
const MAX_MOVE_CLICKS := 2
var current_tile: Vector2i
var pathfinder: PathFinder

var is_player_controlled: bool = false
var movement_grid_active: bool = false
# JSON Movement System Variables
var scripted_move_path: Array[Vector2i] = []
var scripted_move_speed: float = 100.0
var scripted_move_tween: Tween

@onready var tile_map := get_parent().get_node("TileMap")
@onready var move_overlay := get_parent().get_node("MoveOverlay")
@onready var command_menu := get_parent().get_node("CommandMenu")
@onready var anim := $AnimatedSprite2D
@onready var battlemap := get_parent()

# Signal for JSON movement system
signal movement_completed

func _ready():
	current_tile = tile_map.local_to_map(tile_map.to_local(global_position))
	anim.play("idle")
	command_menu.move_selected.connect(_on_move_selected)
	command_menu.end_turn_selected.connect(_on_end_turn_selected)
	
	var walkable_cells: Array[Vector2i] = []
	for cell in tile_map.get_used_cells(0):
		if is_walkable(cell):
			walkable_cells.append(cell)
	pathfinder = PathFinder.new(tile_map, walkable_cells)
	add_to_group("players")

func _physics_process(delta):
	# Handle regular player movement
	if state == PlayerState.MOVING and move_path.size() > 0:
		var next_tile = move_path[0]
		var next_pos = tile_map.map_to_local(next_tile)
		var direction = (next_pos - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		
		if global_position.distance_to(next_pos) < 4:
			global_position = next_pos
			current_tile = next_tile
			move_path.remove_at(0)
			if move_path.is_empty():
				state = PlayerState.WAITING
				velocity = Vector2.ZERO
				anim.play("idle")
				move_overlay.clear()
				if is_player_controlled:
					command_menu.open()

func enable_player_control():
	is_player_controlled = true
	movement_grid_active = true
	show_movement_range()

func disable_player_control():
	is_player_controlled = false
	movement_grid_active = false
	move_overlay.clear()
# JSON Movement System - Required Methods
func start_movement(path: Array, duration: float = 1.0):
	"""Start scripted movement from JSON dialogue system"""
	print("Player starting scripted movement: ", path)
	
	if path.is_empty():
		print("Warning: Empty path provided for player movement")
		movement_completed.emit()
		return
	
	# Convert path to Vector2i array if needed
	scripted_move_path.clear()
	for pos in path:
		if pos is Array and pos.size() >= 2:
			scripted_move_path.append(Vector2i(pos[0], pos[1]))
		elif pos is Vector2i:
			scripted_move_path.append(pos)
		else:
			print("Warning: Invalid path position: ", pos)
	
	if scripted_move_path.is_empty():
		print("Warning: No valid positions in path")
		movement_completed.emit()
		return
	
	# Set state to scripted moving
	state = PlayerState.SCRIPTED_MOVING
	anim.play("walk")
	
	# Calculate movement speed based on duration
	var total_distance = 0.0
	var current_pos = global_position
	
	for tile_pos in scripted_move_path:
		var world_pos = tile_map.map_to_local(tile_pos)
		total_distance += current_pos.distance_to(world_pos)
		current_pos = world_pos
	
	scripted_move_speed = total_distance / duration if duration > 0 else 100.0
	
	# Start the movement
	_execute_scripted_movement()

func _execute_scripted_movement():
	"""Execute the scripted movement along the path"""
	if scripted_move_path.is_empty():
		_finish_scripted_movement()
		return
	
	# Create tween for smooth movement
	if scripted_move_tween:
		scripted_move_tween.kill()
	
	scripted_move_tween = create_tween()
	scripted_move_tween.set_loops()
	
	# Move to each position in sequence
	for i in range(scripted_move_path.size()):
		var target_tile = scripted_move_path[i]
		var target_world_pos = tile_map.map_to_local(target_tile)
		var distance = global_position.distance_to(target_world_pos)
		var move_duration = distance / scripted_move_speed
		
		scripted_move_tween.tween_property(self, "global_position", target_world_pos, move_duration)
		
		# Update current tile when reaching each position
		scripted_move_tween.tween_callback(_update_current_tile.bind(target_tile))
	
	# Finish movement when tween completes
	scripted_move_tween.tween_callback(_finish_scripted_movement)

func _update_current_tile(tile_pos: Vector2i):
	"""Update the current tile position"""
	current_tile = tile_pos

func _finish_scripted_movement():
	"""Finish the scripted movement and return to normal state"""
	print("Player finished scripted movement")
	
	# Clean up
	if scripted_move_tween:
		scripted_move_tween.kill()
		scripted_move_tween = null
	
	scripted_move_path.clear()
	
	# Return to idle state
	state = PlayerState.IDLE
	anim.play("idle")
	velocity = Vector2.ZERO
	
	# Emit completion signal
	movement_completed.emit()

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if state == PlayerState.IDLE:
			var battlemap = get_parent()
			battlemap.selected_player = self
			state = PlayerState.SELECTED
			command_menu.open()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and state == PlayerState.MOVING:
		var click_pos = get_global_mouse_position()
		var tile = tile_map.local_to_map(tile_map.to_local(click_pos))
		
		if is_walkable(tile) and tile != current_tile:
			var path: Array[Vector2i] = []
			for p in pathfinder.find_path(current_tile, tile):
				path.append(Vector2i(p))
			
			if path.size() > 1 and path.size() - 1 <= move_range:
				move_path = path
				state = PlayerState.MOVING
				anim.play("walk")
				move_overlay.clear()

func _on_move_selected(player_name: String):
	if battlemap.selected_player != self:
		return
	
	if move_clicks < MAX_MOVE_CLICKS:
		state = PlayerState.MOVING
		is_player_controlled = true
		movement_grid_active = true
		show_movement_range()
		command_menu.close()
		move_clicks += 1
		if move_clicks >= MAX_MOVE_CLICKS:
			command_menu.disable_move_button()

# In player.gd:

func handle_movement_click(tile_pos: Vector2i):
	if state != PlayerState.MOVING and is_player_controlled:
		var path = []
		for p in pathfinder.find_path(current_tile, tile_pos):
			path.append(Vector2i(p))
		
		if path.size() > 0:
			move_path = path
			state = PlayerState.MOVING
			anim.play("walk")
			
			# Hide movement grid
			get_parent().tile_map.hide_movement_grid()
			
			# Disconnect this handler
			if get_parent().tile_map.tile_clicked.is_connected(handle_movement_click):
				get_parent().tile_map.tile_clicked.disconnect(handle_movement_click)
			
func _on_end_turn_selected():
	if battlemap.selected_player != self:
		return
	state = PlayerState.IDLE
	move_clicks = 0
	command_menu.close()
	command_menu.enable_move_button()
	move_overlay.clear()
	battlemap.trigger_enemy_movement()

func is_walkable(tile_pos: Vector2i) -> bool:
	var layer := 0
	var source_id: int = tile_map.get_cell_source_id(layer, tile_pos)
	if source_id == -1:
		return false
	var data = tile_map.get_cell_tile_data(layer, tile_pos)
	if data == null:
		return false
	if data.get_custom_data("walkable") != true:
		return false
	for player in battlemap.get_players():
		if player != self and player.current_tile == tile_pos:
			return false
	return true

func show_movement_range():
	if not move_overlay or not tile_map:
		return
	var cells: Array[Vector2i] = []
	for x in range(-move_range, move_range + 1):
		for y in range(-move_range, move_range + 1):
			var offset = Vector2i(x, y)
			var target = current_tile + offset
			if abs(x) + abs(y) <= move_range and is_walkable(target):
				cells.append(target)
	move_overlay.draw_cells(cells)

# Debug function to test scripted movement
func test_scripted_movement():
	print("Testing scripted movement...")
	var test_path = [Vector2i(current_tile.x + 1, current_tile.y), 
					Vector2i(current_tile.x + 2, current_tile.y),
					Vector2i(current_tile.x + 2, current_tile.y + 1)]
	start_movement(test_path, 2.0)
