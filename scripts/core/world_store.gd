extends RefCounted
## Plain JSON values only. Scene nodes/resources never enter a save file.

const WorldState = preload("res://scripts/core/world_state.gd")
const Catalog = preload("res://scripts/core/scale_catalog.gd")
const FORMAT_VERSION: int = 3
const MAX_FILE_BYTES: int = 1048576
const HEART_REGIONS: Array[String] = ["", "sinus_venosus", "atrium", "ventricle", "bulbus_arteriosus"]

var directory: String
var protected: bool = false
var _opened: bool = false
var _expected_identity: String = ""


func _init(path: String = "user://world") -> void:
	directory = ProjectSettings.globalize_path(path)


func load_session() -> Dictionary:
	_opened = true
	protected = false
	_expected_identity = _disk_identity()
	var primary: Dictionary = _read("current.json")
	if primary.status == "ok": return primary
	if primary.status in ["incompatible", "unreadable"]:
		protected = true
		return primary
	# A complete previous checkpoint wins over an uncommitted pending write.
	for filename: String in ["previous.json", "pending.json"]:
		var candidate: Dictionary = _read(filename)
		if candidate.status == "ok":
			candidate.status = "recovered"
			candidate["source"] = filename
			return candidate
		if candidate.status in ["incompatible", "unreadable"]:
			protected = true
			return candidate
		if candidate.status != "missing": primary = candidate
	protected = primary.status != "missing"
	return primary


func save_session(payload: Dictionary) -> String:
	if not _opened: return "not_opened"
	if protected: return "protected"
	var invalid: String = payload_error(payload)
	if not invalid.is_empty(): return invalid
	if _disk_identity() != _expected_identity:
		protected = true
		return "changed_on_disk"
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK: return "directory_unwritable"
	# Replace the backup only with a validated committed file. A corrupt primary
	# must never displace the good backup from which this session recovered.
	var primary: Dictionary = _read("current.json")
	if primary.status != "ok" and _read("previous.json").status != "ok":
		# First-save interruption can leave pending.json as the only valid copy.
		# Preserve it before attempting to write a new pending checkpoint.
		primary = _read("pending.json")
	if primary.status == "ok":
		if not _write("previous.pending.json", str(primary.raw)): return "backup_write_failed"
		if DirAccess.rename_absolute(directory.path_join("previous.pending.json"), directory.path_join("previous.json")) != OK:
			return "backup_replace_failed"
	# Each file is flushed and closed before the same-directory rename.
	var payload_text: String = JSON.stringify(payload, "", true, true)
	var text: String = JSON.stringify({"format": "twinverse-world", "version": FORMAT_VERSION,
		"payload": payload_text, "sha256": payload_text.sha256_text()})
	if not _write("pending.json", text):
		_expected_identity = _disk_identity()
		return "write_failed"
	if _read("pending.json").status != "ok":
		_expected_identity = _disk_identity()
		return "verification_failed"
	error = DirAccess.rename_absolute(directory.path_join("pending.json"), directory.path_join("current.json"))
	_expected_identity = _disk_identity()
	return "ok" if error == OK else "replace_failed"


func _read(filename: String) -> Dictionary:
	var path: String = directory.path_join(filename)
	if not FileAccess.file_exists(path): return {"status": "missing"}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: return {"status": "unreadable"}
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return {"status": "corrupt"}
	var raw: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(raw) != OK or not json.data is Dictionary: return {"status": "corrupt"}
	var envelope: Dictionary = json.data
	if envelope.get("format") != "twinverse-world": return {"status": "corrupt"}
	if envelope.get("version") != 1 and envelope.get("version") != 2 and envelope.get("version") != FORMAT_VERSION: return {"status": "incompatible"}
	if not envelope.get("payload") is String or not envelope.get("sha256") is String: return {"status": "corrupt"}
	if str(envelope.payload).sha256_text() != envelope.sha256: return {"status": "corrupt"}
	if json.parse(envelope.payload) != OK or not json.data is Dictionary: return {"status": "corrupt"}
	var payload: Dictionary = json.data
	var invalid: String = payload_error(payload)
	if not invalid.is_empty(): return {"status": "incompatible" if invalid == "incompatible" else "corrupt"}
	return {"status": "ok", "payload": payload, "raw": raw}


