extends RefCounted
## Sole coupled reference chain. Owned by WorldState, independent of scene/LOD.
const Boundary = preload("res://scripts/core/environment_boundary.gd")
const LegacyOxygen = preload("res://scripts/core/oxygen_model.gd")
const MODEL_ID: String = "reef-atp-reference-v1"
const STATUS: String = "reference_model_species_uncalibrated"
const STEP: float = 0.1
const EPOCH: float = 1789524000.0 # 2026-09-16 02:00 UTC; authored reference epoch.
const MODES: Array[String] = ["cycle", "normal", "hypoxia", "food", "risk", "shade", "warm"]
const LABELS: Dictionary = {"cycle": "黄金周期", "normal": "正常供氧", "hypoxia": "持续低氧", "food": "食物补充", "risk": "避险", "shade": "遮光", "warm": "升温"}
const BEHAVIORS: Dictionary = {"feeding": "觅食", "escape": "逃避", "shelter": "躲避", "rest": "休息", "swim": "游动"}
const SOURCES: Array[Dictionary] = [
	{"title": "WOA23 · 区域历史温盐氧", "url": "https://www.ncei.noaa.gov/access/world-ocean-atlas-2023/", "basis": "1971–2000全年1°网格5 m，非局部实时观测。"},
	{"title": "Nilsson 2004 · 礁鱼低氧实验", "url": "https://doi.org/10.1098/rsbl.2003.0087", "basis": "平台/限制的机理背景；不含目标物种，25%阈值为作者假设。"},
	{"title": "Farrell 1987 · 虹鳟灌流心脏", "url": "https://doi.org/10.1242/jeb.129.1.107", "basis": "供氧与心肌工作的背景，不照搬结构、心率或参数。"},
	{"title": "Wilson 2014 · 离体线粒体", "url": "https://doi.org/10.1152/japplphysiol.00736.2014", "basis": "氧/能量状态影响氧化磷酸化；不移植氧分压阈值。"},
	{"title": "Vinnakota 2016 · 大鼠心脏线粒体", "url": "https://pmc.ncbi.nlm.nih.gov/articles/PMC4776028/", "basis": "ATP需求/水解产物反馈；非海葵鱼参数标定。"},
]
const INITIAL: Dictionary = {
	"water": 204.543, "temperature": 26.762, "salinity": 35.156, "light": 1.0,
	"producer": 0.8, "food": 0.8, "coral": 1.0, "risk": 0.05,
	"activity": 0.4, "companion_activity": 0.4, "energy": 65.0, "health": 1.0,
	"gill": 0.91, "companion_gill": 0.91, "fish_demand": 0.91, "blood": 1.0,
	"heart_rate": 0.99, "load": 0.85, "cell_oxygen": 1.0, "atp": 16.0, "adp": 4.0,
	"demand": 0.051, "synthesis": 0.0, "consumption": 0.0, "deficit": 0.0,
	"oxygen_supply": 0.0, "oxygen_use": 0.0, "oxygen_other": 0.91,
	"beat_phase": 0.0, "swim_phase": 0.0, "flux_phase": 0.0,
	"offset_x": 0.0, "offset_y": 0.0, "offset_z": 0.0,
	"exchange": 0.0, "photo": 0.0, "respiration": 0.0, "fish_sink": 0.0,
	"food_growth": 0.0, "food_eaten": 0.0, "energy_intake": 0.0, "energy_cost": 0.0, "energy_overflow": 0.0,
	"water_error": 0.0, "food_error": 0.0, "energy_error": 0.0, "atp_error": 0.0,
	"removal_scale": 1.0, "water_percent": 101.886, "capacity": 1.5,
}
var boundary: Boundary = Boundary.new()
var state: Dictionary = INITIAL.duplicate(true)
var started_at_s: float = 0.0
var steps: int = 0
var step_s: float = STEP # Smaller step only used by numerical comparison fixtures.
var mode: String = "cycle"
var mode_at_s: float = 0.0
var behavior: String = "swim"
var companion_behavior: String = "swim"
var samples: Array[Dictionary] = []
var events: Array[Dictionary] = []
var legacy_oxygen: Dictionary = {}
var error: String = ""
var _base_o: float = 204.543
var _base_t: float = 26.762
var _o100: float = 200.756727
var _low: bool = false
var _atp_low: bool = false


