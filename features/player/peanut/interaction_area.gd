extends Area3D

signal interact_started(trigger: ManualTrigger)
signal interact_ended(trigger: ManualTrigger)

var current_trigger: ManualTrigger = null

var _is_holding := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	if _is_holding:
		return

	current_trigger = _find_nearest_trigger()


func _on_body_entered(_body: Node3D) -> void:
	if _is_holding:
		return

	current_trigger = _find_nearest_trigger()


func _on_body_exited(_body: Node3D) -> void:
	var next := _find_nearest_trigger()

	if _is_holding:
		if next == current_trigger:
			return

		_release()

	current_trigger = next


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _is_holding:
			return

		current_trigger = _find_nearest_trigger()
		if current_trigger == null:
			return

		get_viewport().set_input_as_handled()
		_is_holding = true
		current_trigger.interact_pressed()
		interact_started.emit(current_trigger)

	elif event.is_action_released("interact"):
		if not _is_holding:
			return

		get_viewport().set_input_as_handled()
		_release()
		current_trigger = _find_nearest_trigger()


func _release() -> void:
	var released := current_trigger

	if is_instance_valid(released):
		released.interact_released()

	_is_holding = false
	interact_ended.emit(released)


func _find_nearest_trigger() -> ManualTrigger:
	var nearest: ManualTrigger = null
	var nearest_distance := INF
	var origin := global_position

	for body in get_overlapping_bodies():
		var trigger := find_manual_trigger(body)
		if trigger == null:
			continue

		var distance := origin.distance_squared_to(trigger.global_position)
		if distance < nearest_distance:
			nearest = trigger
			nearest_distance = distance

	return nearest


func find_manual_trigger(node: Node) -> ManualTrigger:
	var current := node

	while current:
		if current is ManualTrigger:
			return current
		current = current.get_parent()

	return null
