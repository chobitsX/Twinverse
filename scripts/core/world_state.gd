extends RefCounted
## One runtime owns this object. Scale scenes receive value snapshots only.

const SCHEMA_VERSION: int = 1
const FIXED_STEP_S: float = 1.0 / 60.0
const MAX_STEPS_PER_ADVANCE: int = 16
const MAX_INPUT_DELTA_S: float = 0.25
const ALLOWED_TIME_SCALES: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0]
const TARGET_FISH_ID: String = "3dworld:fish:golden-path:0001"
const CHECKPOINT_VERSION: int = 15
const MODEL_VERSION: String = "reef-atp-reference-v1+behavior-v1+woodland-browse-v1+urban-runoff-v1+coral-symbiosis-v1+deadwood-carbon-v1+schooling-v1+algal-grazing-v1+desert-seeds-v1+zooplankton-v1+city-crossing-v1"
const V14_MODEL_VERSION: String = "reef-atp-reference-v1+behavior-v1+woodland-browse-v1+urban-runoff-v1+coral-symbiosis-v1+deadwood-carbon-v1+schooling-v1+algal-grazing-v1+desert-seeds-v1+zooplankton-v1"
const V13_MODEL_VERSION: String = "reef-atp-reference-v1+behavior-v1+woodland-browse-v1+urban-runoff-v1+coral-symbiosis-v1+deadwood-carbon-v1+schooling-v1+algal-grazing-v1+desert-seeds-v1"
const V12_MODEL_VERSION: String = "reef-atp-reference-v1+behavior-v1+woodland-browse-v1+urban-runoff-v1+coral-symbiosis-v1+deadwood-carbon-v1+schooling-v1+algal-grazing-v1"
const V11_MODEL_VERSION: String = "reef-atp-reference-v1+behavior-v1+woodland-browse-v1+urban-runoff-v1+coral-symbiosis-v1+deadwood-carbon-v1+schooling-v1"
const V10_MODEL_VERSION: String = "reef-atp-reference-v1+behavior-v1+woodland-browse-v1+urban-runoff-v1+coral-symbiosis-v1+deadwood-carbon-v1"
const V7_MODEL_VERSION: String = "reef-atp-reference-v1+behavior-v1+woodland-browse-v1+urban-runoff-v1+coral-symbiosis-v1"
const V6_MODEL_VERSION: String = "reef-atp-reference-v1+behavior-v1+woodland-browse-v1+urban-runoff-v1"
const V5_MODEL_VERSION: String = "reef-atp-reference-v1+behavior-v1+woodland-browse-v1"
const V4_MODEL_VERSION: String = "reef-atp-reference-v1+behavior-v1"
const V3_MODEL_VERSION: String = "oxygen-reference-v1+authored-motion-v1"
const LEGACY_MODEL_VERSION: String = "authored-observation-v1"
const DATA_VERSION: String = "lizard-island-golden-path-v1"
const AlgalGrazing = preload("res://scripts/core/algal_grazing.gd")
const DesertSeeds = preload("res://scripts/core/desert_seed_transfer.gd")
const Zooplankton = preload("res://scripts/core/zooplankton_lesson.gd")
const CityTrafficLesson = preload("res://scripts/core/city_traffic_lesson.gd")
const Schooling = preload("res://scripts/core/schooling.gd")
const Deadwood = preload("res://scripts/core/deadwood_decomposition.gd")
const Symbiosis = preload("res://scripts/core/coral_symbiosis.gd")
const Runoff = preload("res://scripts/core/urban_runoff.gd")
const Browse = preload("res://scripts/core/woodland_browse.gd")
const Habitat = preload("res://scripts/core/local_habitat.gd")
const Science = preload("res://scripts/core/ecophysiology.gd")
const Oxygen = preload("res://scripts/core/oxygen_model.gd")
const Catalog = preload("res://scripts/core/scale_catalog.gd")

