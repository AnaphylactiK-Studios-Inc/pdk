extends Area3D

var current_node: InteractableNode = null

signal interacted

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func set_enabled(enabled: bool) -> void:
	set_process_unhandled_input(enabled)

func _physics_process(_delta: float) -> void:
	current_node = _find_nearest_node()

func _on_body_entered(_body: Node3D) -> void:
	current_node = _find_nearest_node()

func _on_body_exited(_body: Node3D) -> void:
	current_node = _find_nearest_node()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and !event.is_echo():
		current_node = _find_nearest_node()

		if current_node == null:
			return

		get_viewport().set_input_as_handled()
		current_node.interact()
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
