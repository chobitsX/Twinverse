shader_type spatial;
uniform vec4 glass_color:source_color=vec4(0.05,0.13,0.17,1);
uniform float night_amount=0.0;
varying vec3 place;
void vertex(){place=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 cell=floor(place/vec3(2.47,3.15,2.47));
 float room=fract(sin(dot(cell,vec3(127.1,311.7,74.7)))*43758.5453);
 ALBEDO=glass_color.rgb*(.72+room*.46);
 METALLIC=.28;
 ROUGHNESS=.24;
 EMISSION=vec3(1.0,.69,.35)*night_amount*step(.39,room)*.48;
}
