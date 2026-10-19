extends RefCounted
## Offline geometric Horizons vectors, Jupiter centre, J2000 ecliptic, TDB.
## Not apparent Earth-observer positions and not an N-body integrator.
const PATH: String = "res://assets/data/jovian117/vectors.json"
const SOURCE: String = "https://ssd.jpl.nasa.gov/horizons/"
const START_JD: float = 2461284.5
const END_JD: float = 2461375.5
const STEP_DAYS: float = 1./24.
const NAMES: Array[String] = ["木卫一 · Io","木卫二 · Europa","木卫三 · Ganymede","木卫四 · Callisto"]
const IDS: Array[int] = [501,502,503,504,10]
const RADII_KM: Array[float] = [1821.49,1560.80,2631.20,2410.30]
static var _data: Dictionary = {}
static var _attempted: bool = false

static func available(jd: float) -> bool:
	return is_finite(jd) and jd>=START_JD and jd<=END_JD

static func load_data() -> bool:
	if _attempted: return not _data.is_empty()
	_attempted=true
	if not FileAccess.file_exists(PATH): return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary: return false
	if parsed.get("schema")!=1 or parsed.get("centre_id")!=599: return false
	if parsed.get("frame")!="J2000 ecliptic" or parsed.get("time_scale")!="TDB": return false
	if parsed.get("position_unit")!="km" or parsed.get("velocity_unit")!="km/day": return false
	if parsed.get("start_jd")!=START_JD or parsed.get("end_jd")!=END_JD: return false
	var series: Variant = parsed.get("series")
	if not series is Array or series.size()!=5: return false
	for i: int in range(5):
		if not series[i] is Dictionary or series[i].get("id")!=IDS[i]: return false
		var rows: Variant = series[i].get("rows")
		if not rows is Array or rows.size()!=2185: return false
		for k: int in range(rows.size()):
			var row: Variant = rows[k]
			if not row is Array or row.size()!=7: return false
			for number: Variant in row:
				if not (number is float or number is int) or not is_finite(float(number)): return false
			if absf(float(row[0])-(START_JD+k*STEP_DAYS))>1.e-8: return false
	_data=parsed
	return true

static func sample(index: int, jd: float) -> Dictionary:
	if index<0 or index>=5: return {"valid":false,"reason":"unknown_body"}
	if not available(jd): return {"valid":false,"reason":"outside_frozen_dates"}
	if not load_data(): return {"valid":false,"reason":"data_unavailable"}
	var rows: Array = _data.series[index].rows
	var slot: int = mini(int(floor((jd-START_JD)/STEP_DAYS)),rows.size()-2)
	var a: Array = rows[slot]
	var b: Array = rows[slot+1]
	var h: float = float(b[0])-float(a[0])
	var u: float = clampf((jd-float(a[0]))/h,0.,1.)
	var u2: float = u*u
	var u3: float = u2*u
	var position: Array[float] = []
	var velocity: Array[float] = []
	for axis: int in range(3):
		var p0: float = a[axis+1]
		var p1: float = b[axis+1]
		var v0: float = a[axis+4]
		var v1: float = b[axis+4]
		position.append((2.*u3-3.*u2+1.)*p0+(u3-2.*u2+u)*h*v0+(-2.*u3+3.*u2)*p1+(u3-u2)*h*v1)
		velocity.append(((6.*u2-6.*u)*p0+(3.*u2-4.*u+1.)*h*v0+(-6.*u2+6.*u)*p1+(3.*u2-2.*u)*h*v1)/h)
	# Keep scientific components as scalar float64; Vector3 is for rendering only.
	return {"valid":true,"id":IDS[index],"jd":jd,"position_km":position,"velocity_km_day":velocity,"world_km":Vector3(position[0],position[2],-position[1]),"distance_km":sqrt(position[0]*position[0]+position[1]*position[1]+position[2]*position[2])}

static var _periods: Array[float] = []
static func period_days(index: int) -> float:
	if index<0 or index>=4 or not load_data(): return NAN
	if _periods.is_empty():
		for body: int in range(4):
			var rows: Array = _data.series[body].rows
			var first: Array = rows[0]
			var previous: Vector3 = Vector3(first[1],first[2],first[3])
			var pole: Vector3 = previous.cross(Vector3(first[4],first[5],first[6])).normalized()
			var angle: float = 0.
			for k: int in range(1,rows.size()):
				var row: Array = rows[k]
				var current: Vector3 = Vector3(row[1],row[2],row[3])
				angle+=atan2(pole.dot(previous.cross(current)),previous.dot(current))
				previous=current
			_periods.append((END_JD-START_JD)*TAU/angle)
	return _periods[index]
