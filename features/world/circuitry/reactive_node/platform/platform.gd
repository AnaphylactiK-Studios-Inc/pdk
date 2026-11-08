extends ReactiveNode
class_name Platform

@export var platform: Node3D
@export var move_height: float = 1.0
@export var duration: float = 1.0

var start_pos: Vector3
var activation_mode := false

var _tween: Tween

func _ready() -> void:
	start_pos = platform.position

	state_changed.connect(_on_state_changed)
	activation_received.connect(_on_activation_received)

	super._ready()

	if is_on:
		platform.position = start_pos + Vector3.UP * move_height

func process_inputs() -> void:
	set_state(!inputs.is_empty() and inputs.all(func(input): return input != null and input.is_on))

func _on_state_changed(value: bool) -> void:
	if value:
		_move_platform(start_pos + Vector3.UP * move_height)
	else:
		_move_platform(start_pos)

func _on_activation_received() -> void:
	if is_executing:
		return

	activation_mode = true
	_move_platform(start_pos + Vector3.UP * move_height)

func _move_platform(target: Vector3) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
		finish_execution()

	var move_time := duration
	if move_height != 0.0:
		var remaining := platform.position.distance_to(target)
		move_time = duration * clampf(remaining / absf(move_height), 0.0, 1.0)

	if is_zero_approx(move_time):
		platform.position = target
		_on_movement_finished(target)
		return

	begin_execution()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(platform, "position", target, move_time)
	_tween.finished.connect(_on_movement_finished.bind(target))

func _on_movement_finished(target: Vector3) -> void:
	finish_execution()

	if activation_mode and target != start_pos:
		_move_platform(start_pos)
	elif activation_mode:
		activation_mode = false
