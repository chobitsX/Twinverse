shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 tint:source_color=vec4(1.0);
uniform sampler2D albedo_map:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap_anisotropic;
uniform bool has_albedo=false;
uniform bool has_normal=false;
uniform bool vertex_pigment=false;
uniform bool brown_tang_pigment=false;
uniform float roughness_value=0.5;
instance uniform float swim_phase=0.0;
varying vec3 source_position;
void vertex(){
 source_position=VERTEX;
 // Authored models face +X; increasing phase therefore travels toward -X.
 float u=clamp((VERTEX.x+0.48)/0.72,0.0,1.0);
 float m=1.0-u*u*(3.0-2.0*u);
 float dm=-6.0*u*(1.0-u)/0.72;
 float phase=swim_phase+VERTEX.x*4.0;
 float amplitude=0.075*m*m;
 float slope=0.15*m*dm*sin(phase)+4.0*amplitude*cos(phase);
 VERTEX.z+=sin(phase)*amplitude;
 // Inverse-transpose for z'=z+f(x), including the amplitude gradient.
 float handedness=dot(cross(NORMAL,TANGENT),BINORMAL)<0.0 ? -1.0 : 1.0;
 NORMAL=normalize(vec3(NORMAL.x-slope*NORMAL.z,NORMAL.y,NORMAL.z));
 if(dot(TANGENT,TANGENT)>0.01){
  TANGENT=normalize(TANGENT+vec3(0.0,0.0,slope*TANGENT.x));
  BINORMAL=normalize(cross(NORMAL,TANGENT))*handedness;
 }
}
void fragment(){
 ALBEDO=tint.rgb*(has_albedo ? texture(albedo_map,UV).rgb : vec3(1.0));
 if(brown_tang_pigment && has_albedo){
  vec3 raw=texture(albedo_map,UV).rgb;
  float luma=dot(raw,vec3(.2126,.7152,.0722));
  float belly=clamp((-source_position.y-.08)/.16,0.0,1.0);
  ALBEDO=mix(vec3(.13,.08,.038),vec3(.44,.35,.23),belly)*(.65+.70*luma);
  if(source_position.x>.28 && luma<.065) ALBEDO=raw;
 }
 if(vertex_pigment){ALBEDO*=COLOR.rgb;}
 if(has_normal){NORMAL_MAP=texture(normal_map,UV).rgb;NORMAL_MAP_DEPTH=0.22;}
 ROUGHNESS=roughness_value;
 SPECULAR=0.33;
}
