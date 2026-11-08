extends ReactiveNode
class_name SignalSustainer

@export var duration: float = 5.0
@export var mesh: MeshInstance3D

var timer: Timer
var mesh_material: ShaderMaterial
var progress_tween: Tween

var progress := 0.0

func _ready() -> void:
	_setup_material()

	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_on_timeout)

	_set_progress(1.0 if is_on else 0.0)

	super._ready()

func _setup_material() -> void:
	var shader := Shader.new()

	shader.code = """
	shader_type spatial;
	render_mode blend_mix;

	uniform vec4 off_color : source_color = vec4(0.5725, 0.1490, 0.0, 0.6627);
	uniform vec4 on_color : source_color = vec4(1.0, 0.25, 0.0, 1.0);

	uniform float progress = 0.0;
	uniform float bottom_height = -0.5;
	uniform float top_height = 0.5;

	varying float local_height;

	void vertex() {
		local_height = VERTEX.y;
	}

	void fragment() {
		float height = (local_height - bottom_height) / (top_height - bottom_height);
		float illuminated = step(1.0 - progress, height) * step(0.001, progress);

		ALBEDO = mix(off_color.rgb, on_color.rgb, illuminated);
		ALPHA = mix(off_color.a, on_color.a, illuminated);
		EMISSION = on_color.rgb * 3.0 * illuminated;
	}
	"""

	mesh_material = ShaderMaterial.new()
	mesh_material.shader = shader
	mesh.material_override = mesh_material

	var bounds := mesh.mesh.get_aabb()
	mesh_material.set_shader_parameter("bottom_height", bounds.position.y)
	mesh_material.set_shader_parameter("top_height", bounds.position.y + bounds.size.y)
	mesh_material.set_shader_parameter("progress", progress)

func _set_progress(value: float) -> void:
	progress = value
	mesh_material.set_shader_parameter("progress", progress)

func _update_progress() -> void:
	if timer.is_stopped():
		return

	_set_progress(timer.time_left / duration)

func process_inputs() -> void:
	if _has_active_input():
		timer.stop()
		set_state(true)
		_set_progress(1.0)
	elif is_on and timer.is_stopped():
		timer.start(duration)

func _on_activation_received() -> void:
	set_state(true)

	if !_has_active_input():
		timer.start(duration)
	else:
		timer.stop()

func _process(_delta: float) -> void:
	_update_progress()

func _has_active_input() -> bool:
	for input in inputs:
		if input != null and input.is_on:
			return true

	return false

func _on_timeout() -> void:
	if _has_active_input():
		process_inputs()
		return

	_set_progress(0.0)
	set_state(false)
