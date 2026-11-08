extends ReactiveNode
class_name Wire

@export var wire_cylinder: MeshInstance3D
@export var delay: float = 0.5
@export_range(0.01, 0.5) var pulse_length: float = 0.05

var timer: Timer
var activation_timer: Timer

var wire_material: ShaderMaterial
var progress_tween: Tween
var activation_tween: Tween

var progress := 0.0

func _ready() -> void:
	_setup_material()

	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_on_timeout)

	activation_timer = Timer.new()
	activation_timer.one_shot = true
	add_child(activation_timer)
	activation_timer.timeout.connect(_on_activation_timeout)

	super._ready()

func _setup_material() -> void:
	var shader := Shader.new()

	shader.code = """
shader_type spatial;
render_mode blend_mix;

uniform vec4 off_color : source_color = vec4(0.5725, 0.1490, 0.0, 0.6627);
uniform vec4 on_color : source_color = vec4(1.0, 0.25, 0.0, 1.0);

uniform float progress : hint_range(0.0, 1.0) = 0.0;

uniform float pulse_progress = -0.15;
uniform float pulse_length = 0.15;
uniform float pulse_active = 0.0;

void fragment() {
	float wire_position = 1.0 - UV.y;

	float continuous_lit = step(wire_position, progress);

	float pulse_lit = step(pulse_progress, wire_position)
		* step(wire_position, pulse_progress + pulse_length)
		* pulse_active;

	float lit = max(continuous_lit, pulse_lit);

	ALBEDO = mix(off_color.rgb, on_color.rgb, lit);
	ALPHA = mix(off_color.a, on_color.a, lit);

	EMISSION = on_color.rgb * 3.0 * lit;
}
"""

	wire_material = ShaderMaterial.new()
	wire_material.shader = shader
	wire_material.set_shader_parameter("pulse_length", pulse_length)

	wire_cylinder.material_override = wire_material

func process_inputs() -> void:
	var should_be_on := !inputs.is_empty()

	for input in inputs:
		if input == null or !input.is_on:
			should_be_on = false
			break

	if should_be_on:
		if is_on or !timer.is_stopped():
			return

		begin_execution()
		timer.start(delay)
		_animate_progress(1.0)
	else:
		timer.stop()

		if progress_tween != null and progress_tween.is_valid():
			progress_tween.kill()

		_set_progress(0.0)
		set_state(false)

		if is_executing:
			finish_execution()

func _on_timeout() -> void:
	set_state(true)
	finish_execution()
	
func _on_activation_received() -> void:
	if !activation_timer.is_stopped():
		return

	begin_execution()
	_animate_activation()
	activation_timer.start(delay)

func _on_activation_timeout() -> void:
	activate()
	finish_execution()

func _animate_progress(target: float) -> void:
	if progress_tween != null and progress_tween.is_valid():
		progress_tween.kill()

	progress_tween = create_tween()
	progress_tween.set_trans(Tween.TRANS_SINE)
	progress_tween.set_ease(Tween.EASE_IN_OUT)

	progress_tween.tween_method(
		_set_progress,
		progress,
		target,
		delay
	)

func _animate_activation() -> void:
	if activation_tween != null and activation_tween.is_valid():
		activation_tween.kill()

	wire_material.set_shader_parameter("pulse_active", 1.0)
	wire_material.set_shader_parameter("pulse_progress", -pulse_length)

	activation_tween = create_tween()

	activation_tween.tween_method(
		_set_pulse_progress,
		-pulse_length,
		1.0,
		delay
	)

	activation_tween.finished.connect(func():
		wire_material.set_shader_parameter("pulse_active", 0.0)
	)

func _set_progress(value: float) -> void:
	progress = value
	wire_material.set_shader_parameter("progress", progress)

func _set_pulse_progress(value: float) -> void:
	wire_material.set_shader_parameter("pulse_progress", value)
