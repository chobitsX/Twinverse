shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

uniform mat3 ecef_from_local = mat3(1.0);
uniform vec3 planet_center = vec3(0.0);
uniform vec3 sun_direction = vec3(0.6,0.3,-0.7);
uniform float world_time = 0.0;
uniform float layer_offset = 0.0;
uniform float layer_opacity = 0.56;
uniform sampler2D cloud_map : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_point;
#include "res://shaders/eclipse_visibility.gdshaderinc"
#include "res://shaders/rotation_filter.gdshaderinc"
float hash3(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise3(vec3 p) {
	vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float fbm(vec3 p) { return noise3(p)*0.53+noise3(p*2.09+12.0)*0.27+noise3(p*4.17)*0.13+noise3(p*8.31)*0.07; }
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 n=normalize(world_point-planet_center), ecef=ecef_from_local*n;
	vec2 map_uv=vec2(atan(ecef.x,ecef.z)/TAU+0.5,acos(clamp(ecef.y,-1.0,1.0))/PI);
	map_uv.x += world_time * 0.0000005 + layer_offset * 0.00015;
	// Longitude wraps at the date line; keep derivatives on the shortest arc.
	vec2 uv_dx = dFdx(map_uv), uv_dy = dFdy(map_uv);
	uv_dx.x -= round(uv_dx.x);
	uv_dy.x -= round(uv_dy.x);
	float cloud=rotation_filtered_map(cloud_map,map_uv,uv_dx,uv_dy).r;
	float coverage=smoothstep(0.10+layer_offset*0.06,0.89,cloud);
	float light=max(dot(n,normalize(sun_direction)),0.0)*eclipse_visibility(world_point);
	float relief=0.75+0.25*smoothstep(0.48,0.7,cloud);
	ALBEDO=mix(vec3(0.017,0.025,0.046),vec3(0.88,0.88,0.85),light)*relief;
	ALPHA=clamp(coverage*layer_opacity,0.0,0.86);
}
