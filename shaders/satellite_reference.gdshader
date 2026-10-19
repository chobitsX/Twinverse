shader_type spatial;
render_mode unshaded;
uniform vec3 sun_direction = vec3(1,0,0);
uniform vec3 colour : source_color = vec3(0.55,0.59,0.62);
varying vec3 world_normal;
void vertex() { world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment() {
 float light=max(dot(normalize(world_normal),normalize(sun_direction)),0.0);
 ALBEDO=colour*(0.045+1.0*light);
}
