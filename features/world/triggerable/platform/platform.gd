extends Triggerable
class_name Platform

@export var platform: Node3D
@export var move_height: float = 1.0
@export var duration: float = 1.0

var start_pos: Vector3

var _tween: Tween

func _ready() -> void:
	super._ready()
	start_pos = platform.position

	state_changed.connect(_on_state_changed)
	_on_state_changed(is_on)

func _on_state_changed(value: bool) -> void:
	if value:
		_lift_platform()
	else:
		_lower_platform()

func _lift_platform() -> void:
	_move_platform(start_pos + Vector3.UP * move_height)

func _lower_platform() -> void:
	_move_platform(start_pos)

func _move_platform(target: Vector3) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var move_time := duration
	if move_height != 0.0:
		var remaining := platform.position.distance_to(target)
		move_time = duration * clampf(remaining / absf(move_height), 0.0, 1.0)

	if is_zero_approx(move_time):
		platform.position = target
		return

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)

	_tween.tween_property(
		platform, "position", target, move_time
	)
