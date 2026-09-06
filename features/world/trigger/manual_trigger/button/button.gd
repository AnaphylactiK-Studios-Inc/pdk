extends ManualTrigger
class_name Button3D

@export var unpressed_model: Node3D
@export var pressed_model: Node3D

func _ready() -> void:
	interaction_started.connect(_on_interaction_started)
	interaction_ended.connect(_on_interaction_ended)

	state_changed.connect(_on_state_changed)
	_on_state_changed(is_on)

func _on_interaction_started() -> void:
	set_state(true)

func _on_interaction_ended() -> void:
	set_state(false)

func _on_state_changed(value: bool) -> void:
	unpressed_model.visible = !value
	pressed_model.visible = value
