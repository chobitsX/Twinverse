shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

float eye_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float eye_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float value = mix(mix(eye_hash(cell), eye_hash(cell + vec2(1, 0)), f.x),
		mix(eye_hash(cell + vec2(0, 1)), eye_hash(cell + vec2(1, 1)), f.x), f.y);
	float fade = 1.0 - smoothstep(0.3, 1.0, max(fwidth(p).x, fwidth(p).y));
	return (value - 0.5) * fade;
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	float coarse = eye_noise(p * 7.0 + vec2(1.4, 3.7));
	float fine = eye_noise(p * 38.0 + vec2(4.2, 7.1));
	float pupil_radius = 0.60 + 0.005 * coarse;
	float aa = max(fwidth(radius), 0.001);
	float pupil = 1.0 - smoothstep(pupil_radius - aa, pupil_radius + aa, radius);
	float limbus = smoothstep(0.78, 0.96, radius);
	float angle = atan(p.y, p.x);
	float fiber_visibility = 1.0 - smoothstep(0.25, 1.0, fwidth(angle) * 48.0);
	float fibers = sin(angle * 48.0 + radius * 7.0) * fiber_visibility;
	vec3 iris = vec3(0.55, 0.32, 0.10) * (0.95 + 0.13 * coarse + 0.10 * fine + 0.10 * fibers);
	iris *= 1.0 - 0.07 * limbus;
	vec3 pigment = mix(iris, vec3(0.009, 0.013, 0.012), pupil);
	ALBEDO = mix(pigment / 12.92, pow((pigment + 0.055) / 1.055, vec3(2.4)), greaterThan(pigment, vec3(0.04045)));
	ROUGHNESS = mix(0.40, 0.09, pupil);
	SPECULAR = 0.48;
}
