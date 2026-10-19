shader_type spatial;
render_mode unshaded;
uniform sampler2D surface_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D coverage_map : filter_linear_mipmap, repeat_enable;
uniform bool has_coverage = false;
uniform vec3 sun_direction = vec3(1,0,0);
uniform vec3 body_center = vec3(0);
uniform float longitude_offset = 0.0;
uniform float polar_clamp = 0.0;
varying vec3 surface_point;
varying vec3 local_normal;
void vertex() { surface_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; local_normal=normalize(VERTEX); }
void fragment() {
 vec3 p=normalize(local_normal);
 vec2 uv=vec2(atan(p.x,p.z)/TAU+longitude_offset,clamp(acos(clamp(p.y,-1.0,1.0))/PI,polar_clamp,1.0-polar_clamp));
 vec2 dx=dFdx(uv),dy=dFdy(uv); dx.x-=round(dx.x);dy.x-=round(dy.x);
 vec3 colour=textureGrad(surface_map,uv,dx,dy).rgb;
 float coverage=has_coverage ? textureGrad(coverage_map,uv,dx,dy).r : 1.0;
 float stripe=step(0.5,fract((uv.x+uv.y)*90.0));
 vec3 missing=mix(vec3(0.12,0.19,0.23),vec3(0.25,0.33,0.37),stripe);
 colour=mix(missing,colour,smoothstep(0.2,0.9,coverage));
 float light=max(dot(normalize(surface_point-body_center),normalize(sun_direction)),0.0);
 ALBEDO=colour*(0.012+1.3*light);
}
