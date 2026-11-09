extends ReactiveNode
class_name Platform

@export var platform: Node3D
@export var move_height: float = 1.0
@export var duration: float = 1.0

var start_pos: Vector3

var _tween: Tween
var _pulse_pending := false

func _ready() -> void:
	start_pos = platform.position

	state_changed.connect(_on_state_changed)

	super._ready()

func process_inputs() -> void:
	set_state(_inputs_satisfied())

func _on_state_changed(value: bool) -> void:
	_move_platform(value)

func _on_activation_received() -> void:
	if is_on:
		activate()
		return

	_move_platform(true, true)

func _move_platform(raised: bool, pulse: bool = false) -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
		_flush_pulse()
		finish_execution()

	var target := start_pos + Vector3.UP * move_height if raised else start_pos

	var move_time := duration
	if move_height != 0.0:
		var remaining := platform.position.distance_to(target)
		move_time *= clampf(remaining / absf(move_height), 0.0, 1.0)

	if is_zero_approx(move_time) and !pulse:
		platform.position = target
		return

	begin_execution()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(platform, "position", target, move_time)

	if pulse:
		_pulse_pending = true
		_tween.tween_callback(_flush_pulse)
		_tween.tween_property(platform, "position", start_pos, duration)

	_tween.tween_callback(_on_tween_finished)

func _on_tween_finished() -> void:
	_tween = null
	finish_execution()

func _flush_pulse() -> void:
	if !_pulse_pending:
		return

	_pulse_pending = false
	activate()
