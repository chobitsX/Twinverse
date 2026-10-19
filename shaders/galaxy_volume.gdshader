shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;
#include "res://shaders/cosmos_noise.gdshaderinc"
uniform float world_time = 0.0;
varying vec3 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
// Average the thin disk over each segment instead of sampling a single sheet.
float disk_average(float y, float dy, float height) {
	float offset = abs(dy) * 0.387298335;
	vec3 q = vec3(y - offset, y, y + offset) / height;
	return dot(exp(-q * q), vec3(0.277777778, 0.444444444, 0.277777778));
}
float filtered_fbm(vec3 p, float footprint) {
	float medium = mix(cosmic_noise(p * 2.03 + 9.2), 0.5, smoothstep(0.25, 0.9, footprint * 2.03));
	float fine = mix(cosmic_noise(p * 4.13 + 3.1), 0.5, smoothstep(0.25, 0.9, footprint * 4.13));
	return cosmic_noise(p) * 0.57 + medium * 0.28 + fine * 0.15;
}
void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD, ray = normalize(world_point - eye);
	vec3 a = (vec3(-16.0,-3.0,-16.0) - eye) / ray;
	vec3 b = (vec3(16.0,3.0,16.0) - eye) / ray;
	vec3 near_axis = min(a,b), far_axis = max(a,b);
	float start = max(0.0, max(near_axis.x, max(near_axis.y, near_axis.z)));
	float finish = min(far_axis.x, min(far_axis.y, far_axis.z));
	if (finish <= start) { discard; }
	float step_size = (finish - start) / 96.0;
	vec3 radiance = vec3(0.0);
	float transmission = 1.0;
	// Blend the illustrative long-exposure overview into a darker in-disk view.
	float view_density = mix(0.08, 1.0, smoothstep(8.0, 26.0, length(eye)));
	for (int i = 0; i < 96; i++) {
		vec3 p = eye + ray * (start + (float(i) + 0.5) * step_size);
		float phase = -world_time * 0.028;
		p.xz = mat2(vec2(cos(phase),sin(phase)),vec2(-sin(phase),cos(phase))) * p.xz;
		float radius = length(p.xz);
		float turbulent = filtered_fbm(p * 1.3, step_size * 1.3);
		float arm_phase = atan(p.z, p.x) - 4.0 * log(1.0 + radius / 1.6) + (turbulent - 0.5) * 0.38;
		float major_arm = exp(-pow(sin(arm_phase) / 0.25, 2.0));
		float minor_arm = exp(-pow(sin(arm_phase - 1.65) / 0.19, 2.0)) * 0.30 * smoothstep(2.0, 5.0, radius);
		float disk = disk_average(p.y, ray.y * step_size, 0.14 + radius * 0.021) * exp(-radius / 8.5);
		float core = exp(-length(p * vec3(0.68, 1.65, 0.86)) * 1.2);
		float bar = exp(-dot(p * vec3(.38,2.4,1.3),p * vec3(.38,2.4,1.3))) * .35;
		float lane = exp(-pow(sin(arm_phase + 0.22) / 0.13, 2.0));
		float dust = lane * smoothstep(0.27, 0.66, filtered_fbm(p * 2.8 + 8.0, step_size * 2.8)) * smoothstep(1.0, 3.5, radius);
		float arms = (major_arm + minor_arm) * (0.35 + turbulent * 1.3);
		float disk_density = disk * (0.10 + arms + dust * 0.38);
		float core_density = core * 1.65 + bar;
		float density = (disk_density + core_density) * (1.0 - smoothstep(12.0, 15.7, radius)) * view_density;
		float alpha_step = 1.0 - exp(-density * step_size * 1.7);
		// Dust belongs to the thin disk. Applying its xz mask to the bulge
		// extrudes dark columns above and below the disk at oblique angles.
		vec3 disk_colour = mix(vec3(0.38, 0.56, 0.92), vec3(1.20, 0.83, 0.49), exp(-radius * 0.32));
		disk_colour *= (0.68 + 0.9 * turbulent) * mix(1.0, 0.045, dust);
		vec3 core_colour = vec3(1.40, 1.04, 0.64) * (0.82 + turbulent * 0.35);
		vec3 colour = (disk_colour * disk_density + core_colour * core_density) / max(disk_density + core_density, 0.00001);
		radiance += transmission * alpha_step * colour;
		transmission *= 1.0 - alpha_step;
	}
	float alpha = 1.0 - transmission;
	if (alpha < 0.001) { discard; }
	ALBEDO = radiance / alpha;
	ALPHA = alpha;
}
