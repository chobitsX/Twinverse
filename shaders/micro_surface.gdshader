shader_type spatial;
render_mode cull_disabled;
uniform vec4 tissue_color : source_color = vec4(0.57, 0.22, 0.10, 1.0);
uniform float world_time = 0.0;
uniform float detail_scale = 80.0;
uniform float roughness_value = 0.43;
uniform float detail_strength = 1.0;
uniform float fiber_strength = 0.0;
uniform float organelle_strength = 0.0;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	// Surface detail stays attached to the geometry and fades below a pixel.
	vec3 phase = local_position * detail_scale;
	vec3 attenuation = vec3(1.0) - smoothstep(vec3(0.6), vec3(2.8), fwidth(phase));
	float grain = sin(phase.x) * sin(phase.y * 1.29) * sin(phase.z * 0.89) * attenuation.x * attenuation.y * attenuation.z;
	float mottle = sin(local_position.x * 5.7 + sin(local_position.y * 4.1)) * sin(local_position.z * 6.3);
	float longitudinal = UV.y * 17.0;
	float band_distance = abs(fract(longitudinal + 0.5) - 0.5);
	float aa = max(fwidth(longitudinal), 0.002);
	float z_band = 1.0 - smoothstep(0.035 - aa, 0.065 + aa, band_distance);
	float a_band = smoothstep(0.12 - aa, 0.23 + aa, band_distance);
	float fibril_phase = UV.x * 175.929 + sin(UV.y * 18.0) * 0.35;
	float fibrils = cos(fibril_phase) * (1.0 - smoothstep(0.6, 2.5, fwidth(fibril_phase)));
	float organelle_ribs = sin(UV.y * 65.0 + sin(UV.x * 12.0));
	float detail = detail_strength * (0.018 * grain + 0.035 * mottle);
	float tissue = 1.0 - fiber_strength * (z_band * 0.26 + a_band * 0.13 - fibrils * 0.035);
	ALBEDO = tissue_color.rgb * (0.96 + detail + organelle_strength * organelle_ribs * 0.035) * tissue;
	ROUGHNESS = clamp(roughness_value + detail * 0.6 + fiber_strength * z_band * 0.04, 0.28, 0.82);
	METALLIC = 0.0;
	SPECULAR = 0.20;
	CLEARCOAT = 0.0;
	CLEARCOAT_ROUGHNESS = 0.30;
	SSS_STRENGTH = 0.08;
}
