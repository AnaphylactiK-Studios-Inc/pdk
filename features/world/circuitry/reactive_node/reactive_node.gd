extends CircuitNode
class_name ReactiveNode

enum InputMode { ALL, ANY }

@export var input_mode := InputMode.ALL
@export var inputs: Array[CircuitNode] = []

func _ready() -> void:
	for input in inputs:
		if input == null:
			push_warning("%s has an empty entry in its inputs array." % name)
			continue

		if !input.outputs.has(self):
			input.outputs.append(self)

		input.state_changed.connect(_on_input_changed)
		input.activation_received.connect(_on_activation_received)

	process_inputs()

func _on_input_changed(_value: bool) -> void:
	process_inputs()

func _on_activation_received() -> void:
	activate()

## Pulse-only inputs (buttons) are ignored, so they can share a node with levers.
func _inputs_satisfied() -> bool:
	var has_steady_input := false
	var any_on := false
	var all_on := true

	for input in inputs:
		if input == null:
			all_on = false
			continue

		if !input.is_steady_source():
			continue

		has_steady_input = true

		if input.is_on:
			any_on = true
		else:
			all_on = false

	if input_mode == InputMode.ANY:
		return any_on

	return has_steady_input and all_on