var algal_grazing: AlgalGrazing = AlgalGrazing.new()
var desert_seeds: DesertSeeds = DesertSeeds.new()
var zooplankton: Zooplankton = Zooplankton.new()
var city_traffic: CityTrafficLesson = CityTrafficLesson.new()
var schooling: Schooling = Schooling.new()
var deadwood: Deadwood = Deadwood.new()
var symbiosis: Symbiosis = Symbiosis.new()
var runoff: Runoff = Runoff.new()
var browse: Browse = Browse.new()
var habitat: Habitat = Habitat.new()
var science: Science = Science.new()
var simulation_time_s: float = 0.0
var paused: bool = false
var time_scale: float = 1.0
var foreground: bool = true
var current_scale_id: String = "galaxy"
var seed: int = 41037
var skipped_wall_time_s: float = 0.0
var _accumulator_s: float = 0.0


func _init() -> void:
	_sync_models()


func advance(real_delta_s: float) -> int:
	if paused or not foreground or not science.error.is_empty() or not is_finite(real_delta_s) or real_delta_s <= 0.0:
		return 0
	var admitted_delta: float = minf(real_delta_s, MAX_INPUT_DELTA_S)
	skipped_wall_time_s += real_delta_s - admitted_delta
	_accumulator_s += admitted_delta
	var step_count: int = 0
	while _accumulator_s + 0.000000001 >= FIXED_STEP_S and step_count < MAX_STEPS_PER_ADVANCE:
		_accumulator_s = maxf(0.0, _accumulator_s - FIXED_STEP_S)
		simulation_time_s += FIXED_STEP_S * time_scale
		step_count += 1
	_sync_models()
	return step_count


func set_paused(value: bool) -> void:
	paused = value
	_accumulator_s = 0.0


func set_time_scale(value: float) -> bool:
	if value not in ALLOWED_TIME_SCALES:
		return false
	time_scale = value
	return true


func set_foreground(value: bool) -> void:
	foreground = value
	_accumulator_s = 0.0


func snapshot() -> Dictionary:
	_sync_models()
	return {
		"local_habitat": habitat.snapshot(simulation_time_s, current_scale_id),
		"science": science.snapshot(),
		"city_traffic": city_traffic.snapshot(simulation_time_s),
		"woodland_browse": browse.snapshot(), "urban_runoff": runoff.snapshot(), "coral_symbiosis": symbiosis.snapshot(), "deadwood_decomposition": deadwood.snapshot(), "schooling": schooling.snapshot(), "algal_grazing": algal_grazing.snapshot(), "desert_seed_transfer": desert_seeds.snapshot(), "zooplankton_lesson": zooplankton.snapshot(),
		"schema_version": SCHEMA_VERSION,
		"simulation_time_s": simulation_time_s,
		"paused": paused,
		"time_scale": time_scale,
		"foreground": foreground,
		"target_fish_id": TARGET_FISH_ID,
		"current_scale_id": current_scale_id,
		"seed": seed,
		"skipped_wall_time_s": skipped_wall_time_s,
		"scientific_status": Science.STATUS,
	}


func checkpoint() -> Dictionary:
	_sync_models()
	# Foreground is a live window condition. No wall-clock timestamp is used to
	# advance a restored world, and the fractional step survives a normal save.
	return {
		"version": CHECKPOINT_VERSION, "model_version": MODEL_VERSION, "local_habitat": habitat.checkpoint(),
		"city_traffic": city_traffic.checkpoint(),
		"science": science.checkpoint(), "science_error": science.error, "woodland_browse": browse.checkpoint(), "urban_runoff": runoff.checkpoint(), "coral_symbiosis": symbiosis.checkpoint(), "deadwood_decomposition": deadwood.checkpoint(), "schooling": schooling.checkpoint(), "algal_grazing": algal_grazing.checkpoint(), "desert_seed_transfer": desert_seeds.checkpoint(), "zooplankton_lesson": zooplankton.checkpoint(),
		"data_version": DATA_VERSION, "target_fish_id": TARGET_FISH_ID,
		"simulation_time_s": simulation_time_s, "time_scale": time_scale,
		"paused": paused, "current_scale_id": current_scale_id, "seed": seed,
		"skipped_wall_time_s": skipped_wall_time_s, "accumulator_s": _accumulator_s,
	}


