extends Triggerable
class_name Door

@export var left_door: Node3D
@export var right_door: Node3D
@export var open_distance: float = 0.5
@export var open_time: float = 0.5

var left_closed_position: Vector3
var right_closed_position: Vector3

var _tween: Tween

func _ready() -> void:
	super._ready()

	left_closed_position = left_door.position
	right_closed_position = right_door.position

	state_changed.connect(_on_state_changed)

	if is_on:
		left_door.position = left_closed_position + Vector3.LEFT * open_distance
		right_door.position = right_closed_position + Vector3.RIGHT * open_distance

func _on_state_changed(value: bool) -> void:
	if value:
		_open_doors()
	else:
		_close_doors()

func _open_doors() -> void:
	_move_doors(
		left_closed_position + Vector3.LEFT * open_distance,
		right_closed_position + Vector3.RIGHT * open_distance
	)

func _close_doors() -> void:
	_move_doors(left_closed_position, right_closed_position)

func _move_doors(left_target: Vector3, right_target: Vector3) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var duration := open_time
	if open_distance > 0.0:
		var remaining := left_door.position.distance_to(left_target)
		duration = open_time * clampf(remaining / open_distance, 0.0, 1.0)

	if is_zero_approx(duration):
		left_door.position = left_target
		right_door.position = right_target
		return

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)

	_tween.parallel().tween_property(
		left_door,
		"position",
		left_target,
		duration
	)

	_tween.parallel().tween_property(
		right_door,
		"position",
		right_target,
		duration
	)
