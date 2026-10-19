shader_type spatial;
uniform float night_amount = 0.0;
uniform vec4 shops_color : source_color = vec4(.569,.325,.267,1.);
varying vec3 point;
varying vec3 norm;
varying vec4 variation;
varying vec3 world_position;
void vertex() {
	point = VERTEX * vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	norm = NORMAL;
	variation = INSTANCE_CUSTOM;
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec2 uv = vec2(abs(norm.x)>.5?point.z:point.x,point.y);
	vec2 unit = vec2(mix(2.55,3.25,variation.g),mix(2.9,3.45,variation.r));
	vec2 cell = fract(uv / unit);
	float window = smoothstep(.17,.22,cell.x)*(1.-smoothstep(.73,.78,cell.x))*smoothstep(.26,.31,cell.y)*(1.-smoothstep(.74,.79,cell.y));
	window *= 1.-step(.5,abs(norm.y));
	window *= 1.-smoothstep(190.0,420.0,length(world_position-CAMERA_POSITION_WORLD));
	float style = floor(variation.a*3.0+.5);
	vec3 wall = shops_color.rgb;
	if (variation.b>.5 && variation.b<1.5) {
		wall = style<.5?vec3(.35,.32,.28):style<1.5?vec3(.28,.31,.29):style<2.5?vec3(.39,.29,.25):vec3(.31,.32,.36);
	} else if (variation.b>1.5) {
		wall = style<.5?vec3(.16,.23,.27):style<1.5?vec3(.22,.27,.28):style<2.5?vec3(.19,.24,.31):vec3(.25,.25,.27);
	} else {
		wall *= style<.5?vec3(.94,.86,.81):style<1.5?vec3(1.05,.95,.88):style<2.5?vec3(.84,.91,.91):vec3(.97,.85,.75);
	}
	wall *= mix(.89,1.06,variation.r);
	vec3 roof = mix(vec3(.16,.18,.18),wall,.44);
	vec3 glass = mix(vec3(.055,.095,.12),vec3(.10,.145,.16),variation.g);
	ALBEDO = norm.y>.5?roof:mix(wall,glass,window);
	float room = fract(sin(dot(floor(uv/unit),vec2(127.1,311.7))+variation.g*50.)*43758.5453);
	EMISSION = vec3(1.,.66,.34)*window*step(.62,room)*night_amount*.45;
	ROUGHNESS = mix(.87,.39,window);
	METALLIC = window*.18;
}
