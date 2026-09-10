extends CharacterBody3D

@export var grid: Grid
@export var grid_walkability: GridWalkability
@export var grid_position: Vector2i = Vector2i.ZERO

@export var move_time: float = 0.5
@export var rotation_time: float = 0.15

var _moving: bool = false
var _rotating: bool = false

func _ready() -> void:
	if grid == null:
		return

	global_position = grid.grid_to_world(grid_position)

func _physics_process(_delta: float) -> void:
	if not _moving:
		if Input.is_action_pressed("move_forward"):
			move_forward()
		elif Input.is_action_pressed("move_back"):
			move_backward()
		elif Input.is_action_pressed("move_right"):
			move_right()
		elif Input.is_action_pressed("move_left"):
			move_left()

	if not _rotating:
		if Input.is_action_just_pressed("grid_rotate_left"):
			rotate_left()
		elif Input.is_action_just_pressed("grid_rotate_right"):
			rotate_right()

func rotate_left() -> void:
	rotate_90_degrees(1)

func rotate_right() -> void:
	rotate_90_degrees(-1)

func move_forward() -> void:
	var direction := get_grid_direction(-global_transform.basis.z)
	try_move(direction)

func move_backward() -> void:
	var direction := get_grid_direction(global_transform.basis.z)
	try_move(direction)

func move_right() -> void:
	var direction := get_grid_direction(global_transform.basis.x)
	try_move(direction)

func move_left() -> void:
	var direction := get_grid_direction(-global_transform.basis.x)
	try_move(direction)

func get_grid_direction(local_direction: Vector3) -> Vector2i:
	var direction := local_direction.normalized()

	if abs(direction.x) > abs(direction.z):
		return Vector2i(signi(roundi(direction.x)), 0)
	else:
		return Vector2i(0, signi(roundi(direction.z)))

func try_move(direction: Vector2i) -> void:
	var target_grid_position := grid_position + direction

	if not grid_walkability.can_enter(target_grid_position):
		bump_into_obstacle(direction)
		return

	grid_position = target_grid_position

	var target_world_position: Vector3 = grid.grid_to_world(
		grid_position
	)

	_moving = true

	var tween := create_tween()

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

func bump_into_obstacle(
	direction: Vector2i,
	distance: float = 0.25,
	bump_height: float = -0.1,
	duration: float = 0.08
) -> void:
	if _moving:
		return

	_moving = true

	var start_pos := global_position

	var bump_direction := Vector3(
		direction.x,
		0.0,
		direction.y
	).normalized()

	var end_pos := start_pos + bump_direction * distance

	end_pos.y += bump_height

	var tween := create_tween()

	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"global_position",
		end_pos,
		duration
	)

	tween.tween_property(
		self,
		"global_position",
		start_pos,
		duration * 2
	)

	await tween.finished

	_moving = false

func rotate_90_degrees(direction: int) -> void:
	_rotating = true

	var target_rotation := (
		rotation.y
		+ deg_to_rad(90.0 * direction)
	)

	var tween := create_tween()

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
