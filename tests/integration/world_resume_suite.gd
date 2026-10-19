extends Node
## Two short launches of the actual experience. Never uses the user's save path.

const Experience: PackedScene = preload("res://scenes/experience.tscn")
const Store = preload("res://scripts/core/world_store.gd")
var _main: Node
var _mode: String = ""
var _directory: String = ""
var _output: String = ""
var _cases: Array[Dictionary] = []
var _failures: Array[String] = []
var _expected: Dictionary = {}
var _world_id: int


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, passed: bool) -> void:
	_cases.append({"case": label, "passed": passed})
	if not passed: _failures.append(label)
	print("WORLD_RESUME_CASE ", label, " ", passed)


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world-check="): _mode = argument.trim_prefix("--world-check=")
		if argument.begins_with("--world-dir="): _directory = argument.trim_prefix("--world-dir=")
		if argument.begins_with("--world-report="): _output = argument.trim_prefix("--world-report=")
	if _mode not in ["write", "resume"] or not _directory.is_absolute_path() or not _output.is_absolute_path():
		get_tree().quit(2)
		return
	_main = Experience.instantiate()
	add_child(_main)
	_world_id = _main.world.get_instance_id()
	# Native appearance checks may run in an unfocused window, but this suite
	# only controls functional state; it does not measure frame rate or latency.
	_main.set_process(false)
	if not await _wait_ready():
		await _finish()
		return
	if _mode == "write":
		await _write_session()
	else:
		await _resume_session()
	await _finish()


func _write_session() -> void:
	_check("fresh_session_starts_fish", _main.world.current_scale_id == "fish" and _main._store != null)
	_main.world.simulation_time_s = 37.25
	_main.world.set_paused(true)
	_main.world.set_time_scale(2.0)
	_main._toggle_reduced_motion()
	_main.soundscape.master = 0.21
	_main._muted = true
	_main._toggle_render_quality()
	_drag(Vector2(73, -20))
	_expected["fish_position"] = Store.components(_main.coordinator.active_scene.camera.position)
	_expected["fish_target"] = Store.components(_main._orbit_target)
	_main.world.set_foreground(true)
	_main.navigate_to("heart")
	if not await _wait_ready(): return
	_check("one_world_across_scale_change", _main.world.get_instance_id() == _world_id and _main.world.simulation_time_s == 37.25 and _main.world.current_scale_id == "heart")
	_main._select_heart_region("ventricle")
	if bool(_main.coordinator.active_scene.get_meta("anatomy_cutaway_active", true)): _main._toggle_cutaway()
	_drag(Vector2(-32, 11))
	_expected["heart_position"] = Store.components(_main.coordinator.active_scene.camera.position)
	_expected["heart_target"] = Store.components(_main._orbit_target)
	_main.save_button.pressed.emit()
	var stored: Store = Store.new(_directory)
	var result: Dictionary = stored.load_session()
	_check("real_save_button_persists_world", result.status == "ok" and result.payload.world.current_scale_id == "heart" and result.payload.world.simulation_time_s == 37.25)
	_main.world.simulation_time_s = 38.75
	_expected["time"] = 38.75
	_expected["fish_id"] = _main.world.TARGET_FISH_ID
	_expected["seed"] = _main.world.seed
	FileAccess.open(_directory.path_join("expected.json"), FileAccess.WRITE).store_string(JSON.stringify(_expected, "\t", true, true))
	# _finish invokes the production quit path; it must save the later time.


