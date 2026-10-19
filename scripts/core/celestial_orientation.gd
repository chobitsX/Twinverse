extends RefCounted
## Pure astronomical observation geometry. No authority or independent clock.
## NAIF pck00011 text-PCK orientation; Earth EOP not included.
const RotationData = preload("res://scripts/data/planet_rotations.gd")
const Lunar = preload("res://scripts/core/lunar_ephemeris.gd")
const Orbit = preload("res://scripts/core/solar_ephemeris.gd")
const OBLIQUITY: float = 23.439291111
const MOON_A_KM: float = 384400.0
const MOON_RADIUS_KM: float = 1737.4
const MOON_E: float = 0.0554
const MOON_SIDEREAL_DAYS: float = 27.322
const SUN_ROTATION: Dictionary = {"polynomials":[[286.13,0.0,0.0],[63.87,0.0,0.0],[84.176,14.18440,0.0]],"periodic":[[],[],[]],"phases":[]}


static func equatorial_to_world(value: Vector3) -> Vector3:
	var e: float = deg_to_rad(OBLIQUITY)
	return Vector3(value.x,-sin(e)*value.y+cos(e)*value.z,-cos(e)*value.y-sin(e)*value.z)

static func body_basis(index: int, jd: float) -> Basis:
	return orientation_basis(RotationData.BODIES[index],jd)

static func sun_basis(jd: float) -> Basis:
	# Same frozen pck00011 BODY10 reference frame, not solar differential flow.
	return orientation_basis(SUN_ROTATION,jd)

static func rotation_label(index: int) -> String:
	var days: float = absf(rotation_days(index))
	return "IAU参考自转 %.2f 小时" % (days*24.0) if days<2.0 else "恒星自转 %.2f 天" % days

static func orientation_basis(data: Dictionary, jd: float) -> Basis:
	var days: float = jd-Orbit.EPOCH
	var centuries: float = days/36525.0
	var angles: Array[float] = []
	for axis: int in range(3):
		var c: Array = data.polynomials[axis]
		var t: float = days if axis==2 else centuries
		var angle: float = c[0]+c[1]*t+c[2]*t*t
		var periodic: Array = data.periodic[axis]
		for k: int in range(periodic.size()):
			var phase: Array = data.phases[k]
			var arg: float = deg_to_rad(phase[0]+phase[1]*centuries+(phase[2]*centuries*centuries if phase.size()==3 else 0.0))
			angle += periodic[k]*(cos(arg) if axis==1 else sin(arg))
		angles.append(deg_to_rad(fposmod(angle,360.0)))
	var ra: float = angles[0]
	var dec: float = angles[1]
	var w: float = angles[2]
	var pole: Vector3 = Vector3(cos(dec)*cos(ra),cos(dec)*sin(ra),sin(dec))
	var node: Vector3 = Vector3(-sin(ra),cos(ra),0)
	var tangent: Vector3 = pole.cross(node)
	var prime: Vector3 = node*cos(w)+tangent*sin(w)
	var east: Vector3 = -node*sin(w)+tangent*cos(w)
	# Project texture convention: +Z is prime meridian, +X east, +Y north.
	return Basis(equatorial_to_world(east),equatorial_to_world(pole),equatorial_to_world(prime))

static func rotation_days(index: int) -> float:
	return 360.0/float(RotationData.BODIES[index].polynomials[2][1])

static func obliquity_deg(index: int, jd: float) -> float:
	var el: Array[float] = Orbit.elements(index,jd)
	var node: float = deg_to_rad(el[5])
	var inc: float = deg_to_rad(el[2])
	var normal: Vector3 = Vector3(sin(inc)*sin(node),cos(inc),sin(inc)*cos(node))
	var spin: Vector3 = body_basis(index,jd).y*signf(rotation_days(index))
	return rad_to_deg(acos(clampf(spin.dot(normal),-1.0,1.0)))

static func sun_direction(jd: float) -> Vector3:
	return -Orbit.display_position(2,jd,true).normalized()

static func sun_ecef(jd: float) -> Vector3:
	return body_basis(2,jd).transposed()*sun_direction(jd)

static func moon_elements(jd: float) -> Array[float]:
	# JPL satellite mean elements, J2000 ecliptic. P_apsis is ARGUMENT
	# precession, not longitude of pericenter. Nodal precession is retrograde.
	var days: float = jd-Orbit.EPOCH
	var node: float = 125.08-360.0*days/(18.600*365.25)
	var argument: float = 318.15+360.0*days/(5.997*365.25)
	var longitude: float = 125.08+318.15+135.27+360.0*days/MOON_SIDEREAL_DAYS
	return [MOON_A_KM,MOON_E,5.16,longitude,argument+node,node]

static func mean_moon_position_km(jd: float) -> Vector3:
	# Retained only for historical error comparison; runtime uses the series below.
	var el: Array[float] = moon_elements(jd)
	var e: float = Orbit.eccentric_anomaly(deg_to_rad(el[3]-el[4]),el[1])
	var p: Vector3 = Orbit.orbital_point(el,e)
	return Vector3(p.x,p.z,-p.y)

static func moon_position_km(jd: float) -> Vector3:
	var state: Dictionary=Lunar.sample(jd)
	return state.world_km if state.valid else Vector3(NAN,NAN,NAN)

static func moon_basis(jd: float) -> Basis:
	# NAIF IAU_MOON periodic orientation: independent of instantaneous Earth bearing.
	return orientation_basis(Lunar.Data.ROTATION,jd)

static func lunar_libration(jd: float) -> Vector2:
	var local: Vector3=moon_basis(jd).transposed()*(-moon_position_km(jd).normalized())
	return Vector2(rad_to_deg(atan2(local.x,local.z)),rad_to_deg(asin(clampf(local.y,-1.,1.))))

static func illumination(jd: float) -> float:
	return clampf((1.0+sun_direction(jd).dot(-moon_position_km(jd).normalized()))*0.5,0.0,1.0)

static func latitude_daylight_hours(latitude: float, jd: float) -> float:
	var dec: float = asin(clampf(sun_ecef(jd).y,-1.0,1.0))
	var limit: float = -tan(deg_to_rad(clampf(latitude,-89.999,89.999)))*tan(dec)
	return 24.0*acos(clampf(limit,-1.0,1.0))/PI

static func local_sun(jd: float, latitude: float, longitude: float) -> Vector3:
	var lat: float = deg_to_rad(latitude)
	var lon: float = deg_to_rad(longitude)
	var up: Vector3 = Vector3(cos(lat)*sin(lon),sin(lat),cos(lat)*cos(lon))
	var east: Vector3 = Vector3(cos(lon),0,-sin(lon))
	var north: Vector3 = Vector3(-sin(lat)*sin(lon),cos(lat),-sin(lat)*cos(lon))
	return Basis(east,up,-north).transposed()*sun_ecef(jd)

static func timestamp(jd: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(round((jd-2440587.5)*86400.0))).replace("T"," ")+" TDB"
