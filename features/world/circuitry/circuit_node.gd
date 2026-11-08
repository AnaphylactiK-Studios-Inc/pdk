extends Node3D
class_name CircuitNode

signal state_changed(is_on: bool)
signal activation_received
signal execution_started
signal execution_finished

var is_executing := false
var is_on := false

var outputs: Array[CircuitNode] = []

func process_inputs() -> void:
	pass

func set_state(value: bool) -> void:
	if is_on == value:
		return

	is_on = value
	state_changed.emit(is_on)

func activate() -> void:
	activation_received.emit()

func receive_activation() -> void:
	_on_activation_received()

func _on_activation_received() -> void:
	activate()

func begin_execution() -> void:
	if is_executing:
		return

	is_executing = true
	execution_started.emit()

func finish_execution() -> void:
	if !is_executing:
		return

	is_executing = false
	execution_finished.emit()

func interact() -> void:
	pass
