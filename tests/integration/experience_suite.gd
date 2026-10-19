extends Node
## Real experience nodes, unshortened authoring, bounded asynchronous checks.
## Shared by the project runtime entry and the editor/headless thin launcher.
## Headless runs validate logic only; GPU and Release evidence are separate.

const Catalog = preload("res://scripts/core/scale_catalog.gd")
const WorldState = preload("res://scripts/core/world_state.gd")
const Coordinator = preload("res://scripts/core/transition_coordinator.gd")
const Stage = preload("res://scripts/experience/visual_stage.gd")
const EXPERIENCE_PATH: String = "res://scenes/experience.tscn"
const NORMAL_AUTHORING_MS: float = 2800.0
const TRANSITION_TIMEOUT_MS: int = 30000
const DRAIN_TIMEOUT_MS: int = 12000
const HEROES: Array = [["earth", "atmosphere"], ["pacific", "reef"], ["fish", "heart"]]
const SMOKE_ROUTE: Array[String] = ["reef", "school", "fish", "heart", "fish", "school", "reef", "pacific"]


class EngineLog extends Logger:
	var mutex: Mutex = Mutex.new()
	var pending: Array[Dictionary] = []
	var expected_resource_path: String = ""

	func expect_resource(path: String) -> void:
		mutex.lock()
		expected_resource_path = path
		mutex.unlock()

	func take() -> Array[Dictionary]:
		mutex.lock()
		var items: Array[Dictionary] = pending
		pending = []
		mutex.unlock()
		return items

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		# May execute on loader/render threads: no scene access or logging here.
		var message: String = code + "\n" + rationale
		if message.contains("EXPERIENCE_SUITE_FAILURE "): return
		mutex.lock()
		var expected: bool = not expected_resource_path.is_empty() and message.contains(expected_resource_path) and error_type == Logger.ERROR_TYPE_ERROR
		pending.append({"function": function, "file": file, "line": line, "code": code,
			"rationale": rationale, "type": error_type, "expected_corrupt_fixture": expected,
			"ticks_us": Time.get_ticks_usec()})
		mutex.unlock()

var _main: Node
var _world: WorldState
var _coordinator: Coordinator
var _host: Node
var _suite: String = "smoke"
var _loops: int = 1
var _output_dir: String = ""
var _started_us: int = 0
var _last_time_s: float = -1.0
var _last_intent_id: int = -1
var _checks: int = 0
var _max_host_children: int = 0
var _failures: Array[String] = []
var _arrivals: Array[Dictionary] = []
var _metrics: Array[Dictionary] = []
var _fault_results: Array[Dictionary] = []
var _cycles: Array[Dictionary] = []
var _signal_events: Array[Dictionary] = []
var _expected_terminal: Dictionary = {}
var _step: String = "startup"
var _finishing: bool = false
var _engine_log: EngineLog = EngineLog.new()
var _engine_messages: Array[Dictionary] = []
var _review_captures: bool = false
var _review_images: Array[Dictionary] = []
var _ready_images: Array[Dictionary] = []
var _hero_source: String = ""


func _ready() -> void:
	OS.add_logger(_engine_log)
	_run.call_deferred()