func _resume_session() -> void:
	_expected = JSON.parse_string(FileAccess.get_file_as_string(_directory.path_join("expected.json")))
	_check("new_process_restores_committed_scale_time_identity", _main.world.current_scale_id == "heart" and _main.world.simulation_time_s == float(_expected.time)
		and _main.world.TARGET_FISH_ID == _expected.fish_id and _main.world.seed == int(_expected.seed))
	_check("pause_multiplier_and_preferences_restored", _main.world.paused and _main.world.time_scale == 2.0
		and _main.pause_button.text == "继续时间" and _main._render_ratio == 0.75 and _main._reduced_motion and _main._muted
		and is_equal_approx(_main.soundscape.master, 0.21))
	_check("heart_camera_selection_and_cutaway_restored", _main.coordinator.active_scene.camera.position.is_equal_approx(Store.vector(_expected.heart_position))
		and _main._orbit_target.is_equal_approx(Store.vector(_expected.heart_target)) and _main.info_panel.visible
		and _main.coordinator.active_scene.get_meta("anatomy_selected_region", "") == "ventricle"
		and not bool(_main.coordinator.active_scene.get_meta("anatomy_cutaway_active", true)))
	_main.world.advance(86400.0)
	_check("no_offline_catchup", _main.world.simulation_time_s == float(_expected.time))
	_main.world.set_foreground(true)
	_main.navigate_to("fish")
	if not await _wait_ready(): return
	_check("return_restores_previous_fish_camera", _main.world.current_scale_id == "fish"
		and _main.coordinator.active_scene.camera.position.is_equal_approx(Store.vector(_expected.fish_position))
		and _main._orbit_target.is_equal_approx(Store.vector(_expected.fish_target)) and _main.world.get_instance_id() == _world_id)
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_S
	event.meta_pressed = true
	event.pressed = true
	_main.get_viewport().push_input(event, true)
	event.pressed = false
	_main.get_viewport().push_input(event, true)
	_check("command_s_routes_to_save", _main.message_label.text.contains("世界已保存"))
	# Exercise the ordinary autosave trigger without waiting 30 seconds.
	_main.world.simulation_time_s = 39.5
	_main._next_save_us = 0
	_main._process(0.0)
	var stored: Store = Store.new(_directory)
	var result: Dictionary = stored.load_session()
	_check("scheduled_save_uses_current_world", result.status == "ok" and result.payload.world.simulation_time_s == 39.5)
	var original_store: RefCounted = _main._store
	var blocked_path: String = _directory.path_join("blocked-save-directory")
	FileAccess.open(blocked_path, FileAccess.WRITE).store_string("file occupies directory")
	var blocked_store: Store = Store.new(blocked_path)
	blocked_store.load_session()
	_main._store = blocked_store
	await _main._quit()
	_check("save_failure_does_not_silently_exit", not _main._shutting_down and is_instance_valid(_main._save_failure_dialog) and _main._save_failure_dialog.visible)
	_main._save_failure_dialog.hide()
	_main._store = original_store
	_main.world.set_foreground(true)
	_main.navigate_to("heart")
	var deadline: int = Time.get_ticks_msec() + 10000
	while _main.coordinator.is_busy() and _main.coordinator.phase != _main.coordinator.Phase.AUTHORING and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check("exit_during_transition_setup", _main.coordinator.phase == _main.coordinator.Phase.AUTHORING)
	_main._on_authoring_progress(0, 0.5)
	_main.coordinator.cancel("world_resume_check")
	_check("cancelled_authoring_restores_fish_pose", _main.coordinator.active_scene.camera.position.is_equal_approx(Store.vector(_expected.fish_position)))
	_main.world.simulation_time_s = 41.0
	_main.navigate_to("heart")
	_check("quit_during_resource_loading_setup", _main.coordinator.phase == _main.coordinator.Phase.LOADING)
	# Quit cancels a loading request (which enters DRAINING). The committed fish
	# must still save with the newer time, without waiting on its resource thread.


func _drag(relative: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.relative = relative
	_main._unhandled_input(event)


func _wait_ready() -> bool:
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not _main.coordinator.is_busy() and is_instance_valid(_main.coordinator.active_scene) and _main.coordinator.active_scene.is_prepared(): return true
	_check("functional_readiness_deadline", false)
	return false


func _finish() -> void:
	var code: int = 0 if _failures.is_empty() else 1
	if _main != null: await _main._quit(code)
	if code == 0:
		var reader: Store = Store.new(_directory)
		var result: Dictionary = reader.load_session()
		if _mode == "write":
			_check("quit_saves_latest_time", result.status == "ok" and result.payload.world.simulation_time_s == 38.75)
		else:
			_check("transition_quit_keeps_last_committed_scene_pose", result.status == "ok" and result.payload.world.current_scale_id == "fish"
				and Store.vector(result.payload.observer.views.fish.position).is_equal_approx(Store.vector(_expected.fish_position))
				and result.payload.world.simulation_time_s == 41.0)
	code = 0 if _failures.is_empty() else 1
	var report: Dictionary = {"status": "passed" if code == 0 else "failed", "mode": _mode, "cases": _cases, "failures": _failures,
		"headless": DisplayServer.get_name() == "headless", "debug_build": OS.is_debug_build(), "scope": "Actual experience, UI signals and separate-process persistence. No performance tests or native pointer simulation."}
	FileAccess.open(_output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("WORLD_RESUME_RESULT ", JSON.stringify(report))
	get_tree().quit(code)
