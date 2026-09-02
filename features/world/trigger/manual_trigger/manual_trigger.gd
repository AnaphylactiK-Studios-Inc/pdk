extends Trigger
class_name ManualTrigger

signal interaction_started
signal interaction_ended

func interact_pressed() -> void:
	interaction_started.emit()

func interact_released() -> void:
	interaction_ended.emit()
