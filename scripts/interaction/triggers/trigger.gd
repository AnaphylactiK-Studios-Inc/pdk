extends Node3D
class_name Trigger

signal state_changed(is_on: bool)

@export var is_on: bool = false

func set_state(value: bool) -> void:
	if is_on == value:
		return
		
	is_on = value
	state_changed.emit(is_on)
