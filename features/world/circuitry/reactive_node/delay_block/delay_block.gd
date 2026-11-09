extends ReactiveNode
class_name DelayBlock

@export_range(0.0, 10.0, 0.01, "or_greater") var delay: float = 3.0
@export var prism: MeshInstance3D

var _level_tween: Tween
var _pulse_tween: Tween

func _ready() -> void:
	var bounds := prism.mesh.get_aabb()
	prism.set_instance_shader_parameter("bottom_height", bounds.position.y)
	prism.set_instance_shader_parameter("top_height", bounds.end.y)

	super._ready()

func process_inputs() -> void:
	if !_inputs_satisfied():
		if _level_tween != null:
			_level_tween.kill()
			_level_tween = null
			finish_execution()

		_set_progress(0.0)
		set_state(false)

	elif !is_on and _level_tween == null:
		begin_execution()
		_level_tween = _create_progress_tween(_set_progress, _on_level_finished)

func _on_level_finished() -> void:
	_level_tween = null
	set_state(true)
	finish_execution()

func _on_activation_received() -> void:
	if _pulse_tween != null:
		return

	begin_execution()
	_pulse_tween = _create_progress_tween(_set_pulse_progress, _on_pulse_finished)

func _on_pulse_finished() -> void:
	_pulse_tween = null
	activate()
	_set_pulse_progress(0.0)
	finish_execution()

func _create_progress_tween(setter: Callable, on_finished: Callable) -> Tween:
	var tween := create_tween()
	tween.tween_method(setter, 0.0, 1.0, delay)
	tween.tween_callback(on_finished)
	return tween

func _set_progress(value: float) -> void:
	prism.set_instance_shader_parameter("progress", value)

func _set_pulse_progress(value: float) -> void:
	prism.set_instance_shader_parameter("pulse_progress", value)
