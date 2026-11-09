extends Area3D

signal interacted

func set_enabled(enabled: bool) -> void:
	set_process_unhandled_input(enabled)

func _unhandled_input(event: InputEvent) -> void:
	if !event.is_action_pressed("interact") or event.is_echo():
		return

	var node := _find_nearest_node()
	if node == null:
		return

	get_viewport().set_input_as_handled()
	node.interact()
	interacted.emit()

func _find_nearest_node() -> InteractableNode:
	var nearest: InteractableNode = null
	var nearest_distance := INF
	var origin := global_position

	for body in get_overlapping_bodies():
		var node := find_interactable_node(body)
		if node == null:
			continue

		var distance := origin.distance_squared_to(node.global_position)

		if distance < nearest_distance:
			nearest = node
			nearest_distance = distance

	return nearest

func find_interactable_node(node: Node) -> InteractableNode:
	var current := node

	while current:
		if current is InteractableNode:
			return current
		current = current.get_parent()

	return null
