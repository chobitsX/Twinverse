shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform float expansion_factor = 1.0;
void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz * expansion_factor;
	float authored_radius = length(MODEL_MATRIX[0].xyz);
	vec3 view_center = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
	float pixel_world = abs(view_center.z) / max(VIEWPORT_SIZE.y * abs(PROJECTION_MATRIX[1][1]), 1.0);
	float size = clamp(authored_radius, pixel_world * 1.8, pixel_world * 6.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size,
		INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, vec4(center, 1.0));
}
void fragment() {
	float r2 = dot(UV * 2.0 - 1.0, UV * 2.0 - 1.0);
	if (r2 > 1.0) { discard; }
	ALBEDO = COLOR.rgb * (exp(-r2 * 16.0) * 3.2 + exp(-r2 * 4.5) * 0.22);
	ALPHA = COLOR.a * (1.0 - smoothstep(0.65, 1.0, r2));
}