func _init() -> void:
	var data: Dictionary = boundary.snapshot()
	if not data.ok:
		error = str(data.error)
		return
	_base_o = float(data.data.fields.oxygen.value)
	_base_t = float(data.data.fields.temperature.value)
	_o100 = _base_o / (float(data.data.fields.oxygen_saturation.value) / 100.0)
	state.water = _base_o
	state.temperature = _base_t
	state.salinity = float(data.data.fields.salinity.value)
	_update_light(0.0)
	_sample()


func initialize_at(time_s: float) -> void:
	started_at_s = time_s
	mode_at_s = time_s
	samples.clear()
	_sample()


func at_s() -> float:
	return started_at_s + steps * step_s


func advance_to(time_s: float) -> void:
	if not error.is_empty() or not is_finite(time_s) or time_s < at_s() - 0.000001: return
	var required: int = int(floor((time_s - started_at_s + 0.0000001) / step_s))
	while steps < required:
		steps += 1
		_step(step_s)
		if not error.is_empty(): break
		if at_s() - float(samples.back().time_s) >= 5.0 - 0.0000001: _sample()


func set_mode(value: String) -> bool:
	if value not in MODES or not error.is_empty(): return false
	if value == mode: return true
	mode = value
	mode_at_s = at_s()
	_event("scenario", "reef")
	return true


static func relax(value: float, target: float, dt: float, tau: float) -> float:
	return target + (value - target) * exp(-dt / tau)


static func cycle_factor(time_s: float) -> float:
	var t: float = fposmod(time_s, 300.0)
	if t < 40.0: return 1.0
	if t < 100.0: return lerpf(1.0, 0.06, (t - 40.0) / 60.0)
	if t < 190.0: return 0.06
	if t < 260.0: return lerpf(0.06, 1.0, (t - 190.0) / 70.0)
	return 1.0


func _update_light(elapsed: float) -> void:
	# Repeat the authored reference year; this is neither real date nor irradiance.
	var sun: Dictionary = Boundary.solar_geometry(EPOCH + fposmod(elapsed, 365.0 * 86400.0), -14.6666666667, 145.4666666667)
	if not sun.ok:
		error = str(sun.error)
		return
	state.light = float(sun.daylight_geometry_factor) * (0.08 if mode == "shade" else 1.0)


func _behavior(energy: float, cell: float, previous: String) -> String:
	if state.risk > 0.5: return "escape" if at_s() - mode_at_s < 8.0 else "shelter"
	if cell < 0.4 or (previous == "rest" and cell < 0.65) or state.light < 0.1: return "rest"
	if energy < 75.0 and state.food > 0.15: return "feeding"
	return "swim"


