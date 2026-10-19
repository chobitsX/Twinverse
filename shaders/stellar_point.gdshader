shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

// Optical point-spread illustration at a real 3D position; not a stellar disc.
void vertex() {
	float authored_radius = length(MODEL_MATRIX[0].xyz);
	vec3 view_center = (VIEW_MATRIX * MODEL_MATRIX[3]).xyz;
	// Metal/Vulkan may flip the projection Y axis; size depends on its magnitude.
	float pixel_world = abs(view_center.z) / max(VIEWPORT_SIZE.y * abs(PROJECTION_MATRIX[1][1]), 1.0);
	float radius = clamp(authored_radius, pixel_world * 1.1, pixel_world * 8.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * radius,
		INV_VIEW_MATRIX[1] * radius, INV_VIEW_MATRIX[2] * radius, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	if (r2 > 1.0) { discard; }
	float core = exp(-r2 * 25.0);
	float halo = exp(-r2 * 5.5) * 0.09;
	ALBEDO = COLOR.rgb * (core * 2.0 + halo);
	ALPHA = COLOR.a * (1.0 - smoothstep(0.72, 1.0, r2));
}
