shader_type spatial;
render_mode blend_mix;

uniform vec4 off_color : source_color = vec4(0.5725, 0.1490, 0.0, 0.6627);
uniform vec4 on_color : source_color = vec4(1.0, 0.25, 0.0, 1.0);

instance uniform float progress = 0.0;
instance uniform float bottom_height = -0.5;
instance uniform float top_height = 0.5;

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
