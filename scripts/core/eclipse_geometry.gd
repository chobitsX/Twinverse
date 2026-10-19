extends RefCounted
## Uniform angular discs; geometric direct sunlight, not eclipse predictions.
const Orbit = preload("res://scripts/core/solar_ephemeris.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const SUN_RADIUS_KM: float = 695700.0
const AU_KM: float = 149597870.7
const SOURCE: String = "https://science.nasa.gov/eclipses/geometry/"
# Rounded TDB demonstration dates near documented events, not contact times.
const SOLAR_EXAMPLE_JD: float = 2460409.2625 # 2024-04-08 18:18 TDB
const LUNAR_EXAMPLE_JD: float = 2460748.791666667 # 2025-03-14 07:00 TDB

static func disc_visibility(sun_radius: float, blocker_radius: float, separation: float) -> float:
	if not is_finite(sun_radius) or not is_finite(blocker_radius) or not is_finite(separation) or sun_radius <= 0.0 or blocker_radius < 0.0 or separation < 0.0: return NAN
	# Scale by the solar angular radius to avoid tiny fourth-order products.
	var r: float = blocker_radius / sun_radius
	var d: float = separation / sun_radius
	if r == 0.0 or d >= 1.0 + r: return 1.0
	if d <= absf(1.0-r): return 0.0 if r >= 1.0 else 1.0-r*r
	var a: float = acos(clampf((d*d+1.0-r*r)/(2.0*d),-1.0,1.0))
	var b: float = acos(clampf((d*d+r*r-1.0)/(2.0*d*r),-1.0,1.0))
	var triangle: float = sqrt(maxf(0.0,(-d+1.0+r)*(d+1.0-r)*(d-1.0+r)*(d+1.0+r)))
	return clampf(1.0-(a+r*r*b-0.5*triangle)/PI,0.0,1.0)

static func visibility(point_km: Vector3, sun_km: Vector3, blocker_km: Vector3, blocker_radius_km: float) -> float:
	if not point_km.is_finite() or not sun_km.is_finite() or not blocker_km.is_finite() or not is_finite(blocker_radius_km) or blocker_radius_km < 0.0: return NAN
	var s: Vector3 = sun_km-point_km
	var b: Vector3 = blocker_km-point_km
	var ds: float = s.length()
	var db: float = b.length()
	if ds <= SUN_RADIUS_KM: return NAN
	if db <= blocker_radius_km: return 0.0
	if db >= ds or s.dot(b) <= 0.0: return 1.0
	var direction_s: Vector3 = s/ds
	var direction_b: Vector3 = b/db
	# atan2 stays well-conditioned near alignment; acos(dot) does not in float32.
	var angle: float = atan2(direction_s.cross(direction_b).length(),direction_s.dot(direction_b))
	return disc_visibility(asin(SUN_RADIUS_KM/ds),asin(blocker_radius_km/db),angle)

static func sample(jd: float) -> Dictionary:
	if not Orbit.valid_date(jd): return {"valid":false}
	var earth: Vector3 = Orbit.position_au(2,jd)
	# Same J2000 ecliptic frame as Moon98's render coordinates. Solar origin is
	# the approximate Earth-Moon barycentre, as in the existing solar model.
	var sun: Vector3 = -Vector3(earth.x,earth.z,-earth.y)*AU_KM
	var moon: Vector3 = Orientation.moon_position_km(jd)
	return {"valid":true,"sun_km":sun,"moon_km":moon,
		"moon_center_visibility":visibility(moon,sun,Vector3.ZERO,Orbit.RADII_KM[2])}

static func solar_axis_surface(state: Dictionary) -> Vector3:
	# Entry of the shadow axis into spherical Earth, or the subsolar point when
	# it misses. This is a camera target, not a geographic eclipse-path service.
	var moon: Vector3 = state.moon_km
	var direction: Vector3 = (moon-Vector3(state.sun_km)).normalized()
	var along: float = -moon.dot(direction)
	var closest: Vector3 = moon+direction*along
	var square: float = Orbit.RADII_KM[2]*Orbit.RADII_KM[2]-closest.length_squared()
	if along>0.0 and square>=0.0: return moon+direction*(along-sqrt(square))
	return Vector3(state.sun_km).normalized()*Orbit.RADII_KM[2]
