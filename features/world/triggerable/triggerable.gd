extends Node3D
class_name Triggerable

signal state_changed(is_on: bool)

@export var triggers: Array[Trigger] = []

@export var is_on: bool = false

func _ready() -> void:
	for trigger in triggers:
		if trigger == null:
			push_warning("%s has an empty entry in its triggers array." % name)
			continue

		trigger.state_changed.connect(_on_trigger_state_changed)

	_update_state()

func _on_trigger_state_changed(_value: bool) -> void:
	_update_state()

func _update_state() -> void:
	if triggers.is_empty():
		set_state(false)
		return

	for trigger in triggers:
		if trigger == null or !trigger.is_on:
			set_state(false)
			return

	set_state(true)

func set_state(value: bool) -> void:
	if is_on == value:
		return

	is_on = value
	state_changed.emit(is_on)
