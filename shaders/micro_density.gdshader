shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled;
uniform float world_time = 0.0;
uniform int orbital_mode = 0;
uniform bool section_view = false;
// Same normalized hydrogenic reference functions as core/oxygen_atom.gd.
// a is an authored display unit; this is not an oxygen electronic calculation.
float reference_density(vec3 p) {
 float a = 0.35;
 float u = length(p) / a;
 float v = 3.14159265359 * a * a * a;
 float s1 = exp(-2.0*u) / v;
 float s2 = (2.0-u)*(2.0-u)*exp(-u)/(32.0*v);
 float pa = u*u*exp(-u)/(96.0*v);
 float py = p.y*p.y/(a*a)*exp(-u)/(32.0*v);
 if (orbital_mode==1) return s1;
 if (orbital_mode==2) return s2;
 if (orbital_mode==3) return py;
 return (2.0*s1+2.0*s2+4.0*pa)/8.0;
}
varying vec3 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 ray = normalize(world_point - eye);
	float exposure = orbital_mode==1 ? 1.5 : (orbital_mode==2 ? 48.0 : 14.0);
	if (section_view) {
		// Exact z=0 section; no ray-march sampling alias at the nodal shell.
		if (abs(ray.z)<0.00001) discard;
		float plane_t=-eye.z/ray.z;
		vec3 point=eye+ray*plane_t;
		if (plane_t<0.0 || length(point)>6.0) discard;
		ALBEDO=vec3(0.25,0.63,0.79);
		ALPHA=1.0-exp(-reference_density(point)*exposure*0.75);
	} else {
	// Spherical support avoids edges when the camera enters the illustration.
	float b = dot(eye, ray);
	float discriminant = b * b - dot(eye, eye) + 36.0;
	if (discriminant <= 0.0) { discard; }
	float start = max(0.0, -b - sqrt(discriminant));
	float finish = -b + sqrt(discriminant);
	if (finish <= start) { discard; }
	float step_size = (finish - start) / 112.0;
	float transmission = 1.0;
	vec3 radiance = vec3(0.0);
	for (int i = 0; i < 112; i++) {
		vec3 point = eye + ray * (start + (float(i) + 0.5) * step_size);
		float radius = length(point);
		float density = reference_density(point);
		float alpha_step = 1.0 - exp(-density * step_size * exposure);
		vec3 colour = mix(vec3(0.10, 0.28, 0.47), vec3(0.34, 0.73, 0.86), exp(-radius * 0.6));
		radiance += transmission * alpha_step * colour;
		transmission *= 1.0 - alpha_step;
	}
	float alpha = 1.0 - transmission;
	ALBEDO = radiance / max(alpha, 0.00001);
	ALPHA = alpha;
	}
}
