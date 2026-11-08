extends CircuitNode
class_name ReactiveNode

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