static func checkpoint_error(value: Dictionary) -> String:
	var version: Variant = value.get("version")
	# JSON parses numeric versions as float; Array.has uses stricter types.
	if not finite_number(version) or (version != 1 and version != 2 and version != 3 and version != 4 and version != 5 and version != 6 and version != 7 and version != 8 and version != 9 and version != 10 and version != 11 and version != 12 and version != 13 and version != 14 and version != CHECKPOINT_VERSION) or value.get("data_version") != DATA_VERSION:
		return "incompatible"
	var models: Dictionary = {1:LEGACY_MODEL_VERSION,2:LEGACY_MODEL_VERSION,3:V3_MODEL_VERSION,4:V4_MODEL_VERSION,5:V5_MODEL_VERSION,6:V6_MODEL_VERSION,7:V7_MODEL_VERSION,8:V7_MODEL_VERSION,9:V7_MODEL_VERSION,10:V10_MODEL_VERSION,11:V11_MODEL_VERSION,12:V12_MODEL_VERSION,13:V13_MODEL_VERSION,14:V14_MODEL_VERSION,15:MODEL_VERSION}
	if value.get("model_version") != models[int(version)]: return "incompatible"
	if value.get("target_fish_id") != TARGET_FISH_ID:
		return "invalid_identity"
	if not value.get("current_scale_id") is String or not Catalog.contains(value.current_scale_id):
		return "invalid_scale"
	if not value.get("paused") is bool:
		return "invalid_pause"
	for key: String in ["simulation_time_s", "skipped_wall_time_s", "accumulator_s", "time_scale", "seed"]:
		if not finite_number(value.get(key)):
			return "invalid_" + key
	if value.simulation_time_s < 0.0 or value.simulation_time_s > 1.0e12 or value.skipped_wall_time_s < 0.0 or value.skipped_wall_time_s > 1.0e12:
		return "invalid_time"
	if value.accumulator_s < 0.0 or value.accumulator_s >= FIXED_STEP_S:
		return "invalid_accumulator"
	if float(value.time_scale) not in ALLOWED_TIME_SCALES:
		return "invalid_multiplier"
	if value.seed < 0 or value.seed > 2147483647 or float(value.seed) != floorf(float(value.seed)):
		return "invalid_seed"
	if value.version >= 2:
		if not value.get("local_habitat") is Dictionary: return "invalid_local_state"
		var local_error: String = Habitat.checkpoint_error(value.local_habitat, float(value.simulation_time_s))
		if not local_error.is_empty(): return local_error
	if value.version == 3:
		if not value.get("oxygen") is Dictionary: return "invalid_oxygen_state"
		return Oxygen.checkpoint_error(value.oxygen, float(value.simulation_time_s))
	if value.version >= 4:
		if value.get("science_error") != "": return "science_unavailable"
		if not value.get("science") is Dictionary: return "invalid_science_state"
		var science_error: String = Science.checkpoint_error(value.science, float(value.simulation_time_s))
		if not science_error.is_empty(): return science_error
	if value.version >= 5:
		if not value.get("woodland_browse") is Dictionary: return "invalid_browse_state"
		var browse_error: String = Browse.checkpoint_error(value.woodland_browse,float(value.simulation_time_s))
		if not browse_error.is_empty(): return browse_error
	if value.version >= 6:
		if not value.get("urban_runoff") is Dictionary: return "invalid_runoff_state"
		var runoff_error: String = Runoff.checkpoint_error(value.urban_runoff,float(value.simulation_time_s))
		if not runoff_error.is_empty(): return runoff_error
	if value.version >= 7:
		if not value.get("coral_symbiosis") is Dictionary: return "invalid_symbiosis_state"
		var symbiosis_error: String = Symbiosis.checkpoint_error(value.coral_symbiosis,float(value.simulation_time_s))
		if not symbiosis_error.is_empty(): return symbiosis_error
	if value.version >= 10:
		if not value.get("deadwood_decomposition") is Dictionary: return "invalid_deadwood_state"
		var deadwood_error: String = Deadwood.checkpoint_error(value.deadwood_decomposition,float(value.simulation_time_s))
		if not deadwood_error.is_empty(): return deadwood_error
	if value.version >= 11:
		if not value.get("schooling") is Dictionary: return "invalid_school_state"
		var school_error: String=Schooling.checkpoint_error(value.schooling,float(value.simulation_time_s))
		if not school_error.is_empty(): return school_error
	if value.version>=12:
		if not value.get("algal_grazing") is Dictionary: return "invalid_algae_state"
		var algae_error: String=AlgalGrazing.checkpoint_error(value.algal_grazing,float(value.simulation_time_s))
		if not algae_error.is_empty(): return algae_error
	if value.version>=13:
		if not value.get("desert_seed_transfer") is Dictionary: return "invalid_seed_state"
		var seed_error: String=DesertSeeds.checkpoint_error(value.desert_seed_transfer,float(value.simulation_time_s))
		if not seed_error.is_empty(): return seed_error
	if value.version>=14:
		if not value.get("zooplankton_lesson") is Dictionary: return "invalid_zooplankton_state"
		var plankton_error: String=Zooplankton.checkpoint_error(value.zooplankton_lesson,float(value.simulation_time_s))
		if not plankton_error.is_empty(): return plankton_error
	if value.version>=15:
		if not value.get("city_traffic") is Dictionary: return "invalid_city_traffic_state"
		return CityTrafficLesson.checkpoint_error(value.city_traffic,float(value.simulation_time_s))
	return ""


