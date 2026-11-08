
extends InteractableNode
class_name Button3D

@export var unpressed_model: Node3D
@export var pressed_model: Node3D

var tracked_nodes: Array[CircuitNode] = []
var active_nodes: Array[CircuitNode] = []
var is_pressed := false

func _ready() -> void:
	_on_state_changed(false)

func interact() -> void:
	if is_pressed:
		return

	is_pressed = true
	_on_state_changed(true)

	tracked_nodes.clear()
	active_nodes.clear()

	_collect_downstream(self)

	for node in tracked_nodes:
		node.execution_started.connect(_on_node_execution_started.bind(node))
		node.execution_finished.connect(_on_node_execution_finished.bind(node))

	for output in outputs:
		if output != null:
			output.receive_activation()

	call_deferred("_check_completion")

func _collect_downstream(node: CircuitNode) -> void:
	for output in node.outputs:
		if output == null or tracked_nodes.has(output):
			continue

		tracked_nodes.append(output)
		_collect_downstream(output)

func _on_node_execution_started(node: CircuitNode) -> void:
	if !active_nodes.has(node):
		active_nodes.append(node)
		print("[Button] Node started executing: ", node.name)

func _on_node_execution_finished(node: CircuitNode) -> void:
	active_nodes.erase(node)
	call_deferred("_check_completion")

func _check_completion() -> void:
	if !is_pressed or !active_nodes.is_empty():
		return

	for node in tracked_nodes:
		if node.is_executing:
			return

	print("[Button] Turning OFF.")
	is_pressed = false
	_on_state_changed(false)
	_disconnect_nodes()

func _disconnect_nodes() -> void:
	for node in tracked_nodes:
		var started_callback := _on_node_execution_started.bind(node)
		var finished_callback := _on_node_execution_finished.bind(node)

		if node.execution_started.is_connected(started_callback):
			node.execution_started.disconnect(started_callback)

		if node.execution_finished.is_connected(finished_callback):
			node.execution_finished.disconnect(finished_callback)

	tracked_nodes.clear()
	active_nodes.clear()

func _on_state_changed(value: bool) -> void:
	unpressed_model.visible = !value
	pressed_model.visible = value
