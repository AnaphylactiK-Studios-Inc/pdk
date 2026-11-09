extends InteractableNode
class_name Button3D

@export var unpressed_model: Node3D
@export var pressed_model: Node3D

var is_pressed := false

var _downstream: Array[CircuitNode] = []

func _ready() -> void:
	_update_model(false)
	_track_downstream.call_deferred()

func is_steady_source() -> bool:
	return false

func interact() -> void:
	if is_pressed:
		return

	is_pressed = true
	_update_model(true)
	activate()

	_check_completion.call_deferred()

func _track_downstream() -> void:
	var path: Array[CircuitNode] = []
	_collect_downstream(self, path)

func _collect_downstream(node: CircuitNode, path: Array[CircuitNode]) -> void:
	for output in node.outputs:
		if output == null:
			continue

		if path.has(output):
			push_warning("%s: circuit loops back into %s, so its pulse will never finish." % [name, output.name])
			continue

		if _downstream.has(output):
			continue

		_downstream.append(output)
		output.execution_finished.connect(_check_completion, CONNECT_DEFERRED)

		path.append(output)
		_collect_downstream(output, path)
		path.pop_back()

func _check_completion() -> void:
	if !is_pressed:
		return

	for node in _downstream:
		if node.is_executing:
			return

	is_pressed = false
	_update_model(false)

func _update_model(pressed: bool) -> void:
	unpressed_model.visible = !pressed
	pressed_model.visible = pressed
