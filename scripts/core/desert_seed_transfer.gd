extends RefCounted
## Finite teaching seed units: ground -> cheek pouch -> burrow cache.
## Night is an explicit observation input; the sole WorldState clock advances it.
const MODEL_ID: String = "mesquite-seed-transfer-v1"
const SOURCE: String = "https://research.fs.usda.gov/feis/species-reviews/provel"
const INITIAL_UNITS: int = 8
const ROUTE_S: float = 24.0
const PICKUP_S: float = 6.0
const DEPOSIT_S: float = 10.0

var started_at_s: float = 0.0
var last_world_time_s: float = 0.0
var active_elapsed_s: float = 0.0
var active: bool = false
var picked_up: int = 0
var deposited: int = 0


func initialize_at(time: float) -> void:
	started_at_s = time
	last_world_time_s = time
	active_elapsed_s = 0.0
	active = false
	picked_up = 0
	deposited = 0


static func _events_through(time: float) -> int:
	var cycles: int = int(floor(time / ROUTE_S))
	var phase: float = time - float(cycles) * ROUTE_S
	return cycles * 2 + (1 if phase >= PICKUP_S else 0) + (1 if phase >= DEPOSIT_S else 0)


static func _event_time(index: int) -> float:
	return float(index / 2) * ROUTE_S + (PICKUP_S if index % 2 == 0 else DEPOSIT_S)


func advance_to(time: float) -> void:
	if not is_finite(time) or time < last_world_time_s:
		return
	if active:
		var target: float = active_elapsed_s + time - last_world_time_s
		var next_event: int = _events_through(active_elapsed_s)
		while _event_time(next_event) <= target + 0.000000001:
			if next_event % 2 == 0:
				if picked_up < INITIAL_UNITS and picked_up == deposited:
					picked_up += 1
			elif deposited < picked_up:
				deposited += 1
			if deposited == INITIAL_UNITS:
				break
			next_event += 1
		active_elapsed_s = target
	last_world_time_s = time


func snapshot() -> Dictionary:
	return {
		"model_id": MODEL_ID, "started_at_s": started_at_s,
		"last_world_time_s": last_world_time_s, "active_elapsed_s": active_elapsed_s,
		"active": active, "picked_up": picked_up, "deposited": deposited,
		"ground_units": INITIAL_UNITS - picked_up,
		"pouch_units": picked_up - deposited, "cache_units": deposited,
	}


func checkpoint() -> Dictionary:
	var value: Dictionary = snapshot()
	value.erase("ground_units")
	value.erase("pouch_units")
	value.erase("cache_units")
	return value


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func checkpoint_error(value: Dictionary, world_time: float) -> String:
	if value.get("model_id") != MODEL_ID:
		return "incompatible"
	for key: String in ["started_at_s", "last_world_time_s", "active_elapsed_s", "picked_up", "deposited"]:
		if not _number(value.get(key)):
			return "invalid_seed_number"
	if not value.get("active") is bool:
		return "invalid_seed_active"
	if value.started_at_s < 0.0 or value.started_at_s > world_time or value.last_world_time_s < value.started_at_s or absf(float(value.last_world_time_s) - world_time) > 0.00001:
		return "invalid_seed_time"
	if value.active_elapsed_s < 0.0 or value.active_elapsed_s > world_time - float(value.started_at_s) + 0.00001:
		return "invalid_seed_elapsed"
	if value.picked_up != floorf(float(value.picked_up)) or value.deposited != floorf(float(value.deposited)) or value.deposited < 0 or value.picked_up < value.deposited or value.picked_up > INITIAL_UNITS or value.picked_up - value.deposited > 1:
		return "invalid_seed_balance"
	# Every completed route event changes one unit until the finite source ends.
	var cycles: int=int(floor(float(value.active_elapsed_s)/ROUTE_S))
	var phase: float=float(value.active_elapsed_s)-float(cycles)*ROUTE_S
	var expected_pickups: int=mini(INITIAL_UNITS,cycles+(1 if phase>=PICKUP_S else 0))
	var expected_deposits: int=mini(INITIAL_UNITS,cycles+(1 if phase>=DEPOSIT_S else 0))
	if value.picked_up != expected_pickups or value.deposited != expected_deposits:
		return "invalid_seed_events"
	return ""


func restore(value: Dictionary) -> void:
	started_at_s = float(value.started_at_s)
	last_world_time_s = float(value.last_world_time_s)
	active_elapsed_s = float(value.active_elapsed_s)
	active = bool(value.active)
	picked_up = int(value.picked_up)
	deposited = int(value.deposited)
