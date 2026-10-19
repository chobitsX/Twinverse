extends RefCounted
## Observation cache owned by WorldState. Reads coupled authority; no independent ecology.

const Catalog = preload("res://scripts/core/scale_catalog.gd")
const TARGET_ID: String = "3dworld:fish:golden-path:0001"
const REEF_ID: String = "3dworld:reef:lizard-island:0001"
const FISH_ORIGIN: Vector3 = Vector3(0.36, 0.59, 0.10)
const SAMPLE_INTERVAL_S: float = 5.0
const MAX_SAMPLES: int = 120
const MAX_EVENTS: int = 64
const EVENT_KINDS: Array[String] = ["started", "continued", "arrived", "paused", "running", "speed"]

var reference_state: Dictionary = {}
var started_at_s: float = 0.0
var samples: Array[Dictionary] = []
var events: Array[Dictionary] = []
var visits: Dictionary = {}
var _target_at_s: float = -1.0
var _reef_at_s: float = -1.0
var _target_state: Dictionary = {}
var _reef_state: Dictionary = {}
var _mode: String = ""
var target_updates: int = 0
var reef_updates: int = 0


static func fish_position(time_s: float) -> Vector3:
	var phase: float = time_s * 0.5
	return FISH_ORIGIN + Vector3(sin(phase), sin(phase * 0.61) * 0.3, cos(phase) * 0.25) * 0.005


static func companion_position(time_s: float) -> Vector3:
	var phase: float = time_s * 0.32 + 2.0
	return Vector3(0.16, 0.55, -0.08) + Vector3(sin(phase), sin(phase * 0.61) * 0.3, cos(phase) * 0.25) * 0.018


static func mode_for(scale_id: String) -> String:
	if scale_id in ["fish", "heart", "cardiomyocyte", "mitochondrion", "molecule", "atom"]: return "focused"
	if scale_id in ["pacific", "reef", "school"]: return "local"
	return "remote"


func advance(time_s: float, scale_id: String, force: bool = false) -> void:
	var mode: String = mode_for(scale_id)
	force = force or mode != _mode
	_mode = mode
	var target_interval: float = {"focused": 1.0 / 30.0, "local": 0.25, "remote": 1.0}[mode]
	var reef_interval: float = 0.5 if mode == "local" else 2.0
	if force or time_s - _target_at_s >= target_interval:
		_target_at_s = time_s
		_target_state = {"id": TARGET_ID, "position_m": _components(target_position(time_s)),
			"behavior": reference_state.get("behavior", "authored_host_drift"), "active_since_s": 0.0, "updated_at_s": time_s}
		target_updates += 1
	if force or time_s - _reef_at_s >= reef_interval:
		_reef_at_s = time_s
		_reef_state = {"id": REEF_ID, "background_count": 1, "updated_at_s": time_s,
			"companion_position_m": _components(companion_position(time_s)), "environment": reference_state.get("model_id", "authored_static_boundary")}
		reef_updates += 1
	# Only record a sample when the authority actually advances here. No backfill
	# of invented observations after migration or skipped input time.
	if samples.is_empty() or time_s - float(samples.back().time_s) >= SAMPLE_INTERVAL_S:
		samples.append({"time_s": time_s, "scale_id": scale_id, "position_m": _components(target_position(time_s))})
		if samples.size() > MAX_SAMPLES: samples.pop_front()


func record(kind: String, time_s: float, scale_id: String, multiplier: float = 1.0) -> void:
	assert(kind in EVENT_KINDS and Catalog.contains(scale_id))
	if kind == "arrived" or kind == "started":
		var visit: Dictionary = visits.get(scale_id, {"count": 0, "first_s": time_s, "last_s": time_s})
		visit.count += 1
		visit.last_s = time_s
		visits[scale_id] = visit
	events.append({"kind": kind, "time_s": time_s, "scale_id": scale_id, "multiplier": multiplier})
	if events.size() > MAX_EVENTS: events.pop_front()


func snapshot(time_s: float, scale_id: String) -> Dictionary:
	advance(time_s, scale_id)
	return {"target": _target_state.duplicate(true), "reef": _reef_state.duplicate(true),
		"mode": _mode, "sampled_at_s": time_s, "started_at_s": started_at_s,
		"scientific_status": reference_state.get("scientific_status", "authored_observation_no_ecophysiology_model")}


func checkpoint() -> Dictionary:
	return {"version": 1, "target_id": TARGET_ID, "reef_id": REEF_ID, "started_at_s": started_at_s,
		"samples": samples.duplicate(true), "events": events.duplicate(true), "visits": visits.duplicate(true)}


func restore(value: Dictionary, time_s: float, scale_id: String) -> void:
	started_at_s = float(value.started_at_s)
	samples.assign(value.samples.duplicate(true))
	for sample: Dictionary in samples:
		var p: Array = sample.position_m
		sample.position_m = _components(Vector3(float(p[0]), float(p[1]), float(p[2])))
	events.assign(value.events.duplicate(true))
	visits = value.visits.duplicate(true)
	for scale: String in visits:
		visits[scale].count = int(visits[scale].count)
	advance(time_s, scale_id, true)


static func checkpoint_error(value: Dictionary, time_s: float) -> String:
	if value.get("version") != 1: return "incompatible"
	if value.get("target_id") != TARGET_ID or value.get("reef_id") != REEF_ID: return "invalid_local_identity"
	if not _time_valid(value.get("started_at_s"), time_s): return "invalid_local_start"
	for key: String in ["samples", "events"]:
		if not value.get(key) is Array or value[key].size() > (MAX_SAMPLES if key == "samples" else MAX_EVENTS): return "invalid_journal"
		var previous: float = float(value.started_at_s)
		for row: Variant in value[key]:
			if not row is Dictionary or not _time_valid(row.get("time_s"), time_s): return "invalid_journal_time"
			if float(row.time_s) < previous or not row.get("scale_id") is String or not Catalog.contains(row.scale_id): return "invalid_journal_order"
			previous = float(row.time_s)
			if key == "events":
				if row.get("kind") not in EVENT_KINDS or not _number(row.get("multiplier")) or float(row.multiplier) not in [0.25, 0.5, 1.0, 2.0, 4.0]: return "invalid_event"
			else:
				if not row.get("position_m") is Array or row.position_m.size() != 3: return "invalid_sample"
				for component: Variant in row.position_m:
					if not _number(component) or absf(float(component)) > 1000.0: return "invalid_sample"
	if not value.get("visits") is Dictionary or value.visits.size() > Catalog.EXPLORATION_PATH.size(): return "invalid_visits"
	for scale_id: Variant in value.visits:
		if not scale_id is String or not Catalog.contains(scale_id): return "invalid_visit_scale"
		var visit: Variant = value.visits[scale_id]
		if not visit is Dictionary or not _time_valid(visit.get("first_s"), time_s) or not _time_valid(visit.get("last_s"), time_s): return "invalid_visit"
		if visit.first_s < value.started_at_s or visit.first_s > visit.last_s: return "invalid_visit_time"
		if not _number(visit.get("count")) or visit.count < 1 or visit.count > 1.0e12 or float(visit.count) != floorf(float(visit.count)): return "invalid_visit_count"
	return ""


static func _components(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _time_valid(value: Variant, latest: float) -> bool:
	return _number(value) and value >= 0.0 and value <= latest


func target_position(time_s: float) -> Vector3:
	if reference_state.is_empty(): return fish_position(time_s)
	return FISH_ORIGIN + Vector3(reference_state.offset_x, reference_state.offset_y, reference_state.offset_z)