func _run() -> void:
	_started_us = Time.get_ticks_usec()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--suite="): _suite = argument.trim_prefix("--suite=")
		elif argument.begins_with("--loops="):
			var value: String = argument.trim_prefix("--loops=")
			_loops = int(value) if value.is_valid_int() else 0
		elif argument.begins_with("--evidence-dir="): _output_dir = argument.trim_prefix("--evidence-dir=")
		elif argument == "--review-captures": _review_captures = true
		elif argument.begins_with("--hero="): _hero_source = argument.trim_prefix("--hero=")
		elif argument.begins_with("--duration=") or argument.begins_with("--capture=") or argument == "--tour":
			_check(false, "Do not combine a suite with --duration, --capture or --tour; the suite owns completion.")
	_check(_suite in ["smoke", "heroes", "path", "faults"], "Unknown suite: " + _suite)
	_check(_hero_source.is_empty() or (_suite == "heroes" and _hero_source in ["earth", "pacific", "fish"]), "--hero selects earth, pacific or fish within the heroes suite")
	_check(_loops > 0, "--loops must be a positive integer")
	_check(_output_dir.is_absolute_path(), "An absolute --evidence-dir is required")
	_check(not _review_captures or DisplayServer.get_name() != "headless", "Review captures require native rendering")
	if not _failures.is_empty():
		_output_dir = ""
		_finish()
		return
	_check(not FileAccess.file_exists(_output_dir.path_join("suite-results.json")), "Evidence directory already contains completed results; use a fresh directory")
	_check(DirAccess.make_dir_recursive_absolute(_output_dir) == OK, "Cannot create evidence directory")
	if not _failures.is_empty():
		# Do not overwrite existing results even to report a CLI error.
		_output_dir = ""
		_finish()
		return
	_checkpoint("starting")
	var packed: PackedScene = load(EXPERIENCE_PATH) as PackedScene
	_check(packed != null, "Real experience scene must load")
	if packed == null:
		_finish()
		return
	_main = packed.instantiate()
	get_tree().root.add_child(_main)
	_world = _main.world
	_coordinator = _main.coordinator
	_host = _main.scene_host
	_coordinator.intent_accepted.connect(_on_intent)
	_coordinator.interactive.connect(_on_interactive)
	_coordinator.transition_failed.connect(_on_failed)
	_coordinator.transition_cancelled.connect(_on_cancelled)
	_coordinator.metrics_recorded.connect(_on_metrics)
	_coordinator.resource_ready.connect(_on_ready)
	_coordinator.authoring_started.connect(_on_authoring)
	if not await _wait_initial():
		_finish()
		return
	_verify_active("initial", _world.current_scale_id)
	await _capture_review("initial")
	if _failures.is_empty():
		match _suite:
			"smoke": await _run_smoke()
			"heroes": await _run_heroes()
			"path": await _run_path()
			"faults": await _run_faults()
	_finish()


func _wait_initial() -> bool:
	var deadline: int = Time.get_ticks_msec() + TRANSITION_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		_collect_engine_errors()
		if not _failures.is_empty(): return false
		if is_instance_valid(_coordinator.active_scene) and _coordinator.active_scene.is_prepared():
			return true
	_check(false, "Initial scene did not become prepared within 30 s")
	return false


func _run_smoke() -> void:
	if not await _go("pacific", "smoke/setup"): return
	for cycle: int in range(_loops):
		for target: String in SMOKE_ROUTE:
			if not await _go(target, "smoke/%d/%s" % [cycle + 1, target]): return
		_complete_cycle("smoke", cycle + 1)


func _run_heroes() -> void:
	for pair: Array in HEROES:
		var a: String = pair[0]
		if not _hero_source.is_empty() and a != _hero_source: continue
		var b: String = pair[1]
		var name: String = a + "↔" + b
		if not await _go(a, "heroes/setup/" + a): return
		for cycle: int in range(_loops):
			if not await _go(b, "heroes/%s/%d/forward" % [name, cycle + 1]): return
			if not await _go(a, "heroes/%s/%d/return" % [name, cycle + 1]): return
			_complete_cycle(name, cycle + 1)


func _run_path() -> void:
	_check(Catalog.EXPLORATION_PATH.size() == 13, "Exploration path must include 13 layers with atmosphere")
	if not await _go(Catalog.EXPLORATION_PATH[0], "path/setup"): return
	for cycle: int in range(_loops):
		for index: int in range(1, Catalog.EXPLORATION_PATH.size()):
			if not await _go(Catalog.EXPLORATION_PATH[index], "path/%d/down/%d" % [cycle + 1, index]): return
		for index: int in range(Catalog.EXPLORATION_PATH.size() - 2, -1, -1):
			if not await _go(Catalog.EXPLORATION_PATH[index], "path/%d/up/%d" % [cycle + 1, index]): return
		_complete_cycle("galaxy↔atom/all_13_layers", cycle + 1)


func _go(target: String, label: String, use_next_button: bool = false) -> bool:
	_step = label
	_checkpoint("running")
	if _world.current_scale_id == target:
		_verify_active(label + "/already_here", target)
		return _failures.is_empty()
	var previous_id: int = _last_intent_id
	_expected_terminal = {}
	if use_next_button:
		_check(not _main.next_button.disabled, label + ": next UI button must be enabled")
		_main.next_button.pressed.emit()
	else:
		_main.navigate_to(target)
	_check(_last_intent_id > previous_id, label + ": navigation must emit an accepted intent")
	if _last_intent_id <= previous_id: return false
	if not await _wait_idle(TRANSITION_TIMEOUT_MS, label): return false
	_check(_expected_terminal.get("outcome", "") == "interactive", label + ": must finish with interactive signal")
	_check(_expected_terminal.get("target_id", "") == target, label + ": interactive signal must identify target")
	_check(is_equal_approx(float(_coordinator.latest_metrics.get("D_authoring_approved_ms", 0.0)), NORMAL_AUTHORING_MS), label + ": normal 2.8 s authoring must remain enabled")
	_verify_active(label, target)
	await _capture_review(label)
	return _failures.is_empty()


