extends Node3D
class_name CircuitNode

signal state_changed(is_on: bool)
signal activation_received
signal execution_started
signal execution_finished

var is_on := false
var is_executing: bool:
	get:
		return _execution_count > 0

var _execution_count := 0

var outputs: Array[CircuitNode] = []

func process_inputs() -> void:
	pass

func set_state(value: bool) -> void:
	if is_on == value:
		return

	is_on = value
	state_changed.emit(is_on)

func is_steady_source() -> bool:
	return true

func activate() -> void:
	activation_received.emit()

func begin_execution() -> void:
	_execution_count += 1

	if _execution_count == 1:
		execution_started.emit()

func finish_execution() -> void:
	if _execution_count == 0:
		return

	_execution_count -= 1

	if _execution_count == 0:
		execution_finished.emit()
