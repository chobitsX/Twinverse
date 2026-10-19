// One spatial deformation field is shared by every wall, connector and flow marker.
// Continuous reference phase supplied by WorldState; no measured species BPM.
uniform float world_time = 0.0;
uniform bool reference_enabled = false;
uniform float reference_beat = 0.0;
uniform float reference_flow = 0.0;
uniform float motion_amount : hint_range(0.0, 1.0) = 1.0;

float anatomy_beat(float phase) {
	return pow(max(sin(((reference_enabled ? reference_beat : world_time * 0.82) - phase) * 6.283185307), 0.0), 4.0);
}

vec3 anatomy_position(vec3 p) {
	vec3 atrium_center = vec3(-0.12, 0.205, 0.0);
	vec3 ventricle_center = vec3(-0.035, -0.13, 0.0);
	vec3 bulb_center = vec3(0.27, 0.035, -0.008);
	vec3 a = (p - atrium_center) / vec3(0.25, 0.15, 0.15);
	vec3 v = (p - ventricle_center) / vec3(0.25, 0.25, 0.18);
	vec3 b = (p - bulb_center) / vec3(0.19, 0.12, 0.12);
	float wa = exp(-dot(a, a) * 1.7);
	float wv = exp(-dot(v, v) * 1.8);
	float wb = exp(-dot(b, b) * 2.0);
	vec3 offset = -(p - atrium_center) * wa * anatomy_beat(0.0) * 0.055;
	offset -= (p - ventricle_center) * wv * anatomy_beat(0.18) * 0.075;
	// Elastic expansion after ejection; this is not another active ventricle.
	offset += (p - bulb_center) * wb * anatomy_beat(0.32) * vec3(0.013, 0.055, 0.055);
	return p + offset * motion_amount;
}
