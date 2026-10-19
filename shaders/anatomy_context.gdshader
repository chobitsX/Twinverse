shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform float context_opacity : hint_range(0.0, 1.0) = 0.07;
uniform vec3 anatomy_camera = vec3(1.0, 0.5, 2.0);
varying vec3 context_position;

void vertex() {
	context_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Open a view-dependent window around the heart, leaving a local body outline.
	vec3 view_axis = normalize(anatomy_camera);
	vec3 radial = context_position - view_axis * dot(context_position, view_axis);
	float window = smoothstep(0.68, 1.12, length(radial));
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.8);
	ALBEDO = vec3(0.25, 0.43, 0.44);
	ALPHA = context_opacity * (0.12 + 0.88 * rim) * window;
}
