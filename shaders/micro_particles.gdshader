shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float world_time = 0.0;
uniform float motion_amplitude = 0.06;
uniform vec4 marker_color : source_color = vec4(0.38, 0.76, 0.78, 0.30);
varying float opacity;
void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	float phase = INSTANCE_CUSTOM.x * 6.2831853;
	center += vec3(sin(world_time * 0.11 + phase), cos(world_time * 0.09 + phase * 1.71), sin(world_time * 0.13 + phase * 0.71)) * motion_amplitude;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 p = center + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
	opacity = INSTANCE_CUSTOM.a;
}
void fragment() {
	float radius = length(UV - vec2(0.5)) * 2.0;
	if (radius > 1.0) { discard; }
	float soft = pow(max(1.0 - radius * radius, 0.0), 2.0);
	ALBEDO = marker_color.rgb;
	EMISSION = marker_color.rgb * 0.15;
	ALPHA = soft * marker_color.a * opacity;
}
