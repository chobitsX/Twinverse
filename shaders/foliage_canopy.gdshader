shader_type spatial;
uniform vec4 leaf_color:source_color=vec4(0.18,0.32,0.1,1);
varying vec3 p;
float h(vec3 q){return fract(sin(dot(q,vec3(127.1,311.7,81.2)))*43758.5453);}
void vertex(){
 p=VERTEX;
 float a=sin(p.x*37.0+p.y*18.0)*sin(p.z*29.0-p.y*23.0);
 VERTEX+=NORMAL*a*0.025;
}
void fragment(){
 float fleck=h(floor(p*110.0));
 float clusters=0.5+0.5*sin(p.x*24.0+p.y*7.0)*cos(p.z*19.0-p.y*31.0);
 ALBEDO=leaf_color.rgb*(0.6+0.45*clusters+fleck*0.3);
 ROUGHNESS=0.92;
}
