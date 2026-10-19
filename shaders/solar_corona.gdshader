shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float world_time = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p), angle = atan(p.y, p.x);
	float filaments = 0.64 + 0.18 * sin(angle * 7.0 + sin(angle * 3.0) + world_time * 0.04)
		+ 0.12 * sin(angle * 19.0 - r * 6.0) + 0.06 * sin(angle * 43.0 - world_time * 0.05);
	float surface_distance = max(r - 0.25, 0.0);
	float inner = exp(-surface_distance * 34.0);
	float outer = exp(-surface_distance * 10.0) * filaments;
	float edge = 1.0 - smoothstep(0.70, 1.0, r);
	ALBEDO = vec3(1.0, 0.53, 0.18) * (inner * 0.36 + outer * 0.19);
	ALPHA = smoothstep(0.235, 0.26, r) * edge;
}
