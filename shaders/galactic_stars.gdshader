shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform float world_time = 0.0;
// An idealized rotation curve for an illustrative disc, not stellar ephemerides.
void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	float radius = length(center.xz);
	float phase = world_time * 0.035 * 7.8 / max(radius, 3.0);
	center.xz = mat2(vec2(cos(phase), sin(phase)), vec2(-sin(phase), cos(phase))) * center.xz;
	float authored_radius = length(MODEL_MATRIX[0].xyz);
	vec3 view_center = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
	float pixel_world = abs(view_center.z) / max(VIEWPORT_SIZE.y * abs(PROJECTION_MATRIX[1][1]), 1.0);
	float size = clamp(authored_radius, pixel_world * 0.8, pixel_world * 5.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size,
		INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, vec4(center, 1.0));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	if (r2 > 1.0) { discard; }
	ALBEDO = COLOR.rgb * (exp(-r2 * 30.0) * 3.5 + exp(-r2 * 6.0) * 0.14);
	ALPHA = COLOR.a * (1.0 - smoothstep(0.65, 1.0, r2));
}
