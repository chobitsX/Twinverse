shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

// Authored curtain illustration, not a dated forecast or an emission simulation.
uniform float world_time = 0.0;
uniform float night_strength = 0.0;
uniform float curtain_seed = 0.0;

void vertex() {
	float sway = sin(UV.x * 10.0 + world_time * .10 + curtain_seed);
	VERTEX.z += sway * 7.0 * sin(UV.y * 3.14159265);
	VERTEX.y += sin(UV.x * 18.0 + world_time * .07 + curtain_seed) * 3.0;
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float folds = .18 + .82 * pow(.5 + .5 * sin(u * 25.0 + sin(u * 9.0 + world_time * .09) * 2.4 + curtain_seed), .9);
	float rays = .25 + .75 * pow(.5 + .5 * sin(u * 340.0 + sin(u * 23.0) * 4.0), 3.0);
	float low_edge = .14 + .05 * sin(u * 11.0 + world_time * .055 + curtain_seed);
	float rise = max(v - low_edge, 0.0);
	float veil = smoothstep(low_edge - .015, low_edge + .02, v) * exp(-rise * 8.5);
	float seam = exp(-pow((v-low_edge)/.028, 2.0)) * .42;
	veil = (veil + seam) * (1.0 - smoothstep(.52, .85, v));
	float ends = smoothstep(.0, .17, u) * (1.0 - smoothstep(.83, 1.0, u));
	vec3 green = vec3(.075, .72, .36);
	vec3 violet = vec3(.36, .11, .52);
	vec3 colour = mix(green, violet, smoothstep(.08, .37, rise));
	ALBEDO = colour * (.72 + folds * .32);
	ALPHA = clamp(veil * folds * rays * ends * night_strength * .43, 0.0, .50);
}
