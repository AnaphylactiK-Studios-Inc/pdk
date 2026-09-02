extends Area3D

var current_trigger: ManualTrigger = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func interact_pressed() -> void:
	if current_trigger:
		current_trigger.interact_pressed()

func interact_released() -> void:
	if current_trigger:
		current_trigger.interact_released()

func _on_body_entered(body: Node3D) -> void:
	var trigger := find_manual_trigger(body)
	if trigger:
		current_trigger = trigger

func _on_body_exited(body: Node3D) -> void:
	var trigger := find_manual_trigger(body)
	
	if current_trigger and trigger == current_trigger:
		current_trigger.interact_released()
		current_trigger = null

func find_manual_trigger(node: Node) -> ManualTrigger:
	var current := node

	while current:
		if current is ManualTrigger:
			return current
		current = current.get_parent()

	return null
