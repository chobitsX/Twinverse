shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D particle_texture : source_color, filter_linear_mipmap;
uniform float world_time = 0.0;
varying float particle_opacity;
void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	center += vec3(sin(world_time * 0.12 + INSTANCE_CUSTOM.x * 6.28), sin(world_time * 0.17 + INSTANCE_CUSTOM.y * 6.28), cos(world_time * 0.11 + INSTANCE_CUSTOM.z * 6.28)) * 0.08;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(center + (right * VERTEX.x + up * VERTEX.y) * size, 1.0);
	particle_opacity = INSTANCE_CUSTOM.a;
}
void fragment() {
	vec4 p = texture(particle_texture, UV);
	ALBEDO = p.rgb * vec3(0.48, 0.67, 0.72);
	ALPHA = p.a * particle_opacity;
}
