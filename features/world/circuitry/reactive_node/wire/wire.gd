extends ReactiveNode
class_name Wire

@export var wire_cylinder: MeshInstance3D
@export_range(0.0, 5.0, 0.01, "or_greater") var delay: float = 0.5
@export_range(0.01, 0.5) var pulse_length: float = 0.05

var progress := 0.0

var _fill_tween: Tween
var _pulse_tween: Tween

func _ready() -> void:
	wire_cylinder.set_instance_shader_parameter("pulse_length", pulse_length)

	super._ready()

func process_inputs() -> void:
	if _inputs_satisfied():
		if is_on or _fill_tween != null:
			return

		begin_execution()

		_fill_tween = create_tween()
		_fill_tween.set_trans(Tween.TRANS_SINE)
		_fill_tween.set_ease(Tween.EASE_IN_OUT)
		_fill_tween.tween_method(_set_progress, progress, 1.0, delay)
		_fill_tween.tween_callback(_on_fill_finished)
	else:
		if _fill_tween != null:
			_fill_tween.kill()
			_fill_tween = null
			finish_execution()

		_set_progress(0.0)
		set_state(false)

func _on_fill_finished() -> void:
	_fill_tween = null
	set_state(true)
	finish_execution()

func _on_activation_received() -> void:
	if _pulse_tween != null:
		return

	begin_execution()
	wire_cylinder.set_instance_shader_parameter("pulse_active", 1.0)

	_pulse_tween = create_tween()
	_pulse_tween.tween_method(_set_pulse_progress, -pulse_length, 1.0, delay)
	_pulse_tween.tween_callback(_on_pulse_finished)

func _on_pulse_finished() -> void:
	_pulse_tween = null
	wire_cylinder.set_instance_shader_parameter("pulse_active", 0.0)
	activate()
	finish_execution()

func _set_progress(value: float) -> void:
	progress = value
	wire_cylinder.set_instance_shader_parameter("progress", progress)

func _set_pulse_progress(value: float) -> void:
	wire_cylinder.set_instance_shader_parameter("pulse_progress", value)
