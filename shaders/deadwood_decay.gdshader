shader_type spatial;
render_mode cull_disabled;
uniform float remaining : hint_range(0.0,1.0)=1.0;
uniform float moisture : hint_range(0.0,1.0)=0.0;
uniform bool bark=false;
uniform float floor_y=0.0;
varying vec3 local_point;
varying vec3 original_color;
void vertex(){
 local_point=VERTEX; original_color=COLOR.rgb;
 // Only severe decay settles the residual fragments; early white rot retains its size.
 float settle=smoothstep(.78,.96,1.0-remaining);
 VERTEX.y=mix(VERTEX.y,floor_y+.008,settle);
}
void fragment(){
 float loss=1.0-remaining;
 float fibers=.5+.5*sin(local_point.x*41.0+sin(local_point.y*371.0+local_point.z*209.0)*.55);
 float patch=.5+.5*sin(local_point.x*17.0+sin(local_point.y*27.0+local_point.z*39.0)*2.0);
 float pale=smoothstep(.08,.68,loss)*(.55+.45*patch);
 vec3 white_rot=vec3(.54,.48,.34)*(.72+.28*fibers);
 // White rot first changes colour while retaining the original external dimensions.
 vec3 color=mix(original_color,white_rot,pale*(bark ? .80:1.0));
 ALBEDO=color*(1.0-.18*moisture);
 ROUGHNESS=mix(.96,.69,moisture);
 // Late breakup is an authored visibility map, never a calibrated mass/volume relation.
 float fragment_cell=fract(sin(dot(floor(local_point*vec3(19.0,93.0,91.0)),vec3(12.9898,78.233,37.719)))*43758.5453);
 float late_loss=smoothstep(.78,1.0,loss);
 if(fragment_cell<late_loss) discard;
}
