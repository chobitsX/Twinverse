extends SceneTree
const Model = preload("res://scripts/core/ecophysiology.gd")
const World = preload("res://scripts/core/world_state.gd")
const Oxygen = preload("res://scripts/core/oxygen_model.gd")
var cases: Array[Dictionary] = []
var failures: Array[String] = []
var comparisons: Dictionary = {}

func check(label: String, passed: bool) -> void:
	cases.append({"case": label, "passed": passed})
	if not passed: failures.append(label)

static func equivalent(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int): return absf(float(a) - float(b)) < 1.0e-9
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not equivalent(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i: int in range(a.size()):
			if not equivalent(a[i], b[i]): return false
		return true
	return a == b

func _initialize() -> void:
	var normal: Model = Model.new()
	normal.set_mode("normal")
	normal.advance_to(100.0)
	check("regional_frozen_inputs_reach_running_chain", normal.state.salinity == 35.156 and normal.state.temperature == 26.762 and normal.state.water > 200.0 and normal.state.light > 0.9)
	check("hand_calculated_gill_demand_example", is_equal_approx(0.65 + 0.65 * 0.4, 0.91) and is_equal_approx(1.5 * 15.0 / 25.0, 0.9) and is_equal_approx(1.5 * 6.0 / 25.0, 0.36))
	check("hand_calculated_atp_capacity", absf(0.22 / 1.15 * 4.0 / 6.0 - 0.127536231884) < 1.0e-10)
	check("one_time_constant_relaxation_example", absf(Model.relax(0.0, 1.0, 8.0, 8.0) - (1.0 - exp(-1.0))) < 1.0e-12)
	check("cycle_keyframes", Model.cycle_factor(0) == 1.0 and Model.cycle_factor(100) == 0.06 and Model.cycle_factor(300) == 1.0 and absf(Model.cycle_factor(70) - 0.53) < 1.0e-12)
	var low: Model = Model.new()
	low.set_mode("hypoxia")
	low.advance_to(4.0)
	check("upstream_changes_before_cell_proxy", low.state.water < 155 and low.state.cell_oxygen > 0.98)
	low.advance_to(200.0)
	check("hypoxia_reaches_gill_circulation_cell_and_atp", low.state.gill < normal.state.gill * 0.5 and low.state.blood < 0.6 and low.state.cell_oxygen < 0.42 and low.state.atp < normal.state.atp - 2.0)
	check("hypoxia_selects_rest_and_reduces_relative_heart_rate", low.behavior == "rest" and low.state.activity < 0.2 and low.state.heart_rate < normal.state.heart_rate)
	check("low_oxygen_changes_reef_proxies", low.state.coral < normal.state.coral and low.state.producer < normal.state.producer)
	check("oxygen_supply_is_allocated_not_whole_fish_equals_heart", low.state.oxygen_use <= low.state.oxygen_supply and low.state.oxygen_supply < low.state.gill * 0.05 and low.state.oxygen_other > 0)
	var old_atp: float = low.state.atp
	var old_phase: float = low.state.beat_phase
	low.set_mode("normal")
	check("switching_input_does_not_reset_pools_or_phase", low.state.atp == old_atp and low.state.beat_phase == old_phase and low.at_s() == 200.0)
	low.advance_to(400.0)
	check("recovery_reaches_atp_and_retains_causal_history", low.state.cell_oxygen > 0.95 and low.state.atp > old_atp + 1.0 and low.events.any(func(e: Dictionary) -> bool: return e.kind == "oxygen_recovered"))
	var risk: Model = Model.new()
	risk.set_mode("risk")
	risk.advance_to(5.0)
	check("risk_drives_escape_and_opposite_position", risk.behavior == "escape" and risk.state.activity > 0.8 and risk.state.offset_x < -0.01)
	risk.advance_to(20.0)
	check("shelter_and_companion_aggregation_are_active", risk.behavior == "shelter" and risk.companion_behavior == "shelter" and risk.state.companion_activity < 0.3 and risk.state.food_eaten == 0.0)
	var food: Model = Model.new()
	food.set_mode("food")
	food.advance_to(100.0)
	check("food_increases_resource_and_energy_with_grazing_feedback", food.state.food > normal.state.food and food.state.energy > normal.state.energy and food.state.food_eaten > 0.0 and food.state.energy_intake > 0.0)
	var shade: Model = Model.new()
	shade.set_mode("shade")
	shade.advance_to(100.0)
	check("shade_changes_producers_and_rest", shade.state.light < 0.1 and shade.state.producer < normal.state.producer and shade.behavior == "rest")
	var warm: Model = Model.new()
	warm.set_mode("warm")
	warm.advance_to(100.0)
	check("warming_increases_temperature_and_metabolic_demand", warm.state.temperature > 29.0 and warm.state.fish_demand > normal.state.fish_demand and warm.state.demand > normal.state.demand)
	var reference: Model = Model.new()
	var fine: Model = Model.new()
	fine.step_s = 0.05
	var max_difference: Dictionary = {"water": 0.0, "cell_oxygen": 0.0, "atp": 0.0, "energy": 0.0}
	var balances: bool = true
	for t: int in range(1, 301):
		reference.advance_to(float(t))
		fine.advance_to(float(t))
		for key: String in max_difference: max_difference[key] = maxf(max_difference[key], absf(reference.state[key] - fine.state[key]))
		balances = balances and reference.error.is_empty() and absf(reference.state.atp + reference.state.adp - 20.0) < 1.0e-10 and reference.state.oxygen_use <= reference.state.oxygen_supply + 1.0e-12
	comparisons = max_difference
	check("all_cycle_states_finite_in_range_and_conserved", balances)
	check("step_halving_comparison_with_declared_tolerances", max_difference.water < 0.25 and max_difference.cell_oxygen < 0.01 and max_difference.atp < 0.1 and max_difference.energy < 0.1)
	check("behavior_hysteresis_avoids_repeated_threshold_chatter", reference.events.size() < 15)
	var stressed: Model = Model.new()
	stressed.set_mode("hypoxia")
	stressed.advance_to(1000.0) # Fast numerical horizon, no wall-clock or rendered stability run.
	check("reference_reserve_stress_reaches_health_without_inventing_death", stressed.state.health < 1.0 and stressed.state.health >= 0.0 and stressed.state.atp >= 0.0 and stressed.error.is_empty())
	check("history_is_bounded", stressed.samples.size() == 180 and stressed.events.size() <= 64)
	var world: World = World.new()
	world.set_time_scale(4.0)
	for i: int in range(121): world.advance(0.125)
	var saved: Dictionary = world.checkpoint()
	var resumed: World = World.new()
	check("v4_json_roundtrip_keeps_fractional_model_step", resumed.restore_checkpoint(JSON.parse_string(JSON.stringify(saved, "", true, true))) and equivalent(saved, resumed.checkpoint()))
	world.current_scale_id = "galaxy"
	resumed.current_scale_id = "fish"
	for i: int in range(200):
		world.advance(0.1)
		resumed.advance(0.1)
	check("offscreen_and_focused_coupled_state_are_identical", equivalent(world.science.checkpoint(), resumed.science.checkpoint()))
	world.set_paused(true)
	saved = world.checkpoint()
	world.advance(99)
	check("pause_freezes_chain_and_journal", equivalent(saved, world.checkpoint()))
	world.set_paused(false)
	world.set_foreground(false)
	saved = world.checkpoint()
	world.advance(99)
	check("window_unavailable_freezes_chain", equivalent(saved, world.checkpoint()))
	for version: int in [1, 2, 3]:
		var legacy: Dictionary = saved.duplicate(true)
		legacy.version = version
		legacy.model_version = World.V3_MODEL_VERSION if version == 3 else World.LEGACY_MODEL_VERSION
		legacy.erase("science")
		if version == 1: legacy.erase("local_habitat")
		if version == 3:
			var old: Oxygen = Oxygen.new()
			old.advance(0.0)
			old.advance(legacy.simulation_time_s)
			legacy.oxygen = old.checkpoint()
		check("v%d_upgrade_preserves_world_and_starts_real_chain_history_now" % version, resumed.restore_checkpoint(legacy) and resumed.simulation_time_s == legacy.simulation_time_s and resumed.science.started_at_s == legacy.simulation_time_s and resumed.science.samples.size() == 1)
		if version == 3: check("v3_oxygen_history_is_preserved_as_legacy_not_atp", equivalent(resumed.science.legacy_oxygen, legacy.oxygen) and resumed.science.events.is_empty())
	saved = resumed.checkpoint()
	var invalid_cases: Array[Dictionary] = []
	for pair: Array in [["atp", -1.0], ["cell_oxygen", NAN], ["adp", 19.0], ["oxygen_supply", 100.0], ["water_error", 0.01]]:
		var bad: Dictionary = saved.duplicate(true)
		bad.science.state[pair[0]] = pair[1]
		invalid_cases.append(bad)
	var bad: Dictionary = saved.duplicate(true)
	bad.science.samples[0].time_s += 1.0
	invalid_cases.append(bad)
	bad = saved.duplicate(true)
	bad.science.mode = "unreviewed"
	invalid_cases.append(bad)
	bad = saved.duplicate(true)
	bad.science.boundary_id = "future"
	invalid_cases.append(bad)
	bad = saved.duplicate(true)
	bad.science.steps += 2
	invalid_cases.append(bad)
	var rejected: bool = true
	for invalid: Dictionary in invalid_cases: rejected = rejected and not resumed.restore_checkpoint(invalid) and equivalent(saved, resumed.checkpoint())
	check("invalid_state_units_versions_time_history_rejected_atomically", rejected)
	var snapshot: Dictionary = resumed.snapshot()
	snapshot.science.atp = -10
	check("views_cannot_mutate_scientific_authority", resumed.science.state.atp >= 0.0)
	var slow: World = World.new()
	var fast: World = World.new()
	fast.set_time_scale(4.0)
	for i: int in range(240): slow.advance(0.25)
	for i: int in range(60): fast.advance(0.25)
	check("time_multipliers_reach_identical_coupled_state", equivalent(slow.science.checkpoint(), fast.science.checkpoint()))
	check("paused_scenario_changes_only_future_input", resumed.set_scenario("risk") and resumed.science.state == saved.science.state)
	var report: Dictionary = {"cases": cases, "failures": failures, "step_halving_max_absolute_difference": comparisons, "species_calibration": false, "performance_validation": false}
	var report_path: String = "res://docs/evidence/M2-004/model-tests.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--science-report="): report_path=argument.trim_prefix("--science-report=")
	FileAccess.open(report_path, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("ECOPHYSIOLOGY_RESULT ", cases.size(), " cases; failures=", failures, " differences=", comparisons)
	quit(0 if failures.is_empty() else 1)
