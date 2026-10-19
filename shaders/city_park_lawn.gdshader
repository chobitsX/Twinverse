shader_type spatial;

uniform vec3 deep_green: source_color = vec3(0.18, 0.30, 0.11);
uniform vec3 light_green: source_color = vec3(0.28, 0.40, 0.17);
uniform vec3 path_wear: source_color = vec3(0.28, 0.34, 0.15);

varying vec2 world_xz;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(cell), hash2(cell + vec2(1.0, 0.0)), f.x),
		mix(hash2(cell + vec2(0.0, 1.0)), hash2(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float broad = noise2(world_xz * 0.13);
	float medium = noise2(world_xz * 0.58);
	float fine = noise2(world_xz * 5.7);
	vec3 grass = mix(deep_green, light_green, broad * 0.72 + medium * 0.28);
	grass *= 0.91 + fine * 0.18;
	float path_edge = min(abs(world_xz.x - 33.0), abs(world_xz.y - 33.0)) - 2.0;
	float wear = 1.0 - smoothstep(0.0, 0.9, path_edge);
	ALBEDO = mix(grass, path_wear, wear * 0.19);
	ROUGHNESS = 0.98;
}
