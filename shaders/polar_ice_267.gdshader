shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 ice_position;
varying vec3 ice_normal;

float grain(vec3 p) {
	return fract(sin(dot(floor(p), vec3(17.31, 83.17, 41.79))) * 43758.5453);
}

float cloud(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(grain(i), grain(i+vec3(1,0,0)), f.x),
		mix(grain(i+vec3(0,1,0)), grain(i+vec3(1,1,0)), f.x), f.y),
		mix(mix(grain(i+vec3(0,0,1)), grain(i+vec3(1,0,1)), f.x),
		mix(grain(i+vec3(0,1,1)), grain(i+vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	ice_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ice_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 p = ice_position;
	float up = clamp(ice_normal.y, 0.0, 1.0);
	float layers = cloud(p * vec3(.25, .63, .25));
	float fine = cloud(p * 2.3);
	float cracks = pow(1.0 - abs(sin(p.x * .41 + sin(p.z * .23) * 1.4 + layers * 2.0)), 22.0);
	float snow = smoothstep(.24, .66, up) * (.86 + .14 * layers);
	float flecks = grain(p * 26.0) - .5;
	vec3 blue = mix(vec3(.065, .27, .36), vec3(.47, .70, .76), .45 + .34 * layers + .09 * fine);
	blue *= 1.0 - cracks * .17 * (1.0 - snow);
	vec3 white = vec3(.84, .89, .91) + flecks * .018 + (fine-.5) * .025;
	ALBEDO = mix(blue, white, snow);
	ROUGHNESS = mix(.38, .87, snow);
	METALLIC = 0.0;
	SPECULAR = .48;
}
