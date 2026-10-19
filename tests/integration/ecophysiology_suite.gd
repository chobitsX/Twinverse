extends Node
## Actual entry, short controlled workflow, isolated persistence. No performance measurements.
const Experience = preload("res://scenes/experience.tscn")
const Model = preload("res://scripts/core/ecophysiology.gd")
const World = preload("res://scripts/core/world_state.gd")
var main: Node
var mode: String
var directory: String
var output: String
var cases: Array[Dictionary] = []
var failures: Array[String] = []

func _ready() -> void: run.call_deferred()

func check(label: String, passed: bool) -> void:
	cases.append({"case": label, "passed": passed})
	if not passed: failures.append(label)
	print("CHAIN_CASE ", label, " ", passed)

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

func ready_stage() -> bool:
	var deadline: int = Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared(): return true
	check("stage_ready", false)
	return false

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage2-check="): mode = arg.trim_prefix("--stage2-check=")
		if arg.begins_with("--oxygen-check="): mode = arg.trim_prefix("--oxygen-check=")
		if arg.begins_with("--world-dir="): directory = arg.trim_prefix("--world-dir=")
		if arg.begins_with("--world-report="): output = arg.trim_prefix("--world-report=")
	if mode not in ["write", "resume"] or not directory.is_absolute_path() or not output.is_absolute_path():
		get_tree().quit(2)
		return
	main = Experience.instantiate()
	add_child(main)
	main.set_process(false)
	if not await ready_stage():
		await finish()
		return
	main.world.set_foreground(true)
	if mode == "write": await write_session()
	else: await resume_session()
	await finish()

func capture(name_value: String) -> void:
	main._process(0.0)
	main.observation_panel.refresh()
	if DisplayServer.get_name() == "headless": return
	for frame: int in range(3): await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.get_base_dir().path_join(name_value + ".png"))

func advance(seconds: int) -> void:
	main.world.set_paused(false)
	main.world.set_foreground(true)
	main.world.set_time_scale(4.0)
	for step: int in range(seconds): main.world.advance(0.25)
	main.world.set_paused(true)
	main.pause_button.text = "继续时间"
	main.observation_panel.refresh()

