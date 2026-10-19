// Physical kilometres are independent of the displayed (possibly compressed) orbit.
uniform bool eclipse_enabled = false;
uniform vec3 eclipse_sun_km = vec3(149597870.7, 0.0, 0.0);
uniform vec3 eclipse_blocker_km = vec3(0.0);
uniform float eclipse_blocker_radius_km = 6371.0084;
uniform vec3 eclipse_body_km = vec3(0.0);
uniform vec3 eclipse_display_center = vec3(0.0);
uniform float eclipse_km_per_unit = 6371.0084;

float eclipse_visibility(vec3 display_point) {
	if (!eclipse_enabled) { return 1.0; }
	vec3 point = eclipse_body_km + (display_point-eclipse_display_center)*eclipse_km_per_unit;
	vec3 s = eclipse_sun_km-point, b = eclipse_blocker_km-point;
	float ds = length(s), db = length(b);
	if (db <= eclipse_blocker_radius_km) { return 0.0; }
	if (db >= ds || dot(s,b) <= 0.0) { return 1.0; }
	vec3 ns=s/ds, nb=b/db;
	float solar = asin(clamp(695700.0/ds,0.0,1.0));
	float r = asin(clamp(eclipse_blocker_radius_km/db,0.0,1.0))/solar;
	float d = atan(length(cross(ns,nb)),dot(ns,nb))/solar;
	if (r <= 0.0 || d >= 1.0+r) { return 1.0; }
	if (d <= abs(1.0-r)) { return r>=1.0 ? 0.0 : 1.0-r*r; }
	float a=acos(clamp((d*d+1.0-r*r)/(2.0*d),-1.0,1.0));
	float c=acos(clamp((d*d+r*r-1.0)/(2.0*d*r),-1.0,1.0));
	float triangle=sqrt(max(0.0,(-d+1.0+r)*(d+1.0-r)*(d-1.0+r)*(d+1.0+r)));
	return clamp(1.0-(a+r*r*c-0.5*triangle)/PI,0.0,1.0);
}
