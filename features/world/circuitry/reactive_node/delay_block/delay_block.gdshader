shader_type spatial;
render_mode blend_mix;

uniform vec4 off_color : source_color = vec4(0.5725, 0.1490, 0.0, 0.6627);
uniform vec4 on_color : source_color = vec4(1.0, 0.25, 0.0, 1.0);
uniform float band_width = 0.04;

instance uniform float progress = 0.0;
instance uniform float pulse_progress = 0.0;
instance uniform float bottom_height = -1.0;
instance uniform float top_height = 1.0;

varying float local_height;

void vertex() {
	local_height = VERTEX.y;
}

float band_at(float height, float position) {
	return (1.0 - smoothstep(
		band_width,
		band_width + 0.015,
		abs(height - position)
	)) * step(0.001, position);
}

void fragment() {
	float height = (local_height - bottom_height) / (top_height - bottom_height);
	float band = max(band_at(height, progress), band_at(height, pulse_progress));

	ALBEDO = mix(off_color.rgb, on_color.rgb, band);
	ALPHA = mix(off_color.a, on_color.a, band);
	EMISSION = mix(off_color.rgb, on_color.rgb, band) * band * 3.0;
}
