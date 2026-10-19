extends RefCounted
## Frozen identities and geometric states; all positions read the owner's TDB date.
const PATH: String = "res://assets/data/satellites273/catalogue.json"
const Span = preload("res://scripts/core/satellite_ephemeris_span.gd")
const START_JD: float = Span.START_JD
const END_JD: float = Span.END_JD
const CACHE_START_JD: float = 2461284.5
const CACHE_END_JD: float = 2461375.5
const HOSTS: Array[String] = ["mercury","venus","earth","mars","jupiter","saturn","uranus","neptune","pluto"]
const NAMES: Array[String] = ["水星","金星","地球","火星","木星","土星","天王星","海王星","冥王星"]
const BRANCHES: Dictionary = {"earth":"earth_moon","mars":"mars_moons","jupiter":"jupiter_moons","saturn":"saturn_moons","uranus":"uranus_moons","neptune":"neptune_moons"}
static var _catalogue: Dictionary = {}
static var _vectors: PackedByteArray = PackedByteArray()
static var _outer: Dictionary = {}
static var _outer_vectors: PackedByteArray = PackedByteArray()

static func outer() -> Dictionary:
	if _outer.is_empty() and FileAccess.file_exists("res://assets/data/satellites275/outer.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/satellites275/outer.json"))
		if parsed is Dictionary and int(parsed.get("schema",0))==1: _outer=parsed
	return _outer

static func catalogue() -> Dictionary:
	if _catalogue.is_empty():
		var file: FileAccess = FileAccess.open(PATH,FileAccess.READ)
		if file == null: return {}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary and int(parsed.get("schema",0)) == 1: _catalogue = parsed
	return _catalogue

static func records(host: String) -> Array:
	return catalogue().get("groups",{}).get(host,[])

static func host_for_scale(id: String) -> String:
	for host: String in BRANCHES:
		if BRANCHES[host] == id: return host
	return ""

static func is_system(id: String) -> bool:
	return id in ["mars_moons","jupiter_moons","saturn_moons","uranus_moons","neptune_moons"]

static func available(jd: float) -> bool:
	return is_finite(jd) and jd >= START_JD and jd <= END_JD

static func count(host: String) -> int:
	return records(host).size()

static func name(host: String) -> String:
	var index: int = HOSTS.find(host)
	return NAMES[index] if index >= 0 else host

static func sample(item: Dictionary, jd: float) -> Dictionary:
	if item.get("ephemeris_status","") != "vectors": return {"valid":false}
	if item.get("code")!=null and Span.covers(int(item.code)) and Span.available(jd):
		return Span.sample(int(item.code),int(item.centre_id),jd)
	var wide: Dictionary = outer().get("records",{}).get(str(item.key),{})
	var use_wide: bool = not wide.is_empty() and (jd<CACHE_START_JD or jd>CACHE_END_JD)
	if use_wide and (not is_finite(jd) or jd<float(wide.start_jd) or jd>float(wide.end_jd)): return {"valid":false}
	if not use_wide and (not is_finite(jd) or jd<CACHE_START_JD or jd>CACHE_END_JD): return {"valid":false}
	if use_wide:
		if _outer_vectors.is_empty(): _outer_vectors=FileAccess.get_file_as_bytes(str(outer().get("binary","")))
	elif _vectors.is_empty(): _vectors=FileAccess.get_file_as_bytes(str(catalogue().get("vector_path","")))
	var bytes: PackedByteArray = _outer_vectors if use_wide else _vectors
	var stride: int = 32 if use_wide else 56
	var offset: int = int(wide.offset) if use_wide else int(item.get("vector_offset",-1))
	var count_value: int = int(wide.count) if use_wide else int(item.get("vector_count",0))
	if offset < 0 or count_value < 2 or offset+count_value*stride > bytes.size(): return {"valid":false}
	var low: int = 0
	var high: int = count_value-1
	while high-low > 1:
		var middle: int = (low+high)/2
		if bytes.decode_double(offset+middle*stride) <= jd: low=middle
		else: high=middle
	var a: int = offset+low*stride
	var b: int = offset+high*stride
	var step: float = bytes.decode_double(b)-bytes.decode_double(a)
	var u: float = (jd-bytes.decode_double(a))/step
	var position: Array[float] = []
	var velocity: Array[float] = []
	for axis: int in range(3):
		var p0: float = bytes.decode_float(a+8+axis*4) if use_wide else bytes.decode_double(a+8+axis*8)
		var p1: float = bytes.decode_float(b+8+axis*4) if use_wide else bytes.decode_double(b+8+axis*8)
		var v0: float = bytes.decode_float(a+20+axis*4) if use_wide else bytes.decode_double(a+32+axis*8)
		var v1: float = bytes.decode_float(b+20+axis*4) if use_wide else bytes.decode_double(b+32+axis*8)
		position.append((2*u*u*u-3*u*u+1)*p0+(u*u*u-2*u*u+u)*step*v0+(-2*u*u*u+3*u*u)*p1+(u*u*u-u*u)*step*v1)
		velocity.append(((6*u*u-6*u)*p0+(3*u*u-4*u+1)*step*v0+(-6*u*u+6*u)*p1+(3*u*u-2*u)*step*v1)/step)
	return {"valid":true,"position_km":position,"velocity_km_day":velocity,"distance_km":sqrt(position[0]*position[0]+position[1]*position[1]+position[2]*position[2])}

static func major_records(host: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in records(host):
		if item.get("code")!=null and Span.covers(int(item.code)): result.append(item)
	return result

static func date_range(item: Dictionary) -> Array[float]:
	if item.get("code")!=null and Span.covers(int(item.code)) or outer().get("records",{}).has(str(item.key)): return [START_JD,END_JD]
	return [CACHE_START_JD,CACHE_END_JD]

static func has_state(item: Dictionary, jd: float) -> bool:
	if item.get("ephemeris_status","")!="vectors": return false
	var bounds: Array[float] = date_range(item)
	return is_finite(jd) and jd>=bounds[0] and jd<=bounds[1]

static func world_position(state: Dictionary, radius_km: float) -> Vector3:
	var p: Array = state.position_km
	# Normalize double precision kilometres before entering the float render world.
	return Vector3(p[0]/radius_km,p[2]/radius_km,-p[1]/radius_km)

static func description(item: Dictionary) -> String:
	var text: String = str(item.display_name)+"\n"+name(str(item.host))+"的天然卫星 · JPL/IAU名录"
	var physical: Dictionary = item.get("physical",{})
	if physical.get("mean_radius_km") != null: text += "\n平均半径 %s km" % str(physical.mean_radius_km)
	else: text += "\n此数据表未提供平均半径；点标不代表真实大小。"
	if item.get("rotation") != null:
		var w: float = float(item.rotation.polynomials[2][1])
		if absf(w)>0.0: text += "\nIAU参考自转约 %.3f 天" % (360.0/absf(w))
	else: text += "\n没有采用自转模型；不以静止示意球声称无自转。"
	if item.get("code")!=null and int(item.code)==607: text += "\n土卫七存在混沌自转，不能假定始终同面朝向土星。"
	if item.get("ephemeris_status","")=="vectors":
		text += "\nJPL几何星历：1995—2050 TDB。" if date_range(item)[0]==START_JD else "\nHorizons几何星历：2026-09-01—12-01 TDB。"
		text += "轨迹取自星历，非平均轨道推算。"
	elif item.get("ephemeris_status","")=="existing_lunar": text += "\n月球使用既有ERFA位置与NAIF朝向，共享世界日期。"
	else: text += "\n当前离线星历未覆盖，保留完整身份；不绘制猜测位置。"
	return text
