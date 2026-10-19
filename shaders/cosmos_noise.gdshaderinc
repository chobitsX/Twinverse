// Stable authoring noise, not an observation or simulation dataset.
float cosmic_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float cosmic_noise(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(cosmic_hash(i), cosmic_hash(i + vec3(1,0,0)), f.x),
		mix(cosmic_hash(i + vec3(0,1,0)), cosmic_hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(cosmic_hash(i + vec3(0,0,1)), cosmic_hash(i + vec3(1,0,1)), f.x),
		mix(cosmic_hash(i + vec3(0,1,1)), cosmic_hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float cosmic_fbm(vec3 p) {
	return cosmic_noise(p) * 0.57 + cosmic_noise(p * 2.03 + 9.2) * 0.28 + cosmic_noise(p * 4.13 + 3.1) * 0.15;
}