func _step(dt: float) -> void:
	var s: Dictionary = state
	var elapsed: float = at_s() - started_at_s
	_update_light(elapsed)
	s.temperature = relax(s.temperature, _base_t + (3.0 if mode == "warm" else 0.0), dt, 45.0)
	s.risk = 0.9 if mode == "risk" else 0.05
	var factor: float = cycle_factor(at_s() - mode_at_s) if mode == "cycle" else (0.06 if mode == "hypoxia" else 1.0)
	var old_water: float = s.water
	s.exchange = (_base_o * factor - old_water) / 12.0
	s.photo = 0.10 * s.producer * s.light
	s.respiration = 0.04 * s.producer
	s.fish_sink = 0.025 * (s.gill + s.companion_gill)
	var positive: float = maxf(s.exchange, 0.0) + s.photo
	var negative: float = maxf(-s.exchange, 0.0) + s.respiration + s.fish_sink
	s.removal_scale = minf(1.0, (old_water / dt + positive) / maxf(negative, 0.000000001))
	if s.exchange < 0.0: s.exchange *= s.removal_scale
	s.respiration *= s.removal_scale
	s.fish_sink *= s.removal_scale
	s.water = old_water + dt * (s.exchange + s.photo - s.respiration - s.fish_sink)
	s.water_error = s.water - old_water - dt * (s.exchange + s.photo - s.respiration - s.fish_sink)
	s.water_percent = s.water / _o100 * 100.0
	s.coral = relax(s.coral, clampf(1.0 - 0.6 * (1.0 - minf(s.water_percent / 25.0, 1.0)) - 0.05 * maxf(s.temperature - _base_t, 0.0), 0.1, 1.0), dt, 180.0)
	s.producer = relax(s.producer, (0.1 + 0.8 * s.light) * s.coral, dt, 120.0)
	var previous_behavior: String = behavior
	behavior = _behavior(s.energy, s.blood, behavior)
	companion_behavior = _behavior(60.0, s.blood, companion_behavior)
	var activities: Dictionary = {"feeding": 0.6, "escape": 1.0, "shelter": 0.18, "rest": 0.12, "swim": 0.4}
	s.activity = relax(s.activity, activities[behavior], dt, 3.0)
	s.companion_activity = relax(s.companion_activity, activities[companion_behavior], dt, 3.0)
	var old_food: float = s.food
	s.food_growth = (0.012 * s.producer + (0.012 if mode == "food" else 0.0)) * (1.0 - old_food)
	var target_food: float = 0.003 * old_food if behavior == "feeding" else 0.0
	var companion_food: float = 0.002 * old_food if companion_behavior == "feeding" else 0.0
	var food_scale: float = minf(1.0, (old_food / dt + s.food_growth) / maxf(target_food + companion_food, 0.000000001))
	target_food *= food_scale
	companion_food *= food_scale
	s.food_eaten = target_food + companion_food
	s.food = old_food + dt * (s.food_growth - s.food_eaten)
	s.food_error = s.food - old_food - dt * (s.food_growth - s.food_eaten)
	var q: float = pow(2.0, (s.temperature - _base_t) / 10.0)
	var old_energy: float = s.energy
	s.energy_intake = target_food * 30.0
	s.energy_cost = minf((0.04 + 0.035 * s.activity) * q, old_energy / dt + s.energy_intake)
	s.energy_overflow = maxf(0.0, old_energy + dt * (s.energy_intake - s.energy_cost) - 100.0) / dt
	s.energy = old_energy + dt * (s.energy_intake - s.energy_cost - s.energy_overflow)
	s.energy_error = s.energy - old_energy - dt * (s.energy_intake - s.energy_cost - s.energy_overflow)
	s.fish_demand = (0.65 + 0.65 * s.activity) * q
	s.capacity = 1.5 * clampf(s.water_percent / 25.0, 0.0, 1.0)
	s.gill = relax(s.gill, minf(s.fish_demand, s.capacity), dt, 4.0)
	s.companion_gill = relax(s.companion_gill, minf((0.65 + 0.65 * s.companion_activity) * q, s.capacity), dt, 4.0)
	s.blood = relax(s.blood, minf(s.gill / s.fish_demand, 1.0), dt, 8.0)
	s.heart_rate = relax(s.heart_rate, (0.85 + 0.35 * s.activity) * (0.55 + 0.45 * s.blood), dt, 10.0)
	s.load = 0.65 + 0.5 * s.activity
	s.cell_oxygen = relax(s.cell_oxygen, clampf(s.blood * s.heart_rate / (0.85 + 0.35 * s.activity), 0.0, 1.0), dt, 12.0)
	s.demand = 0.06 * s.load * q
	s.oxygen_supply = 0.04 * s.gill * s.cell_oxygen
	var production: float = 0.22 * s.cell_oxygen / (0.15 + s.cell_oxygen) * s.adp / (2.0 + s.adp) * minf(s.energy / 30.0, 1.0)
	s.synthesis = minf(production, minf(5.0 * s.oxygen_supply, s.adp / dt))
	s.oxygen_use = s.synthesis / 5.0
	s.oxygen_other = s.gill - s.oxygen_use
	var old_atp: float = s.atp
	s.consumption = minf(s.demand, old_atp / dt + s.synthesis)
	s.deficit = maxf(0.0, s.demand - s.consumption)
	s.atp = old_atp + dt * (s.synthesis - s.consumption)
	s.adp = 20.0 - s.atp
	s.atp_error = s.atp - old_atp - dt * (s.synthesis - s.consumption)
	s.health = relax(s.health, clampf(minf(1.0, s.atp / 8.0) * minf(1.0, s.energy / 30.0), 0.0, 1.0), dt, 90.0)
	s.beat_phase += 0.82 * s.heart_rate * dt
	s.swim_phase += s.activity * dt
	s.flux_phase += s.synthesis / 0.06 * dt
	var desired_x: float = {"feeding": 0.012, "escape": -0.018, "shelter": -0.006, "rest": 0.0, "swim": 0.0}[behavior]
	s.offset_x = relax(s.offset_x, desired_x + sin(s.swim_phase) * 0.005 * s.activity, dt, 2.0)
	s.offset_y = relax(s.offset_y, sin(s.swim_phase * 0.61) * 0.0015 * s.activity, dt, 2.0)
	s.offset_z = relax(s.offset_z, cos(s.swim_phase) * 0.00125 * s.activity, dt, 2.0)
	error = state_error(s)
	if previous_behavior != behavior: _event("behavior", "fish")
	var low: bool = s.blood < 0.65
	if low != _low:
		_low = low
		_event("oxygen_low" if low else "oxygen_recovered", "heart")
	var atp_low: bool = s.atp < 15.0
	if atp_low != _atp_low:
		_atp_low = atp_low
		_event("atp_low" if atp_low else "atp_recovered", "mitochondrion")


