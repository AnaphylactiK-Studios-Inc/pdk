extends ReactiveNode
class_name SignalSustainer

@export_range(0.0, 30.0, 0.01, "or_greater") var duration: float = 5.0
@export var mesh: MeshInstance3D

var _hold_tween: Tween

func _ready() -> void:
	var bounds := mesh.mesh.get_aabb()
	mesh.set_instance_shader_parameter("bottom_height", bounds.position.y)
	mesh.set_instance_shader_parameter("top_height", bounds.end.y)

	super._ready()

func process_inputs() -> void:
	if _inputs_satisfied():
		_stop_hold()
		set_state(true)
		_set_progress(1.0)
	elif is_on and _hold_tween == null:
		_start_hold()

func _on_activation_received() -> void:
	set_state(true)
	_stop_hold()

	if _inputs_satisfied():
		_set_progress(1.0)
	else:
		_start_hold()

func _start_hold() -> void:
	begin_execution()

	_hold_tween = create_tween()
	_hold_tween.tween_method(_set_progress, 1.0, 0.0, duration)
	_hold_tween.tween_callback(_on_hold_finished)

func _stop_hold() -> void:
	if _hold_tween == null:
		return

	_hold_tween.kill()
	_hold_tween = null
	finish_execution()

func _on_hold_finished() -> void:
	_hold_tween = null
	set_state(false)
	finish_execution()

func _set_progress(value: float) -> void:
	mesh.set_instance_shader_parameter("progress", value)
