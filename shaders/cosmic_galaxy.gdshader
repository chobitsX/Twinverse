shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 tint = vec3(0.50, 0.72, 1.0);
uniform float phase = 0.0;
uniform float inclination = 0.65;
uniform bool batched = false;
uniform float expansion_factor = 1.0;
varying flat vec4 galaxy_shape;
varying flat vec3 galaxy_tint;
void vertex() {
	galaxy_shape = batched ? INSTANCE_CUSTOM : vec4(phase,inclination,0.0,0.0);
	galaxy_tint = batched ? COLOR.rgb : tint;
	if (batched) {
		vec3 center = MODEL_MATRIX[3].xyz * expansion_factor;
		float radius = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * radius,
			INV_VIEW_MATRIX[1] * radius, INV_VIEW_MATRIX[2] * radius, vec4(center,1.0));
	}
}
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float c = cos(galaxy_shape.z), s = sin(galaxy_shape.z);
	vec2 p = mat2(vec2(c,s),vec2(-s,c)) * uv;
	p /= vec2(1.0, galaxy_shape.y);
	float r = length(p);
	if (r > 1.0) { discard; }
	float arm = exp(-pow(sin(atan(p.y, p.x) - 4.0 * log(1.0 + r * 4.0) - galaxy_shape.x) / 0.27, 2.0));
	float core = exp(-r * r * 65.0);
	float disc = exp(-r * 3.0) * mix(0.12 + arm * 0.75, 0.65, galaxy_shape.w);
	vec3 colour = mix(galaxy_tint, vec3(1.0, 0.84, 0.65), exp(-r * 9.0));
	ALBEDO = colour * (core * 2.0 + disc);
	ALPHA = (1.0 - smoothstep(0.72, 1.0, r)) * 0.85;
}