static func finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


func restore_checkpoint(value: Dictionary) -> bool:
	# Validate everything before mutating the sole authority; failed loads leave
	# its identity, time and pause state untouched.
	if not checkpoint_error(value).is_empty() or not science.boundary.error.is_empty(): return false
	simulation_time_s = float(value.simulation_time_s)
	time_scale = float(value.time_scale)
	paused = bool(value.paused)
	current_scale_id = str(value.current_scale_id)
	seed = int(value.seed)
	skipped_wall_time_s = float(value.skipped_wall_time_s)
	_accumulator_s = float(value.accumulator_s)
	science = Science.new()
	if value.version >= 4:
		science.restore(value.science)
	else:
		# Upgrade preserves identity/time/history; no fabricated ATP prehistory.
		science.initialize_at(simulation_time_s)
		if value.version == 3: science.legacy_oxygen = value.oxygen.duplicate(true)
	browse = Browse.new()
	if value.version >= 5: browse.restore(value.woodland_browse)
	else: browse.initialize_at(simulation_time_s)
	runoff = Runoff.new()
	if value.version >= 6: runoff.restore(value.urban_runoff)
	else: runoff.initialize_at(simulation_time_s)
	symbiosis = Symbiosis.new()
	if value.version >= 7: symbiosis.restore(value.coral_symbiosis)
	else: symbiosis.initialize_at(simulation_time_s)
	deadwood = Deadwood.new()
	if value.version >= 10: deadwood.restore(value.deadwood_decomposition)
	else: deadwood.initialize_at(simulation_time_s)
	schooling = Schooling.new()
	if value.version >= 11: schooling.restore(value.schooling)
	else: schooling.initialize_at(simulation_time_s)
	algal_grazing=AlgalGrazing.new()
	if value.version>=12: algal_grazing.restore(value.algal_grazing)
	else: algal_grazing.initialize_at(simulation_time_s)
	desert_seeds=DesertSeeds.new()
	if value.version>=13: desert_seeds.restore(value.desert_seed_transfer)
	else: desert_seeds.initialize_at(simulation_time_s)
	zooplankton=Zooplankton.new()
	if value.version>=14: zooplankton.restore(value.zooplankton_lesson)
	else: zooplankton.initialize_at(simulation_time_s)
	city_traffic=CityTrafficLesson.new()
	if value.version>=15: city_traffic.restore(value.city_traffic)
	habitat = Habitat.new()
	habitat.reference_state = science.snapshot()
	if value.version >= 2:
		habitat.restore(value.local_habitat, simulation_time_s, current_scale_id)
	else:
		# A v1 save has no recorded history. Start recording at restoration time.
		habitat.started_at_s = simulation_time_s
		habitat.advance(simulation_time_s, current_scale_id, true)
	_sync_models()

	return true