func write_session() -> void:
	var panel: Node = main.observation_panel.oxygen_view
	main._toggle_observation()
	panel.scenario.item_selected.emit(Model.MODES.find("normal"))
	advance(100)
	var normal: Dictionary = main.world.science.snapshot()
	check("panel_exposes_seven_controlled_scenarios_and_frozen_boundary", panel.scenario.item_count == 7 and panel.details.text.contains("26.762") and main.world.science.error.is_empty())
	panel.scenario.item_selected.emit(Model.MODES.find("hypoxia"))
	advance(190)
	var low: Dictionary = main.world.science.snapshot()
	check("ui_hypoxia_propagates_to_whole_chain", low.gill < normal.gill and low.cell_oxygen < normal.cell_oxygen and low.atp < normal.atp and panel.values.text.contains("ATP"))
	check("charts_contain_actual_authoritative_history", panel.water_trace.samples.size() > 40 and panel.atp_trace.samples == main.world.science.samples and panel.uptake_trace.field == "cell_oxygen")
	check("causal_events_show_source_and_downstream_values", panel.events.text.contains("循环供氧下降") and panel.events.text.contains("供给/需求"))
	await capture("83-chain-low")
	var identity: int = main.world.science.get_instance_id()
	var saved_time: float = main.world.simulation_time_s
	for scale: String in ["reef", "fish", "heart", "cardiomyocyte", "mitochondrion", "molecule", "atom", "fish"]:
		main.observe_scale(scale)
		if not await ready_stage(): return
		main._process(0)
		check("path_" + scale + "_keeps_world_and_model", main.world.current_scale_id == scale and main.world.simulation_time_s == saved_time and main.world.science.get_instance_id() == identity)
		var stage: Node = main.coordinator.active_scene
		if scale == "heart":
			var matched: bool = false
			for material: ShaderMaterial in stage.materials:
				if material.shader.resource_path.ends_with("anatomy_tissue.gdshader"):
					matched = is_equal_approx(float(material.get_shader_parameter("reference_beat")), low.beat_phase)
					break
			check("heart_material_uses_saved_continuous_model_phase", matched)
			main.observation_panel.hide()
			await capture("83-heart-reference")
			main.observation_panel.show()
		if scale == "mitochondrion":
			var matched: bool = false
			for material: ShaderMaterial in stage.materials:
				if material.shader.resource_path.ends_with("micro_particles.gdshader"):
					matched = is_equal_approx(float(material.get_shader_parameter("world_time")), low.flux_phase)
					break
			check("mitochondrial_process_uses_atp_flux_phase", matched)
			await capture("83-mito-reference")
		if scale == "atom":
			var fixed_structure: bool = str(stage.get_meta("scientific_label", "")).contains("概率")
			for material: ShaderMaterial in stage.materials:
				fixed_structure = fixed_structure and is_equal_approx(float(material.get_shader_parameter("world_time")), saved_time)
			check("atom_keeps_explanatory_structure_and_world_time", fixed_structure)
	panel.scenario.item_selected.emit(Model.MODES.find("risk"))
	advance(5)
	main._process(0)
	var fish_moved: bool = false
	for item: Dictionary in main.coordinator.active_scene.animated_nodes:
		if item.get("kind") == "target_fish": fish_moved = item.node.position.x < 0.35
	check("risk_button_drives_visible_target_escape", main.world.science.behavior == "escape" and fish_moved)
	advance(10)
	check("risk_proceeds_to_shelter_without_reset", main.world.science.behavior == "shelter" and main.world.science.started_at_s == 0.0)
	panel.scenario.item_selected.emit(Model.MODES.find("normal"))
	advance(180)
	check("recovery_returns_cell_oxygen_and_atp", main.world.science.state.cell_oxygen > 0.95 and main.world.science.state.atp > low.atp)
	await capture("83-chain-recovery")
	panel.details.show()
	panel.budgets.show()
	check("offline_explanation_covers_sources_unknowns_and_conservation", panel.details.text.contains("未做物种标定") and panel.details.text.contains("营养盐") and panel.details.text.contains("10.1152/japplphysiol.00736.2014") and panel.budgets.text.contains("ATP+ADP = 20"))
	await get_tree().process_frame
	panel.get_parent().ensure_control_visible(panel.budgets)
	await capture("83-source-budgets")
	panel.details.hide()
	panel.budgets.hide()
	panel.get_parent().scroll_vertical = 0
	main.observation_panel.tabs.current_tab = 1
	check("existing_journal_still_supports_activity_and_visits", main.observation_panel.trace.samples.size() > 0 and main.observation_panel.journal.text.contains("到达"))
	main.observation_panel.tabs.current_tab = 0
	var original: Dictionary = main.world.checkpoint()
	check("v4_world_written", main.save_world() == "ok")
	var sha: String = FileAccess.get_sha256(directory.path_join("current.json"))
	main.toggle_trial()
	if not await ready_stage(): return
	check("trial_protects_original_file_and_restarts_reference_model", main.is_trial() and main.world.science.started_at_s == 0.0 and main.world.science.steps == 0 and main.save_world() == "trial" and FileAccess.get_sha256(directory.path_join("current.json")) == sha)
	main.toggle_trial()
	if not await ready_stage(): return
	check("return_from_trial_restores_all_pools_phase_and_history", not main.is_trial() and equivalent(main.world.checkpoint(), original))
	if DisplayServer.get_name() != "headless":
		var original_size: Vector2i = get_window().size
		get_window().size = Vector2i(1280, 720)
		await capture("83-compact")
		var rect: Rect2 = main.observation_panel.get_global_rect()
		check("compact_panel_inside_viewport_and_scrollable", rect.position.x >= 0 and rect.end.x <= 1280 and rect.position.y >= 0 and rect.end.y <= 720 and panel.get_parent().get_v_scroll_bar().max_value > panel.get_parent().get_v_scroll_bar().page)
		get_window().size = original_size
	check("final_native_checkpoint_saved", main.save_world() == "ok")
	FileAccess.open(directory.path_join("expected-chain.json"), FileAccess.WRITE).store_string(JSON.stringify(main.world.checkpoint(), "", true, true))

func resume_session() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("expected-chain.json")))
	check("new_process_restores_v4_clock_identity_and_pause", main.world.paused and absf(main.world.simulation_time_s - expected.simulation_time_s) < 1.0e-9 and expected.target_fish_id == World.TARGET_FISH_ID)
	check("separate_process_restores_all_chain_pools_and_history", equivalent(main.world.science.checkpoint(), expected.science))
	main._toggle_observation()
	main.observation_panel.refresh()
	check("restored_panel_contains_live_atp_and_chain", main.observation_panel.oxygen_view.values.text.contains("ATP") and main.observation_panel.oxygen_view.atp_trace.samples.size() == main.world.science.samples.size())
	var panel: Node = main.observation_panel.oxygen_view
	check("offline_explanation_covers_sources_unknowns_and_conservation", panel.details.text.contains("未做物种标定") and panel.details.text.contains("营养盐") and panel.details.text.contains("10.1152/japplphysiol.00736.2014") and panel.budgets.text.contains("ATP+ADP = 20"))
	var old_steps: int = main.world.science.steps
	advance(2)
	check("resumed_chain_advances_from_saved_fractional_step", main.world.science.steps == old_steps + 20 and main.world.science.error.is_empty())
	check("resumed_v4_can_save_again", main.save_world() == "ok")

func finish() -> void:
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"mode": mode, "cases": cases, "failures": failures,
		"headless": DisplayServer.get_name() == "headless", "debug_build": OS.is_debug_build(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "primary_screen": DisplayServer.get_primary_screen() if DisplayServer.get_name() != "headless" else -1,
		"window_screen": get_window().current_screen, "window_unfocusable": get_window().unfocusable,
		"output_px": [get_window().size.x, get_window().size.y], "species_calibration": false, "performance_validation": false}, "\t"))
	await main._quit(0 if failures.is_empty() else 1)
