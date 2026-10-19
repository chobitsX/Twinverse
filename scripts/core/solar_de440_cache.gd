extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## Compact DE440 heliocentric positions. The observer date remains owned by Experience.
const START_JD: float = 2378496.5
const END_JD: float = 2469807.5
const MAGIC: String = "TWDE4401"
const HEADER_BYTES: int = 40
const RECORD_BYTES: int = 48
const STEPS_DAYS: Array[int] = [1, 2, 2, 4, 8, 16, 16, 16]
static var _series: Dictionary = {}
static var _failed: Dictionary = {}

static func _read_vector(file: FileAccess) -> Vector3:
	return Vector3(file.get_double(), file.get_double(), file.get_double())

static func _open(index: int) -> bool:
	if _series.has(index): return true
	if _failed.has(index): return false
	if index < 0 or index >= STEPS_DAYS.size(): return false
	var path: String = "res://assets/data/solar_de440_179/planet_%d.bin" % index
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failed[index] = "missing"
		push_warning(I18n.text("DE440离线星历不可读：") + path)
		return false
	file.big_endian = false
	var magic: String = file.get_buffer(8).get_string_from_ascii()
	var planet: int = file.get_32()
	var step: int = file.get_32()
	var count: int = file.get_32()
	var reserved: int = file.get_32()
	var first: float = file.get_double()
	var last: float = file.get_double()
	var expected_count: int = int(ceil((END_JD - START_JD) / float(STEPS_DAYS[index]))) + 1
	if magic != MAGIC or planet != index or step != STEPS_DAYS[index] or count != expected_count or reserved != 0 or first != START_JD or last != END_JD or file.get_length() != HEADER_BYTES + count * RECORD_BYTES:
		_failed[index] = "invalid_header"
		push_warning(I18n.text("DE440离线星历头或长度无效：") + path)
		return false
	_series[index] = {"file": file, "step": step, "count": count, "node": -1}
	return true

static func has_all_data() -> bool:
	for index: int in range(8):
		if not _open(index): return false
	return true

static func position_au(index: int, jd: float) -> Vector3:
	if not is_finite(jd) or jd < START_JD or jd > END_JD or not _open(index): return Vector3.INF
	var series: Dictionary = _series[index]
	var step: int = int(series.step)
	var node: int = mini(int(floor((jd - START_JD) / float(step))), int(series.count) - 2)
	if node != int(series.node):
		var file: FileAccess = series.file
		file.seek(HEADER_BYTES + node * RECORD_BYTES)
		series.p0 = _read_vector(file)
		series.v0 = _read_vector(file)
		series.p1 = _read_vector(file)
		series.v1 = _read_vector(file)
		series.node = node
		_series[index] = series
	var left: float = START_JD + float(node * step)
	var span: float = minf(float(step), END_JD - left)
	var u: float = (jd - left) / span
	var u2: float = u * u
	var u3: float = u2 * u
	return (2.0*u3 - 3.0*u2 + 1.0)*Vector3(series.p0) + (u3 - 2.0*u2 + u)*span*Vector3(series.v0) + (-2.0*u3 + 3.0*u2)*Vector3(series.p1) + (u3-u2)*span*Vector3(series.v1)

static func velocity_au_per_day(index: int, jd: float) -> Vector3:
	# Derivative of the same cubic Hermite segment used for the visible position.
	if not position_au(index,jd).is_finite(): return Vector3.INF
	var series: Dictionary = _series[index]
	var step: int = int(series.step)
	var left: float = START_JD + float(int(series.node) * step)
	var span: float = minf(float(step), END_JD - left)
	var u: float = (jd - left) / span
	var u2: float = u * u
	return ((6.0*u2-6.0*u)/span)*Vector3(series.p0) + (3.0*u2-4.0*u+1.0)*Vector3(series.v0) + ((-6.0*u2+6.0*u)/span)*Vector3(series.p1) + (3.0*u2-2.0*u)*Vector3(series.v1)

static func position_components_au(index: int, jd: float) -> Array[float]:
	# Keep float64 components until a host-relative subtraction is complete.
	# Vector3 is a render vector and must not round heliocentric AU first.
	if not is_finite(jd) or jd<START_JD or jd>END_JD or not _open(index): return []
	var series: Dictionary = _series[index]
	var step: int = int(series.step)
	var node: int = mini(int(floor((jd-START_JD)/float(step))),int(series.count)-2)
	if int(series.get("raw_node",-1))!=node:
		var file: FileAccess = series.file
		file.seek(HEADER_BYTES+node*RECORD_BYTES)
		var values: Array[float] = []
		for i: int in range(12): values.append(file.get_double())
		series.raw_values=values; series.raw_node=node
	var values: Array[float] = series.raw_values
	var left: float = START_JD+node*step
	var span: float = minf(float(step),END_JD-left)
	var u: float = (jd-left)/span
	var result: Array[float] = []
	for axis: int in range(3):
		result.append((2*u*u*u-3*u*u+1)*values[axis]+(u*u*u-2*u*u+u)*span*values[axis+3]+(-2*u*u*u+3*u*u)*values[axis+6]+(u*u*u-u*u)*span*values[axis+9])
	return result
