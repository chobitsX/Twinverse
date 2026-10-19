shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform vec4 colour : source_color = vec4(0.56,0.80,0.91,1.0);
void fragment() {
 float r=length(UV-vec2(0.5));
 if(r>0.48) discard;
 ALBEDO=colour.rgb*mix(0.6,1.0,1.0-smoothstep(0.05,0.48,r));
}
