shader_type spatial;
render_mode unshaded;
uniform sampler2D moon_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 sun_direction = vec3(1,0,0);
uniform vec3 planet_center = vec3(0);
varying vec3 surface_point;
varying vec3 local_normal;
#include "res://shaders/eclipse_visibility.gdshaderinc"
#include "res://shaders/rotation_filter.gdshaderinc"
void vertex() { surface_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; local_normal=normalize(VERTEX); }
void fragment() {
 vec3 p=normalize(local_normal);
 vec2 uv=vec2(atan(p.x,p.z)/TAU+0.5,acos(clamp(p.y,-1.0,1.0))/PI);
 vec2 dx=dFdx(uv),dy=dFdy(uv); dx.x-=round(dx.x);dy.x-=round(dy.x);
 vec3 colour=rotation_filtered_map(moon_map,uv,dx,dy).rgb;
 float light=max(dot(normalize(surface_point-planet_center),normalize(sun_direction)),0.0);
	ALBEDO=colour*(0.008+1.6*light*eclipse_visibility(surface_point));
}
