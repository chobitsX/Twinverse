shader_type sky;
#include "res://shaders/ocean_air.gdshaderinc"
uniform vec3 light_direction = vec3(-0.3, 0.86, -0.2);
uniform float immersion = 1.0;

void sky() {
	float elevation = max(EYEDIR.y, 0.0);
	float light = max(dot(EYEDIR, normalize(light_direction)), 0.0);
	// Linear radiance near the horizontal sightline matches the distance fog.
	// An authored water-column gradient, not a measured optical water profile.
	vec3 horizon = vec3(0.0054, 0.0946, 0.1329);
	vec3 underwater = mix(horizon, vec3(0.002, 0.045, 0.074), smoothstep(0.0, 0.7, -EYEDIR.y));
	underwater = mix(underwater, vec3(0.055, 0.24, 0.29), smoothstep(0.0, 0.95, elevation));
	underwater += vec3(0.06, 0.15, 0.15) * pow(light, 12.0);
	vec3 air = ocean_air_sky(EYEDIR, normalize(light_direction));
	air += vec3(1.0, 0.95, 0.85) * pow(light, 1800.0) * 2.5;
	COLOR = mix(air, underwater, immersion);
}
