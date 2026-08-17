extends CharacterBody3D

@export var cell_size: float = 4.0
@export var move_time: float = 0.5
@export var rotation_time: float = 0.15

@onready var front_raycast: RayCast3D = $FrontRaycast
@onready var back_raycast: RayCast3D = $BackRaycast

var grid_position: Vector2i = Vector2i.ZERO
var _moving: bool = false
var _rotating: bool = false

func _ready() -> void:
	global_position = grid_to_world(grid_position)
	
	front_raycast.target_position = Vector3(0, -cell_size, 0)
	back_raycast.target_position = Vector3(0, cell_size, 0)

func _unhandled_input(event: InputEvent) -> void:
	if _rotating or _moving:
		return

	if event.is_action_pressed("grid_rotate_left"):
		rotate_left()
	elif event.is_action_pressed("grid_rotate_right"):
		rotate_right()
	elif event.is_action_pressed("grid_move_forward"):
		move_forward()
	elif event.is_action_pressed("grid_move_back"):
		move_backward()

func rotate_left() -> void:
	rotate_90_degrees(1)

func rotate_right() -> void:
	rotate_90_degrees(-1)

func move_forward() -> void:
	if !can_move_forward():
		return

	var direction := get_forward_grid_direction()
	try_move(direction)

func move_backward() -> void:
	if !can_move_backwards():
		return
		
	var direction := -get_forward_grid_direction()
	try_move(direction)

# Movement
func get_forward_grid_direction() -> Vector2i:
	var forward := -global_transform.basis.z

	if abs(forward.x) > abs(forward.z):
		return Vector2i(
			signi(roundi(forward.x)),
			0
		)
	else:
		return Vector2i(
			0,
			signi(roundi(forward.z))
		)

func try_move(direction: Vector2i) -> void:
	var target_grid_position := grid_position + direction

	grid_position = target_grid_position
	var target_world_position := grid_to_world(grid_position)

	_moving = true

	var tween = create_tween()

	tween.tween_property(
		self,
		"global_position",
		target_world_position,
		move_time
	)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	_moving = false

func grid_to_world(grid: Vector2i) -> Vector3:
	return Vector3(
		grid.x * cell_size,
		global_position.y,
		grid.y * cell_size
	)

func can_move_forward() -> bool:
	return !front_raycast.is_colliding()
	
func can_move_backwards() -> bool:
	return !back_raycast.is_colliding()

# Rotation
func rotate_90_degrees(direction: int) -> void:
	_rotating = true

	var target_rotation = rotation.y + deg_to_rad(90.0 * direction)

	var tween = create_tween()
	tween.tween_property(
		self,
		"rotation:y",
		target_rotation,
		rotation_time
	)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	_rotating = false
