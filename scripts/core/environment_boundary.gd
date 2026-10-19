extends RefCounted
## Read-only regional inputs. A caller supplies UTC; no clock or simulation lives here.

const DATA_PATH: String = "res://data/environment/lizard_woa23_annual.json"
const DATA_ID: String = "lizard-woa23-1971-2000-annual-5m-v1"
const UNITS: Dictionary = {
	"temperature": "degC", "salinity": "1", "oxygen": "umol/kg",
	"oxygen_saturation": "%", "temperature_analysis_error": "degC",
	"oxygen_analysis_error": "umol/kg",
}
const UTC_START: float = 946684800.0 # 2000-01-01T00:00:00Z, inclusive.
const UTC_END: float = 4102444800.0 # 2100-01-01T00:00:00Z, exclusive.
const SOLAR_SOURCE: String = "https://gml.noaa.gov/grad/solcalc/solareqns.PDF"
var _data: Dictionary = {}
var error: String = ""


func _init(path: String = DATA_PATH) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = "boundary_file_unavailable"
		return
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		error = "boundary_json_invalid"
		return
	if not parser.data is Dictionary:
		error = "boundary_object_required"
		return
	var candidate: Dictionary = parser.data
	error = validate(candidate)
	if error.is_empty(): _data = candidate.duplicate(true)


func snapshot() -> Dictionary:
	if not error.is_empty(): return {"ok": false, "error": error}
	return {"ok": true, "data": _data.duplicate(true)}


static func _finite(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func validate(data: Dictionary) -> String:
	if not _finite(data.get("schema_version")) or data.schema_version != 1:
		return "boundary_version_unsupported"
	if data.get("id") != DATA_ID or data.get("role") != "regional_boundary_context":
		return "boundary_identity_mismatch"
	if not data.get("period") is Dictionary or not data.get("sample") is Dictionary:
		return "boundary_context_missing"
	var period: Dictionary = data.period
	var sample: Dictionary = data.sample
	if period.get("start_year") != 1971 or period.get("end_year") != 2000 or period.get("aggregation") != "annual":
		return "boundary_period_mismatch"
	for key: String in ["latitude_deg", "longitude_deg", "depth_m", "grid_deg"]:
		if not _finite(sample.get(key)): return "boundary_sample_invalid"
	if sample.latitude_deg != -14.5 or sample.longitude_deg != 145.5 or sample.depth_m != 5 or sample.grid_deg != 1:
		return "boundary_sample_mismatch"
	if not data.get("fields") is Dictionary or not data.get("sources") is Dictionary:
		return "boundary_fields_missing"
	var fields: Dictionary = data.fields
	var sources: Dictionary = data.sources
	for key: String in UNITS:
		if not fields.get(key) is Dictionary: return "boundary_field_missing:" + key
		var field: Dictionary = fields[key]
		if field.get("unit") != UNITS[key]: return "boundary_unit_mismatch:" + key
		if not _finite(field.get("value")): return "boundary_value_invalid:" + key
		if key != "temperature" and float(field.value) < 0.0: return "boundary_value_negative:" + key
		if key == "temperature" and (float(field.value) < -5.0 or float(field.value) > 45.0):
			return "boundary_temperature_out_of_scope"
		if field.get("source_id") != key or not sources.get(key) is Dictionary:
			return "boundary_source_missing:" + key
		var source: Dictionary = sources[key]
		if not source.get("sha256") is String or str(source.sha256).length() != 64 or not str(source.get("url", "")).begins_with("https://www.ncei.noaa.gov/"):
			return "boundary_source_invalid:" + key
		var expected_status: String = "source_analysis_estimate_not_local_error_bound" if key.ends_with("_analysis_error") else "frozen_climatology"
		if field.get("status") != expected_status: return "boundary_evidence_mismatch:" + key
	if not data.get("unknown_fields") is Array or not "local_reef_observation_error" in data.unknown_fields:
		return "boundary_unknowns_missing"
	return ""


static func solar_geometry(utc_unix_s: float, latitude_deg: float, longitude_deg: float) -> Dictionary:
	if not is_finite(utc_unix_s) or utc_unix_s < UTC_START or utc_unix_s >= UTC_END:
		return {"ok": false, "error": "utc_out_of_supported_range"}
	if not is_finite(latitude_deg) or not is_finite(longitude_deg) or absf(latitude_deg) > 90.0 or absf(longitude_deg) > 180.0:
		return {"ok": false, "error": "coordinates_invalid"}
	var whole_seconds: int = int(floor(utc_unix_s))
	var date: Dictionary = Time.get_datetime_dict_from_unix_time(whole_seconds)
	var year: int = int(date.year)
	var leap: bool = year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
	var month_offsets: Array[int] = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	var day_of_year: int = month_offsets[int(date.month) - 1] + int(date.day)
	if leap and int(date.month) > 2: day_of_year += 1
	var hour: float = float(date.hour) + float(date.minute) / 60.0 + (float(date.second) + utc_unix_s - float(whole_seconds)) / 3600.0
	var gamma: float = TAU / (366.0 if leap else 365.0) * (float(day_of_year) - 1.0 + (hour - 12.0) / 24.0)
	var eqtime: float = 229.18 * (0.000075 + 0.001868*cos(gamma) - 0.032077*sin(gamma) - 0.014615*cos(2.0*gamma) - 0.040849*sin(2.0*gamma))
	var decl: float = 0.006918 - 0.399912*cos(gamma) + 0.070257*sin(gamma) - 0.006758*cos(2.0*gamma) + 0.000907*sin(2.0*gamma) - 0.002697*cos(3.0*gamma) + 0.00148*sin(3.0*gamma)
	var hour_angle: float = deg_to_rad(fposmod(hour * 60.0 + eqtime + 4.0 * longitude_deg, 1440.0) / 4.0 - 180.0)
	var lat: float = deg_to_rad(latitude_deg)
	var cosine: float = clampf(sin(lat)*sin(decl) + cos(lat)*cos(decl)*cos(hour_angle), -1.0, 1.0)
	return {
		"ok": true, "utc_unix_s": utc_unix_s, "day_of_year": day_of_year,
		"elevation_deg": rad_to_deg(asin(cosine)), "cosine_zenith": cosine,
		"daylight_geometry_factor": maxf(0.0, cosine), "equation_of_time_min": eqtime,
		"declination_deg": rad_to_deg(decl), "source": SOLAR_SOURCE,
		"status": "analytic_approximation_no_refraction", "irradiance_w_m2": null,
	}
