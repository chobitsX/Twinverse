extends RefCounted
## Original JPL SPK polynomials, coefficient compression bounded at freeze time.
## No independent clock, orbit integrator, repeated dates, or extrapolation.
const PATH: String = "res://assets/data/satellites275/manifest.json"
const START_JD: float = 2449718.5
const END_JD: float = 2469807.5
static var _manifest: Dictionary = {}
static var _binary: PackedByteArray = PackedByteArray()
static var _records: Dictionary = {}

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary and int(parsed.get("schema",0))==1: _manifest=parsed
	return _manifest

static func available(jd: float) -> bool:
	return is_finite(jd) and jd>=START_JD and jd<=END_JD

static func covers(code: int) -> bool:
	# JSON numbers are floats in Godot; Array.has does not coerce their type.
	for identity: Variant in manifest().get("major_codes",[]):
		if int(identity)==code: return true
	return false

static func sample(code: int, centre: int, jd: float) -> Dictionary:
	if not available(jd) or not covers(code): return {"valid":false}
	var body: Dictionary = _state(code,jd)
	if body.is_empty(): return {"valid":false}
	var p: Array[float] = body.position
	var v: Array[float] = body.velocity
	if int(body.center)!=centre:
		var origin: Dictionary = _state(centre,jd,str(body.kernel))
		if origin.is_empty() or int(origin.center)!=int(body.center): return {"valid":false}
		for axis: int in range(3):
			p[axis]-=float(origin.position[axis])
			v[axis]-=float(origin.velocity[axis])
	return {"valid":true,"position_km":p,"velocity_km_day":v,"distance_km":sqrt(p[0]*p[0]+p[1]*p[1]+p[2]*p[2]),"source":"JPL SPK 1995—2050"}

static func planet_centre_offset(index: int, jd: float) -> Array[float]:
	if index<3 or index>7 or not available(jd): return []
	var kernel: String = {3:"mar099s.bsp",4:"jup365.bsp",5:"sat441.bsp",6:"ura182.bsp",7:"nep097-ssd.bsp"}[index]
	var state: Dictionary = _state((index+1)*100+99,jd,kernel)
	if state.is_empty() or int(state.center)!=index+1: return []
	return state.position

static func _state(code: int, jd: float, preferred: String = "") -> Dictionary:
	var chosen: Dictionary = {}
	var segments: Array = manifest().get("segments",[])
	for i: int in range(segments.size()-1,-1,-1):
		var item: Dictionary = segments[i]
		if int(item.target)!=code or jd<float(item.start_jd) or jd>float(item.end_jd): continue
		if chosen.is_empty(): chosen=item
		if preferred.is_empty() or str(item.kernel)==preferred:
			chosen=item
			break
	if chosen.is_empty(): return {}
	if _binary.is_empty(): _binary=FileAccess.get_file_as_bytes(str(manifest().get("binary","")))
	var slot: int = clampi(int(floor((jd-float(chosen.epoch_jd))/float(chosen.step_days))),0,int(chosen.count)-1)
	var x: float = 2.0*((jd-float(chosen.epoch_jd))/float(chosen.step_days)-float(slot))-1.0
	var n: int = int(chosen.coeff_count)
	var precision: int = int(chosen.precision)
	var source_offset: int = int(chosen.offset)
	if not _records.has(source_offset):
		# Eight Saturn moons plus five planet-centre offsets need 13 records.
		# Keep a bounded cache without re-decoding those records each frame.
		if _records.size()>=16: _records.erase(_records.keys()[0])
		var compressed: PackedByteArray = _binary.slice(source_offset,source_offset+int(chosen.compressed_bytes))
		_records[source_offset]=compressed.decompress(int(chosen.uncompressed_bytes),FileAccess.COMPRESSION_DEFLATE)
	var bytes: PackedByteArray = _records[source_offset]
	var base: int = slot*3*n*precision
	if base<0 or base+3*n*precision>bytes.size(): return {}
	var coefficient_unit: float = float(chosen.coefficient_unit_km)
	var planes: int = int(chosen.count)*3*n if str(chosen.encoding)=="int64-shuffled-deflate" else 0
	var p: Array[float] = []
	var v: Array[float] = []
	for axis: int in range(3):
		var a: float = 0.0
		var b: float = 0.0
		var da: float = 0.0
		var db: float = 0.0
		for k: int in range(n-1,0,-1):
			var offset: int = base+(axis*n+k)*precision
			var c: float = _coefficient(bytes,offset,planes)*coefficient_unit
			var next: float = c+2.0*x*a-b
			var derivative: float = 2.0*a+2.0*x*da-db
			b=a; a=next; db=da; da=derivative
		var offset: int = base+axis*n*precision
		var constant: float = _coefficient(bytes,offset,planes)*coefficient_unit
		p.append(constant+x*a-b)
		v.append((a+x*da-db)*2.0/float(chosen.step_days))
	return {"position":p,"velocity":v,"center":chosen.center,"kernel":chosen.kernel}

static func _coefficient(bytes: PackedByteArray, offset: int, planes: int) -> float:
	if planes==0: return float(bytes.decode_s64(offset))
	var index: int = offset/8
	var number: int = int(bytes.decode_s8(index+planes*7))<<56
	for k: int in range(7): number|=int(bytes[index+planes*k])<<(k*8)
	return float(number)
