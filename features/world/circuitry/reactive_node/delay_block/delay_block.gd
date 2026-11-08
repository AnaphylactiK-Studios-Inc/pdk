extends ReactiveNode
class_name DelayBlock

@export var delay: float = 3.0
@export var prism: MeshInstance3D

var timer: Timer
var activation_timer: Timer

var prism_material: ShaderMaterial
var progress_tween: Tween

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
	var bounds: AABB = prism.mesh.get_aabb()

	var shader := Shader.new()

	shader.code = """
	shader_type spatial;
	render_mode blend_mix;

	uniform vec4 off_color : source_color = vec4(0.5725, 0.1490, 0.0, 0.6627);
	uniform vec4 on_color : source_color = vec4(1.0, 0.25, 0.0, 1.0);

	uniform float progress : hint_range(0.0, 1.0) = 0.0;
	uniform float bottom_height;
	uniform float top_height;

	varying float local_height;

	void vertex() {
		local_height = VERTEX.y;
	}

	void fragment() {
		float height = (local_height - bottom_height) / (top_height - bottom_height);

		float band_width = 0.04;
		float band = (1.0 - smoothstep(
			band_width,
			band_width + 0.015,
			abs(height - progress)
		)) * step(0.001, progress);

		float intensity = band;

		vec3 color = mix(off_color.rgb, on_color.rgb, intensity);

		ALBEDO = color;
		ALPHA = mix(off_color.a, on_color.a, intensity);
		EMISSION = mix(off_color.rgb, on_color.rgb, band) * band * 3.0;
	}
	"""

	prism_material = ShaderMaterial.new()
	prism_material.shader = shader

	prism_material.set_shader_parameter("bottom_height", bounds.position.y)
	prism_material.set_shader_parameter("top_height", bounds.end.y)

	prism.material_override = prism_material


func _start_progress() -> void:
	_reset_progress()

	progress_tween = create_tween()
	progress_tween.set_trans(Tween.TRANS_LINEAR)
	progress_tween.set_ease(Tween.EASE_IN_OUT)

	progress_tween.tween_method(
		_set_progress,
		0.0,
		1.0,
		delay
	)


func _set_progress(value: float) -> void:
	progress = value
	prism_material.set_shader_parameter("progress", progress)


func _reset_progress() -> void:
	if progress_tween != null and progress_tween.is_valid():
		progress_tween.kill()

	progress = 0.0
	prism_material.set_shader_parameter("progress", progress)


func process_inputs() -> void:
	if inputs.is_empty():
		_on_trigger_state_changed(false)
		return

	for input in inputs:
		if input == null or !input.is_on:
			_on_trigger_state_changed(false)
			return

	_on_trigger_state_changed(true)


func _on_trigger_state_changed(value: bool) -> void:
	if !value:
		timer.stop()
		_reset_progress()

		if is_executing:
			finish_execution()

		set_state(false)

	elif !is_on and timer.is_stopped():
		begin_execution()
		_start_progress()
		timer.start(delay)


func _on_timeout() -> void:
	set_state(true)
	finish_execution()


func _on_activation_received() -> void:
	if activation_timer.is_stopped():
		begin_execution()
		_start_progress()
		activation_timer.start(delay)


func _on_activation_timeout() -> void:
	activate()
	_reset_progress()
	finish_execution()
