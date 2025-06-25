extends CharacterBody2D

enum State { IDLE, SELECTED, MOVING, WAITING }
var state: State = State.IDLE

var move_path = []
var move_speed := 100
var current_tile: Vector2i
var moving := false

var move_clicks := 0
const MAX_MOVE_CLICKS := 2

@onready var map = get_parent().get_node("TileMap")
@onready var command_menu = get_parent().get_node("CommandMenu")
@onready var anim = $AnimatedSprite2D

func _ready():
	current_tile = map.local_to_map(map.to_local(global_position))
	command_menu.move_selected.connect(_on_move_selected)
	command_menu.end_turn_selected.connect(_on_end_turn_selected)

func _physics_process(delta):
	if state == State.MOVING and move_path.size() > 0:
		var next_tile = move_path[0]
		var next_pos = map.map_to_local(next_tile)
		var direction = (next_pos - global_position).normalized()
		velocity = direction * move_speed

		if anim.animation != "walk":
			anim.play("walk")

		move_and_slide()

		if global_position.distance_to(next_pos) < 4:
			global_position = next_pos
			current_tile = next_tile
			move_path.remove_at(0)

			if move_path.is_empty():
				state = State.WAITING
				velocity = Vector2.ZERO
				anim.play("idle")
				command_menu.open()

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if state == State.IDLE:
			state = State.SELECTED
			command_menu.open()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if state == State.MOVING:
			var click_pos = get_global_mouse_position()
			var tile = map.local_to_map(map.to_local(click_pos))
			if map.get_cell_source_id(0, tile) != -1:
				move_path = [tile]
				moving = true

func _on_move_selected():
	if move_clicks < MAX_MOVE_CLICKS:
		state = State.MOVING
		command_menu.close()
		move_clicks += 1

		if move_clicks >= MAX_MOVE_CLICKS:
			command_menu.disable_move_button()
	else:
		print("No more moves left!")

func _on_end_turn_selected():
	state = State.IDLE
	command_menu.close()
	move_clicks = 0
	command_menu.enable_move_button()
