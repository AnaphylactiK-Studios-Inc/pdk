extends Node3D
class_name Triggerable

@export var triggers: Array[Trigger] = []
var is_on: bool = false

signal state_changed(is_on: bool)

func _ready() -> void:
	for trigger in triggers:
		trigger.state_changed.connect(_on_trigger_state_changed)

	_update_state()

func _on_trigger_state_changed(_value: bool) -> void:
	_update_state()

func _update_state() -> void:
	for trigger in triggers:
		if !trigger.is_on:
			set_state(false)
			return

	set_state(true)

func set_state(value: bool) -> void:
	if is_on == value:
		return
		
	is_on = value
	state_changed.emit(is_on)
