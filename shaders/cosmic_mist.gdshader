shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform float expansion_factor = 1.0;
void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz * expansion_factor;
	float size = length(MODEL_MATRIX[0].xyz) * 6.0;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size,
		INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, vec4(center,1.0));
}
void fragment() {
	float r2 = dot(UV * 2.0 - 1.0,UV * 2.0 - 1.0);
	if (r2 > 1.0) { discard; }
	ALBEDO = COLOR.rgb * vec3(.45,.68,1.0);
	ALPHA = exp(-r2*5.0) * COLOR.a * .13 * (1.0-smoothstep(.6,1.0,r2));
}
