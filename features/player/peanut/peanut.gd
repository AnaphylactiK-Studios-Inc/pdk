extends CharacterBody3D


const SPEED = 3.0
const JUMP_VELOCITY = 4.5
const ROTATION_SPEED = 20.0
const LAND_LENGTH = 0.5

# Jump phases
enum State { GROUNDED, JUMP_START, AIR, LAND }

@onready var model: Node3D = $peanut
@onready var anim: AnimationPlayer = $peanut/AnimationPlayer

var state: State = State.GROUNDED


func _ready() -> void:
	if anim.has_animation("jump_mid_air"):
		anim.get_animation("jump_mid_air").loop_mode = Animation.LOOP_LINEAR
	if anim.has_animation("jump_start"):
		anim.get_animation("jump_start").loop_mode = Animation.LOOP_NONE
	if anim.has_animation("land"):
		var land := anim.get_animation("land")
		land.loop_mode = Animation.LOOP_NONE
		land.length = LAND_LENGTH


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	if not on_floor:
		velocity += get_gravity() * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative_direction(input_dir)

	if Input.is_action_just_pressed("jump") and on_floor and (state == State.GROUNDED or state == State.LAND):
		velocity.y = JUMP_VELOCITY
		state = State.JUMP_START
		anim.play("jump_start")
	elif on_floor and velocity.y <= 0.0 and (state == State.JUMP_START or state == State.AIR):
		if direction:
			state = State.GROUNDED
		else:
			state = State.LAND
			anim.play("land")
	elif state == State.JUMP_START and _clip_finished():
		state = State.AIR
		anim.play("jump_mid_air")
	elif state == State.LAND and (direction or _clip_finished()):
		state = State.GROUNDED

	# Handle the movement/deceleration.
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED

		var target_yaw := atan2(direction.x, direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, ROTATION_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	_update_animation(direction)

	move_and_slide()
	
# Turn raw WASD input into a world-space direction relative to where the camera
# is looking, so "forward" always means away from the camera as it orbits.
func _camera_relative_direction(input_dir: Vector2) -> Vector3:
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		# No active camera: fall back to world-relative movement.
		return Vector3(input_dir.x, 0, input_dir.y).normalized()

	var cam_basis := cam.global_transform.basis

	# Flatten the camera's forward/right onto the ground plane. basis.z points
	# back toward the camera, so pressing forward (input_dir.y = -1) moves the
	# character away from it.
	var forward := cam_basis.z
	forward.y = 0
	forward = forward.normalized()

	var right := cam_basis.x
	right.y = 0
	right = right.normalized()

	return (right * input_dir.x + forward * input_dir.y).normalized()


func _clip_finished() -> bool:
	return anim.current_animation_position >= anim.current_animation_length


func _update_animation(direction: Vector3) -> void:
	if state != State.GROUNDED:
		return
	var want := "run" if direction else "idle"
	if anim.current_animation != want:
		anim.play(want)
