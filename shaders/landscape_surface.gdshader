shader_type spatial;
uniform vec4 base_color: source_color = vec4(0.2,0.3,0.13,1.0);
uniform float water = 0.0;
uniform float world_time = 0.0;
varying vec3 point;
float h(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float n(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y); }
void vertex(){ point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 float v=n(point.xz*0.8)*0.5+n(point.xz*4.0)*0.3+n(point.xz*26.0)*0.2;
 ALBEDO=base_color.rgb*(0.75+v*0.45);
 ROUGHNESS=0.94;
 if(water>0.5){
   float wave=(n(point.xz*3.0+vec2(world_time*0.1,0.0))-0.5)*0.4;
   NORMAL=normalize(NORMAL+vec3(wave*0.09,0.0,(n(point.xz*8.0+world_time*0.04)-0.5)*0.08));
   ROUGHNESS=0.20; METALLIC=0.35; ALBEDO=base_color.rgb*(0.96+wave*0.04);
 }
}
