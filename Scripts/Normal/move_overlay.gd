extends TileMap

signal tile_clicked(tile_pos: Vector2i, player: Node)

var current_player: Node = null

func _ready():
	# Make sure the tilemap can receive input events
	set_process_unhandled_input(true)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_player != null:
			# Get the clicked tile position
			var click_pos = get_global_mouse_position()
			var tile_pos = local_to_map(to_local(click_pos))
			
			# Check if the clicked tile has a movement cell
			var source_id = get_cell_source_id(0, tile_pos)
			if source_id != -1:  # If there's a tile at this position
				tile_clicked.emit(tile_pos, current_player)

func draw_cells(cells: Array) -> void:
	clear()
	for cell in cells:
		set_cell(0, cell, 0, Vector2i(0, 0))  # Blue tile for movement

func show_movement_grid(cells: Array, player: Node = null):
	current_player = player
	draw_cells(cells)
	visible = true

func hide_movement_grid():
	clear()
	current_player = null
	visible = false

func _clear():
	clear_layer(0)
