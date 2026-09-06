extends Trigger
class_name PressurePlate

@export var unpressed_model: Node3D
@export var pressed_model: Node3D
@onready var area: Area3D = $Area3D

func _ready() -> void:
	area.body_entered.connect(_update_state)
	area.body_exited.connect(_update_state)

	state_changed.connect(_on_state_changed)
	_on_state_changed(is_on)

func _update_state(_body: Node3D) -> void:
	set_state(area.get_overlapping_bodies().size() > 0)

func _on_state_changed(value: bool) -> void:
	unpressed_model.visible = !value
	pressed_model.visible = value
