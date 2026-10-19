shader_type spatial;
render_mode unshaded;
#include "res://shaders/cosmos_noise.gdshaderinc"
uniform float world_time = 0.0;
varying vec3 sphere_position;
void vertex() { sphere_position = VERTEX; }
void fragment() {
	vec3 p = normalize(sphere_position);
	// Authored visible-light texture: retain broad structure at overview size,
	// and filter only the fine detail that a pixel cannot resolve.
	vec3 drift = vec3(world_time * 0.012, 0, 0);
	float active = cosmic_fbm(p * 5.0 + drift * 0.15);
	vec3 cells = p * 24.0 + vec3(active * 2.5) + drift;
	float broad = cosmic_fbm(cells);
	float fine = cosmic_fbm(p * 85.0 + drift);
	fine = mix(fine, 0.5, smoothstep(0.4, 1.2, length(fwidth(p * 85.0))));
	float structure = smoothstep(0.22, 0.74, broad * 0.78 + fine * 0.22);
	float spots = smoothstep(0.68, 0.79, active) * 0.38;
	float limb = 0.62 + 0.38 * pow(max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 0.55);
	vec3 colour = mix(vec3(0.82, 0.19, 0.025), vec3(1.0, 0.63, 0.19), structure);
	ALBEDO = colour * (1.10 + 0.62 * structure) * limb * (1.0 - spots);
}
