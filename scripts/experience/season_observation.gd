extends RefCounted
## View-only presets computed with the existing solar geometry and date authority.
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Sites = preload("res://scripts/data/earth_sites.gd")
const Orbit = preload("res://scripts/core/solar_ephemeris.gd")
const SOURCE: String = "https://science.nasa.gov/earth/facts/"
const DATES: Array[String] = ["2026-03-20","2026-06-21","2026-09-23","2026-12-22"]

static func date_jd(date: String) -> float:
	return 2440587.5+float(Time.get_unix_time_from_datetime_string(date+"T00:00:00"))/86400.0

static func noon(jd: float, longitude: float) -> float:
	# Solve upper meridian transit. The label remains approximate: the base
	# model omits EOP, UTC conversion, refraction and real terrain horizons.
	# The endpoint is midnight 2050-01-01; use the last complete valid day.
	var day: float = clampf(floor(jd-.5)+.5,Orbit.START_JD,Orbit.END_JD-1.0)
	var guess: float = day+.5-longitude/360.0
	for iteration: int in range(4):
		var sun: Vector3 = Orientation.sun_ecef(guess)
		var error: float = wrapf(atan2(sun.x,sun.z)-deg_to_rad(longitude),-PI,PI)
		guess += error/TAU
	return guess

static func preset(index: int, scale_id: String) -> float:
	var jd: float = date_jd(DATES[clampi(index,0,DATES.size()-1)])
	var site: Dictionary = Sites.for_scale(scale_id)
	return noon(jd,float(site.lon)) if scale_id in ["woodland","city","desert","polar","arctic"] else jd+4.0/24.0

static func sample(jd: float, scale_id: String) -> Dictionary:
	var site: Dictionary = Sites.for_scale(scale_id)
	if site.is_empty(): return {}
	var sun: Vector3 = Orientation.local_sun(jd,float(site.lat),float(site.lon))
	return {"elevation":rad_to_deg(asin(clampf(sun.y,-1,1))),"daylight":Orientation.latitude_daylight_hours(float(site.lat),jd),"sun":sun}

static func readout(host: Node) -> String:
	var value: Dictionary = sample(host.solar_jd,host.world.current_scale_id)
	if value.is_empty(): return ""
	return "%s\n太阳高度 %.1f° · 昼长 %.1f h\n%s参考光照 · %s" % [Orientation.timestamp(host.solar_jd),value.elevation,value.daylight,Sites.latitude_label(float(Sites.for_scale(host.world.current_scale_id).lat)),"随日期变化" if host.ground_light_preview else "当前为固定展示光照"]