func record_observation(kind: String) -> void:
	_sync_models()
	habitat.record(kind, simulation_time_s, current_scale_id, time_scale)


func _sync_models() -> void:
	science.advance_to(simulation_time_s)
	browse.advance_to(simulation_time_s)
	runoff.advance_to(simulation_time_s)
	symbiosis.advance_to(simulation_time_s)
	deadwood.advance_to(simulation_time_s)
	schooling.advance_to(simulation_time_s)
	algal_grazing.advance_to(simulation_time_s)
	desert_seeds.advance_to(simulation_time_s)
	zooplankton.advance_to(simulation_time_s)
	habitat.reference_state = science.snapshot()
	habitat.advance(simulation_time_s, current_scale_id)


func set_scenario(value: String) -> bool:
	_sync_models()
	return science.set_mode(value)


func set_browse_protected(value: bool) -> void:
	_sync_models()
	browse.protected_left=value


func reset_browse() -> void:
	_sync_models()
	browse.initialize_at(simulation_time_s)


func set_runoff_rain(value: bool) -> void:
	_sync_models()
	runoff.raining=value


func reset_runoff() -> void:
	_sync_models()
	runoff.initialize_at(simulation_time_s)


func set_coral_heat(value: bool) -> void:
	_sync_models()
	symbiosis.heated=value


func reset_coral_symbiosis() -> void:
	_sync_models()
	symbiosis.initialize_at(simulation_time_s)


func set_deadwood_mode(value: int) -> bool:
	if value<0 or value>=Deadwood.MODES.size(): return false
	_sync_models()
	deadwood.left_mode=value
	return true


func reset_deadwood() -> void:
	_sync_models()
	deadwood.initialize_at(simulation_time_s)


func set_school_alignment(value: bool) -> void:
	_sync_models()
	schooling.alignment=value

func perturb_school() -> void:
	_sync_models()
	schooling.perturb_representative()

func reset_school() -> void:
	_sync_models()
	schooling.initialize_at(simulation_time_s)


func set_algae_enabled(value: bool) -> void:
	_sync_models()
	algal_grazing.enabled=value

func set_algae_adaptive(value: bool) -> void:
	_sync_models()
	algal_grazing.adaptive=value

func reset_algal_grazing() -> void:
	_sync_models()
	algal_grazing.initialize_at(simulation_time_s)


func set_desert_seed_active(value: bool) -> void:
	_sync_models()
	desert_seeds.active=value


func reset_desert_seed_transfer() -> void:
	_sync_models()
	desert_seeds.initialize_at(simulation_time_s)


func set_zooplankton_active(value: bool) -> void:
	_sync_models()
	zooplankton.active=value


func reset_zooplankton_lesson() -> void:
	_sync_models()
	zooplankton.initialize_at(simulation_time_s)


func set_city_traffic_profile(value: int) -> bool:
	if value<0 or value>=CityTrafficLesson.DURATIONS.size(): return false
	_sync_models()
	return city_traffic.select(value,simulation_time_s)


func reset_city_traffic() -> void:
	_sync_models()
	city_traffic.reset_at(simulation_time_s)
