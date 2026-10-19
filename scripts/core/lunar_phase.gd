extends RefCounted
## Read-only phase geometry: Moon98 lunar series and approximate solar direction.
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Orbit = preload("res://scripts/core/solar_ephemeris.gd")
const SOURCE: String = "https://science.nasa.gov/moon/moon-phases/"
const NAMES: Array[String] = ["新月附近","上弦附近","满月附近","下弦附近"]

static func cycle(jd: float) -> float:
	var moon: Vector3 = Orientation.moon_position_km(jd)
	var sun: Vector3 = Orientation.sun_direction(jd)
	return fposmod(atan2(-moon.z,moon.x)-atan2(-sun.z,sun.x),TAU)/TAU

static func phase_name(jd: float) -> String:
	var names: Array[String] = ["新月附近","蛾眉月","上弦附近","盈凸月","满月附近","亏凸月","下弦附近","残月"]
	return names[int(floor(cycle(jd)*8.0+.5))%8]

static func next_phase(jd: float, quarter: int) -> float:
	if not Orbit.valid_date(jd) or quarter<0 or quarter>3: return NAN
	var target: float = float(quarter)*.25
	var start: float = cycle(jd)
	var delta: float = fposmod(target-start,1.0)
	if minf(delta,1.0-delta)<1.e-7: return jd
	var end: float = minf(jd+32.0,Orbit.END_JD)
	var previous: float = jd
	var elapsed: float = 0.0
	var last: float = start
	while previous<end:
		var next: float = minf(previous+.5,end)
		var phase: float = cycle(next)
		var gain: float = fposmod(phase-last,1.0)
		if elapsed+gain>=delta:
			var low: float = previous
			var high: float = next
			for step: int in range(32):
				var middle: float = (low+high)*.5
				if elapsed+fposmod(cycle(middle)-last,1.0)<delta: low=middle
				else: high=middle
			return (low+high)*.5
		elapsed+=gain
		previous=next
		last=phase
	return NAN # No requested phase within the supported date interval.
