shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 tint:source_color=vec4(1.0);
uniform bool vertex_pigment=false;
uniform float roughness_value=0.6;
instance uniform float swim_phase=0.0;
float wave(vec3 p){
 float edge=smoothstep(0.065,0.25,abs(p.z));
 // Model +X is anterior. Constant phase moves toward -X as time increases.
 return edge*0.031*sin(swim_phase+p.x*11.0);
}
void vertex(){
 vec3 p=VERTEX;
 float dx=(wave(p+vec3(0.001,0.0,0.0))-wave(p-vec3(0.001,0.0,0.0)))/0.002;
 float dz=(wave(p+vec3(0.0,0.0,0.001))-wave(p-vec3(0.0,0.0,0.001)))/0.002;
 VERTEX.y+=wave(p);
 NORMAL=normalize(vec3(NORMAL.x-dx*NORMAL.y,NORMAL.y,NORMAL.z-dz*NORMAL.y));
}
void fragment(){
 ALBEDO=tint.rgb*(vertex_pigment?COLOR.rgb:vec3(1.0));
 ROUGHNESS=roughness_value;
 SPECULAR=0.27;
}
