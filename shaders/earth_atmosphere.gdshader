shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled, fog_disabled;

uniform float planet_radius = 3.0;
uniform float atmosphere_radius = 3.04709;
uniform float km_per_unit = 2123.6667;
uniform vec3 planet_center = vec3(0.0);
uniform vec3 sun_direction = vec3(0.6,0.3,-0.7);
uniform float scattering_exposure = 2.6;
uniform float world_time = 0.0;
uniform bool composite_local_air = false;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
varying vec3 world_point;

#include "res://shaders/atmosphere_scattering.gdshaderinc"

void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 origin = CAMERA_POSITION_WORLD - planet_center;
	vec3 ray = normalize(world_point - CAMERA_POSITION_WORLD);
	vec2 hit = air_sphere_hit(origin, ray, atmosphere_radius);
	float start = max(hit.x, 0.0), finish = hit.y;
	// Every opaque body can end the ray, including a Moon in front of Earth.
	// Reverse-Z depth is from this same viewport; do not integrate atmosphere
	// behind a foreground sphere. This also preserves the local horizon pass.
	float depth = texture(depth_texture, SCREEN_UV).r;
	if (depth > 0.0) {
		vec4 view_position = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		finish = min(finish, length(view_position.xyz / view_position.w));
	}
	if (!composite_local_air) {
		vec2 ground = air_sphere_hit(origin, ray, planet_radius);
		if (ground.x > 0.0) { finish = min(finish, ground.x); }
	}
	if (finish <= start) { discard; }
	vec3 transmittance;
	vec3 scattered = air_scattering(origin, ray, normalize(sun_direction), start, finish,
		planet_radius, atmosphere_radius, km_per_unit, scattering_exposure, transmittance);
	if (composite_local_air) {
		// Ground and sky share wavelength-dependent extinction, once only.
		ALBEDO = scattered + transmittance * textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
		ALPHA = 1.0;
	} else {
		float alpha = clamp(1.0 - dot(transmittance, vec3(0.33333)), 0.0, 0.97);
		ALBEDO = scattered / max(alpha, 0.0001);
		ALPHA = alpha;
	}
}
