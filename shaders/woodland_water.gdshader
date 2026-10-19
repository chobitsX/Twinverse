shader_type spatial;
render_mode cull_disabled;
uniform float world_time=0.;
varying vec3 p;
void vertex(){p=VERTEX;}
void fragment(){
 // Slopes belong to world space. Adding world X/Z to the built-in view-space
 // NORMAL made the old water bands change orientation when orbiting the camera.
 // Bend two wave families across the channel so their highlights do not
 // repeat as straight, equally spaced bars in the shore overview.
 float bend_phase=p.x*.43+p.z*.71;
 float bend=.35*sin(bend_phase);
 float bend_x=.35*.43*cos(bend_phase);
 float bend_z=.35*.71*cos(bend_phase);
 float phase_a=p.x*1.8+p.z*2.5-world_time*.7+bend;
 float phase_b=p.x*4.6-p.z*2.1-world_time*.48-.45*bend;
 float phase_c=p.x*1.1+p.z*4.3+world_time*.38;
 float dx=.007*(1.8+bend_x)*cos(phase_a)+.003*(4.6-.45*bend_x)*cos(phase_b)+.002*1.1*cos(phase_c);
 float dz=.007*(2.5+bend_z)*cos(phase_a)+.003*(-2.1-.45*bend_z)*cos(phase_b)+.002*4.3*cos(phase_c);
 vec3 world_normal=normalize(vec3(-dx,1.,-dz));
 NORMAL=normalize((VIEW_MATRIX*vec4(world_normal,0.)).xyz);
 float depth=max(UV2.x,0.);
 float deep=1.-exp(-depth*4.2);
 vec3 shallow=vec3(.12,.105,.059);
 vec3 channel=vec3(.014,.064,.054);
 ALBEDO=mix(shallow,channel,deep);
 ROUGHNESS=mix(.52,.38,deep);
 SPECULAR=.43;
}
