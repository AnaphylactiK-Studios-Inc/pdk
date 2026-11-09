shader_type spatial;
render_mode blend_mix;

uniform vec4 off_color : source_color = vec4(0.5725, 0.1490, 0.0, 0.6627);
uniform vec4 on_color : source_color = vec4(1.0, 0.25, 0.0, 1.0);

instance uniform float progress = 0.0;
instance uniform float pulse_progress = -0.15;
instance uniform float pulse_length = 0.15;
instance uniform float pulse_active = 0.0;

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
