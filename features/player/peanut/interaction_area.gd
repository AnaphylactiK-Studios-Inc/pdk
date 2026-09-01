extends Area3D

var current_trigger: ManualTrigger = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	var trigger := find_manual_trigger(body)

	if trigger != null:
		current_trigger = trigger

func _on_body_exited(body: Node3D) -> void:
	var trigger := find_manual_trigger(body)

	if trigger == current_trigger:
		if current_trigger:
			current_trigger.interact_released()
			
		current_trigger = null

func find_manual_trigger(node: Node) -> ManualTrigger:
	var current := node

	while current != null:
		if current is ManualTrigger:
			return current

		current = current.get_parent()

	return null

func _process(_delta: float) -> void:
	if current_trigger == null:
		return

	if Input.is_action_just_pressed("interact"):
		current_trigger.interact_pressed()

	if Input.is_action_just_released("interact"):
		current_trigger.interact_released()
