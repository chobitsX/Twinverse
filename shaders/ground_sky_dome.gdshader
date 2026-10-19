shader_type spatial;
render_mode unshaded,cull_front,depth_draw_never;
uniform sampler2D galaxy_map : source_color,filter_linear_mipmap,repeat_enable;
uniform bool use_galaxy_map = false;
uniform mat3 galactic_from_local;
uniform vec3 sun_direction = vec3(0.0,-1.0,0.0);
uniform vec3 moon_direction = vec3(0.0,-1.0,0.0);
uniform float moon_light = 0.0;
uniform float night_strength = 1.0;
uniform float view_exposure = 1.0;
varying vec3 local_direction;
float hash(vec3 p) { p=fract(p*.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z); }
float noise(vec3 p) { vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z); }
void vertex() { local_direction=VERTEX; }
void fragment() {
	vec3 d=normalize(local_direction);
	float height=max(d.y,0.0);
	vec3 g=galactic_from_local*d;
	float latitude=asin(clamp(g.z,-1.0,1.0));
	float longitude=atan(g.y,g.x);
	vec2 uv=vec2(fract(.5-longitude/6.28318530718),.5-latitude/3.14159265359);
	vec3 milky;
	if (use_galaxy_map) {
		// Diffuse survey light; the catalog supplies distinct bright stars.
		milky=textureLod(galaxy_map,uv,2.0).rgb*.70;
	} else {
		float dust=noise(g*38.0)*.62+noise(g*97.0)*.25+noise(g*241.0)*.13;
		float width=.075+.045*noise(g*12.0);
		float band=exp(-pow(latitude/width,2.0));
		float bulge=exp(-pow(longitude/.35,2.0)-pow(latitude/.14,2.0));
		milky=mix(vec3(.07,.11,.18),vec3(.46,.33,.20),bulge)*band*(.23+pow(dust,3.0)*2.3);
		milky+=vec3(.47,.35,.24)*bulge*.31;
	}
	float extinction=smoothstep(.01,.22,height);
	float glare=pow(max(dot(d,moon_direction),0.0),22.0)*moon_light;
	vec3 night=mix(vec3(.009,.016,.029),vec3(.0007,.0016,.005),pow(height,.32));
	night+=milky*night_strength*extinction*(1.0-.58*moon_light)*view_exposure;
	night+=vec3(.025,.036,.058)*exp(-height*8.0)+vec3(.033,.038,.047)*glare;
	float facing=max(dot(d,sun_direction),0.0);
	vec3 day=mix(vec3(.44,.60,.75),vec3(.018,.16,.39),pow(height,.35));
	float sunset=exp(-pow(sun_direction.y/.16,2.0));
	day=mix(day,vec3(.83,.31,.12),sunset*exp(-height*6.0)*(.25+.75*pow(facing,5.0)));
	ALBEDO=mix(day,night,night_strength);
	EMISSION=vec3(0.0);
	ALPHA=1.0; // Draw the background before the catalog's additive points.
}
