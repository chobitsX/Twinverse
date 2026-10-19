extends RefCounted
## The world owns the selected itinerary and its world-time origin.
## Elapsed time is derived, never advanced by a scene or a second clock.
const Traffic = preload("res://scripts/core/city_traffic.gd")
const DURATIONS: Array[float] = [16.0,24.0]
const ROUTE_M: float = 16.4
const SOURCE: String = "https://highways.dot.gov/sites/fhwa.dot.gov/files/2022-06/fhwasa13027.pdf"
var profile: int = 0
var started_at_s: float = 0.0

func select(value: int, world_time: float) -> bool:
	if value<0 or value>=DURATIONS.size(): return false
	profile=value
	started_at_s=world_time
	return true

func reset_at(world_time: float) -> void:
	started_at_s=world_time

func snapshot(world_time: float) -> Dictionary:
	var duration: float=DURATIONS[profile]
	var elapsed: float=maxf(0.0,world_time-started_at_s)
	return {"profile":profile,"started_at_s":started_at_s,"elapsed_s":elapsed,
		"walk_duration_s":duration,"period_s":Traffic.cycle_period(duration),
		"phase_s":Traffic.phase(elapsed,duration),"clear_end_s":Traffic.clear_end(duration),
		"route_m":ROUTE_M,"mean_speed_m_s":ROUTE_M/duration}

func checkpoint() -> Dictionary:
	return {"profile":profile,"started_at_s":started_at_s}

static func checkpoint_error(value: Dictionary, world_time: float) -> String:
	var chosen: Variant=value.get("profile")
	if not (chosen is int or chosen is float) or not is_finite(float(chosen)) or float(chosen)!=floorf(float(chosen)) or chosen<0 or chosen>=DURATIONS.size():
		return "invalid_city_traffic_profile"
	var origin: Variant=value.get("started_at_s")
	if not (origin is int or origin is float) or not is_finite(float(origin)) or origin<0.0 or origin>world_time:
		return "invalid_city_traffic_origin"
	return ""

func restore(value: Dictionary) -> void:
	profile=int(value.profile)
	started_at_s=float(value.started_at_s)
