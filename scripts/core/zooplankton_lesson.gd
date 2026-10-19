extends RefCounted
## A finite, magnified teaching budget near the blue-green chromis school.
## It represents neither individual prey nor measured zooplankton density.
const MODEL_ID: String = "chromis-zooplankton-lesson-v1"
const SPECIES_SOURCE: String = "https://fishesofaustralia.net.au/home/species/329"
const PLANKTON_SOURCE: String = "https://oceanservice.noaa.gov/facts/plankton.html"
const INITIAL_UNITS: int = 12
const TAKE_INTERVAL_S: float = 4.0

var started_at_s: float = 0.0
var last_world_time_s: float = 0.0
var active_elapsed_s: float = 0.0
var active: bool = false
var taken: int = 0


func initialize_at(time: float) -> void:
	started_at_s = time
	last_world_time_s = time
	active_elapsed_s = 0.0
	active = false
	taken = 0


func advance_to(time: float) -> void:
	if not is_finite(time) or time < last_world_time_s:
		return
	if active:
		active_elapsed_s += time - last_world_time_s
		taken = mini(INITIAL_UNITS, int(floor((active_elapsed_s + 0.000000001) / TAKE_INTERVAL_S)))
	last_world_time_s = time


func snapshot() -> Dictionary:
	return {"model_id": MODEL_ID, "started_at_s": started_at_s,
		"last_world_time_s": last_world_time_s, "active_elapsed_s": active_elapsed_s,
		"active": active, "taken": taken, "water_units": INITIAL_UNITS - taken}


func checkpoint() -> Dictionary:
	var value: Dictionary = snapshot()
	value.erase("water_units")
	return value


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func checkpoint_error(value: Dictionary, world_time: float) -> String:
	if value.get("model_id") != MODEL_ID:
		return "incompatible"
	for key: String in ["started_at_s", "last_world_time_s", "active_elapsed_s", "taken"]:
		if not _number(value.get(key)):
			return "invalid_zooplankton_number"
	if not value.get("active") is bool:
		return "invalid_zooplankton_active"
	if value.started_at_s < 0.0 or value.started_at_s > world_time or value.last_world_time_s < value.started_at_s or absf(float(value.last_world_time_s) - world_time) > 0.00001:
		return "invalid_zooplankton_time"
	if value.active_elapsed_s < 0.0 or value.active_elapsed_s > world_time - float(value.started_at_s) + 0.00001:
		return "invalid_zooplankton_elapsed"
	if value.taken < 0 or value.taken > INITIAL_UNITS or floorf(float(value.taken)) != value.taken:
		return "invalid_zooplankton_balance"
	var expected: int = mini(INITIAL_UNITS, int(floor((float(value.active_elapsed_s) + 0.000000001) / TAKE_INTERVAL_S)))
	if value.taken != expected:
		return "invalid_zooplankton_events"
	return ""


func restore(value: Dictionary) -> void:
	started_at_s = float(value.started_at_s)
	last_world_time_s = float(value.last_world_time_s)
	active_elapsed_s = float(value.active_elapsed_s)
	active = bool(value.active)
	taken = int(value.taken)