func _capture_review(label: String) -> void:
	if not _review_captures or not _failures.is_empty(): return
	await RenderingServer.frame_post_draw
	var file: String = "%02d-%s.png" % [_review_images.size(), _world.current_scale_id]
	var error: Error = get_viewport().get_texture().get_image().save_png(_output_dir.path_join(file))
	_check(error == OK, label + ": review image must save")
	_review_images.append({"file": file, "step": label, "scale": _world.current_scale_id,
		"simulation_time_s": _world.simulation_time_s, "elapsed_s": _elapsed_s()})
	_write_json("review-images.json", {"images": _review_images})


func _wait_idle(timeout_ms: int, label: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while _coordinator.is_busy() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		_monitor()
		if not _failures.is_empty(): return false
	_check(not _coordinator.is_busy(), label + ": bounded wait expired in phase %d" % _coordinator.phase)
	# Allow detached queue_free nodes and main's visible UI state to settle one frame.
	await get_tree().process_frame
	_monitor()
	return _failures.is_empty()


func _monitor() -> void:
	_collect_engine_errors()
	if not is_instance_valid(_coordinator.active_scene):
		_check(false, _step + ": active scene lost")
		return
	var time_s: float = _world.simulation_time_s
	_check(is_finite(time_s) and time_s >= _last_time_s, _step + ": authority time must be finite and monotonic")
	_last_time_s = time_s
	_check(str(_world.snapshot().get("target_fish_id", "")) == WorldState.TARGET_FISH_ID, _step + ": stable target fish ID changed")
	_check(_world.current_scale_id == _coordinator.active_scene.scale_id, _step + ": authority and active scale diverged")
	var child_count: int = _host.get_child_count()
	_max_host_children = maxi(_max_host_children, child_count)
	_check(child_count >= 1 and child_count <= 2, _step + ": host must own one active and at most one incoming scene")


func _verify_active(label: String, target: String) -> void:
	_monitor()
	var active: Node = _coordinator.active_scene
	_check(not _coordinator.is_busy(), label + ": coordinator must be idle")
	_check(active is Stage, label + ": active must be the actual visual stage")
	_check(_world.current_scale_id == target, label + ": wrong authority scale")
	_check(_host.get_child_count() == 1 and active.get_parent() == _host, label + ": exactly one active child must remain")
	_check(active.is_prepared(), label + ": active must be prepared")
	if not active is Stage: return
	var camera: Camera3D = active.camera
	_check(is_instance_valid(camera), label + ": real Camera3D required")
	if camera == null: return
	_check(camera.position.is_finite() and camera.global_basis.x.is_finite() and camera.global_basis.y.is_finite() and camera.global_basis.z.is_finite(), label + ": camera pose must be finite")
	_check(absf(camera.global_basis.determinant()) > 0.01, label + ": camera basis must be nonsingular")
	_check(active.target_position.is_finite(), label + ": semantic target must be finite")
	var viewport: SubViewport = active.viewport
	_check(is_instance_valid(viewport) and viewport.own_world_3d, label + ": local World3D/SubViewport required")
	var geometry: Dictionary = _geometry_counts(active.world_root)
	_check(int(geometry.mesh_instances) + int(geometry.multimesh_instances) > 0 and int(geometry.mesh_surfaces) > 0, label + ": actual 3D mesh surfaces required")
	var bound_snapshot: Dictionary = active.world_snapshot
	_check(str(bound_snapshot.get("target_fish_id", "")) == WorldState.TARGET_FISH_ID, label + ": scene bound to wrong target fish ID")
	_check(float(bound_snapshot.get("simulation_time_s", INF)) <= _world.simulation_time_s, label + ": scene snapshot time cannot be in the future")
	_arrivals.append({"step": label, "scale_id": target, "simulation_time_s": _world.simulation_time_s,
		"target_fish_id": WorldState.TARGET_FISH_ID, "active_instance_id": active.get_instance_id(),
		"host_children": _host.get_child_count(), "prepared": active.is_prepared(),
		"camera_position": _vector(camera.position), "target": _vector(active.target_position),
		"viewport_output_px": [viewport.size.x, viewport.size.y], "render_scale": viewport.scaling_3d_scale,
		"geometry": geometry, "elapsed_s": _elapsed_s()})


func _geometry_counts(node: Node) -> Dictionary:
	var count: Dictionary = {"mesh_instances": 0, "multimesh_instances": 0, "mesh_surfaces": 0}
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D and current.mesh != null:
			count.mesh_instances += 1
			count.mesh_surfaces += current.mesh.get_surface_count()
		elif current is MultiMeshInstance3D and current.multimesh != null and current.multimesh.mesh != null:
			count.multimesh_instances += current.multimesh.instance_count
			count.mesh_surfaces += current.multimesh.mesh.get_surface_count()
		for child: Node in current.get_children(): stack.append(child)
	return count


func _run_faults() -> void:
	if not await _go("reef", "faults/setup"): return
	for cycle: int in range(_loops):
		for kind: String in ["missing", "corrupt", "budget", "cancel_loading", "cancel_authoring", "prepare_timeout"]:
			if not await _fault(kind, cycle + 1): return
		_complete_cycle("faults/six_cases_plus_ui_recovery", cycle + 1)


func _fault(kind: String, cycle: int) -> bool:
	_step = "faults/%d/%s" % [cycle, kind]
	var original: Node = _coordinator.active_scene
	var original_id: int = original.get_instance_id()
	var original_scale: String = _world.current_scale_id
	_world.set_paused(true)
	var original_snapshot: Dictionary = _world.snapshot()
	var started: int = Time.get_ticks_msec()
	var request_id: int = -1
	var fixture_path: String = ""
	var expected_outcome: String = "failed"
	var expected_reason: String = ""
	_expected_terminal = {}
	match kind:
		"missing":
			expected_reason = "resource_missing"
			request_id = _coordinator.request_transition("school", "res://tests/integration/intentionally_missing_stage.tscn", 10.0, 2.8)
		"corrupt":
			expected_reason = "resource_load_failed"
			fixture_path = "user://integration_corrupt_%d_%d.tscn" % [OS.get_process_id(), cycle]
			var corrupt: FileAccess = FileAccess.open(fixture_path, FileAccess.WRITE)
			_check(corrupt != null, _step + ": corrupt fixture must be written")
			if corrupt == null: return false
			corrupt.store_string("[gd_scene format=3]\n[node name=\"Broken\" type=\"Node3D\"]\nposition = Vector3(BROKEN)\n")
			corrupt.close()
			_engine_log.expect_resource(fixture_path)
			request_id = _coordinator.request_transition("school", fixture_path, 10.0, 2.8)
		"budget":
			expected_reason = "resource_budget_rejected"
			request_id = _coordinator.request_transition("school", "res://scenes/experience/ocean_stage.tscn", _coordinator.overlap_budget_mb + 1.0, 2.8)
		"cancel_loading":
			expected_outcome = "cancelled"
			expected_reason = "suite_cancel_loading"
			_main.navigate_to("school")
			request_id = _last_intent_id
			_check(_coordinator.phase == Coordinator.Phase.LOADING, _step + ": cancel must happen in loading phase")
			_coordinator.cancel(expected_reason)
		"cancel_authoring":
			expected_outcome = "cancelled"
			expected_reason = "suite_cancel_authoring"
			_main.navigate_to("school")
			request_id = _last_intent_id
			var deadline: int = Time.get_ticks_msec() + TRANSITION_TIMEOUT_MS
			while _coordinator.phase != Coordinator.Phase.AUTHORING and _coordinator.is_busy() and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
				_monitor()
			_check(_coordinator.phase == Coordinator.Phase.AUTHORING, _step + ": real incoming stage must reach authoring before cancellation")
			_check(_host.get_child_count() == 2, _step + ": both true visual stages must exist before cancellation")
			# Exercise moved cameras and overlapping layers, not only the first authoring tick.
			var authoring_deadline: int = Time.get_ticks_msec() + 350
			while _coordinator.phase == Coordinator.Phase.AUTHORING and Time.get_ticks_msec() < authoring_deadline:
				await get_tree().process_frame
				_monitor()
			_coordinator.cancel(expected_reason)
		"prepare_timeout":
			expected_reason = "preparation_timeout"
			fixture_path = "res://tests/core/fixture_never_prepared.tscn"
			request_id = _coordinator.request_transition("school", fixture_path, 1.0, 2.8, 500)
	_check(request_id >= 0, _step + ": fault request must be admitted to coordinator")
	var returned_idle: bool = await _wait_idle(DRAIN_TIMEOUT_MS, _step)
	_engine_log.expect_resource("")
	if fixture_path.begins_with("user://"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	_check(returned_idle, _step + ": fault must drain to idle within 12 s")
	_check(_expected_terminal.get("outcome", "") == expected_outcome, _step + ": wrong terminal outcome")
	_check(_expected_terminal.get("reason", "") == expected_reason, _step + ": wrong terminal reason")
	_check(_coordinator.active_scene.get_instance_id() == original_id, _step + ": failure/cancellation must retain original active instance")
	_check(_world.snapshot() == original_snapshot, _step + ": paused authority snapshot must not change on failure/cancellation")
	_check(not _main.message_label.text.is_empty(), _step + ": main UI must show recovery feedback")
	_verify_active(_step + "/retained", original_scale)
	var fault_record: Dictionary = {"kind": kind, "cycle": cycle, "outcome": _expected_terminal.duplicate(true),
		"elapsed_until_idle_ms": Time.get_ticks_msec() - started, "retained_instance_id": original_id,
		"retained_scale_id": original_scale, "authority_unchanged": _world.snapshot() == original_snapshot,
		"ui_feedback": _main.message_label.text, "fixture_path": fixture_path,
		"fixture_is_gpu_load_test": false, "recovery_via_ui_button": false}
	_fault_results.append(fault_record)
	_world.set_paused(false)
	if not _failures.is_empty(): return false
	# Emit the real button's signal, using its normal bound navigation callback.
	# This checks UI wiring and recovery; it does not claim pointer-hit or accessibility QA.
	if not await _go("school", _step + "/UI-recovery", true): return false
	fault_record.recovery_via_ui_button = true
	if not await _go("reef", "faults/%d/%s/return" % [cycle, kind]): return false
	return _failures.is_empty()


func _on_intent(request_id: int, target_id: String) -> void:
	_last_intent_id = request_id
	_signal_events.append({"event": "intent", "request_id": request_id, "target_id": target_id, "elapsed_s": _elapsed_s()})


func _on_interactive(request_id: int, target_id: String, _active: Node) -> void:
	_expected_terminal = {"outcome": "interactive", "request_id": request_id, "target_id": target_id}


func _on_failed(request_id: int, reason: String) -> void:
	_expected_terminal = {"outcome": "failed", "request_id": request_id, "reason": reason}


func _on_cancelled(request_id: int, reason: String) -> void:
	_expected_terminal = {"outcome": "cancelled", "request_id": request_id, "reason": reason}


func _on_metrics(record: Dictionary) -> void:
	var item: Dictionary = record.duplicate(true)
	item["suite_step"] = _step
	_metrics.append(item)


func _on_ready(request_id: int, incoming: Node) -> void:
	_check(incoming is Stage and incoming.is_prepared(), _step + ": resource_ready requires a prepared true visual stage")
	_signal_events.append({"event": "resource_ready", "request_id": request_id, "elapsed_s": _elapsed_s(), "host_children": _host.get_child_count()})
	_checkpoint("running")
	if _review_captures and incoming is Stage and _failures.is_empty():
		var file: String = "ready-%02d-%s.png" % [request_id, incoming.scale_id]
		var pixels: Image = incoming.viewport.get_texture().get_image()
		var error: Error = pixels.save_png(_output_dir.path_join(file))
		_check(error == OK and not pixels.is_empty(), _step + ": prepared viewport image must be readable")
		_ready_images.append({"file": file, "scale": incoming.scale_id, "step": _step,
			"elapsed_s": _elapsed_s(), "width": pixels.get_width(), "height": pixels.get_height()})


func _on_authoring(request_id: int, _outgoing: Node, _incoming: Node, duration_s: float) -> void:
	_check(is_equal_approx(duration_s, 2.8), _step + ": authoring duration was shortened")
	_check(_host.get_child_count() == 2, _step + ": authoring must retain old plus new real stages")
	_signal_events.append({"event": "authoring_started", "request_id": request_id, "duration_s": duration_s, "elapsed_s": _elapsed_s()})


func _complete_cycle(route: String, cycle: int) -> void:
	_cycles.append({"route": route, "round_trip": cycle, "elapsed_s": _elapsed_s(), "ending_scale": _world.current_scale_id})
	_checkpoint("running")
	print("SUITE_CYCLE ", JSON.stringify(_cycles.back()))


func _checkpoint(status: String) -> void:
	if _output_dir.is_empty(): return
	_write_json("suite-progress.json", {"status": status, "suite": _suite, "requested_loops": _loops,
		"current_step": _step, "elapsed_s": _elapsed_s(), "completed_round_trips": _cycles,
		"arrivals": _arrivals.size(), "transition_records": _metrics.size(), "failures": _failures,
		"pid": OS.get_process_id(), "headless": DisplayServer.get_name() == "headless",
		"phase": _coordinator.phase if is_instance_valid(_coordinator) else -1,
		"metrics": _metrics, "signals": _signal_events})


func _finish() -> void:
	if _finishing: return
	_finishing = true
	_collect_engine_errors()
	var status: String = "passed" if _failures.is_empty() else "failed"
	var report: Dictionary = {"schema_version": 1, "suite": _suite, "status": status, "suite_implementation": "Node",
		"requested_loops": _loops, "elapsed_s": _elapsed_s(), "checks": _checks,
		"headless": DisplayServer.get_name() == "headless", "renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "engine": Engine.get_version_info(),
		"debug_build": OS.is_debug_build(), "arm64": OS.has_feature("arm64"), "command_line": OS.get_cmdline_args(), "user_arguments": OS.get_cmdline_user_args(),
		"authoring_ms": NORMAL_AUTHORING_MS, "max_host_children": _max_host_children,
		"target_fish_id": WorldState.TARGET_FISH_ID, "failures": _failures, "round_trips": _cycles,
		"arrivals": _arrivals, "transitions": _metrics, "signals": _signal_events, "faults": _fault_results,
		"engine_messages": _engine_messages,
		"review_images": _review_images,
		"prepared_images": _ready_images,
		"limits": ["Headless validates scene/state logic only; it does not render Metal or prove quality/performance.",
			"A passed suite is not stage-0 Gate acceptance, RSS plateau proof, or GPU timing acceptance.",
			"Camera/mesh checks prove finite structure, not pleasing framing or visible imagery.",
			"Fault timeout uses a lightweight never-ready fixture; only retained/recovery scenes are production visual stages.",
			"Main-loop deadlines cannot interrupt a synchronous engine stall; an external wall-time supervisor is required."]}
	if not _output_dir.is_empty():
		_write_json("suite-results.json", report)
		_checkpoint(status)
	print("EXPERIENCE_SUITE_RESULT ", JSON.stringify({"status": status, "suite": _suite, "checks": _checks, "failures": _failures, "elapsed_s": _elapsed_s(), "evidence_dir": _output_dir, "headless": DisplayServer.get_name() == "headless"}))
	var code: int = 0 if _failures.is_empty() else 1
	if is_instance_valid(_main):
		# The main owner drains its recorder writer thread before exiting.
		await _main.call("_quit", code)
		# Release the suite's typed references after the main owner has finished
		# its asynchronous shutdown, including recorder and audio cleanup.
		_main.free()
		_main = null
		_world = null
		_coordinator = null
		_host = null
	else:
		get_tree().quit(code)
	OS.remove_logger(_engine_log)
	_engine_log = null


func _collect_engine_errors() -> void:
	if _engine_log == null: return
	for item: Dictionary in _engine_log.take():
		_engine_messages.append(item)
		if not item.expected_corrupt_fixture and int(item.type) != Logger.ERROR_TYPE_WARNING:
			_check(false, "Unexpected engine error: %s %s at %s:%d" % [item.code, item.rationale, item.file, item.line])


func _write_json(filename: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(_output_dir.path_join(filename), FileAccess.WRITE)
	if file == null:
		_check(false, "Evidence write failed: " + filename)
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.close()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition and message not in _failures:
		_failures.append(message)
		push_error("EXPERIENCE_SUITE_FAILURE " + message)


func _elapsed_s() -> float:
	return float(Time.get_ticks_usec() - _started_us) / 1000000.0


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
