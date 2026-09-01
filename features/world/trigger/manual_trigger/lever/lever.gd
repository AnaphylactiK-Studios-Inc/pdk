extends ManualTrigger
class_name Lever

@export var on_model: Node3D
@export var off_model: Node3D

func _ready() -> void:
	state_changed.connect(_on_state_changed)
	_on_state_changed(is_on)

func interact_pressed() -> void:
	set_state(!is_on)

func _on_state_changed(value: bool) -> void:
	on_model.visible = value
	off_model.visible = !value
