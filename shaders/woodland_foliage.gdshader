shader_type spatial;
render_mode cull_disabled;
uniform float world_time=0.;
uniform float wind_amount=.022;
varying float height_fraction;
void vertex(){
 height_fraction=clamp(VERTEX.y,0.,1.);
 vec3 at=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 float weight=pow(max(0.,VERTEX.y),2.);
 VERTEX.x+=sin(world_time*.8+at.x*.22+at.z*.13)*weight*wind_amount;
 VERTEX.z+=sin(world_time*1.17+at.z*.2)*weight*wind_amount*.5;
}
void fragment(){
 ALBEDO=COLOR.rgb;
 if(min(COLOR.r,min(COLOR.g,COLOR.b))>.95) ALBEDO=vec3(.09,.15,.025);
 if(!FRONT_FACING) NORMAL=-NORMAL;
 ROUGHNESS=.88;
 BACKLIGHT=ALBEDO*.22;
}
