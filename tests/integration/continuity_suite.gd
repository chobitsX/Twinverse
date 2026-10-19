extends Node
## Short real-entry workflow, isolated files, no performance measurements.

const Experience = preload("res://scenes/experience.tscn")
const Store = preload("res://scripts/core/world_store.gd")
const Habitat = preload("res://scripts/core/local_habitat.gd")
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
	print("CONTINUITY_CASE ", label, " ", passed)


func ready_stage() -> bool:
	var deadline: int = Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared(): return true
	check("stage_ready", false)
	return false


func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--continuity-check="): mode = arg.trim_prefix("--continuity-check=")
		if arg.begins_with("--world-dir="): directory = arg.trim_prefix("--world-dir=")
		if arg.begins_with("--world-report="): output = arg.trim_prefix("--world-report=")
	if mode not in ["write", "resume"] or not directory.is_absolute_path() or not output.is_absolute_path():
		get_tree().quit(2)
		return
	main = Experience.instantiate()
	add_child(main)
	main.set_process(false)
	if not await ready_stage():
		finish()
		return
	main.world.set_foreground(true)
	if mode == "write": await write_session()
	else: resume_session()
	await finish()


func write_session() -> void:
	var authority: int = main.world.get_instance_id()
	for step: int in range(120): main.world.advance(0.25)
	main._toggle_pause()
	main.observe_scale("galaxy")
	if not await ready_stage(): return
	main._toggle_pause()
	for step: int in range(40): main.world.advance(0.25)
	main._toggle_pause()
	check("target_continues_while_observing_space", main.world.habitat.snapshot(main.world.simulation_time_s, "galaxy").mode == "remote" and main.world.habitat.samples.size() >= 7)
	main._toggle_observation()
	main.observation_panel.fish_button.pressed.emit()
	if not await ready_stage(): return
	var stage: Node = main.coordinator.active_scene
	stage.set_world_time(main.world.simulation_time_s)
	check("return_fish_button_uses_current_authoritative_pose", main.world.current_scale_id == "fish" and stage.get_meta("target_node").position == Habitat.fish_position(main.world.simulation_time_s))
	main.observation_panel.journal.meta_clicked.emit("fish")
	check("history_link_does_not_rewind_time", main.world.simulation_time_s > 39.9)
	main._remember_view()
	var original: Dictionary = main.world.checkpoint()
	var original_views: Dictionary = main._views.duplicate(true)
	check("original_world_saved", main.save_world() == "ok")
	var disk_identity: String = FileAccess.get_sha256(directory.path_join("current.json"))
	main.observation_panel.restart_button.pressed.emit()
	if not await ready_stage(): return
	check("trial_starts_at_zero_on_same_authority_and_seed", main.is_trial() and main.world.simulation_time_s == 0.0 and main.world.seed == original.seed and main.world.get_instance_id() == authority and main.world.current_scale_id == "galaxy")
	main.world.advance(0.25)
	check("trial_cannot_overwrite_original", main.save_world() == "trial" and FileAccess.get_sha256(directory.path_join("current.json")) == disk_identity)
	main.toggle_trial()
	main.coordinator.cancel("continuity_cancel_return")
	if not await ready_stage(): return
	check("cancelled_return_keeps_original_checkpoint", main.is_trial() and main.save_world() == "trial" and FileAccess.get_sha256(directory.path_join("current.json")) == disk_identity)
	main.toggle_trial()
	if not await ready_stage(): return
	check("return_trial_restores_original_time_and_records", not main.is_trial() and main.world.checkpoint() == original)
	check("return_trial_restores_original_camera", main._views.galaxy == original_views.galaxy and main._orbit_target.is_equal_approx(Store.vector(original_views.fish.target)) and main.coordinator.active_scene.camera.position.is_equal_approx(Store.vector(original_views.fish.position)))
	main.observation_panel.show()
	main.observation_panel.refresh()
	main.coordinator.active_scene.set_world_time(main.world.simulation_time_s)
	if DisplayServer.get_name() != "headless":
		for frame: int in range(3): await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.get_base_dir().path_join("observation-panel.png"))
	check("final_world_and_history_saved", main.save_world() == "ok")
	FileAccess.open(directory.path_join("expected-continuity.json"), FileAccess.WRITE).store_string(JSON.stringify(original, "", true, true))


func resume_session() -> void:
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("expected-continuity.json")))
	check("new_process_restores_original_world_not_trial", not main.is_trial() and main.world.current_scale_id == "fish" and main.world.simulation_time_s == float(original.simulation_time_s) and main.world.paused)
	check("recent_events_survive_restart", main.world.habitat.events.size() == original.local_habitat.events.size() + 1 and main.world.habitat.events.back().kind == "continued")
	check("recent_movement_samples_survive_restart", main.world.habitat.samples.size() == original.local_habitat.samples.size() and main.world.habitat.samples[0].time_s == original.local_habitat.samples[0].time_s)
	main.world.advance(100.0)
	check("no_offline_or_paused_catchup", main.world.simulation_time_s == float(original.simulation_time_s))


func finish() -> void:
	var code: int = 0 if failures.is_empty() else 1
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"mode": mode, "cases": cases, "failures": failures,
		"headless": DisplayServer.get_name() == "headless", "debug_build": OS.is_debug_build(), "performance_validation": false}, "\t"))
	await main._quit(code)
