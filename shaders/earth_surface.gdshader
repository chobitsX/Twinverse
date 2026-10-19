shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D earth_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cloud_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform mat3 ecef_from_local = mat3(1.0);
uniform vec3 planet_center = vec3(0.0);
uniform vec3 sun_direction = vec3(0.6, 0.3, -0.7);
uniform float world_time = 0.0;
uniform float cloud_shadow_strength = 0.18;
uniform float local_water_reflection = 0.0;
varying vec3 world_point;

float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7))) * 43758.5453); }
float noise3(vec3 p) {
	vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float clouds(vec3 p) {
	return noise3(p)*0.57+noise3(p*2.09+12.0)*0.28+noise3(p*4.17)*0.15;
}
#include "res://shaders/atmosphere_scattering.gdshaderinc"
#include "res://shaders/rotation_filter.gdshaderinc"

void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 local_n=normalize(world_point-planet_center);
	vec3 n=normalize(ecef_from_local*local_n);
	vec2 spherical_uv=vec2(atan(n.x,n.z)/TAU+0.5,acos(clamp(n.y,-1.0,1.0))/PI);
	// Longitude wraps at the date line; keep derivatives on the shortest arc.
	vec2 uv_dx = dFdx(spherical_uv), uv_dy = dFdy(spherical_uv);
	uv_dx.x -= round(uv_dx.x);
	uv_dy.x -= round(uv_dy.x);
	vec3 base=rotation_filtered_map(earth_map,spherical_uv,uv_dx,uv_dy).rgb;
	float daylight=max(dot(local_n,normalize(sun_direction)),0.0)*eclipse_visibility(world_point);
	float shadow=smoothstep(0.18,0.88,rotation_filtered_map(cloud_map,spherical_uv+vec2(0.001,0.0003),uv_dx,uv_dy).r);
	float water=smoothstep(0.018,0.075,base.b-max(base.r,base.g*0.82));
	vec3 view_dir=normalize(CAMERA_POSITION_WORLD-world_point);
	vec3 half_dir=normalize(view_dir+normalize(sun_direction));
	float glint=pow(max(dot(local_n,half_dir),0.0),150.0)*water*0.24;
	ALBEDO=base*(0.018+daylight*1.12)*(1.0-cloud_shadow_strength*shadow)+vec3(glint)*daylight;
	// The regional water view needs grazing sky reflection. The historical
	// map is dark in linear space, so classify its colour ratio, not brightness.
	float ocean = smoothstep(0.05, 0.28, (base.b - max(base.r, base.g * 0.85)) / max(base.b, 0.001));
	float fresnel = 0.02 + 0.98 * pow(1.0 - max(dot(local_n, view_dir), 0.0), 5.0);
	vec3 reflected = reflect(-view_dir, local_n);
	if (local_water_reflection > 0.0 && ocean > 0.001) {
		// Reflect the same atmospheric radiance as the visible sky. A separate
		// blue gradient creates a hard colour boundary at grazing angles.
		vec3 sky_origin = world_point - planet_center + local_n * 0.001;
		float sky_finish = air_sphere_hit(sky_origin, reflected, 6471.0).y;
		vec3 sky_transmittance;
		vec3 sky_colour = air_scattering(sky_origin, reflected, normalize(sun_direction),
			0.0, max(sky_finish, 0.0), 6371.0, 6471.0, 1.0, 2.6, sky_transmittance);
		ALBEDO += sky_colour * ocean * fresnel * local_water_reflection;
	}
	ROUGHNESS=mix(0.84,0.18,water);
}
