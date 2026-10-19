shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float world_time = 0.0;
uniform vec4 ice_edges[14];
uniform bool authored_coast = true;
varying vec3 world_position;

float shore_line(float x) {
	float west = smoothstep(-41.0, -30.0, x) * (1.0 - smoothstep(-21.0, -10.0, x));
	float east = smoothstep(16.0, 27.0, x) * (1.0 - smoothstep(42.0, 51.0, x));
	return -3.0 + 2.2 * sin(.115 * x + .4) + .9 * sin(.36 * x) - 19.0 * west - 7.0 * east;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Authored shading slopes only: the original sea plane and waterline stay put.
	// The host supplies paused/seekable world time; engine TIME is deliberately unused.
	vec2 p = world_position.xz;
	float distance_to_eye = length(CAMERA_POSITION_WORLD.xz - p);
	float detail = 1.0 - smoothstep(24.0, 85.0, distance_to_eye);
	float warp = sin(dot(p, vec2(.17,.23))) * .8;
	float swell = dot(p, vec2(.34, .26)) + warp + world_time * .28;
	float cross_swell = dot(p, vec2(-.22, .41)) - warp * .6 + world_time * .19;
	float ripple = dot(p, vec2(-1.40, .93)) + sin(p.x*.39) + world_time * .61;
	float fine = dot(p, vec2(3.70, -2.80)) + sin(p.y*.65) + world_time * .97;
	vec2 slope = .055 * cos(swell) * vec2(.82, .56) + .043 * cos(cross_swell) * vec2(-.48, .88)
		+ detail * (.028 * cos(ripple) * vec2(-.83, .55)
		+ .012 * cos(fine) * vec2(.80, -.60));
	vec3 surface_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(surface_normal, 0.0)).xyz);
	float broad = sin(world_position.x * 0.11 + world_position.z * 0.07 + world_time * 0.035);
	float small = sin(world_position.x * 0.42 - world_position.z * 0.29 + world_time * 0.09);
	float waviness = (broad * 0.7 + small * 0.3) * 0.5 + 0.5;
	ALBEDO = mix(vec3(0.012, 0.070, 0.105), vec3(0.027, 0.096, 0.128), waviness);
	ROUGHNESS = mix(.35, .43, 1.0 - detail);
	// Thin authored foam accent, independent of the fixed observation waterline.
	float foam = 0.0;
	if (authored_coast && abs(p.x) < 51.0) {
		float shore_distance = shore_line(p.x) - p.y;
		foam = (1.0 - smoothstep(.10, .80, shore_distance)) * step(0.0, shore_distance);
	}
	for (int i = 0; i < 14; i++) {
		vec4 edge = ice_edges[i];
		vec2 radii = max(edge.zw, vec2(.001));
		float edge_distance = (length((p - edge.xy) / radii) - 1.0) * min(radii.x, radii.y);
		float rim = (1.0 - smoothstep(.03, .55, edge_distance)) * step(0.0, edge_distance);
		foam = max(foam, rim * step(.01, edge.z));
	}
	float lace = .5 + .5 * sin(p.x * 8.1 + sin(p.y * 6.3) * 2.3 + world_time * .4);
	foam *= mix(.20, .50, lace) * mix(.45, 1.0, detail);
	ALBEDO = mix(ALBEDO, vec3(.52, .71, .75), foam);
	ROUGHNESS = mix(ROUGHNESS, .72, foam);
	METALLIC = 0.0;
}