func _write(filename: String, text: String) -> bool:
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES: return false
	var file: FileAccess = FileAccess.open(directory.path_join(filename), FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	file.flush()
	var status: Error = file.get_error()
	file.close()
	return status == OK


func _disk_identity() -> String:
	var result: String = ""
	for filename: String in ["current.json", "previous.json", "pending.json"]:
		var path: String = directory.path_join(filename)
		result += FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return result


static func payload_error(payload: Dictionary) -> String:
	if not payload.get("world") is Dictionary or not payload.get("observer") is Dictionary:
		return "invalid_payload"
	var invalid: String = WorldState.checkpoint_error(payload.world)
	if not invalid.is_empty(): return invalid
	var observer: Dictionary = payload.observer
	if not observer.get("views") is Dictionary or not observer.get("preferences") is Dictionary:
		return "invalid_observer"
	if not observer.views.has(str(payload.world.current_scale_id)) or observer.views.size() > Catalog.SCALES.size():
		return "missing_current_view"
	for scale_id: Variant in observer.views:
		if not scale_id is String or not Catalog.contains(scale_id) or not observer.views[scale_id] is Dictionary:
			return "invalid_view"
		if not valid_view(observer.views[scale_id]): return "invalid_view"
	var preferences: Dictionary = observer.preferences
	if not WorldState.finite_number(preferences.get("render_ratio")) or float(preferences.render_ratio) not in [0.5, 0.75, 1.0]:
		return "invalid_quality"
	for key: String in ["muted", "reduced_motion"]:
		if not preferences.get(key) is bool: return "invalid_" + key
	for key: String in ["master", "environment_volume", "music_volume", "effects_volume"]:
		if not WorldState.finite_number(preferences.get(key)) or preferences[key] < 0.0 or preferences[key] > 1.0:
			return "invalid_volume"
	return ""


static func valid_view(view: Dictionary) -> bool:
	if view.has("local_geometry_version") and (not WorldState.finite_number(view.local_geometry_version) or float(view.local_geometry_version)!=1.0): return false
	if view.has("solar_physical_context") and (not WorldState.finite_number(view.solar_physical_context) or float(view.solar_physical_context)!=float(int(view.solar_physical_context)) or int(view.solar_physical_context)<-1 or int(view.solar_physical_context)>8): return false
	if view.has("solar_geometry_version") and (not WorldState.finite_number(view.solar_geometry_version) or float(view.solar_geometry_version)!=1.0): return false
	if view.has("solar_exploring") and not view.solar_exploring is bool: return false
	if view.has("solar_observer_target") and (not WorldState.finite_number(view.solar_observer_target) or float(view.solar_observer_target)!=float(int(view.solar_observer_target)) or int(view.solar_observer_target)<-1 or int(view.solar_observer_target)>31): return false
	if view.has("solar_lookaround") and not view.solar_lookaround is bool: return false
	if view.has("solar_look_fov") and (not WorldState.finite_number(view.solar_look_fov) or float(view.solar_look_fov)<.05 or float(view.solar_look_fov)>80.0): return false
	if view.has("satellite_framing") and not _valid_satellite_framing(view.satellite_framing): return false
	if view.has("satellite_key") and (not view.satellite_key is String or view.satellite_key.length()>80): return false
	if view.has("sky_fov") and (not WorldState.finite_number(view.sky_fov) or float(view.sky_fov)<1.0 or float(view.sky_fov)>104.0): return false
	if view.has("city_people_view") and not view.city_people_view is bool: return false
	if view.has("city_street_view") and not view.city_street_view is bool: return false
	if bool(view.get("city_people_view",false)) and bool(view.get("city_street_view",false)): return false
	if view.has("astronomy"):
		var a: Variant = view.astronomy
		if not a is Dictionary: return false
		for key: String in ["jd","time","rate"]:
			if not WorldState.finite_number(a.get(key)): return false
		if a.has("ground_light") and not a.ground_light is bool: return false
		if a.has("auto") and not a.auto is bool: return false
		if a.has("manual") and not a.manual is bool: return false
		if a.jd<2378496.5 or a.jd>2469807.5 or a.time<0 or not _valid_astronomy_rate(float(a.rate)) or not a.get("true_distance") is bool: return false
		if a.has("close_playback"):
			var close: Variant=a.close_playback
			if not close is Dictionary or not WorldState.finite_number(close.get("rate")) or not close.get("auto") is bool or not WorldState.finite_number(close.get("target")): return false
			if not _valid_astronomy_rate(float(close.rate)) or close.rate<=1.0/24.0 or close.target<0 or close.target>31 or close.target!=floorf(float(close.target)): return false
			if close.target>9 and str(view.get("satellite_key","")).is_empty(): return false
			if close.has("context") and (not close.context is bool or bool(close.context) and (close.target<3 or close.target>7)): return false
			if absf(float(a.rate)-1.0/24.0)>1e-12 or bool(a.get("manual",false)) or bool(a.get("auto",false)): return false
	for key: String in ["position", "target", "up"]:
		if not view.get(key) is Array or view[key].size() != 3: return false
		for component: Variant in view[key]:
			if not WorldState.finite_number(component) or absf(float(component)) > 1.0e9: return false
	var direction: Vector3 = vector(view.target) - vector(view.position)
	var up: Vector3 = vector(view.up)
	if direction.length_squared() < 1.0e-10 or up.length_squared() < 0.5 or up.length_squared() > 1.5: return false
	if absf(direction.normalized().dot(up.normalized())) > 0.9999: return false
	return view.get("cutaway") is bool and view.get("heart_region") in HEART_REGIONS and view.get("info_visible") is bool


static func vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


static func components(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func _valid_astronomy_rate(value: float) -> bool:
	for rate: float in [0.0,1.0/1440.0,1.0/240.0,1.0/24.0,.25,1.0,10.0,15.0,30.0,100.0]:
		if absf(value-rate)<1e-12: return true
	return false


static func _valid_satellite_framing(value: Variant) -> bool:
	if not value is Dictionary or value.get("mode","") not in ["pair","detail"]: return false
	if not WorldState.finite_number(value.get("owner")) or float(value.owner)!=floorf(float(value.owner)) or int(value.owner)<2 or int(value.owner)>7: return false
	if not value.get("key") is String or value.key.length()>80: return false
	if str(value.mode)=="detail": return WorldState.finite_number(value.get("detail_distance")) and float(value.detail_distance)>0.0 and float(value.detail_distance)<=1.0e9 and WorldState.finite_number(value.get("fov")) and float(value.fov)>=.05 and float(value.fov)<=80.0
	for field: String in ["fov","base_fov"]:
		if not WorldState.finite_number(value.get(field)) or float(value[field])<.05 or float(value[field])>80.0: return false
	for field: String in ["normal","eye","aim","up"]:
		if not value.get(field) is Array or value[field].size()!=3: return false
		for component: Variant in value[field]:
			if not WorldState.finite_number(component) or absf(float(component))>1.0e6: return false
	if vector(value.normal).length_squared()<.9 or vector(value.up).length_squared()<.9: return false
	return vector(value.eye).distance_squared_to(vector(value.aim))>1.0e-12
