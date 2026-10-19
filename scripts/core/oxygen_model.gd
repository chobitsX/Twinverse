extends RefCounted
## WorldState owns this quasi-steady reference model and its real observations.
## Water is an imposed boundary; uptake is calculated from that boundary.

const Definition = preload("res://scripts/data/oxygen_definition.gd")
const MAX_SAMPLES: int = 120
const MAX_EVENTS: int = 32
var started_at_s: float = 0.0
var samples: Array[Dictionary] = []
var events: Array[Dictionary] = []
var _last_time_s: float = -1.0
var _was_limited: bool = false


static func water_at(elapsed_s: float) -> float:
	var phase: float = fposmod(maxf(0.0, elapsed_s), Definition.value("scenario_period"))
	for index: int in range(1, Definition.BOUNDARY.size()):
		var right: Vector2 = Definition.BOUNDARY[index]
		var left: Vector2 = Definition.BOUNDARY[index - 1]
		if phase <= right.x:
			return lerpf(left.y, right.y, (phase - left.x) / (right.x - left.x))
	return Definition.BOUNDARY.back().y


static func relative_uptake(oxygen_percent: float, critical_percent: float) -> float:
	if not is_finite(oxygen_percent) or not is_finite(critical_percent) or critical_percent <= 0.0: return NAN
	# Plateau + linear supply limitation is an explicit approximation, not a fit.
	return clampf(oxygen_percent / critical_percent, 0.0, 1.0)


func state_at(time_s: float) -> Dictionary:
	return _state_at(time_s, started_at_s)


static func _state_at(time_s: float, start_s: float) -> Dictionary:
	var oxygen: float = water_at(time_s - start_s)
	var critical: float = Definition.value("critical_oxygen")
	return {"time_s": time_s, "water_oxygen_percent": oxygen,
		"uptake_relative": relative_uptake(oxygen, critical),
		"sensitivity_low_relative": relative_uptake(oxygen, Definition.value("sensitivity_high")),
		"sensitivity_high_relative": relative_uptake(oxygen, Definition.value("sensitivity_low")),
		"limited": oxygen < critical}


func advance(time_s: float) -> void:
	if time_s < started_at_s or time_s <= _last_time_s: return
	var state: Dictionary = state_at(time_s)
	# Events record the first observed crossing. Never backfill skipped history.
	if _last_time_s >= 0.0 and bool(state.limited) != _was_limited:
		events.append({"kind": "limited" if state.limited else "regulated", "time_s": time_s,
			"water_oxygen_percent": state.water_oxygen_percent, "uptake_relative": state.uptake_relative})
		if events.size() > MAX_EVENTS: events.pop_front()
	_was_limited = bool(state.limited)
	_last_time_s = time_s
	if samples.is_empty() or time_s - float(samples.back().time_s) >= Definition.value("sample_interval"):
		samples.append(state)
		if samples.size() > MAX_SAMPLES: samples.pop_front()


func snapshot(time_s: float) -> Dictionary:
	var result: Dictionary = state_at(time_s)
	result["model_id"] = Definition.ID
	result["scientific_status"] = Definition.STATUS
	result["started_at_s"] = started_at_s
	return result


func checkpoint() -> Dictionary:
	return {"version": 1, "model_id": Definition.ID, "started_at_s": started_at_s,
		"last_time_s": _last_time_s, "samples": samples.duplicate(true), "events": events.duplicate(true)}


func restore(data: Dictionary) -> void:
	started_at_s = float(data.started_at_s)
	_last_time_s = float(data.last_time_s)
	samples.assign(data.samples.duplicate(true))
	events.assign(data.events.duplicate(true))
	_was_limited = bool(state_at(_last_time_s).limited)


static func checkpoint_error(data: Dictionary, world_time_s: float) -> String:
	if data.get("version") != 1 or data.get("model_id") != Definition.ID: return "incompatible"
	if not _valid_time(data.get("started_at_s"), 0.0, world_time_s): return "invalid_oxygen_start"
	if not _valid_time(data.get("last_time_s"), float(data.started_at_s), world_time_s): return "invalid_oxygen_time"
	for key: String in ["samples", "events"]:
		if not data.get(key) is Array or data[key].size() > (MAX_SAMPLES if key == "samples" else MAX_EVENTS): return "invalid_oxygen_history"
		if key == "samples" and data[key].is_empty(): return "invalid_oxygen_history"
		var previous: float = float(data.started_at_s) - 1.0
		for row: Variant in data[key]:
			if not row is Dictionary or not _valid_time(row.get("time_s"), float(data.started_at_s), float(data.last_time_s)): return "invalid_oxygen_history_time"
			if float(row.time_s) <= previous: return "invalid_oxygen_history_order"
			previous = float(row.time_s)
			var expected: Dictionary = _state_at(float(row.time_s), float(data.started_at_s))
			for field: String in (["water_oxygen_percent", "uptake_relative", "sensitivity_low_relative", "sensitivity_high_relative"] if key == "samples" else ["water_oxygen_percent", "uptake_relative"]):
				if not _number(row.get(field)) or absf(float(row[field]) - float(expected[field])) > 0.000001: return "invalid_oxygen_value"
			if key == "samples":
				if not row.get("limited") is bool or row.limited != expected.limited: return "invalid_oxygen_flag"
			elif row.get("kind") != ("limited" if expected.limited else "regulated"): return "invalid_oxygen_event"
	return ""


static func _number(input: Variant) -> bool:
	return (input is float or input is int) and is_finite(float(input))


static func _valid_time(input: Variant, earliest: float, latest: float) -> bool:
	return _number(input) and float(input) >= earliest and float(input) <= latest
