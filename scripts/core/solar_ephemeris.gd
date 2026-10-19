extends RefCounted
## DE440 cached positions, Table 1 teaching ellipses. TDB days, AU, J2000 ecliptic.
## No integrator or independent clock. Earth is the Earth-Moon barycenter.
const De440 = preload("res://scripts/core/solar_de440_cache.gd")
const EPOCH: float = 2451545.0
const START_JD: float = 2378496.5 # 1800-01-01
const END_JD: float = 2469807.5 # 2050-01-01; conservative end of validity
const DEFAULT_JD: float = 2461299.5 # 2026-09-16 00:00 TDB (educational epoch)
const NAMES: Array[String] = ["水星", "金星", "地球", "火星", "木星", "土星", "天王星", "海王星"]
const ELEMENTS: Array = [
[0.38709927,0.20563593,7.00497902,252.25032350,77.45779628,48.33076593],
[0.72333566,0.00677672,3.39467605,181.97909950,131.60246718,76.67984255],
[1.00000261,0.01671123,-0.00001531,100.46457166,102.93768193,0.0],
[1.52371034,0.09339410,1.84969142,-4.55343205,-23.94362959,49.55953891],
[5.20288700,0.04838624,1.30439695,34.39644051,14.72847983,100.47390909],
[9.53667594,0.05386179,2.48599187,49.95424423,92.59887831,113.66242448],
[19.18916464,0.04725744,0.77263783,313.23810451,170.95427630,74.01692503],
[30.06992276,0.00859048,1.77004347,-55.12002969,44.96476227,131.78422574]]
const RATES: Array = [
[0.00000037,0.00001906,-0.00594749,149472.67411175,0.16047689,-0.12534081],
[0.00000390,-0.00004107,-0.00078890,58517.81538729,0.00268329,-0.27769418],
[0.00000562,-0.00004392,-0.01294668,35999.37244981,0.32327364,0.0],
[0.00001847,0.00007882,-0.00813131,19140.30268499,0.44441088,-0.29257343],
[-0.00011607,-0.00013253,-0.00183714,3034.74612775,0.21252668,0.20469106],
[-0.00125060,-0.00050991,0.00193609,1222.49362201,-0.41897216,-0.28867794],
[-0.00196176,-0.00004397,-0.00242939,428.48202785,0.40805281,0.04240589],
[0.00026291,0.00005105,0.00035372,218.45945325,-0.32241464,-0.00508664]]
const RADII_KM: Array[float] = [2439.4,6051.8,6371.0084,3389.5,69911,58232,25362,24622]
const PERIOD_YEARS: Array[float] = [0.2408467,0.61519726,1.0000174,1.8808476,11.862615,29.447498,84.016846,164.79132]
## Overview only: spaced radial bands include Saturn's rings and local Moon.
## Real AU distances and every scientific vector remain unchanged.
const DISPLAY_A: Array[float] = [2.7,3.9,6.2,9.3,13.5,19.0,24.0,27.0]
const AU_KM: float = 149597870.7 # IAU 2012 Resolution B2, exact AU in km.

static func valid_date(jd: float) -> bool:
	return is_finite(jd) and jd >= START_JD and jd <= END_JD

static func elements(index: int, jd: float) -> Array[float]:
	if index < 0 or index >= 8 or not valid_date(jd): return []
	var t: float = (jd - EPOCH) / 36525.0
	var result: Array[float] = []
	for k: int in range(6): result.append(ELEMENTS[index][k] + t * RATES[index][k])
	return result

static func eccentric_anomaly(mean: float, eccentricity: float) -> float:
	var m: float = wrapf(mean, -PI, PI)
	var e: float = m
	for _k: int in range(12):
		var correction: float = (e - eccentricity * sin(e) - m) / (1.0 - eccentricity * cos(e))
		e -= correction
		if absf(correction) < 1e-12: break
	return e

static func orbital_point(el: Array[float], anomaly: float) -> Vector3:
	var x: float = el[0] * (cos(anomaly) - el[1])
	var y: float = el[0] * sqrt(1.0 - el[1]*el[1]) * sin(anomaly)
	var w: float = deg_to_rad(el[4] - el[5])
	var node: float = deg_to_rad(el[5])
	var inc: float = deg_to_rad(el[2])
	var u: float = cos(w)*x - sin(w)*y
	var v: float = sin(w)*x + cos(w)*y
	return Vector3(cos(node)*u - sin(node)*cos(inc)*v, sin(node)*u + cos(node)*cos(inc)*v, sin(inc)*v)

static func position_au(index: int, jd: float) -> Vector3:
	if index < 0 or index >= 8 or not valid_date(jd): return Vector3.INF
	var cached: Vector3 = De440.position_au(index, jd)
	if cached.is_finite(): return cached
	return approximate_position_au(index, jd)

static func speed_km_s(index: int, jd: float) -> float:
	if index < 0 or index >= 8 or not valid_date(jd): return INF
	var velocity: Vector3 = De440.velocity_au_per_day(index,jd)
	return velocity.length()*AU_KM/86400.0 if velocity.is_finite() else INF

static func approximate_position_au(index: int, jd: float) -> Vector3:
	var el: Array[float] = elements(index,jd)
	if el.is_empty(): return Vector3.INF
	return orbital_point(el, eccentric_anomaly(deg_to_rad(el[3]-el[4]),el[1]))

static func position_source() -> String:
	return "DE440离线行星位置" if De440.has_all_data() else "JPL Table 1近似位置（离线数据不可用）"

static func trajectory_window(index: int, jd: float) -> Array[float]:
	if index < 0 or index >= 8 or not valid_date(jd): return []
	var span_days: float = PERIOD_YEARS[index] * 365.25
	var first: float = clampf(jd - span_days * 0.5, START_JD, END_JD - span_days)
	return [first, first + span_days]

static func display_position(index: int, jd: float, true_distance: bool = false) -> Vector3:
	return display_vector(index, position_au(index,jd), true_distance)

static func display_vector(index: int, value: Vector3, true_distance: bool) -> Vector3:
	# Fixed uniform scale per entire ellipse preserves focus/eccentricity/plane.
	var scale_factor: float = 0.55 if true_distance else DISPLAY_A[index] / ELEMENTS[index][0]
	return Vector3(value.x, value.z, -value.y) * scale_factor

static func body_display_scale(index: int, true_distance: bool) -> float:
	# The enlarged local Earth-Moon group must fit between Venus and Mars in
	# AU view too. Both bodies and their local orbit use this same factor.
	return (0.045 if index==2 else 0.16) if true_distance else 1.0

static func date_label(jd: float) -> String:
	return Time.get_date_string_from_unix_time(int((jd - 2440587.5)*86400.0)) + " TDB"
