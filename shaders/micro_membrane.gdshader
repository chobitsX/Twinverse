shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform vec4 membrane_color : source_color = vec4(0.28, 0.63, 0.64, 0.30);
uniform float world_time = 0.0;
uniform float rim_strength = 0.18;
void fragment() {
	float facing = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.4);
	vec2 phase = UV * vec2(240.0, 180.0);
	vec2 aa = vec2(1.0) - smoothstep(vec2(0.7), vec2(2.5), fwidth(phase));
	float texture_detail = sin(phase.x) * sin(phase.y) * aa.x * aa.y;
	ALBEDO = membrane_color.rgb * (0.97 + 0.025 * texture_detail);
	// Keep broad faces transmissive while retaining a readable contour.
	// The cutaway is an observation aid; opacity does not encode membrane density.
	ALPHA = clamp(membrane_color.a * mix(0.45, 1.0, facing) + facing * rim_strength, 0.0, 0.72);
	ROUGHNESS = 0.62;
	SPECULAR = 0.16;
	EMISSION = membrane_color.rgb * facing * 0.035;
}
