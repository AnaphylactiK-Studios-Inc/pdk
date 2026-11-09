extends ReactiveNode
class_name Door

@export var left_door: Node3D
@export var right_door: Node3D
@export var open_distance: float = 0.5
@export var open_time: float = 0.5

var left_closed_position: Vector3
var right_closed_position: Vector3

var _tween: Tween
var _pulse_pending := false

func _ready() -> void:
	left_closed_position = left_door.position
	right_closed_position = right_door.position

	state_changed.connect(_on_state_changed)

	super._ready()

func process_inputs() -> void:
	set_state(_inputs_satisfied())

func _on_state_changed(value: bool) -> void:
	_move_doors(value)

func _on_activation_received() -> void:
	if is_on:
		activate()
		return

	_move_doors(true, true)

func _move_doors(open: bool, pulse: bool = false) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
		_flush_pulse()
		finish_execution()

	var left_target := left_closed_position
	var right_target := right_closed_position

	if open:
		left_target += Vector3.LEFT * open_distance
		right_target += Vector3.RIGHT * open_distance

	var duration := open_time

	if open_distance > 0.0:
		var remaining := left_door.position.distance_to(left_target)
		duration *= clampf(remaining / open_distance, 0.0, 1.0)

	if is_zero_approx(duration) and !pulse:
		left_door.position = left_target
		right_door.position = right_target
		return

	begin_execution()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)

	_tween.tween_property(left_door, "position", left_target, duration)
	_tween.parallel().tween_property(right_door, "position", right_target, duration)

	if pulse:
		_pulse_pending = true
		_tween.tween_callback(_flush_pulse)
		_tween.tween_property(left_door, "position", left_closed_position, open_time)
		_tween.parallel().tween_property(right_door, "position", right_closed_position, open_time)

	_tween.finished.connect(finish_execution)

func _flush_pulse() -> void:
	if !_pulse_pending:
		return

	_pulse_pending = false
	activate()
