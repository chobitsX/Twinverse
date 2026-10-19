shader_type spatial;
uniform vec4 wall_color:source_color=vec4(0.65,0.68,0.63,1);
uniform float night_amount = 0.0;
varying vec3 p;
varying vec3 norm;
void vertex(){p=VERTEX; norm=NORMAL;}
void fragment(){
 vec2 uv=vec2(abs(norm.x)>0.5?p.z:p.x,p.y);
 vec2 cell=fract(uv*vec2(0.60,0.40));
 float win=smoothstep(0.16,0.21,cell.x)*(1.0-smoothstep(0.78,0.84,cell.x))*smoothstep(0.19,0.24,cell.y)*(1.0-smoothstep(0.72,0.76,cell.y));
 win*=1.0-step(0.5,abs(norm.y));
 ALBEDO=mix(wall_color.rgb,vec3(0.055,0.14,0.18),win);
 float occupied=step(0.32,fract(sin(dot(floor(uv*vec2(0.6,0.4)),vec2(127.1,311.7)))*43758.5453));
 EMISSION=vec3(1.0,0.62,0.24)*win*occupied*night_amount*0.7;
 METALLIC=win*0.45; ROUGHNESS=mix(0.75,0.25,win);
}
