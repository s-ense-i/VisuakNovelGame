extends CharacterBody2D

enum State { IDLE, SELECTED, MOVING, WAITING }
var state: State = State.IDLE

var move_path: Array[Vector2i] = []
var move_speed := 100
var move_range := 10
var move_clicks := 0
const MAX_MOVE_CLICKS := 2

var current_tile: Vector2i
var pathfinder: PathFinder

@onready var tile_map := get_parent().get_node("TileMap")
@onready var move_overlay := get_parent().get_node("MoveOverlay")
@onready var command_menu := get_parent().get_node("CommandMenu")
@onready var anim := $AnimatedSprite2D
@onready var battlemap := get_parent()  


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
	
	add_to_group("players")  # ✅ لازم قبل أي استخدام لـ get_players()
	




func _physics_process(delta):
	if state == State.MOVING and move_path.size() > 0:
		var next_tile = move_path[0]
		var tile_size = tile_map.tile_set.tile_size
		var next_pos = tile_map.map_to_local(next_tile)

		var direction = (next_pos - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()

		if global_position.distance_to(next_pos) < 4:
			global_position = next_pos
			current_tile = next_tile
			move_path.remove_at(0)

			if move_path.is_empty():
				state = State.WAITING
				velocity = Vector2.ZERO
				anim.play("idle")
				move_overlay.clear()
				command_menu.open()
	else:
		velocity = Vector2.ZERO
		move_and_slide()


func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if state == State.IDLE:
			var battlemap = get_parent()  # ✅ الصح
			battlemap.selected_player = self
			state = State.SELECTED
			command_menu.open()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and state == State.MOVING:
		var click_pos = get_global_mouse_position()
		var tile = tile_map.local_to_map(tile_map.to_local(click_pos))

		if is_walkable(tile) and tile != current_tile:
			var path: Array[Vector2i] = []
			for p in pathfinder.find_path(current_tile, tile):
				path.append(Vector2i(p))

			if path.size() > 1 and path.size() - 1 <= move_range:
				move_path = path
				state = State.MOVING
				anim.play("walk")
				move_overlay.clear()

func _on_move_selected():
	if battlemap.selected_player != self:
		return  # ⛔ مش أنا اللاعب المحدد، تجاهل الإشارة

	if move_clicks < MAX_MOVE_CLICKS:
		state = State.MOVING
		show_movement_range()
		command_menu.close()
		move_clicks += 1

		if move_clicks >= MAX_MOVE_CLICKS:
			command_menu.disable_move_button()


func _on_end_turn_selected():
	if battlemap.selected_player != self:
		return  # ⛔ مش أنا اللاعب المحدد، تجاهل الإشارة

	state = State.IDLE
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

	# 🔥 تحقق إذا كان في لاعب تاني واقف على نفس البلاطة
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
