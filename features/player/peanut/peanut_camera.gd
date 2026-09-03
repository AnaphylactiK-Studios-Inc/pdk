class_name PeanutCamera
extends Node3D

## Free-look third-person orbit camera for Peanut. Dreadnought Killer moves on
## a grid and carries its own fixed camera, so the two don't share a rig.
##
## Mouse and right stick are both live at once, with no mode to switch.

signal capture_changed(captured: bool)

## Degrees per pixel of mouse travel, at the ends of the sensitivity slider.
const MOUSE_DEGREES_PER_PIXEL := Vector2(0.03, 0.30)
## Degrees per second at full stick deflection, at the ends of the slider.
const STICK_DEGREES_PER_SECOND := Vector2(70.0, 420.0)
const STICK_DEADZONE := 0.12

@export_group("Target")
## Left empty, the camera takes the first node in the "peanut" group.
@export var target: Node3D
@export var pivot_offset := Vector3(0.0, 0.35, 0.0)
@export var follow_sharpness := 12.0
## Kept slower than the horizontal rate so stairs and hops don't jolt the frame.
@export var vertical_follow_sharpness := 7.0

@export_group("Framing")
@export var distance := 2.2
## Positive puts Peanut left of centre, the usual over-the-shoulder look.
@export var shoulder_offset := 0.18
@export var spring_margin := 0.08

@export_group("Look")
@export_range(-89.0, 89.0) var pitch_min := -60.0
@export_range(-89.0, 89.0) var pitch_max := 25.0
@export var starting_pitch := -12.0
@export var invert_mouse_y := false
@export var invert_stick_y := false
## Above 1.0 buys fine control near centre, full speed still at the edge.
@export_range(1.0, 3.0) var stick_response_curve := 1.8

@export_group("Mouse")
@export var capture_mouse := true
## Escape drops the cursor, a click takes it back. Turn off once a pause menu
## owns that job.
@export var release_on_ui_cancel := true

@onready var spring_arm: SpringArm3D = $SpringArm3D
## SpringArm3D overwrites its direct children's positions, so the camera hangs
## one node further down and keeps its shoulder offset.
@onready var camera: Camera3D = $SpringArm3D/ArmEnd/Camera3D

var _yaw := 0.0
var _pitch := 0.0
var _mouse_delta := Vector2.ZERO
var _has_settings := false


func _ready() -> void:
	_has_settings = get_tree().root.has_node("SettingsManager")

	if target == null:
		target = _find_peanut()

	_yaw = rotation.y
	_pitch = deg_to_rad(clampf(starting_pitch, pitch_min, pitch_max))

	spring_arm.spring_length = distance
	spring_arm.margin = spring_margin
	camera.position.x = shoulder_offset

	# Otherwise the arm collides with Peanut and slams the camera into her back.
	if target is CollisionObject3D:
		spring_arm.add_excluded_object((target as CollisionObject3D).get_rid())

	if target != null:
		global_position = _pivot_position()
	_apply_rotation()

	# Follow after the target has moved, whatever order the scene lists them in.
	process_physics_priority = 100

	set_captured(capture_mouse)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		capture_changed.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_mouse_delta += (event as InputEventMouseMotion).relative
		return

	if not release_on_ui_cancel:
		return

	if event.is_action_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		set_captured(false)
	elif event is InputEventMouseButton and event.pressed \
			and capture_mouse and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		set_captured(true)


## Look runs every drawn frame so mouse aim stays as responsive as the display.
func _process(delta: float) -> void:
	_apply_look(delta)


## Following runs on the physics tick instead, because the goal it chases only
## changes on the physics tick. Smoothing toward a stepped goal at render rate
## leaves the camera still drifting on the frames where Peanut is frozen, which
## reads as Peanut shimmering against the background.
func _physics_process(delta: float) -> void:
	_follow(delta)


# --- Public API ---

func look_along(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		return
	# The camera looks down -Z, so yaw is the heading of the reversed vector.
	_yaw = atan2(-flat.x, -flat.z)
	_apply_rotation()


## Call after teleporting Peanut, so the camera doesn't fly across the level.
func snap_to_target() -> void:
	if target == null:
		return
	global_position = _pivot_position()


func set_captured(captured: bool) -> void:
	var mode := Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode == mode:
		return
	Input.mouse_mode = mode
	_mouse_delta = Vector2.ZERO
	capture_changed.emit(captured)


# --- Look ---

func _apply_look(delta: float) -> void:
	var look := _mouse_look() + _stick_look(delta)
	_mouse_delta = Vector2.ZERO

	if look == Vector2.ZERO:
		return

	_yaw -= look.x
	_pitch = clampf(_pitch - look.y, deg_to_rad(pitch_min), deg_to_rad(pitch_max))
	_apply_rotation()


## Mouse motion is already a distance, so it is deliberately not delta-scaled.
func _mouse_look() -> Vector2:
	if _mouse_delta == Vector2.ZERO:
		return Vector2.ZERO

	# Named per_pixel because `scale` would shadow Node3D.scale.
	var per_pixel := deg_to_rad(
		lerpf(MOUSE_DEGREES_PER_PIXEL.x, MOUSE_DEGREES_PER_PIXEL.y, _mouse_sensitivity())
	)
	var look := _mouse_delta * per_pixel
	if invert_mouse_y:
		look.y = -look.y
	return look


func _stick_look(delta: float) -> Vector2:
	var raw := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if raw.length() < STICK_DEADZONE:
		return Vector2.ZERO

	# Curve the magnitude, not each axis, so diagonals aren't slower.
	var magnitude: float = pow(minf(raw.length(), 1.0), stick_response_curve)
	var direction := raw.normalized()

	var speed := Vector2(
		deg_to_rad(lerpf(
			STICK_DEGREES_PER_SECOND.x, STICK_DEGREES_PER_SECOND.y, _stick_sensitivity_x()
		)),
		deg_to_rad(lerpf(
			STICK_DEGREES_PER_SECOND.x, STICK_DEGREES_PER_SECOND.y, _stick_sensitivity_y()
		)),
	)

	var look := direction * magnitude * speed * delta
	if invert_stick_y:
		look.y = -look.y
	return look


func _apply_rotation() -> void:
	rotation.y = _yaw
	spring_arm.rotation.x = _pitch


# --- Follow ---

func _follow(delta: float) -> void:
	if target == null:
		return

	var goal := _pivot_position()
	var current := global_position

	var horizontal := Vector2(current.x, current.z).lerp(
		Vector2(goal.x, goal.z), 1.0 - exp(-follow_sharpness * delta)
	)
	var vertical := lerpf(current.y, goal.y, 1.0 - exp(-vertical_follow_sharpness * delta))

	global_position = Vector3(horizontal.x, vertical, horizontal.y)


func _pivot_position() -> Vector3:
	return target.global_position + pivot_offset


# --- Settings ---

## Guarded: the scene can be run on its own, without the autoload.
func _mouse_sensitivity() -> float:
	return SettingsManager.mouse_sensitivity if _has_settings else 0.5


func _stick_sensitivity_x() -> float:
	return SettingsManager.stick_sensitivity_x if _has_settings else 0.5


func _stick_sensitivity_y() -> float:
	return SettingsManager.stick_sensitivity_y if _has_settings else 0.5


func _find_peanut() -> Node3D:
	for node in get_tree().get_nodes_in_group("peanut"):
		if node is Node3D:
			return node
	push_warning("PeanutCamera: no target set and nothing in the \"peanut\" group.")
	return null
