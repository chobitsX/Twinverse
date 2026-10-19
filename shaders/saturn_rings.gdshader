shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec3 planet_center = vec3(0.0);
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
uniform float planet_radius = 0.7;
varying vec3 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float r = UV.x;
	float fine = 0.5 + 0.5 * sin(r * 430.0) * (1.0 - smoothstep(0.6, 3.0, fwidth(r) * 430.0));
	float bands = 0.6 + 0.4 * sin(r * 67.0 + sin(r * 19.0) * 2.0);
	float broad = smoothstep(0.12, 0.24, r) * (1.0 - smoothstep(0.54, 0.63, r));
	float cassini = smoothstep(0.018, 0.030, abs(r - 0.64));
	vec3 to_sun = normalize(sun_direction);
	vec3 offset = world_point - planet_center;
	float closest = length(offset + to_sun * max(-dot(offset, to_sun), 0.0));
	float shadow = smoothstep(planet_radius * 0.94, planet_radius * 1.04, closest);
	ALBEDO = mix(vec3(0.30, 0.24, 0.15), vec3(0.66, 0.55, 0.36), bands * 0.65 + broad * 0.35)
		* (0.90 + 0.16 * fine) * mix(0.07, 1.0, shadow);
	ALPHA = (0.44 + 0.24 * smoothstep(0.10, 0.22, r) + 0.10 * bands + 0.05 * fine)
		* cassini * smoothstep(0.0, 0.04, r) * (1.0 - smoothstep(0.96, 1.0, r));
}
