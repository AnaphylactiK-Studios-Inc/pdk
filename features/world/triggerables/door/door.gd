extends Triggerable
class_name Door

@export var left_door: Node3D
@export var right_door: Node3D
@export var open_distance: float = 0.5
@export var open_time: float = 0.5

var left_closed_position: Vector3
var right_closed_position: Vector3

func _ready() -> void:
	super._ready()

	left_closed_position = left_door.position
	right_closed_position = right_door.position

	state_changed.connect(_on_state_changed)
	_on_state_changed(is_on)

func _on_state_changed(value: bool) -> void:
	if value:
		_open_doors()
	else:
		_close_doors()

func _open_doors() -> void:
	var left_open_position := left_closed_position + Vector3.LEFT * open_distance
	var right_open_position := right_closed_position + Vector3.RIGHT * open_distance

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.parallel().tween_property(
		left_door,
		"position",
		left_open_position,
		open_time
	)

	tween.parallel().tween_property(
		right_door,
		"position",
		right_open_position,
		open_time
	)

func _close_doors() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.parallel().tween_property(
		left_door,
		"position",
		left_closed_position,
		open_time
	)

	tween.parallel().tween_property(
		right_door,
		"position",
		right_closed_position,
		open_time
	)