func _sample() -> void:
	samples.append({"time_s": at_s(), "water_percent": state.water_percent, "gill": state.gill, "blood": state.blood, "cell_oxygen": state.cell_oxygen, "atp": state.atp, "energy": state.energy, "synthesis": state.synthesis, "demand": state.demand})
	if samples.size() > 180: samples.pop_front()


func _event(kind: String, scale_id: String) -> void:
	events.append({"time_s": at_s(), "kind": kind, "scale_id": scale_id, "mode": mode, "behavior": behavior,
		"water_percent": state.water_percent, "gill": state.gill, "blood": state.blood, "cell_oxygen": state.cell_oxygen, "atp": state.atp,
		"synthesis": state.synthesis, "demand": state.demand, "activity": state.activity, "risk": state.risk})
	if events.size() > 64: events.pop_front()


func snapshot() -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	result.merge({"model_id": MODEL_ID, "scientific_status": STATUS, "time_s": at_s(), "started_at_s": started_at_s,
		"mode": mode, "behavior": behavior, "companion_behavior": companion_behavior, "error": error,
		"boundary_id": Boundary.DATA_ID, "legacy_samples": legacy_oxygen.get("samples", []).size()})
	return result


func checkpoint() -> Dictionary:
	return {"version": 1, "model_id": MODEL_ID, "boundary_id": Boundary.DATA_ID, "started_at_s": started_at_s,
		"steps": steps, "step_s": step_s, "mode": mode, "mode_at_s": mode_at_s, "behavior": behavior,
		"companion_behavior": companion_behavior, "state": state.duplicate(true), "samples": samples.duplicate(true),
		"events": events.duplicate(true), "legacy_oxygen": legacy_oxygen.duplicate(true)}


static func number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func state_error(s: Dictionary) -> String:
	for key: String in INITIAL:
		if not number(s.get(key)): return "nonfinite_or_missing:" + key
		if absf(float(s[key])) > 1.0e13: return "out_of_range:" + key
	for key: String in ["light", "producer", "food", "coral", "risk", "activity", "companion_activity", "health", "blood", "cell_oxygen", "removal_scale"]:
		if s[key] < -1.0e-9 or s[key] > 1.0 + 1.0e-9: return "out_of_range:" + key
	for key: String in ["water", "gill", "companion_gill", "energy", "heart_rate", "load", "capacity", "demand", "synthesis", "consumption", "deficit", "oxygen_supply", "oxygen_use", "oxygen_other", "atp", "adp"]:
		if s[key] < -1.0e-9: return "negative:" + key
	if s.energy > 100.0 or absf(s.atp + s.adp - 20.0) > 1.0e-8: return "pool_balance"
	if s.oxygen_use > s.oxygen_supply + 1.0e-8 or s.oxygen_supply > s.gill + 1.0e-8: return "oxygen_budget"
	for key: String in ["water_error", "food_error", "energy_error", "atp_error"]:
		if absf(s[key]) > 1.0e-7: return "balance:" + key
	if absf(s.offset_x) > 0.1 or absf(s.offset_y) > 0.1 or absf(s.offset_z) > 0.1: return "position_range"
	return ""


