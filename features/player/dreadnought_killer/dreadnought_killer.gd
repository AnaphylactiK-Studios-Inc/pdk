extends Area3D

@export var grid_walkability: GridWalkability
@export var grid_position: Vector2i = Vector2i.ZERO

@export var move_time: float = 0.5
@export var rotation_time: float = 0.15

const QUARTER_TURN := PI * 0.5

var _grid: Grid
var _active: bool = false
var _moving: bool = false
var _rotating: bool = false

func _ready() -> void:
	if grid_walkability == null:
		push_error(
			"DreadnoughtKiller: grid_walkability is unassigned; "
			+ "movement disabled."
		)

		return

	_grid = grid_walkability.grid

	if _grid == null:
		push_error(
			"DreadnoughtKiller: GridWalkability has no grid; "
			+ "movement disabled."
		)

		return

	_grid.ensure_initialized()

	_validate_start_position()
	_snap_to_grid()

	_active = true

func _validate_start_position() -> void:
	if not _grid.is_valid_position(grid_position):
		var clamped := Vector2i(
			clampi(grid_position.x, 0, _grid.width - 1),
			clampi(grid_position.y, 0, _grid.length - 1)
		)

		push_warning(
			"DreadnoughtKiller: start position %s is out of bounds; "
			% grid_position
			+ "clamped to %s." % clamped
		)

		grid_position = clamped

	if not grid_walkability.is_walkable(grid_position):
		push_warning(
			"DreadnoughtKiller: start position %s is not walkable."
			% grid_position
		)

func _physics_process(_delta: float) -> void:
	if not _active or is_busy():
		return

	if Input.is_action_just_pressed("grid_rotate_left"):
		rotate_left()
	elif Input.is_action_just_pressed("grid_rotate_right"):
		rotate_right()
	elif Input.is_action_pressed("move_forward"):
		move_forward()
	elif Input.is_action_pressed("move_back"):
		move_backward()
	elif Input.is_action_pressed("move_right"):
		move_right()
	elif Input.is_action_pressed("move_left"):
		move_left()

func is_busy() -> bool:
	return _moving or _rotating

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
	var flat := Vector3(local_direction.x, 0.0, local_direction.z)

	if flat.length_squared() < 0.0001:
		return Vector2i.ZERO

	var direction := flat.normalized()

	if absf(direction.x) > absf(direction.z):
		return Vector2i(signi(roundi(direction.x)), 0)

	return Vector2i(0, signi(roundi(direction.z)))

func try_move(direction: Vector2i) -> void:
	if is_busy():
		return

	if direction == Vector2i.ZERO:
		return

	var target_grid_position := grid_position + direction

	if not grid_walkability.can_enter(target_grid_position):
		bump_into_obstacle(direction)
		return

	grid_position = target_grid_position

	var target_world_position: Vector3 = _grid.grid_to_world(
		grid_position
	)

	_moving = true

	var tween := create_tween()

	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		self,
		"global_position",
		target_world_position,
		move_time
	)

	await tween.finished

	if not is_inside_tree():
		return

	_snap_to_grid()

	_moving = false

func bump_into_obstacle(
	direction: Vector2i,
	distance: float = 0.25,
	bump_height: float = -0.1,
	duration: float = 0.08
) -> void:
	if is_busy():
		return

	_moving = true

	var start_pos := _grid.grid_to_world(grid_position)

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

	if not is_inside_tree():
		return

	_snap_to_grid()

	_moving = false

func rotate_90_degrees(direction: int) -> void:
	if is_busy():
		return

	_rotating = true

	var target_rotation := (
		rotation.y
		+ deg_to_rad(90.0 * direction)
	)

	var tween := create_tween()

	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		self,
		"rotation:y",
		target_rotation,
		rotation_time
	)

	await tween.finished

	if not is_inside_tree():
		return

	rotation.y = snappedf(rotation.y, QUARTER_TURN)

	_rotating = false

func _snap_to_grid() -> void:
	global_position = _grid.grid_to_world(grid_position)
