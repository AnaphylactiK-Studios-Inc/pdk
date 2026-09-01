extends CharacterBody3D

@export var cell_size: float = 4.0
@export var move_time: float = 0.5
@export var rotation_time: float = 0.15

@onready var front_raycast: RayCast3D = $FrontRaycast
@onready var back_raycast: RayCast3D = $BackRaycast
@onready var right_raycast: RayCast3D = $RightRaycast
@onready var left_raycast: RayCast3D = $LeftRaycast

var grid_position: Vector2i = Vector2i.ZERO
var _moving: bool = false
var _rotating: bool = false

func _ready() -> void:
	global_position = grid_to_world(grid_position)
	
	front_raycast.target_position = Vector3(0, -cell_size, 0)
	back_raycast.target_position = Vector3(0, cell_size, 0)
	right_raycast.target_position = Vector3(0, cell_size , 0)
	left_raycast.target_position = Vector3(0, cell_size, 0)

func _physics_process(_delta):
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
	
	if !can_move(front_raycast):
		bump_into_obstacle(direction)
		return

	try_move(direction)

func move_backward() -> void:
	var direction := get_grid_direction(global_transform.basis.z)
	
	if !can_move(back_raycast):
		bump_into_obstacle(direction)
		return
		
	try_move(direction)

func move_right() -> void:
	var direction := get_grid_direction(global_transform.basis.x)
	
	if !can_move(right_raycast):
		bump_into_obstacle(direction)
		return
		
	try_move(direction)
	
	
func move_left() -> void:
	var direction := get_grid_direction(-global_transform.basis.x)
	
	if !can_move(left_raycast):
		bump_into_obstacle(direction)
		return
		
	try_move(direction)

# Movement
func get_grid_direction(local_direction: Vector3) -> Vector2i:
	var dir := local_direction.normalized()

	if abs(dir.x) > abs(dir.z):
		return Vector2i(signi(roundi(dir.x)), 0)
	else:
		return Vector2i(0, signi(roundi(dir.z)))

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

func can_move(raycast: RayCast3D) -> bool:
	return !raycast.is_colliding()
	
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
	var bump_direction := Vector3(direction.x, 0.0, direction.y).normalized()
	var end_pos := start_pos + bump_direction * distance
	
	end_pos.y += bump_height

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "global_position", end_pos, duration)
	tween.tween_property(self, "global_position", start_pos, duration * 2)

	await tween.finished
	_moving = false

# Rotation
func rotate_90_degrees(direction: int) -> void:
	_rotating = true

	var target_rotation = rotation.y + deg_to_rad(90.0 * direction)

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
