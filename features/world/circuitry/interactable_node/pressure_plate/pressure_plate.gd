extends InteractableNode
class_name PressurePlate

@export var unpressed_model: Node3D
@export var pressed_model: Node3D

@onready var area: Area3D = $Area3D

var overlapping_bodies: Array[Node3D] = []

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	state_changed.connect(_on_state_changed)
	_on_state_changed(is_on)

func _on_body_entered(body: Node3D) -> void:
	if !overlapping_bodies.has(body):
		overlapping_bodies.append(body)

	_update_state()

func _on_body_exited(body: Node3D) -> void:
	overlapping_bodies.erase(body)
	_update_state()

func _update_state() -> void:
	set_state(!overlapping_bodies.is_empty())

func _on_state_changed(value: bool) -> void:
	unpressed_model.visible = !value
	pressed_model.visible = value