static func checkpoint_error(v: Dictionary, world_time: float) -> String:
	if v.get("version") != 1 or v.get("model_id") != MODEL_ID or v.get("boundary_id") != Boundary.DATA_ID or v.get("step_s") != STEP: return "incompatible"
	for key: String in ["started_at_s", "steps", "mode_at_s"]:
		if not number(v.get(key)) or v[key] < 0.0: return "invalid_chain_clock"
	var at: float = v.started_at_s + v.steps * STEP
	if v.steps != floorf(v.steps) or v.started_at_s > world_time or at > world_time + 0.000001 or world_time - at > STEP + 0.000001 or v.mode_at_s < v.started_at_s or v.mode_at_s > at: return "invalid_chain_clock"
	if v.get("mode") not in MODES or not BEHAVIORS.has(v.get("behavior")) or not BEHAVIORS.has(v.get("companion_behavior")): return "invalid_chain_mode"
	if not v.get("state") is Dictionary: return "invalid_chain_state"
	var problem: String = state_error(v.state)
	if not problem.is_empty(): return problem
	for key: String in ["samples", "events"]:
		if not v.get(key) is Array or v[key].size() > (180 if key == "samples" else 64): return "invalid_chain_history"
		if key == "samples" and v[key].is_empty(): return "missing_chain_history"
		var previous: float = float(v.started_at_s) - 1.0
		for row: Variant in v[key]:
			if not row is Dictionary or not number(row.get("time_s")) or row.time_s < v.started_at_s or row.time_s < previous or row.time_s > at: return "invalid_chain_history_time"
			if key == "samples" and row.time_s <= previous: return "duplicate_chain_sample"
			previous = row.time_s
			for field: String in ["water_percent", "gill", "blood", "cell_oxygen", "atp", "synthesis", "demand"]:
				if not number(row.get(field)) or row[field] < -1.0e-9 or row[field] > 1000.0: return "invalid_chain_sample"
			if row.atp > 20.0 or row.blood > 1.0 or row.cell_oxygen > 1.0: return "invalid_chain_sample"
			if key == "samples":
				if not number(row.get("energy")) or row.energy < 0 or row.energy > 100: return "invalid_energy_sample"
			else:
				if row.get("kind") not in ["scenario", "behavior", "oxygen_low", "oxygen_recovered", "atp_low", "atp_recovered"] or row.get("scale_id") not in ["reef", "fish", "heart", "mitochondrion"] or row.get("mode") not in MODES or not BEHAVIORS.has(row.get("behavior")): return "invalid_chain_event"
				for field: String in ["activity", "risk"]:
					if not number(row.get(field)) or row[field] < 0 or row[field] > 1: return "invalid_chain_cause"
	if not v.get("legacy_oxygen") is Dictionary: return "invalid_legacy_archive"
	if not v.legacy_oxygen.is_empty(): return LegacyOxygen.checkpoint_error(v.legacy_oxygen, float(v.started_at_s))
	return ""


func restore(v: Dictionary) -> void:
	started_at_s = float(v.started_at_s)
	steps = int(v.steps)
	mode_at_s = float(v.mode_at_s)
	mode = v.mode
	behavior = v.behavior
	companion_behavior = v.companion_behavior
	state = v.state.duplicate(true)
	samples.assign(v.samples.duplicate(true))
	events.assign(v.events.duplicate(true))
	legacy_oxygen = v.legacy_oxygen.duplicate(true)
	_low = state.blood < 0.65
	_atp_low = state.atp < 15.0
