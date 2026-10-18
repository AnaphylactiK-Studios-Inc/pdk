extends Node2D
class_name WireGridMarker

@export var grid: WireGrid
@export var cell_position := Vector2i.ZERO

func _ready():
	update_position()

func _process(_delta):
	var movement := Vector2i.ZERO

	if Input.is_action_just_pressed("interface_up"):
		movement = Vector2i(0, -1)
	elif Input.is_action_just_pressed("interface_down"):
		movement = Vector2i(0, 1)
	elif Input.is_action_just_pressed("interface_left"):
		movement = Vector2i(-1, 0)
	elif Input.is_action_just_pressed("interface_right"):
		movement = Vector2i(1, 0)

	if movement != Vector2i.ZERO:
		move(movement)

	if Input.is_action_just_pressed("interface_accept"):
		if grid:
			grid.rotate_cell(cell_position)

func move(direction: Vector2i):
	var new_position := cell_position + direction

	if new_position.x < 0 or new_position.x >= grid.size:
		return

	if new_position.y < 0 or new_position.y >= grid.size:
		return

	cell_position = new_position
	update_position()

func update_position():
	if grid == null:
		return

	global_position = grid.to_global(
		grid.map_to_local(cell_position)
	)
